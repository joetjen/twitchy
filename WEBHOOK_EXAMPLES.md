# EventSub Webhook Examples

## Basic Webhook Setup in Phoenix

```elixir
# config/config.exs
config :my_app,
  twitch_webhook_secret: System.get_env("TWITCH_WEBHOOK_SECRET")

# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/webhooks", MyAppWeb do
    pipe_through :api

    # EventSub webhook endpoint
    post "/twitch/eventsub", Twitchy.EventSub.Plug,
      secret: {:system, "TWITCH_WEBHOOK_SECRET"},
      handler: {MyApp.TwitchEventHandler, :handle_event, []},
      replay_protection: true
  end
end

# lib/my_app/twitch_event_handler.ex
defmodule MyApp.TwitchEventHandler do
  require Logger

  def handle_event(%{"subscription" => subscription, "event" => event}, _opts) do
    subscription_type = subscription["type"]

    Logger.info("Received #{subscription_type} event")

    case subscription_type do
      "channel.follow" -> handle_follow(event)
      "stream.online" -> handle_stream_online(event)
      "stream.offline" -> handle_stream_offline(event)
      "channel.update" -> handle_channel_update(event)
      "channel.subscribe" -> handle_subscription(event)
      "channel.cheer" -> handle_cheer(event)
      _ -> Logger.warning("Unhandled event type: #{subscription_type}")
    end
  end

  defp handle_follow(event) do
    follower = event["user_name"]
    broadcaster = event["broadcaster_user_name"]

    Logger.info("#{follower} followed #{broadcaster}!")

    # Broadcast to Phoenix channels
    MyAppWeb.Endpoint.broadcast(
      "stream:#{event["broadcaster_user_id"]}",
      "new_follower",
      %{follower: follower, followed_at: event["followed_at"]}
    )
  end

  defp handle_stream_online(event) do
    broadcaster = event["broadcaster_user_name"]
    Logger.info("#{broadcaster} is now LIVE!")

    # Send notifications to subscribers
    MyApp.Notifications.broadcast_stream_start(
      event["broadcaster_user_id"],
      event["broadcaster_user_name"],
      event["type"]
    )
  end

  defp handle_stream_offline(event) do
    broadcaster = event["broadcaster_user_name"]
    Logger.info("#{broadcaster} went offline")

    MyApp.StreamStats.finalize_session(event["broadcaster_user_id"])
  end

  defp handle_channel_update(event) do
    Logger.info("Channel updated: #{event["title"]}")

    MyApp.Cache.update_channel_info(event["broadcaster_user_id"], %{
      title: event["title"],
      category: event["category_name"],
      language: event["language"]
    })
  end

  defp handle_subscription(event) do
    subscriber = event["user_name"]
    tier = event["tier"]
    is_gift = event["is_gift"]

    Logger.info("New #{tier} subscription from #{subscriber} (gift: #{is_gift})")

    MyApp.SubTracker.record_subscription(event)
  end

  defp handle_cheer(event) do
    cheerer = event["user_name"] || "Anonymous"
    bits = event["bits"]

    Logger.info("#{cheerer} cheered #{bits} bits!")

    MyApp.BitTracker.record_cheer(event)
  end
end
```

## Phoenix Controller Approach

```elixir
# lib/my_app_web/controllers/webhook_controller.ex
defmodule MyAppWeb.WebhookController do
  use MyAppWeb, :controller
  require Logger

  def eventsub(conn, _params) do
    secret = Application.get_env(:my_app, :twitch_webhook_secret)

    Twitchy.EventSub.Plug.handle_webhook(conn,
      secret: secret,
      handler: {MyApp.TwitchEventHandler, :handle_event, []},
      replay_protection: true,
      on_error: {__MODULE__, :handle_error, []}
    )
  end

  def handle_error(reason, _opts) do
    Logger.error("Webhook verification failed: #{inspect(reason)}")

    # Send to monitoring service
    Sentry.capture_message("EventSub webhook verification failed",
      extra: %{reason: reason}
    )
  end
end

# lib/my_app_web/router.ex
scope "/webhooks", MyAppWeb do
  pipe_through :api

  post "/eventsub", WebhookController, :eventsub
end
```

## Setting Up Webhook Subscription

