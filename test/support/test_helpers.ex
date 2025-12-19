defmodule Twitchy.TestHelpers do
  @moduledoc """
  Common test helpers for Twitchy tests.
  """

  @doc """
  Creates a test client configuration.
  """
  def test_client(attrs \\ %{}) do
    defaults = %{
      client_id: "test_client_id",
      client_secret: "test_client_secret",
      access_token: "test_access_token",
      base_url: "https://api.twitch.tv/helix"
    }

    Twitchy.Config.new(Map.merge(defaults, attrs))
  end

  @doc """
  Creates a test client with authentication.
  """
  def authenticated_client(attrs \\ %{}) do
    test_client(
      Map.merge(
        %{
          access_token: "test_token_#{:rand.uniform(1000)}",
          token_type: "bearer",
          expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
        },
        attrs
      )
    )
  end

  @doc """
  Computes HMAC signature for webhook testing.
  """
  def compute_webhook_signature(message_id, timestamp, body, secret) do
    message = message_id <> timestamp <> body
    hmac = :crypto.mac(:hmac, :sha256, secret, message)
    "sha256=" <> Base.encode16(hmac, case: :lower)
  end

  @doc """
  Creates a mock Twitch API response.
  """
  def mock_api_response(data, opts \\ []) do
    %{
      "data" => data,
      "pagination" => opts[:pagination] || %{}
    }
  end

  @doc """
  Creates mock user data.
  """
  def mock_user(attrs \\ %{}) do
    defaults = %{
      "id" => "123456",
      "login" => "testuser",
      "display_name" => "TestUser",
      "type" => "user",
      "broadcaster_type" => "affiliate",
      "description" => "Test user description",
      "profile_image_url" => "https://example.com/avatar.jpg",
      "offline_image_url" => "https://example.com/offline.jpg",
      "view_count" => 1000,
      "created_at" => "2020-01-01T00:00:00Z"
    }

    Map.merge(defaults, Enum.into(attrs, %{}))
  end

  @doc """
  Creates mock stream data.
  """
  def mock_stream(attrs \\ %{}) do
    defaults = %{
      "id" => "987654321",
      "user_id" => "123456",
      "user_login" => "testuser",
      "user_name" => "TestUser",
      "game_id" => "12345",
      "game_name" => "Test Game",
      "type" => "live",
      "title" => "Test Stream Title",
      "viewer_count" => 100,
      "started_at" => "2024-12-19T12:00:00Z",
      "language" => "en",
      "thumbnail_url" => "https://example.com/thumb.jpg",
      "tag_ids" => [],
      "is_mature" => false
    }

    Map.merge(defaults, Enum.into(attrs, %{}))
  end

  @doc """
  Attaches a telemetry test handler.
  """
  def attach_telemetry_handler(event_prefix, test_pid \\ self()) do
    handler_id = "test-handler-#{:rand.uniform(10000)}"

    :telemetry.attach_many(
      handler_id,
      [event_prefix],
      fn event, measurements, metadata, _ ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit = fn -> :telemetry.detach(handler_id) end
    {handler_id, on_exit}
  end

  @doc """
  Waits for a telemetry event.
  """
  def assert_receive_telemetry(event_name, timeout \\ 100) do
    receive do
      {:telemetry_event, ^event_name, measurements, metadata} ->
        {measurements, metadata}
    after
      timeout ->
        raise "Expected telemetry event #{inspect(event_name)} but did not receive it"
    end
  end

  @doc """
  Creates a mock EventSub notification.
  """
  def mock_eventsub_notification(subscription_type, event_data) do
    %{
      "metadata" => %{
        "message_id" => "test_msg_#{:rand.uniform(1000)}",
        "message_type" => "notification",
        "message_timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "subscription_type" => subscription_type,
        "subscription_version" => "1"
      },
      "subscription" => %{
        "id" => "sub_#{:rand.uniform(1000)}",
        "type" => subscription_type,
        "version" => "1",
        "status" => "enabled",
        "cost" => 1,
        "condition" => %{"broadcaster_user_id" => "12345"},
        "transport" => %{
          "method" => "websocket",
          "session_id" => "session_123"
        },
        "created_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      },
      "event" => event_data
    }
  end

  @doc """
  Creates a mock EventSub welcome message.
  """
  def mock_eventsub_welcome(session_id \\ "test_session_123") do
    %{
      "metadata" => %{
        "message_id" => "welcome_msg_#{:rand.uniform(1000)}",
        "message_type" => "session_welcome",
        "message_timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      },
      "payload" => %{
        "session" => %{
          "id" => session_id,
          "status" => "connected",
          "keepalive_timeout_seconds" => 10,
          "reconnect_url" => nil,
          "connected_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        }
      }
    }
  end
end
