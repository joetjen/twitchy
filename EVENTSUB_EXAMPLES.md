# EventSub WebSocket Examples

## Basic WebSocket Connection

```elixir
# Define your event handler
defmodule MyApp.EventHandler do
  require Logger

  def handle_event(%{"metadata" => %{"message_type" => "session_welcome"}} = event, _opts) do
    session_id = get_in(event, ["payload", "session", "id"])
    Logger.info("WebSocket connected with session: #{session_id}")
    :ok
  end

  def handle_event(%{"metadata" => %{"message_type" => "notification"}} = event, _opts) do
    subscription_type = get_in(event, ["payload", "subscription", "type"])
    event_data = get_in(event, ["payload", "event"])

    Logger.info("Received #{subscription_type} event: #{inspect(event_data)}")
    :ok
  end

  def handle_event(_event, _opts), do: :ok
end

# Start WebSocket connection
client = Twitchy.new(
  client_id: "your_client_id",
  client_secret: "your_client_secret"
)

{:ok, ws_pid} = Twitchy.EventSub.Supervisor.start_websocket(
  name: :my_bot,
  client: client,
  handler: {MyApp.EventHandler, :handle_event, []}
)

# Get session ID
{:ok, session_id} = Twitchy.EventSub.Supervisor.get_session_id(:my_bot)

# Create subscription manually
{:ok, _response} = Twitchy.EventSub.create_subscription(client,
  type: "channel.follow",
  version: "2",
  condition: %{
    broadcaster_user_id: "12345",
    moderator_user_id: "12345"
  },
  transport: %{
    method: "websocket",
    session_id: session_id
  }
)

# Stop connection
Twitchy.EventSub.Supervisor.stop_websocket(:my_bot)
```

## Declarative Subscription Management

```elixir
# Define subscriptions configuration
subscriptions = [
  %{
    type: "channel.follow",
    version: "2",
    condition: %{
      broadcaster_user_id: "12345",
      moderator_user_id: "12345"
    }
  },
  %{
    type: "stream.online",
    version: "1",
    condition: %{broadcaster_user_id: "12345"}
  },
  %{
    type: "stream.offline",
    version: "1",
    condition: %{broadcaster_user_id: "12345"}
  },
  %{
    type: "channel.update",
    version: "2",
    condition: %{broadcaster_user_id: "12345"}
  }
]

# Start declarative manager (automatically creates subscriptions)
{:ok, pid} = Twitchy.EventSub.Declarative.start_link(
  name: :my_bot,
  client: client,
  subscriptions: subscriptions,
  handler: {MyApp.EventHandler, :handle_event, []}
)

# Get current state
state = Twitchy.EventSub.Declarative.get_state(:my_bot)
IO.inspect(state.desired, label: "Desired subscriptions")
IO.inspect(state.actual, label: "Active subscriptions")

# Update subscriptions (reconciles automatically)
new_subscriptions = [
  %{
    type: "channel.chat.message",
    version: "1",
    condition: %{
      broadcaster_user_id: "12345",
      user_id: "12345"
    }
  }
]

Twitchy.EventSub.Declarative.update_subscriptions(:my_bot, new_subscriptions)

# Stop (automatically cleans up all subscriptions)
Twitchy.EventSub.Declarative.stop(:my_bot)
```

## Stream Monitor Example

```elixir
defmodule MyApp.StreamMonitor do
  use GenServer
  require Logger

  def start_link(broadcaster_id) do
    GenServer.start_link(__MODULE__, broadcaster_id, name: __MODULE__)
  end

  def init(broadcaster_id) do
    client = Twitchy.new(
      client_id: System.get_env("TWITCH_CLIENT_ID"),
      client_secret: System.get_env("TWITCH_CLIENT_SECRET")
    )

    # Authenticate with app access token
    {:ok, client} = Twitchy.authenticate(client, :app_access)

    subscriptions = [
      %{
        type: "stream.online",
        version: "1",
        condition: %{broadcaster_user_id: broadcaster_id}
      },
      %{
        type: "stream.offline",
        version: "1",
        condition: %{broadcaster_user_id: broadcaster_id}
      }
    ]

    {:ok, _pid} = Twitchy.EventSub.Declarative.start_link(
      name: :stream_monitor,
      client: client,
      subscriptions: subscriptions,
      handler: {__MODULE__, :handle_event, []}
    )

    state = %{
      broadcaster_id: broadcaster_id,
      is_live: false,
      started_at: nil
    }

    {:ok, state}
  end

  def handle_event(%{"metadata" => %{"message_type" => "notification"}} = event, _opts) do
    subscription_type = get_in(event, ["payload", "subscription", "type"])
    event_data = get_in(event, ["payload", "event"])

    case subscription_type do
      "stream.online" ->
        Logger.info("Stream went ONLINE!")
        broadcaster_name = event_data["broadcaster_user_name"]
        started_at = event_data["started_at"]

        # Notify your application
        Phoenix.PubSub.broadcast(
          MyApp.PubSub,
          "stream_events",
          {:stream_online, broadcaster_name, started_at}
        )

      "stream.offline" ->
        Logger.info("Stream went OFFLINE!")
        broadcaster_name = event_data["broadcaster_user_name"]

        Phoenix.PubSub.broadcast(
          MyApp.PubSub,
          "stream_events",
          {:stream_offline, broadcaster_name}
        )

      _ ->
        :ok
    end
  end

  def handle_event(_event, _opts), do: :ok
end

# Start the monitor
{:ok, _pid} = MyApp.StreamMonitor.start_link("12345")
```