```elixir
# Create webhook subscription via API
client = Twitchy.new(
  client_id: "your_client_id",
  client_secret: "your_client_secret"
)
|> Twitchy.authenticate!(:app_access)

# Your publicly accessible webhook URL
callback_url = "https://your-domain.com/webhooks/twitch/eventsub"
secret = "your_webhook_secret_min_10_chars"

# Create subscription
{:ok, response} = Twitchy.EventSub.create_subscription(client,
  type: "channel.follow",
  version: "2",
  condition: %{
    broadcaster_user_id: "12345",
    moderator_user_id: "12345"
  },
  transport: %{
    method: "webhook",
    callback: callback_url,
    secret: secret
  }
)

subscription_id = response["data"] |> List.first() |> Map.get("id")
IO.puts("Subscription created: #{subscription_id}")
```

## GenServer-Based Webhook Handler

```elixir
defmodule MyApp.EventProcessor do
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  # Called by webhook handler
  def handle_event(event, _opts) do
    GenServer.cast(__MODULE__, {:process_event, event})
  end

  def handle_cast({:process_event, event}, state) do
    subscription_type = get_in(event, ["subscription", "type"])
    event_data = event["event"]

    # Process asynchronously
    Task.start(fn ->
      case subscription_type do
        "channel.follow" ->
          process_follow(event_data)

        "stream.online" ->
          process_stream_online(event_data)

        "channel.chat.message" ->
          process_chat_message(event_data)

        _ ->
          Logger.debug("Unhandled event: #{subscription_type}")
      end
    end)

    {:noreply, state}
  end

  defp process_follow(event) do
    %{
      "user_name" => follower,
      "broadcaster_user_name" => broadcaster,
      "followed_at" => followed_at
    } = event

    # Store in database
    MyApp.Repo.insert!(%MyApp.Follower{
      username: follower,
      broadcaster: broadcaster,
      followed_at: followed_at
    })

    # Update follower count
    MyApp.Cache.increment_follower_count(event["broadcaster_user_id"])
  end

  defp process_stream_online(event) do
    # Send push notifications
    broadcaster_id = event["broadcaster_user_id"]

    MyApp.Repo.all(
      from u in MyApp.User,
      where: ^broadcaster_id in u.subscribed_streamers
    )
    |> Enum.each(fn user ->
      MyApp.PushNotifications.send(user, %{
        title: "#{event["broadcaster_user_name"]} is live!",
        body: event["title"],
        type: event["type"]
      })
    end)
  end

  defp process_chat_message(event) do
    # Analyze chat for commands, moderation, etc.
    message = event["message"]["text"]

    if String.starts_with?(message, "!") do
      MyApp.CommandProcessor.process(event)
    end
  end
end

# In router
post "/webhooks/eventsub", Twitchy.EventSub.Plug,
  secret: {:system, "TWITCH_WEBHOOK_SECRET"},
  handler: {MyApp.EventProcessor, :handle_event, []}
```

## Multiple Webhook Endpoints

```elixir
# Different handlers for different event types
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  scope "/webhooks/twitch" do
    pipe_through :api

    # Stream events
    post "/streams", Twitchy.EventSub.Plug,
      secret: {:system, "TWITCH_WEBHOOK_SECRET"},
      handler: {MyApp.StreamEventHandler, :handle_event, []}

    # Chat events
    post "/chat", Twitchy.EventSub.Plug,
      secret: {:system, "TWITCH_WEBHOOK_SECRET"},
      handler: {MyApp.ChatEventHandler, :handle_event, []}

    # Subscription events
    post "/subscriptions", Twitchy.EventSub.Plug,
      secret: {:system, "TWITCH_WEBHOOK_SECRET"},
      handler: {MyApp.SubEventHandler, :handle_event, []}
  end
end
```

## Testing Webhooks

