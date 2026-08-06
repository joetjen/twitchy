# Tutorial: Building a Stream Alert & Moderation Bot

This tutorial walks through building a small, real, deployable Elixir application
with Twitchy: a bot that announces when a channel goes live or offline, and lets
viewers redeem a "Timeout Yourself" channel points reward to time themselves out
for a laugh.

Along the way you'll touch most of what Twitchy offers: app and user access
tokens, the Helix REST API, channel points, chat, moderation, and real-time
events over EventSub WebSocket. Each step builds on the last, and the tutorial
ends with the complete, runnable module.

For focused, shorter walkthroughs of a single API area (Users & Streams, Chat &
Moderation, Predictions & Polls, etc.), see the "Tutorial" section in each guide
under [docs/api/API_REFERENCE.md](docs/api/API_REFERENCE.md).

## What You'll Build

A supervised `MyApp.StreamBot` process that, once started:

1. Authenticates against the Twitch API.
2. Looks up the broadcaster's channel.
3. Creates a "Timeout Yourself" channel points reward if it doesn't already exist.
4. Subscribes to `stream.online`, `stream.offline`, and channel points redemption
   events over a persistent EventSub WebSocket connection.
5. Posts a chat announcement when the stream goes live or offline.
6. Times out (and thanks) anyone who redeems "Timeout Yourself".

## Prerequisites

