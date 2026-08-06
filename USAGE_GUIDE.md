# Twitchy Usage Guide

Comprehensive guide to using Twitchy in your Elixir applications.

## Table of Contents

- [Client Configuration](#client-configuration)
- [Authentication](#authentication)
- [Making API Calls](#making-api-calls)
- [Pagination](#pagination)
- [Error Handling](#error-handling)
- [EventSub](#eventsub)
- [Telemetry](#telemetry)
- [Advanced Features](#advanced-features)

## Client Configuration

### Basic Configuration

```elixir
# In config/config.exs
config :twitchy,
  client_id: System.get_env("TWITCH_CLIENT_ID"),
  client_secret: System.get_env("TWITCH_CLIENT_SECRET"),
  redirect_uri: "http://localhost:4000/auth/callback"
```

### Advanced Configuration

```elixir
config :twitchy,
  client_id: System.get_env("TWITCH_CLIENT_ID"),
  client_secret: System.get_env("TWITCH_CLIENT_SECRET"),
  redirect_uri: System.get_env("TWITCH_REDIRECT_URI"),
  # Custom token store
  token_store: MyApp.CustomTokenStore,
  # Finch pool configuration
  finch_pools: %{
    default: [size: 50, count: 3]
  },
  # Rate limiting
  rate_limit_per_window: 800,
  rate_limit_window_ms: 60_000,
  # Telemetry
  telemetry_enabled: true
```

## Authentication

### App Access Token (Server-to-Server)

Best for backend services that don't act on behalf of users.

```elixir
# Create a client
client = Twitchy.new()

# Authenticate
{:ok, authenticated_client} = Twitchy.authenticate(client, :app_access)

# Client is now ready to use
{:ok, response} = Twitchy.Users.get_user(authenticated_client, login: "ninja")
```

### User Access Token (OAuth Flow)

Required for user-specific actions.

#### Step 1: Generate Authorization URL

```elixir
scopes = [
  "user:read:email",
  "channel:read:subscriptions",
  "moderator:manage:banned_users",
  "chat:edit",
  "chat:read"
]

auth_url = Twitchy.generate_auth_url(scopes, state: "random_state_string")

# Redirect user to auth_url
# They'll be redirected back to your redirect_uri with a code parameter
```

#### Step 2: Exchange Code for Token

```elixir
# In your callback handler
def callback(conn, %{"code" => code, "state" => state}) do
  client = Twitchy.new()

  case Twitchy.authenticate(client, :user_access, code: code) do
    {:ok, authenticated_client} ->
      # Store tokens for this user
      conn
      |> put_session(:twitch_access_token, authenticated_client.access_token)
      |> put_session(:twitch_refresh_token, authenticated_client.refresh_token)
      |> redirect(to: "/dashboard")

    {:error, error} ->
      send_resp(conn, 401, "Authentication failed")
  end
end
```

## Making API Calls

### Basic Pattern

```elixir
{:ok, response} = Twitchy.ModuleName.function_name(client, params)
```

### Examples

```elixir
# Get a single user
{:ok, response} = Twitchy.Users.get_user(client, login: "ninja")
user = List.first(response["data"])

# Get multiple users
{:ok, response} = Twitchy.Users.get_users(client, login: ["ninja", "shroud"])

# Get streams
{:ok, response} = Twitchy.Streams.get_streams(client,
  game_id: "509658",
  language: "en",
  first: 20
)
```

## Pagination

Many APIs return paginated results:

```elixir
def get_all_followers(client, broadcaster_id) do
  get_all_followers(client, broadcaster_id, nil, [])
end

defp get_all_followers(client, broadcaster_id, cursor, acc) do
  params = [broadcaster_id: broadcaster_id, first: 100]
  params = if cursor, do: Keyword.put(params, :after, cursor), else: params

  {:ok, response} = Twitchy.Users.get_followers(client, params)
  new_acc = acc ++ response["data"]

  case response["pagination"]["cursor"] do
    nil -> new_acc
    next_cursor -> get_all_followers(client, broadcaster_id, next_cursor, new_acc)
  end
end
```

## Error Handling

```elixir
case Twitchy.Users.get_user(client, login: "nonexistent") do
  {:ok, response} ->
    handle_success(response)

  {:error, %{"status" => 401}} ->
    # Unauthorized - token invalid/expired
    refresh_or_reauth()

  {:error, %{"status" => 404}} ->
    handle_not_found()

  {:error, %{"status" => 429}} ->
    # Rate limited
    handle_rate_limit()

  {:error, error} ->
    Logger.error("API error: #{inspect(error)}")
end
```

## EventSub

### WebSocket (Recommended)

```elixir
{:ok, _pid} = Twitchy.EventSub.Declarative.start_link(
  client: client,
  handler: MyApp.EventHandler,
  subscriptions: [
    %{
      type: "stream.online",
      condition: %{"broadcaster_user_id" => "123456"}
    },
    %{
      type: "channel.follow",
      condition: %{
        "broadcaster_user_id" => "123456",
        "moderator_user_id" => "123456"
      },
      version: "2"
    }
  ]
)

defmodule MyApp.EventHandler do
  def handle_event("stream.online", event, _metadata) do
    IO.puts("#{event["broadcaster_user_name"]} went live!")
    :ok
  end
  
  def handle_event(_type, _event, _metadata), do: :ok
end
```

## Telemetry

Twitchy emits telemetry events for monitoring:

```elixir
defmodule MyApp.TelemetryHandler do
  require Logger

  def setup do
    events = [
      [:twitchy, :request, :start],
      [:twitchy, :request, :stop],
      [:twitchy, :request, :exception],
      [:twitchy, :eventsub, :event]
    ]

    :telemetry.attach_many(
      "my-app-twitchy-handler",
      events,
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event([:twitchy, :request, :stop], measurements, metadata, _config) do
    Logger.info("Twitch API request completed in #{measurements.duration}ms")
  end
end
```

## Advanced Features

### Custom Token Store

```elixir
defmodule MyApp.TokenStore do
  @behaviour Twitchy.TokenStore

  @impl true
  def get_token(user_id) do
    case MyApp.Repo.get_by(Token, user_id: user_id) do
      %Token{access_token: token} -> {:ok, token}
      nil -> {:error, :not_found}
    end
  end

  @impl true
  def put_token(user_id, token) do
    # Save to database
    :ok
  end

  @impl true
  def delete_token(user_id) do
    # Delete from database
    :ok
  end
end
```

### Concurrent Requests

```elixir
user_logins = ["ninja", "shroud", "pokimane"]

tasks = Enum.map(user_logins, fn login ->
  Task.async(fn ->
    Twitchy.Users.get_user(client, login: login)
  end)
end)

results = Task.await_many(tasks, 5000)
```

## Best Practices

1. **Always handle errors** - Network requests can fail
2. **Use appropriate auth type** - App access for backend, user access for user actions
3. **Store tokens securely** - Don't log or expose access tokens
4. **Respect rate limits** - Don't hammer the API
5. **Use telemetry** - Monitor your API usage
6. **Cache when possible** - Don't repeatedly fetch the same data
7. **Use EventSub** - More efficient than polling
8. **Test with mocks** - Don't hit live API in tests

## See Also

- [Quick Start Guide](QUICKSTART.md)
- [Examples](EXAMPLES.md)
- [API Documentation](docs/api/API_REFERENCE.md)
- [EventSub Examples](EVENTSUB_EXAMPLES.md)
