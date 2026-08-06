defmodule Twitchy.EventSub.Webhook do
  @moduledoc """
  EventSub Webhook verification and processing.

  Handles EventSub webhook requests with HMAC-SHA256 signature verification,
  challenge response, and message timestamp validation.

  ## Security

  All webhook requests are verified using HMAC-SHA256 signatures. The signature
  is computed from:
  - Message ID (from `Twitch-Eventsub-Message-Id` header)
  - Timestamp (from `Twitch-Eventsub-Message-Timestamp` header)
  - Request body (raw JSON string)

  Requests are rejected if:
  - Signature doesn't match
  - Timestamp is older than 10 minutes
  - Message ID has been seen before (replay attack prevention)

  ## Usage

      # In your Phoenix controller or plug
      def handle_webhook(conn, _params) do
        secret = "your_webhook_secret"

        case Twitchy.EventSub.Webhook.verify_and_process(conn, secret) do
          {:ok, :challenge, challenge} ->
            # Respond to challenge
            conn
            |> put_resp_content_type("text/plain")
            |> send_resp(200, challenge)

          {:ok, :notification, event} ->
            # Process notification
            MyApp.EventProcessor.process(event)
            send_resp(conn, 200, "")

          {:ok, :revocation, event} ->
            # Handle revocation
            MyApp.EventProcessor.handle_revocation(event)
            send_resp(conn, 200, "")

          {:error, error_reason} ->
            # Log and reject
            Logger.error("Webhook verification failed: " <> inspect(error_reason))
            send_resp(conn, 403, "")
        end
      end

  ## Telemetry Events

  - `[:twitchy, :eventsub, :webhook, :challenge]` - Challenge verification
  - `[:twitchy, :eventsub, :webhook, :notification]` - Event notification received
  - `[:twitchy, :eventsub, :webhook, :revocation]` - Subscription revoked
  - `[:twitchy, :eventsub, :webhook, :error]` - Verification or processing error
  """

  require Logger
  import Bitwise

  @type message_type :: :challenge | :notification | :revocation
  @type verification_result ::
          {:ok, message_type(), map() | String.t()} | {:error, atom() | String.t()}

  @max_message_age_seconds 600

  @doc """
  Verifies and processes an EventSub webhook request.

  ## Parameters

  - `conn` - Plug.Conn struct with the webhook request
  - `secret` - Webhook secret used for signature verification
  - `opts` - Options (optional)
    - `:skip_timestamp_check` - Skip timestamp validation (default: false, for testing only)
    - `:seen_message_ids` - Agent/ETS process for replay attack prevention

  ## Returns

  - `{:ok, :challenge, challenge_string}` - Challenge verification request
  - `{:ok, :notification, event_map}` - Event notification
  - `{:ok, :revocation, event_map}` - Subscription revocation
  - `{:error, reason}` - Verification failed

  ## Examples

      case Twitchy.EventSub.Webhook.verify_and_process(conn, "my_secret") do
        {:ok, :challenge, challenge} -> {:challenge, challenge}
        {:ok, :notification, event} -> {:notification, event}
        {:ok, :revocation, event} -> {:revocation, event}
        {:error, reason} -> {:error, reason}
      end
  """
  @spec verify_and_process(Plug.Conn.t(), String.t(), keyword()) :: verification_result()
  def verify_and_process(conn, secret, opts \\ []) do
    with {:ok, headers} <- extract_headers(conn),
         {:ok, body} <- read_body(conn),
         :ok <- verify_signature(headers, body, secret),
         :ok <- verify_timestamp_from_headers(headers, opts),
         :ok <- check_message_replay(headers, opts),
         {:ok, message_type, payload} <- parse_message(body, headers) do
      emit_telemetry(message_type, %{}, %{
        message_id: headers.message_id,
        subscription_type: headers.subscription_type,
        subscription_version: headers.subscription_version
      })

      {:ok, message_type, payload}
    else
      {:error, reason} = error ->
        emit_telemetry(:error, %{}, %{reason: reason})
        error
    end
  end

  @doc """
  Verifies the HMAC-SHA256 signature of a webhook request.

  ## Parameters

  - `message_id` - Message ID from header
  - `timestamp` - Timestamp from header
  - `body` - Raw request body (JSON string)
  - `signature` - Signature from header
  - `secret` - Webhook secret

  ## Examples

      Twitchy.EventSub.Webhook.verify_signature(
        "msg-id",
        "2024-12-19T12:00:00Z",
        ~s({"key": "value"}),
        "sha256=abc123...",
        "my_secret"
      )
      # => :ok or {:error, :invalid_signature}
  """
  @spec verify_signature(String.t(), String.t(), String.t(), String.t(), String.t()) ::
          :ok | {:error, :invalid_signature}
  def verify_signature(message_id, timestamp, body, signature, secret) do
    message = message_id <> timestamp <> body
    expected_signature = "sha256=" <> compute_hmac(message, secret)

    if secure_compare(signature, expected_signature) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  @doc """
  Generates a challenge response for webhook verification.

  When setting up a webhook subscription, Twitch sends a challenge request
  that must be responded to with the challenge value.

  ## Examples

      {:ok, :challenge, challenge} = verify_and_process(conn, secret)
      # Respond with challenge in plain text
  """
  @spec handle_challenge(map()) :: String.t()
  def handle_challenge(%{"challenge" => challenge}), do: challenge

  @doc """
  Checks if a message timestamp is within the acceptable time window.

  Messages older than 10 minutes are rejected to prevent replay attacks.

  ## Examples

      Twitchy.EventSub.Webhook.verify_timestamp("2024-12-19T12:00:00Z")
      # => :ok or {:error, :timestamp_too_old}
  """
  @spec verify_timestamp(String.t(), keyword()) :: :ok | {:error, :timestamp_too_old}
  def verify_timestamp(timestamp, opts \\ []) do
    if opts[:skip_timestamp_check] do
      :ok
    else
      check_timestamp_age(timestamp)
    end
  end

  defp check_timestamp_age(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, message_time, _offset} -> check_age(message_time)
      {:error, _} -> {:error, :invalid_timestamp}
    end
  end

  defp check_age(message_time) do
    age_seconds = DateTime.diff(DateTime.utc_now(), message_time)

    if age_seconds <= @max_message_age_seconds do
      :ok
    else
      {:error, :timestamp_too_old}
    end
  end

  ## Private Functions

  defp extract_headers(conn) do
    headers = %{
      message_id: get_header(conn, "twitch-eventsub-message-id"),
      message_type: get_header(conn, "twitch-eventsub-message-type"),
      timestamp: get_header(conn, "twitch-eventsub-message-timestamp"),
      signature: get_header(conn, "twitch-eventsub-message-signature"),
      subscription_type: get_header(conn, "twitch-eventsub-subscription-type"),
      subscription_version: get_header(conn, "twitch-eventsub-subscription-version")
    }

    required = [:message_id, :message_type, :timestamp, :signature]

    if Enum.all?(required, &headers[&1]) do
      {:ok, headers}
    else
      {:error, :missing_headers}
    end
  end

  defp get_header(conn, name) do
    case Plug.Conn.get_req_header(conn, name) do
      [value | _] -> value
      [] -> nil
    end
  end

  defp read_body(conn) do
    case conn.assigns[:raw_body] do
      nil ->
        # Body hasn't been read yet or cached
        case Plug.Conn.read_body(conn) do
          {:ok, body, _conn} -> {:ok, body}
          {:error, reason} -> {:error, reason}
        end

      body ->
        # Body was cached in assigns by a previous plug
        {:ok, body}
    end
  end

  defp verify_signature(headers, body, secret) do
    verify_signature(
      headers.message_id,
      headers.timestamp,
      body,
      headers.signature,
      secret
    )
  end

  defp verify_timestamp_from_headers(headers, opts) do
    verify_timestamp(headers.timestamp, opts)
  end

  defp check_message_replay(headers, opts) do
    case opts[:seen_message_ids] do
      nil ->
        # No replay protection configured
        :ok

      agent when is_pid(agent) or is_atom(agent) ->
        check_and_record_message_id(agent, headers.message_id)
    end
  end

  defp check_and_record_message_id(agent, message_id) do
    if Agent.get(agent, &MapSet.member?(&1, message_id)) do
      {:error, :duplicate_message_id}
    else
      Agent.update(agent, &MapSet.put(&1, message_id))
      :ok
    end
  end

  defp parse_message(body, headers) do
    case Jason.decode(body) do
      {:ok, data} ->
        case headers.message_type do
          "webhook_callback_verification" ->
            challenge = data["challenge"]
            {:ok, :challenge, challenge}

          "notification" ->
            {:ok, :notification, data}

          "revocation" ->
            {:ok, :revocation, data}

          unknown ->
            {:error, {:unknown_message_type, unknown}}
        end

      {:error, reason} ->
        {:error, {:json_decode_error, reason}}
    end
  end

  defp compute_hmac(message, secret) do
    :crypto.mac(:hmac, :sha256, secret, message)
    |> Base.encode16(case: :lower)
  end

  defp secure_compare(a, b) when byte_size(a) != byte_size(b), do: false

  defp secure_compare(a, b) do
    # Constant-time comparison to prevent timing attacks
    a_bytes = :binary.bin_to_list(a)
    b_bytes = :binary.bin_to_list(b)

    Enum.zip(a_bytes, b_bytes)
    |> Enum.reduce(0, fn {x, y}, acc -> acc ||| Bitwise.bxor(x, y) end)
    |> Kernel.==(0)
  end

  defp emit_telemetry(event, measurements, metadata) do
    :telemetry.execute(
      [:twitchy, :eventsub, :webhook, event],
      Map.merge(%{system_time: System.system_time()}, measurements),
      metadata
    )
  end
end