## Multiple Connection Management

```elixir
# Monitor multiple streamers
streamers = [
  {"streamer1", "12345"},
  {"streamer2", "67890"},
  {"streamer3", "11111"}
]

Enum.each(streamers, fn {name, broadcaster_id} ->
  client = Twitchy.new(
    client_id: System.get_env("TWITCH_CLIENT_ID"),
    client_secret: System.get_env("TWITCH_CLIENT_SECRET")
  )
  |> Twitchy.authenticate!(:app_access)

  subscriptions = [
    %{
      type: "stream.online",
      version: "1",
      condition: %{broadcaster_user_id: broadcaster_id}
    },
    %{
      type: "channel.update",
      version: "2",
      condition: %{broadcaster_user_id: broadcaster_id}
    }
  ]

  Twitchy.EventSub.Declarative.start_link(
    name: String.to_atom("monitor_#{name}"),
    client: client,
    subscriptions: subscriptions,
    handler: {MyApp.MultiStreamHandler, :handle_event, [name]}
  )
end)

# List all active connections
connections = Twitchy.EventSub.Supervisor.list_connections()
IO.inspect(connections, label: "Active connections")
```

## Telemetry Integration

```elixir
# Attach telemetry handlers
:telemetry.attach_many(
  "eventsub-telemetry",
  [
    [:twitchy, :eventsub, :websocket, :connected],
    [:twitchy, :eventsub, :websocket, :disconnected],
    [:twitchy, :eventsub, :websocket, :message],
    [:twitchy, :eventsub, :websocket, :error],
    [:twitchy, :eventsub, :declarative, :subscription_created],
    [:twitchy, :eventsub, :declarative, :subscription_deleted]
  ],
  fn event, measurements, metadata, _config ->
    IO.inspect(%{
      event: event,
      measurements: measurements,
      metadata: metadata
    }, label: "EventSub Telemetry")
  end,
  nil
)
```

## Error Handling

```elixir
defmodule MyApp.ResilientEventHandler do
  require Logger

  def handle_event(event, _opts) do
    try do
      process_event(event)
    rescue
      error ->
        Logger.error("Error processing event: #{inspect(error)}")
        Logger.error(Exception.format_stacktrace(__STACKTRACE__))

        # Send to error tracking service
        Sentry.capture_exception(error,
          extra: %{event: event},
          tags: %{component: "eventsub"}
        )

        :ok
    end
  end

  defp process_event(%{"metadata" => %{"message_type" => type}} = event) do
    case type do
      "notification" -> handle_notification(event)
      "revocation" -> handle_revocation(event)
      "session_welcome" -> handle_welcome(event)
      _ -> :ok
    end
  end

  defp handle_notification(event) do
    subscription = get_in(event, ["payload", "subscription"])
    event_data = get_in(event, ["payload", "event"])

    # Process based on subscription type
    case subscription["type"] do
      "channel.follow" ->
        follower = event_data["user_name"]
        MyApp.FollowerTracker.record_follow(follower)

      "channel.subscribe" ->
        subscriber = event_data["user_name"]
        tier = event_data["tier"]
        MyApp.SubTracker.record_sub(subscriber, tier)

      _ ->
        :ok
    end
  end

  defp handle_revocation(event) do
    subscription_id = get_in(event, ["payload", "subscription", "id"])
    reason = get_in(event, ["payload", "subscription", "status"])

    Logger.warning("Subscription #{subscription_id} revoked: #{reason}")
    :ok
  end

  defp handle_welcome(_event), do: :ok
end
```
