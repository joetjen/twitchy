# Quick Start Guide

Get up and running with Twitchy in 5 minutes.

## Installation

Add to `mix.exs`:

```elixir
def deps do
  [
    {:twitchy, "~> 0.1.0"}
  ]
end
```

Run: `mix deps.get`

## Get Twitch Credentials

1. Go to [Twitch Developer Console](https://dev.twitch.tv/console/apps)
2. Register your application
3. Get your **Client ID** and **Client Secret**

## First API Call

```elixir
# Create client
client = Twitchy.new(
  client_id: System.get_env("TWITCH_CLIENT_ID"),
  client_secret: System.get_env("TWITCH_CLIENT_SECRET")
)

# Authenticate
{:ok, client} = Twitchy.authenticate(client, :app_access)

# Get top games
{:ok, response} = Twitchy.Games.get_top_games(client, first: 5)
```

## Common Use Cases

### Get User Information

```elixir
{:ok, response} = Twitchy.Users.get_users(client, login: ["ninja"])
user = List.first(response["data"])
```

### Check if Stream is Live

```elixir
{:ok, response} = Twitchy.Streams.get_streams(client, user_login: ["ninja"])

case response["data"] do
  [stream | _] -> IO.puts("#{stream["user_name"]} is live!")
  [] -> IO.puts("Stream is offline")
end
```

### Real-Time Events

```elixir
# Add to your application
children = [Twitchy.EventSub.Supervisor]

# Start WebSocket
{:ok, _pid} = Twitchy.EventSub.Supervisor.start_websocket(
  client: client,
  handler: MyApp.EventHandler
)

# Handle events
defmodule MyApp.EventHandler do
  def handle_event("stream.online", event, _metadata) do
    IO.puts("🔴 #{event["broadcaster_user_name"]} went live!")
    :ok
  end
end
```

See full documentation in [USAGE_GUIDE.md](USAGE_GUIDE.md)
