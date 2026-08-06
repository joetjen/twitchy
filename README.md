# Twitchy

A comprehensive, production-ready Elixir client for the Twitch Helix API with full EventSub support (WebSocket & Webhooks).

[![Hex.pm](https://img.shields.io/hexpm/v/twitchy.svg)](https://hex.pm/packages/twitchy)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/twitchy)
[![Docs (main)](https://img.shields.io/badge/docs-main-blue.svg)](https://joetjen.github.io/twitchy)
[![License](https://img.shields.io/hexpm/l/twitchy.svg)](LICENSE)

## Features

### 🚀 Complete API Coverage
- **30+ API modules** covering all Twitch Helix endpoints
- Users, Streams, Channels, Games, Videos, Clips
- Moderation, Chat, Subscriptions, Bits, Channel Points
- Predictions, Polls, Raids, Hype Trains, Ads
- Charity, Extensions, Goals, Guest Star

### 🔐 Flexible Authentication
- **App Access Tokens** (Client Credentials flow)
- **User Access Tokens** (Authorization Code flow)
- Automatic token refresh and validation
- Custom token storage with behavior interface

### 📡 EventSub Support
- **WebSocket** - Real-time events with auto-reconnection
- **Webhooks** - HMAC-SHA256 signature verification
- Declarative subscription management
- Built-in Plug integration for Phoenix

### 🛠️ Developer-Friendly
- **Pipeline-friendly API** with struct-based builders
- Automatic pagination with Stream protocol
- Built-in rate limiting (800 points/minute)
- Comprehensive telemetry events
- Full error handling

### 🔧 Production-Ready
- Custom Finch connection pools
- Automatic retry with backoff
- Request/response telemetry
- Configurable timeouts and retries
- Memory-efficient streaming

## Installation

```elixir
def deps do
  [
    {:twitchy, "~> 0.1.0"}
  ]
end
```

## Quick Start

```elixir
# Create and authenticate client
client = Twitchy.new(
  client_id: "your_client_id",
  client_secret: "your_client_secret"
)
{:ok, client} = Twitchy.authenticate(client, :app_access)

# Fetch top games
{:ok, response} = Twitchy.Games.get_top_games(client, first: 10)

# Get user information
{:ok, response} = Twitchy.Users.get_users(client, login: ["ninja"])

# Check if stream is live
{:ok, response} = Twitchy.Streams.get_streams(client, user_login: ["shroud"])
```

See [QUICKSTART.md](QUICKSTART.md) for detailed getting started guide.

## EventSub Real-Time Events

```elixir
# Start EventSub WebSocket
{:ok, _pid} = Twitchy.EventSub.Supervisor.start_websocket(
  name: :my_bot,
  client: client,
  handler: {MyApp.EventHandler, :handle_event, []}
)

# Handle events (the handler receives the raw EventSub WebSocket message)
defmodule MyApp.EventHandler do
  def handle_event(%{"metadata" => %{"message_type" => "notification"}} = event, _opts) do
    case get_in(event, ["payload", "subscription", "type"]) do
      "stream.online" ->
        broadcaster = get_in(event, ["payload", "event", "broadcaster_user_name"])
        IO.puts("🔴 #{broadcaster} went live!")

      _other ->
        :ok
    end

    :ok
  end

  def handle_event(_event, _opts), do: :ok
end
```

See [TUTORIAL.md](TUTORIAL.md) for a complete, step-by-step walkthrough of subscribing to events and reacting to them.

See [EVENTSUB_EXAMPLES.md](EVENTSUB_EXAMPLES.md) for comprehensive EventSub guide.

## API Modules

| Module | Description |
|--------|-------------|
| `Twitchy.Users` | User information, follows, blocks |
| `Twitchy.Streams` | Live stream data |
| `Twitchy.Channels` | Channel information |
| `Twitchy.Games` | Game information |
| `Twitchy.Videos` | VODs and highlights |
| `Twitchy.Clips` | Clip management |
| `Twitchy.Chat` | Chat settings |
| `Twitchy.Moderation` | Moderation actions |
| `Twitchy.Subscriptions` | Channel subscriptions |
| `Twitchy.ChannelPoints` | Custom rewards |
| `Twitchy.Predictions` | Channel predictions |
| `Twitchy.Polls` | Channel polls |
| `Twitchy.EventSub` | Event subscriptions |

[See all API modules →](docs/api/API_REFERENCE.md)

## Documentation

- [Quick Start Guide](QUICKSTART.md)
- [Tutorial: Building a Stream Alert & Moderation Bot](TUTORIAL.md)
- [Usage Guide](USAGE_GUIDE.md)
- [Examples](EXAMPLES.md)
- [API Documentation](docs/api/API_REFERENCE.md)
- [Testing Guide](TESTING_GUIDE.md)
- [Generated docs (main branch)](https://joetjen.github.io/twitchy) / [Generated docs (latest release)](https://hexdocs.pm/twitchy)

## Requirements

- Elixir 1.14+
- Erlang/OTP 25+

## License

MIT License - see [LICENSE](LICENSE)