- Elixir 1.14+ and Erlang/OTP 25+ (see [README.md](README.md#requirements)).
- A Twitch account for the channel the bot will run on.
- Twitchy added to your `mix.exs` dependencies (see [QUICKSTART.md](QUICKSTART.md)):

  ```elixir
  def deps do
    [
      {:twitchy, "~> 0.1"}
    ]
  end
  ```

### Register a Twitch Application

1. Go to the [Twitch Developer Console](https://dev.twitch.tv/console/apps) and
   register a new application.
2. Add an OAuth redirect URL. For this tutorial, any URL you can read the query
   string from works — `http://localhost:4000/auth/callback` is fine even if
   nothing is listening there yet; you'll copy the `code` parameter out of the
   browser's address bar by hand in Step 2.
3. Note the **Client ID** and generate a **Client Secret** — you'll need both.

### Choose Your Scopes

Looking up public data (users, streams, games) works with an **app access
token** and no scopes. Everything the bot *does* — creating a reward, sending
chat announcements, and timing viewers out — requires a **user access token**
for the broadcaster, authorized with:

- `channel:manage:redemptions` — create/manage the custom reward and its redemptions
- `moderator:manage:announcements` — post chat announcements
- `moderator:manage:banned_users` — time out (ban) users

A broadcaster's own user token is always allowed to moderate and manage their
own channel, so we'll authenticate as the broadcaster and use their user ID as
both `broadcaster_id` and `moderator_id` throughout.

## Step 1: Install and Configure Twitchy

```elixir
# mix.exs
def deps do
  [
    {:twitchy, "~> 0.1"}
  ]
end
```

```bash
mix deps.get
```

Twitchy reads `TWITCH_CLIENT_ID`/`TWITCH_CLIENT_SECRET` from the environment by
default, or you can pass them explicitly to `Twitchy.new/1`. We'll pass them
explicitly so the bot's configuration lives in one place.

## Step 2: Get a User Access Token for the Broadcaster

Start an `iex -S mix` session and generate the authorization URL:

```elixir
client =
  Twitchy.new(
    client_id: "your_client_id",
    client_secret: "your_client_secret",
    redirect_uri: "http://localhost:4000/auth/callback"
  )

auth_url =
  Twitchy.auth_url(client, [
    "channel:manage:redemptions",
    "moderator:manage:announcements",
    "moderator:manage:banned_users"
  ])

IO.puts(auth_url)
```

Open the printed URL in a browser, log in as the broadcaster, and click
**Authorize**. You'll be redirected to your `redirect_uri` with a `code` query
parameter — copy it out of the address bar, even if the page itself fails to
load:

```text
http://localhost:4000/auth/callback?code=abcdef123456&scope=...
                                          ^^^^^^^^^^^^ copy this
```

Exchange the code for a token:

```elixir
{:ok, authenticated} = Twitchy.authenticate(client, :user_access, code: "abcdef123456")

authenticated.access_token
authenticated.refresh_token
```

**Save `authenticated.refresh_token` somewhere durable** (a `.env` file, a
secrets manager — anything except source control). The bot will use it to
obtain fresh access tokens every time it starts, via `Twitchy.refresh_token/1`,
instead of repeating this browser flow.

## Step 3: Look Up the Channel

With a real client in hand, look up the broadcaster's user record — you'll need
their ID for every call that follows:

```elixir
{:ok, broadcaster} = Twitchy.Users.get_user(authenticated, login: "your_channel_name")
broadcaster_id = broadcaster["id"]
```

`Twitchy.Users.get_user/2` is a convenience wrapper around `get_users/2` that
returns the first match, or `{:error, :user_not_found}` if the login doesn't
exist — worth handling explicitly, since a typo here means everything after it
fails.

You can also check whether the channel is currently live, which is handy for
logging or deciding whether to skip the "we just went live" announcement on
startup if the bot is restarting mid-stream:

```elixir
case Twitchy.Streams.get_stream(authenticated, user_id: broadcaster_id) do
  {:ok, nil} -> IO.puts("Channel is offline")
  {:ok, stream} -> IO.puts("Channel is live: #{stream["title"]}")
  {:error, error} -> IO.puts("Couldn't check stream status: #{Exception.message(error)}")
end
```

## Step 4: Create the "Timeout Yourself" Reward

Channel points rewards should only be created once — recreating it on every
restart would spam the redemption list with duplicates. Look for an existing
reward with the same title first, and only create one if it's missing:

```elixir
defp ensure_timeout_reward(client, broadcaster_id) do
  case Twitchy.ChannelPoints.get_custom_rewards(client, broadcaster_id: broadcaster_id) do
    {:ok, %{"data" => rewards}} ->
      case Enum.find(rewards, &(&1["title"] == "Timeout Yourself")) do
        nil -> create_timeout_reward(client, broadcaster_id)
        reward -> {:ok, reward}
      end

    error ->
      error
  end
end

defp create_timeout_reward(client, broadcaster_id) do
  case Twitchy.ChannelPoints.create_custom_reward(client,
         broadcaster_id: broadcaster_id,
         title: "Timeout Yourself",
         cost: 500,
         prompt: "Time yourself out for 60 seconds. Chaos mode!",
         is_user_input_required: false
       ) do
    {:ok, %{"data" => [reward | _]}} -> {:ok, reward}
    error -> error
  end
end
```

`get_custom_rewards/2` only returns rewards created by *your* application by
default (add `only_manageable_rewards: true` if the broadcaster also has
manually-created rewards you want to include), so this lookup is safe to run
on every restart.

## Step 5: Subscribe to Real-Time Events

Rather than managing an EventSub WebSocket connection and its subscriptions by
hand, use `Twitchy.EventSub.Declarative` — you declare the subscriptions you
want, and it creates them once the session is ready, reconciles them if you
change your mind later, and cleans them up when it stops:

```elixir
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
  },
  %{
    type: "channel.channel_points_custom_reward_redemption.add",
    version: "1",
    condition: %{broadcaster_user_id: broadcaster_id, reward_id: reward["id"]}
  }
]

{:ok, _pid} =
  Twitchy.EventSub.Declarative.start_link(
    name: :stream_bot_eventsub,
    client: authenticated,
    subscriptions: subscriptions,
    handler: {MyApp.StreamBot, :handle_event, [self()]}
  )
```

The `handler` tuple is called as `handle_event(event, self())` for **every**
message the WebSocket receives — not just notifications. `event` is the raw
decoded EventSub message, so your handler needs to filter for the messages it
cares about:

```elixir
def handle_event(%{"metadata" => %{"message_type" => "notification"}} = event, bot_pid) do
  type = get_in(event, ["payload", "subscription", "type"])
  data = get_in(event, ["payload", "event"])
  send(bot_pid, {:eventsub, type, data})
  :ok
end

def handle_event(_event, _bot_pid), do: :ok
```

Forwarding the parsed event to the calling process as a plain message keeps the
handler function itself tiny and lets the rest of the bot's logic live in
ordinary `handle_info/2` clauses, which is what the complete example below
does.

## Step 6: React to Events

Once notifications arrive as `{:eventsub, type, data}` messages, reacting to
them is a regular GenServer `handle_info` callback:

```elixir
def handle_info({:eventsub, "stream.online", _data}, state) do
  announce(state.client, state.broadcaster_id, "🔴 We're live! Welcome in.")
  {:noreply, state}
end

def handle_info({:eventsub, "stream.offline", _data}, state) do
  announce(state.client, state.broadcaster_id, "Thanks for watching! 💜 See you next time.")
  {:noreply, state}
end

def handle_info({:eventsub, "channel.channel_points_custom_reward_redemption.add", data}, state) do
  if data["reward"]["id"] == state.reward_id do
    timeout_redeemer(state.client, state.broadcaster_id, data)
  end

  {:noreply, state}
end
```

Chat announcements go through `Twitchy.Chat.send_chat_announcement/2`:

```elixir
defp announce(client, broadcaster_id, message) do
  case Twitchy.Chat.send_chat_announcement(client,
         broadcaster_id: broadcaster_id,
         moderator_id: broadcaster_id,
         message: message,
         color: :primary
       ) do
    :ok -> :ok
    {:error, error} -> Logger.warning("Failed to send announcement: #{Exception.message(error)}")
  end
end
```

Timing someone out combines `Twitchy.Moderation.ban_user/2` (a `:duration` turns
a ban into a timeout) with `Twitchy.ChannelPoints.update_redemption_status/2`
to mark the redemption fulfilled — or canceled, which automatically refunds the
viewer's points, if the timeout call itself failed:

```elixir
defp timeout_redeemer(client, broadcaster_id, redemption) do
  user_id = redemption["user_id"]
  user_login = redemption["user_login"]
  reward_id = redemption["reward"]["id"]

  with :ok <-
         Twitchy.Moderation.ban_user(client,
           broadcaster_id: broadcaster_id,
           moderator_id: broadcaster_id,
           user_id: user_id,
           duration: 60,
           reason: "Self-inflicted via channel points"
         ),
       :ok <-
         Twitchy.ChannelPoints.update_redemption_status(client,
           broadcaster_id: broadcaster_id,
           reward_id: reward_id,
           id: [redemption["id"]],
           status: "FULFILLED"
         ) do
    announce(client, broadcaster_id, "😂 #{user_login} timed themselves out for 60s!")
  else
    {:error, error} ->
      Logger.warning("Failed to time out #{user_login}: #{Exception.message(error)}")

      Twitchy.ChannelPoints.update_redemption_status(client,
        broadcaster_id: broadcaster_id,
        reward_id: reward_id,
        id: [redemption["id"]],
        status: "CANCELED"
      )
  end
end
```

## Step 7: Handle Errors the Way the API Actually Reports Them

Every Twitchy call that can fail returns `{:error, exception}` where `exception`
is one of the structs in `Twitchy.Error` — never a bare string or generic map.
Match on the struct when you need to branch on *why* something failed, and fall
back to `Exception.message/1` for logging:

```elixir
case Twitchy.Users.get_user(client, login: "your_channel_name") do
  {:ok, user} ->
    {:ok, user}

  {:error, %Twitchy.Error.AuthError{status: 401}} ->
    # Access token expired mid-run — refresh and retry once.
    with {:ok, refreshed} <- Twitchy.refresh_token(client) do
      Twitchy.Users.get_user(refreshed, login: "your_channel_name")
    end

  {:error, %Twitchy.Error.RateLimitError{reset_at: reset_at}} ->
    Logger.warning("Rate limited until #{reset_at}")
    {:error, :rate_limited}

  {:error, error} ->
    Logger.error(Exception.message(error))
    {:error, error}
end
```

The complete example below keeps this simpler by logging and moving on rather
than retrying — appropriate for a stream bot where a single missed
announcement isn't critical, but worth tightening up for anything that must
not silently drop work.

## Step 8: Supervise It

`MyApp.StreamBot` (below) does its setup — authenticate, look up the channel,
ensure the reward exists, start the EventSub connection — inside
`handle_continue/2`, so `start_link/1` returns immediately and the expensive
work happens without blocking its supervisor. If anything in that setup fails,
the process stops and its supervisor restarts it, safely redoing the whole
sequence from scratch:

```elixir
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {MyApp.StreamBot,
       client_id: System.fetch_env!("TWITCH_CLIENT_ID"),
       client_secret: System.fetch_env!("TWITCH_CLIENT_SECRET"),
       refresh_token: System.fetch_env!("TWITCH_BOT_REFRESH_TOKEN"),
       broadcaster_login: System.fetch_env!("TWITCH_BROADCASTER_LOGIN")}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end
end
```

## The Complete Bot

Everything above, assembled into one supervised module. Drop this into
`lib/my_app/stream_bot.ex` in a project with `:twitchy` as a dependency and the
four environment variables from Step 8 set, and it's ready to run.

```elixir
defmodule MyApp.StreamBot do
  @moduledoc """
  Announces when the channel goes live/offline, and lets viewers time
  themselves out by redeeming a "Timeout Yourself" channel points reward.
  """

  use GenServer
  require Logger

  @reward_title "Timeout Yourself"
  @timeout_seconds 60

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Server callbacks

  @impl true
  def init(opts) do
    {:ok, Map.new(opts), {:continue, :authenticate}}
  end

  @impl true
  def handle_continue(:authenticate, opts) do
    client =
      Twitchy.new(
        client_id: opts.client_id,
        client_secret: opts.client_secret,
        refresh_token: opts.refresh_token
      )

    case Twitchy.refresh_token(client) do
      {:ok, client} ->
        {:noreply, %{client: client, broadcaster_login: opts.broadcaster_login}, {:continue, :setup}}

      {:error, error} ->
        Logger.error("StreamBot failed to authenticate: #{Exception.message(error)}")
        {:stop, :auth_failed, opts}
    end
  end

  def handle_continue(:setup, state) do
    with {:ok, broadcaster} <- Twitchy.Users.get_user(state.client, login: state.broadcaster_login),
         broadcaster_id = broadcaster["id"],
         {:ok, reward} <- ensure_timeout_reward(state.client, broadcaster_id),
         {:ok, _pid} <- start_eventsub(state.client, broadcaster_id, reward["id"]) do
      state =
        state
        |> Map.put(:broadcaster_id, broadcaster_id)
        |> Map.put(:reward_id, reward["id"])

      Logger.info("StreamBot ready for #{state.broadcaster_login}")
      {:noreply, state}
    else
      {:error, error} ->
        Logger.error("StreamBot failed to set up: #{inspect(error)}")
        {:stop, :setup_failed, state}
    end
  end

  @impl true
  def handle_info({:eventsub, "stream.online", _data}, state) do
    announce(state.client, state.broadcaster_id, "🔴 We're live! Welcome in.")
    {:noreply, state}
  end

  def handle_info({:eventsub, "stream.offline", _data}, state) do
    announce(state.client, state.broadcaster_id, "Thanks for watching! 💜 See you next time.")
    {:noreply, state}
  end

  def handle_info({:eventsub, "channel.channel_points_custom_reward_redemption.add", data}, state) do
    if data["reward"]["id"] == state.reward_id do
      timeout_redeemer(state.client, state.broadcaster_id, data)
    end

    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  ## EventSub handler (called by Twitchy.EventSub.Declarative for every WebSocket message)

  @doc false
  def handle_event(%{"metadata" => %{"message_type" => "notification"}} = event, bot_pid) do
    type = get_in(event, ["payload", "subscription", "type"])
    data = get_in(event, ["payload", "event"])
    send(bot_pid, {:eventsub, type, data})
    :ok
  end

  def handle_event(_event, _bot_pid), do: :ok

  ## Private helpers

  defp start_eventsub(client, broadcaster_id, reward_id) do
    subscriptions = [
      %{type: "stream.online", version: "1", condition: %{broadcaster_user_id: broadcaster_id}},
      %{type: "stream.offline", version: "1", condition: %{broadcaster_user_id: broadcaster_id}},
      %{
        type: "channel.channel_points_custom_reward_redemption.add",
        version: "1",
        condition: %{broadcaster_user_id: broadcaster_id, reward_id: reward_id}
      }
    ]

    Twitchy.EventSub.Declarative.start_link(
      name: :stream_bot_eventsub,
      client: client,
      subscriptions: subscriptions,
      handler: {__MODULE__, :handle_event, [self()]}
    )
  end

  defp ensure_timeout_reward(client, broadcaster_id) do
    case Twitchy.ChannelPoints.get_custom_rewards(client, broadcaster_id: broadcaster_id) do
      {:ok, %{"data" => rewards}} ->
        case Enum.find(rewards, &(&1["title"] == @reward_title)) do
          nil -> create_timeout_reward(client, broadcaster_id)
          reward -> {:ok, reward}
        end

      error ->
        error
    end
  end

  defp create_timeout_reward(client, broadcaster_id) do
    case Twitchy.ChannelPoints.create_custom_reward(client,
           broadcaster_id: broadcaster_id,
           title: @reward_title,
           cost: 500,
           prompt: "Time yourself out for #{@timeout_seconds} seconds. Chaos mode!",
           is_user_input_required: false
         ) do
      {:ok, %{"data" => [reward | _]}} -> {:ok, reward}
      error -> error
    end
  end

  defp announce(client, broadcaster_id, message) do
    case Twitchy.Chat.send_chat_announcement(client,
           broadcaster_id: broadcaster_id,
           moderator_id: broadcaster_id,
           message: message,
           color: :primary
         ) do
      :ok -> :ok
      {:error, error} -> Logger.warning("Failed to send announcement: #{Exception.message(error)}")
    end
  end

  defp timeout_redeemer(client, broadcaster_id, redemption) do
    user_id = redemption["user_id"]
    user_login = redemption["user_login"]
    reward_id = redemption["reward"]["id"]

    with :ok <-
           Twitchy.Moderation.ban_user(client,
             broadcaster_id: broadcaster_id,
             moderator_id: broadcaster_id,
             user_id: user_id,
             duration: @timeout_seconds,
             reason: "Self-inflicted via channel points"
           ),
         :ok <-
           Twitchy.ChannelPoints.update_redemption_status(client,
             broadcaster_id: broadcaster_id,
             reward_id: reward_id,
             id: [redemption["id"]],
             status: "FULFILLED"
           ) do
      announce(client, broadcaster_id, "😂 #{user_login} timed themselves out for #{@timeout_seconds}s!")
    else
      {:error, error} ->
        Logger.warning("Failed to time out #{user_login}: #{Exception.message(error)}")

        Twitchy.ChannelPoints.update_redemption_status(client,
          broadcaster_id: broadcaster_id,
          reward_id: reward_id,
          id: [redemption["id"]],
          status: "CANCELED"
        )
    end
  end
end
```

## Running It

```bash
export TWITCH_CLIENT_ID="your_client_id"
export TWITCH_CLIENT_SECRET="your_client_secret"
export TWITCH_BOT_REFRESH_TOKEN="the refresh_token from Step 2"
export TWITCH_BROADCASTER_LOGIN="your_channel_name"

mix run --no-halt
```

Go live (or simulate it — see [TESTING_GUIDE.md](TESTING_GUIDE.md) for testing
against Bypass instead of the real API) and watch the bot post an announcement.
Redeem "Timeout Yourself" from the channel points panel and watch it fire back.

## Where to Go Next

This bot only scratches the surface of each API it touches. Deeper,
single-topic tutorials with their own complete examples live alongside the API
reference:

- [Users & Streams](docs/api/USERS_STREAMS.md) — look up channels and track who's live
- [Channels & Games](docs/api/CHANNELS_GAMES.md) — update stream title/category
- [Videos & Clips](docs/api/VIDEOS_CLIPS.md) — build a highlights digest
- [Chat & Moderation](docs/api/CHAT_MODERATION.md) — deeper AutoMod and ban management
- [Subscriptions & Channel Points](docs/api/SUBSCRIPTIONS_CHANNELPOINTS.md) — manage a redemption queue
- [Predictions, Polls & Hype Train](docs/api/PREDICTIONS_POLLS_HYPETRAIN.md) — run interactive stream events
- [Bits, Teams, Schedule & Raids](docs/api/BITS_TEAMS_SCHEDULE_RAIDS.md) — schedule and raid tooling
- [Analytics, Search, Ads & Misc](docs/api/ANALYTICS_SEARCH_ADS_MISC.md) — reporting and search

Also worth reading next:

- [EVENTSUB_EXAMPLES.md](EVENTSUB_EXAMPLES.md) — webhook-based EventSub, multi-channel bots, and reconnect handling
- [TESTING_GUIDE.md](TESTING_GUIDE.md) — testing code that calls Twitchy without hitting the real API
- [USAGE_GUIDE.md](USAGE_GUIDE.md) — patterns for pagination, telemetry, and token storage
