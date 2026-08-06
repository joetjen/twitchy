defmodule Twitchy.Error do
  @moduledoc """
  Error types for the Twitchy library.

  All API errors are normalized into structured exceptions with consistent
  fields for error handling and logging.
  """

  defmodule HTTPError do
    @moduledoc """
    Represents an HTTP-level error (connection failure, timeout, etc).
    """
    defexception [:message, :reason]

    @type t :: %__MODULE__{
            message: String.t(),
            reason: term()
          }
  end

  defmodule APIError do
    @moduledoc """
    Represents a Twitch API error response.

    Twitch API errors include a status code, error message, and optional details.
    """
    defexception [:message, :status, :error, :error_message, :request_id]

    @type t :: %__MODULE__{
            message: String.t(),
            status: integer(),
            error: String.t() | nil,
            error_message: String.t() | nil,
            request_id: String.t() | nil
          }

    @impl true
    def message(%__MODULE__{} = error) do
      base = "Twitch API error (#{error.status})"

      details =
        [error.error, error.error_message, error.request_id && "request_id: #{error.request_id}"]
        |> Enum.reject(&is_nil/1)
        |> Enum.join(", ")

      if details != "", do: "#{base}: #{details}", else: base
    end
  end

  defmodule AuthError do
    @moduledoc """
    Represents an authentication or authorization error.
    """
    defexception [:message, :reason, :status]

    @type t :: %__MODULE__{
            message: String.t(),
            reason: atom() | String.t(),
            status: integer() | nil
          }

    @impl true
    def message(%__MODULE__{} = error) do
      base = error.message || "Authentication error"
      if error.reason, do: "#{base}: #{error.reason}", else: base
    end
  end

  defmodule RateLimitError do
    @moduledoc """
    Represents a rate limit error (HTTP 429).

    Includes information about when the limit will reset.
    """
    defexception [:message, :reset_at, :remaining, :limit]

    @type t :: %__MODULE__{
            message: String.t(),
            reset_at: DateTime.t() | nil,
            remaining: integer() | nil,
            limit: integer() | nil
          }

    @impl true
    def message(%__MODULE__{} = error) do
      base = error.message || "Rate limit exceeded"

      if error.reset_at do
        "#{base}. Resets at #{DateTime.to_iso8601(error.reset_at)}"
      else
        base
      end
    end
  end

  defmodule ValidationError do
    @moduledoc """
    Represents a validation error for client configuration or parameters.
    """
    defexception [:message, :field, :reason]

    @type t :: %__MODULE__{
            message: String.t(),
            field: atom() | String.t() | nil,
            reason: String.t() | nil
          }

    @impl true
    def message(%__MODULE__{} = error) do
      if error.field do
        "Validation error for #{error.field}: #{error.reason || error.message}"
      else
        "Validation error: #{error.reason || error.message}"
      end
    end
  end

  defmodule EventSubError do
    @moduledoc """
    Represents an EventSub-specific error (WebSocket or Webhook).
    """
    defexception [:message, :reason, :session_id, :subscription_id]

    @type t :: %__MODULE__{
            message: String.t(),
            reason: atom() | String.t(),
            session_id: String.t() | nil,
            subscription_id: String.t() | nil
          }
  end

  @doc """
  Normalizes various error types into structured exceptions.

  ## Examples

      iex> Twitchy.Error.normalize({:error, %Mint.TransportError{reason: :timeout}})
      %Twitchy.Error.HTTPError{reason: :timeout, message: "HTTP transport error: timeout"}

      iex> Twitchy.Error.normalize({:error, %{status: 401, body: %{"error" => "Unauthorized"}}})
      %Twitchy.Error.AuthError{status: 401, reason: "Unauthorized"}
  """
  @spec normalize(term()) :: Exception.t()
  def normalize({:error, %_{} = exception}) when is_exception(exception) do
    exception
  end

  def normalize({:error, %{status: 401} = error}) do
    %AuthError{
      message: "Authentication failed",
      reason: body_value(error[:body], "message") || body_value(error[:body], "error") || "Unauthorized",
      status: 401
    }
  end

  def normalize({:error, %{status: 403} = error}) do
    %AuthError{
      message: "Authorization failed",
      reason: body_value(error[:body], "message") || body_value(error[:body], "error") || "Forbidden",
      status: 403
    }
  end

  def normalize({:error, %{status: 429} = error}) do
    reset_at =
      case get_in(error, [:headers, "ratelimit-reset"]) do
        nil -> nil
        timestamp -> parse_unix_timestamp(timestamp)
      end

    %RateLimitError{
      message: "Rate limit exceeded",
      reset_at: reset_at,
      remaining: parse_int(get_in(error, [:headers, "ratelimit-remaining"])),
      limit: parse_int(get_in(error, [:headers, "ratelimit-limit"]))
    }
  end

  def normalize({:error, %{status: status, body: body} = error}) when status >= 400 and status < 500 do
    %APIError{
      message: "Client error",
      status: status,
      error: body_value(body, "error"),
      error_message: body_value(body, "message"),
      request_id: get_in(error, [:headers, "twitch-request-id"])
    }
  end

  def normalize({:error, %{status: status, body: body} = error}) when status >= 500 do
    %APIError{
      message: "Server error",
      status: status,
      error: body_value(body, "error"),
      error_message: body_value(body, "message"),
      request_id: get_in(error, [:headers, "twitch-request-id"])
    }
  end

  def normalize({:error, %{__exception__: true} = exception}) do
    %HTTPError{
      message: Exception.message(exception),
      reason: exception
    }
  end

  def normalize({:error, reason}) when is_atom(reason) do
    %HTTPError{
      message: "HTTP error: #{reason}",
      reason: reason
    }
  end

  def normalize({:error, reason}) do
    %HTTPError{
      message: "Unknown error",
      reason: reason
    }
  end

  def normalize(error) do
    %HTTPError{
      message: "Unexpected error format",
      reason: error
    }
  end

  defp body_value(body, key) when is_map(body), do: body[key]
  defp body_value(_body, _key), do: nil

  defp parse_int(nil), do: nil
  defp parse_int(value) when is_integer(value), do: value

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_unix_timestamp(nil), do: nil

  defp parse_unix_timestamp(timestamp) when is_integer(timestamp) do
    DateTime.from_unix(timestamp)
    |> case do
      {:ok, dt} -> dt
      _ -> nil
    end
  end

  defp parse_unix_timestamp(timestamp) when is_binary(timestamp) do
    case Integer.parse(timestamp) do
      {unix, _} -> parse_unix_timestamp(unix)
      :error -> nil
    end
  end
end