```elixir
defmodule MyApp.WebhookTest do
  use MyAppWeb.ConnCase

  @webhook_secret "test_secret_1234567890"

  setup do
    # Configure test secret
    Application.put_env(:my_app, :twitch_webhook_secret, @webhook_secret)
    :ok
  end

  test "handles challenge request", %{conn: conn} do
    challenge = "test_challenge_string"

    body = Jason.encode!(%{
      "challenge" => challenge,
      "subscription" => %{
        "type" => "channel.follow",
        "version" => "2"
      }
    })

    signature = compute_signature("msg-id", timestamp(), body, @webhook_secret)

    conn =
      conn
      |> put_req_header("twitch-eventsub-message-id", "msg-id")
      |> put_req_header("twitch-eventsub-message-type", "webhook_callback_verification")
      |> put_req_header("twitch-eventsub-message-timestamp", timestamp())
      |> put_req_header("twitch-eventsub-message-signature", signature)
      |> post("/webhooks/eventsub", body)

    assert response(conn, 200) == challenge
    assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
  end

  test "handles notification", %{conn: conn} do
    body = Jason.encode!(%{
      "subscription" => %{
        "type" => "channel.follow",
        "version" => "2"
      },
      "event" => %{
        "user_name" => "test_follower",
        "broadcaster_user_name" => "test_streamer",
        "followed_at" => "2024-12-19T12:00:00Z"
      }
    })

    signature = compute_signature("msg-id-2", timestamp(), body, @webhook_secret)

    conn =
      conn
      |> put_req_header("twitch-eventsub-message-id", "msg-id-2")
      |> put_req_header("twitch-eventsub-message-type", "notification")
      |> put_req_header("twitch-eventsub-message-timestamp", timestamp())
      |> put_req_header("twitch-eventsub-message-signature", signature)
      |> put_req_header("twitch-eventsub-subscription-type", "channel.follow")
      |> put_req_header("twitch-eventsub-subscription-version", "2")
      |> post("/webhooks/eventsub", body)

    assert response(conn, 200)
  end

  test "rejects invalid signature", %{conn: conn} do
    body = Jason.encode!(%{"test" => "data"})

    conn =
      conn
      |> put_req_header("twitch-eventsub-message-id", "msg-id-3")
      |> put_req_header("twitch-eventsub-message-type", "notification")
      |> put_req_header("twitch-eventsub-message-timestamp", timestamp())
      |> put_req_header("twitch-eventsub-message-signature", "sha256=invalid")
      |> post("/webhooks/eventsub", body)

    assert response(conn, 403)
  end

  defp compute_signature(message_id, timestamp, body, secret) do
    message = message_id <> timestamp <> body
    hmac = :crypto.mac(:hmac, :sha256, secret, message)
    "sha256=" <> Base.encode16(hmac, case: :lower)
  end

  defp timestamp do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end
end
```

## Telemetry Metrics

```elixir
defmodule MyApp.TelemetryMetrics do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    # Attach handlers
    :telemetry.attach_many(
      "eventsub-webhook-metrics",
      [
        [:twitchy, :eventsub, :webhook, :challenge],
        [:twitchy, :eventsub, :webhook, :notification],
        [:twitchy, :eventsub, :webhook, :error],
        [:twitchy, :eventsub, :plug, :request],
        [:twitchy, :eventsub, :plug, :success],
        [:twitchy, :eventsub, :plug, :error]
      ],
      &handle_event/4,
      nil
    )

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp handle_event([:twitchy, :eventsub, :webhook, :notification], _measurements, metadata, _config) do
    :telemetry.execute(
      [:my_app, :eventsub, :event_received],
      %{count: 1},
      %{subscription_type: metadata.subscription_type}
    )
  end

  defp handle_event([:twitchy, :eventsub, :plug, :success], measurements, metadata, _config) do
    :telemetry.execute(
      [:my_app, :eventsub, :request_duration],
      %{duration: measurements.duration},
      %{message_type: metadata.message_type}
    )
  end

  defp handle_event([:twitchy, :eventsub, :webhook, :error], _measurements, metadata, _config) do
    :telemetry.execute(
      [:my_app, :eventsub, :verification_failed],
      %{count: 1},
      %{reason: metadata.reason}
    )
  end

  defp handle_event(_, _, _, _), do: :ok

  defp periodic_measurements do
    []
  end
end
```

## Production Deployment Checklist

1. **Webhook URL Requirements:**
   - Must be HTTPS (not HTTP)
   - Must be publicly accessible
   - Must respond within 10 seconds
   - Port 443 or 8443 only

2. **Secret Management:**
   - Use environment variables
   - Minimum 10 characters, maximum 100
   - Rotate secrets periodically
   - Different secrets for dev/staging/prod

3. **Monitoring:**
   - Log all verification failures
   - Alert on high error rates
   - Track event processing latency
   - Monitor subscription health

4. **Security:**
   - Always verify signatures
   - Enable replay protection in production
   - Validate timestamp age
   - Rate limit webhook endpoint

5. **Error Handling:**
   - Handle handler crashes gracefully
   - Return 200 even if processing fails
   - Queue failed events for retry
   - Dead letter queue for poison messages
