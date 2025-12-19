# Quick Start Guide

Get up and running with Twitchy in 5 minutes.

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:twitchy, "~> 0.1.0"}
  ]
end
```

Run `mix deps.get`

## Setup

### 1. Get Twitch Credentials

1. Go to [Twitch Developer Console](https://dev.twitch.tv/console/apps)
2. Click "Register Your Application"
3. Fill in the details and get your **Client ID** and **Client Secret**

### 2. Configure (Optional)

Add to `config/config.exs`:

```elixir
config :twitchy,
  client_id: System.get_env("TWITCH_CLIENT_ID"),
  client_secret: System.get_env("TWITCH_CLIENT_SECRET")
```

## Your First API Call

```elixir
# Create and authenticate a client
client = Twitchy.new()
{:ok, client} = Twitchy.authenticate(client, :app_access)

# Make an API call
{:ok, response} = Twitchy.Users.get_user(client, login: "ninja")
user = List.first(response["data"])

IO.puts("User: #{user["display_name"]}")
IO.puts("Bio: #{user["description"]}")
```

## Common Use Cases

### Check if Stream is Live

```elixir
{:ok, response} = Twitchy.Streams.get_streams(client, user_login: ["ninja"])

case response["data"] do
  [stream | _] ->
    IO.puts("🔴 #{stream["user_name"]} is live!")
    IO.puts("Playing: #{stream["game_name"]}")
    IO.puts("Viewers: #{stream["viewer_count"]}")

  [] ->
    IO.puts("Stream is offline")
end
```

### Get Top Games

```elixir
{:ok, response} = Twitchy.Games.get_top_games(client, first: 10)

Enum.with_index(response["data"], 1) |> Enum.each(fn {game, rank} ->
  IO.puts("#{rank}. #{game["name"]}")
end)
```

### Real-Time Events with EventSub

```elixir
# Start EventSub WebSocket connection
{:ok, _pid} = Twitchy.EventSub.Declarative.start_link(
  client: client,
  handler: MyApp.EventHandler,
  subscriptions: [
    %{
      type: "stream.online",
      condition: %{"broadcaster_user_id" => "123456"}
    }
  ]
)

# Handle events
defmodule MyApp.EventHandler do
  def handle_event("stream.online", event, _metadata) do
    IO.puts("🔴 #{event["broadcaster_user_name"]} went live!")
    :ok
  end

  def handle_event(_type, _event, _metadata), do: :ok
end
```

## Next Steps

- **[Usage Guide](USAGE_GUIDE.md)** - Comprehensive guide covering all features
- **[Examples](EXAMPLES.md)** - Real-world applications and patterns
- **[API Documentation](docs/api/)** - Detailed API module documentation
- **[EventSub Guide](EVENTSUB_EXAMPLES.md)** - Real-time events examples
- **[Testing Guide](TESTING_GUIDE.md)** - How to test your applications

## Need Help?

Check out the [full documentation](README.md) for more details!
