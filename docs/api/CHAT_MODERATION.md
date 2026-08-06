# Chat & Moderation API

Documentation for Twitch Chat and Moderation APIs.

## Chat API

### Get Chatters

Get the list of users connected to a broadcaster's chat (requires `moderator:read:chatters` scope).

```elixir
{:ok, response} = Twitchy.Chat.get_chatters(client,
  broadcaster_id: "123456",
  moderator_id: "123456",
  first: 100
)

IO.puts("Total chatters: #{response["total"]}")

Enum.each(response["data"], fn chatter ->
  IO.puts("#{chatter["user_name"]} (#{chatter["user_login"]})")
end)
```

### Get Chat Settings

Get the broadcaster's chat settings.

```elixir
{:ok, response} = Twitchy.Chat.get_chat_settings(client,
  broadcaster_id: "123456"
)

settings = List.first(response["data"])
IO.puts("Slow mode: #{settings["slow_mode"]}")
IO.puts("Follower mode: #{settings["follower_mode"]}")
IO.puts("Subscriber mode: #{settings["subscriber_mode"]}")
IO.puts("Emote mode: #{settings["emote_mode"]}")
```

### Update Chat Settings

Modify chat settings (requires `moderator:manage:chat_settings` scope).

```elixir
{:ok, response} = Twitchy.Chat.update_chat_settings(client,
  broadcaster_id: "123456",
  moderator_id: "123456",
  slow_mode: true,
  slow_mode_wait_time: 30,
  follower_mode: true,
  follower_mode_duration: 10  # 10 minutes
)
```

### Send Chat Announcement

Post an announcement to chat (requires `moderator:manage:announcements` scope).

```elixir
:ok = Twitchy.Chat.send_chat_announcement(client,
  broadcaster_id: "123456",
  moderator_id: "123456",
  message: "Hello chat! PogChamp",
  color: :primary
)
```

### Get Emotes

Get emotes available in the channel.

```elixir
# Global emotes
{:ok, response} = Twitchy.Chat.get_global_emotes(client)

# Channel emotes
{:ok, response} = Twitchy.Chat.get_channel_emotes(client,
  broadcaster_id: "123456"
)

Enum.each(response["data"], fn emote ->
  IO.puts("#{emote["name"]} - #{emote["images"]["url_1x"]}")
end)
```

### Get Badges

Get chat badges for a channel.

```elixir
{:ok, response} = Twitchy.Chat.get_channel_chat_badges(client,
  broadcaster_id: "123456"
)

Enum.each(response["data"], fn badge_set ->
  IO.puts("Badge Set: #{badge_set["set_id"]}")

  Enum.each(badge_set["versions"], fn version ->
    IO.puts("  Version #{version["id"]}: #{version["image_url_1x"]}")
  end)
end)
```

## Moderation API

### Ban User

Ban or timeout a user (requires `moderator:manage:banned_users` scope).

```elixir
# Permanent ban
:ok = Twitchy.Moderation.ban_user(client,
  broadcaster_id: "123456",
  moderator_id: "123456",
  user_id: "789",
  reason: "Spamming"
)

# Temporary timeout (600 seconds = 10 minutes)
:ok = Twitchy.Moderation.ban_user(client,
  broadcaster_id: "123456",
  moderator_id: "123456",
  user_id: "789",
  duration: 600,
  reason: "Excessive caps"
)
```

### Unban User

Remove a ban or timeout.

```elixir
:ok = Twitchy.Moderation.unban_user(client,
  broadcaster_id: "123456",
  moderator_id: "123456",
  user_id: "789"
)
```

### Get Banned Users

Get list of banned users.

```elixir
{:ok, response} = Twitchy.Moderation.get_banned_users(client,
  broadcaster_id: "123456",
  first: 100
)

Enum.each(response["data"], fn ban ->
  IO.puts("#{ban["user_name"]} - #{ban["reason"]}")
  IO.puts("  Banned by: #{ban["moderator_name"]} at #{ban["created_at"]}")

  if ban["expires_at"] do
    IO.puts("  Expires: #{ban["expires_at"]}")
  else
    IO.puts("  Permanent ban")
  end
end)
```

### Get Moderators

Get list of channel moderators.

```elixir
{:ok, response} = Twitchy.Moderation.get_moderators(client,
  broadcaster_id: "123456",
  first: 100
)

Enum.each(response["data"], fn mod ->
  IO.puts("Moderator: #{mod["user_name"]}")
end)
```

### Add/Remove Moderator

Manage channel moderators (requires `channel:manage:moderators` scope).

```elixir
# Add moderator
:ok = Twitchy.Moderation.add_channel_moderator(client,
  broadcaster_id: "123456",
  user_id: "789"
)

# Remove moderator
:ok = Twitchy.Moderation.remove_channel_moderator(client,
  broadcaster_id: "123456",
  user_id: "789"
)
```

### AutoMod Settings

Check and manage AutoMod settings.

```elixir
# Get AutoMod settings
{:ok, response} = Twitchy.Moderation.get_automod_settings(client,
  broadcaster_id: "123456",
  moderator_id: "123456"
)

settings = List.first(response["data"])
IO.puts("Bullying: #{settings["bullying"]}")
IO.puts("Swearing: #{settings["swearing"]}")
IO.puts("Sexuality: #{settings["sexuality_sex_or_gender"]}")

# Update AutoMod settings
{:ok, _} = Twitchy.Moderation.update_automod_settings(client,
  broadcaster_id: "123456",
  moderator_id: "123456",
  bullying: 2,
  swearing: 1,
  sexuality_sex_or_gender: 3
)
```

## Examples

### Chat Bot

A comprehensive chat bot with command handling.

```elixir
defmodule MyApp.ChatBot do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    client = opts[:client]
    channel_id = opts[:channel_id]

    # Subscribe to chat events via EventSub
    {:ok, _} = Twitchy.EventSub.Declarative.start_link(
      name: :chat_bot_eventsub,
      client: client,
      handler: {__MODULE__, :handle_event, []},
      subscriptions: [
        %{
          type: "channel.chat.message",
          version: "1",
          condition: %{
            broadcaster_user_id: channel_id,
            user_id: channel_id
          }
        }
      ]
    )

    {:ok, %{
      client: client,
      channel_id: channel_id,
      commands: build_commands()
    }}
  end

  # The handler is called for every WebSocket message, not just notifications —
  # filter for the message type and subscription type we care about.
  def handle_event(%{"metadata" => %{"message_type" => "notification"}} = event, _opts) do
    if get_in(event, ["payload", "subscription", "type"]) == "channel.chat.message" do
      handle_chat_message(get_in(event, ["payload", "event"]))
    end

    :ok
  end

  def handle_event(_event, _opts), do: :ok

  defp handle_chat_message(event) do
    message = event["message"]["text"]
    user = event["chatter_user_name"]
    user_id = event["chatter_user_id"]

    if String.starts_with?(message, "!") do
      handle_command(message, user, user_id)
    end

    :ok
  end

  defp handle_command("!hello" <> _, user, _user_id) do
    send_message("Hello, #{user}! 👋")
  end

  defp handle_command("!uptime", _user, _user_id) do
    state = :sys.get_state(__MODULE__)

    case Twitchy.Streams.get_streams(state.client, user_id: [state.channel_id]) do
      {:ok, %{"data" => [stream | _]}} ->
        started = DateTime.from_iso8601(stream["started_at"]) |> elem(1)
        uptime = DateTime.diff(DateTime.utc_now(), started, :second)
        send_message("Stream uptime: #{format_uptime(uptime)}")

      {:ok, %{"data" => []}} ->
        send_message("Stream is currently offline")
    end
  end

  defp handle_command("!commands", _user, _user_id) do
    send_message("Available commands: !hello, !uptime, !game, !commands")
  end

  defp handle_command("!game", _user, _user_id) do
    state = :sys.get_state(__MODULE__)

    {:ok, response} = Twitchy.Channels.get_channel_information(state.client,
      broadcaster_id: state.channel_id
    )

    channel = List.first(response["data"])
    send_message("Current game: #{channel["game_name"]}")
  end

  defp handle_command(_, _, _), do: :ok

  defp send_message(text) do
    state = :sys.get_state(__MODULE__)

    Twitchy.Chat.send_chat_announcement(state.client,
      broadcaster_id: state.channel_id,
      moderator_id: state.channel_id,
      message: text
    )
  end

  defp format_uptime(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    "#{hours}h #{minutes}m"
  end

  defp build_commands do
    %{
      "!hello" => "Greet the user",
      "!uptime" => "Show stream uptime",
      "!game" => "Show current game",
      "!commands" => "List all commands"
    }
  end
end
```

### Moderation Bot

Automated moderation with customizable rules.

```elixir
defmodule MyApp.ModerationBot do
  use GenServer
  require Logger

  @spam_threshold 5  # Messages per 10 seconds
  @caps_threshold 0.7  # 70% caps = warning

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    client = opts[:client]
    channel_id = opts[:channel_id]

    # Note: Twitchy doesn't currently expose an endpoint for resolving already-held
    # AutoMod messages, so this bot only reacts to messages after they're posted
    # (via `channel.chat.message`). Use `Twitchy.Moderation.check_automod_status/2`
    # if you need to pre-screen messages before they reach chat.
    {:ok, _} = Twitchy.EventSub.Declarative.start_link(
      name: :moderation_bot_eventsub,
      client: client,
      handler: {__MODULE__, :handle_event, []},
      subscriptions: [
        %{
          type: "channel.chat.message",
          version: "1",
          condition: %{
            broadcaster_user_id: channel_id,
            user_id: channel_id
          }
        }
      ]
    )

    {:ok, %{
      client: client,
      channel_id: channel_id,
      user_messages: %{},  # Track spam
      warned_users: MapSet.new()
    }}
  end

  # The handler is called for every WebSocket message, not just notifications —
  # filter for the message type and subscription type we care about.
  def handle_event(%{"metadata" => %{"message_type" => "notification"}} = event, _opts) do
    if get_in(event, ["payload", "subscription", "type"]) == "channel.chat.message" do
      handle_chat_message(get_in(event, ["payload", "event"]))
    end

    :ok
  end

  def handle_event(_event, _opts), do: :ok

  defp handle_chat_message(event) do
    message = event["message"]["text"]
    user_id = event["chatter_user_id"]
    user_name = event["chatter_user_name"]

    state = :sys.get_state(__MODULE__)

    # Check for spam
    if is_spam?(state, user_id) do
      timeout_user(state.client, state.channel_id, user_id, 300, "Spam")
      Logger.warning("Timed out #{user_name} for spam")
    end

    # Check for excessive caps
    if excessive_caps?(message) && !is_moderator?(user_id) do
      if MapSet.member?(state.warned_users, user_id) do
        timeout_user(state.client, state.channel_id, user_id, 60, "Excessive caps")
      else
        warn_user(state.client, state.channel_id, user_name, "Please don't use excessive caps")
        GenServer.cast(__MODULE__, {:warn_user, user_id})
      end
    end

    # Track message for spam detection
    GenServer.cast(__MODULE__, {:track_message, user_id})

    :ok
  end

  def handle_cast({:track_message, user_id}, state) do
    now = System.system_time(:second)

    # Get user's recent messages
    messages = Map.get(state.user_messages, user_id, [])

    # Remove messages older than 10 seconds
    recent = Enum.filter(messages, &(&1 > now - 10))

    # Add current message
    updated = [now | recent]

    {:noreply, %{state | user_messages: Map.put(state.user_messages, user_id, updated)}}
  end

  def handle_cast({:warn_user, user_id}, state) do
    # Remove warning after 5 minutes
    Process.send_after(self(), {:remove_warning, user_id}, 300_000)

    {:noreply, %{state | warned_users: MapSet.put(state.warned_users, user_id)}}
  end

  def handle_info({:remove_warning, user_id}, state) do
    {:noreply, %{state | warned_users: MapSet.delete(state.warned_users, user_id)}}
  end

  defp is_spam?(state, user_id) do
    messages = Map.get(state.user_messages, user_id, [])
    now = System.system_time(:second)

    recent = Enum.filter(messages, &(&1 > now - 10))
    length(recent) >= @spam_threshold
  end

  defp excessive_caps?(message) do
    if String.length(message) < 10 do
      false
    else
      caps_count = message
        |> String.graphemes()
        |> Enum.count(&(&1 =~ ~r/[A-Z]/))

      total_letters = message
        |> String.graphemes()
        |> Enum.count(&(&1 =~ ~r/[A-Za-z]/))

      if total_letters == 0 do
        false
      else
        caps_count / total_letters >= @caps_threshold
      end
    end
  end

  defp is_moderator?(_user_id) do
    # Check if user is a moderator
    # In production, maintain a cache of moderators
    false
  end

  defp timeout_user(client, broadcaster_id, user_id, duration, reason) do
    Twitchy.Moderation.ban_user(client,
      broadcaster_id: broadcaster_id,
      moderator_id: broadcaster_id,
      user_id: user_id,
      duration: duration,
      reason: reason
    )
  end

  defp warn_user(client, broadcaster_id, user_name, warning) do
    Twitchy.Chat.send_chat_announcement(client,
      broadcaster_id: broadcaster_id,
      moderator_id: broadcaster_id,
      message: "@#{user_name} #{warning}"
    )
  end
end
```

### Chat Analytics

Track chat activity and engagement.

```elixir
defmodule MyApp.ChatAnalytics do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    client = opts[:client]
    channel_id = opts[:channel_id]

    schedule_snapshot()

    {:ok, %{
      client: client,
      channel_id: channel_id,
      snapshots: []
    }}
  end

  def handle_info(:take_snapshot, state) do
    {:ok, response} = Twitchy.Chat.get_chatters(state.client,
      broadcaster_id: state.channel_id,
      moderator_id: state.channel_id,
      first: 1000
    )

    snapshot = %{
      timestamp: DateTime.utc_now(),
      chatter_count: response["total"],
      chatters: response["data"]
    }

    new_snapshots = [snapshot | Enum.take(state.snapshots, 287)]  # Keep 24h (5 min intervals)

    # Analyze trends
    if length(new_snapshots) >= 12 do  # 1 hour of data
      analyze_trends(new_snapshots)
    end

    schedule_snapshot()
    {:noreply, %{state | snapshots: new_snapshots}}
  end

  defp analyze_trends(snapshots) do
    latest = List.first(snapshots)
    hour_ago = Enum.at(snapshots, 11)

    change = latest.chatter_count - hour_ago.chatter_count
    percent = (change / hour_ago.chatter_count * 100) |> Float.round(1)

    IO.puts("\n=== Chat Analytics ===")
    IO.puts("Current chatters: #{latest.chatter_count}")
    IO.puts("Change (1h): #{change} (#{percent}%)")

    # Find most active chatters
    frequent_chatters = find_frequent_chatters(snapshots)
    IO.puts("\nMost active chatters:")
    Enum.take(frequent_chatters, 5) |> Enum.each(fn {name, count} ->
      IO.puts("  #{name}: present in #{count}/12 snapshots")
    end)
  end

  defp find_frequent_chatters(snapshots) do
    snapshots
    |> Enum.take(12)
    |> Enum.flat_map(& &1.chatters)
    |> Enum.map(& &1["user_name"])
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end

  defp schedule_snapshot do
    # Take snapshot every 5 minutes
    Process.send_after(self(), :take_snapshot, 300_000)
  end
end
```

## Tutorial

This tutorial builds a small **Chat Moderation Assistant**: a toolkit of plain
functions that a mod team can call from `iex`, a scheduled job, or a chat
command handler. It screens a batch of reported messages through AutoMod
before anyone acts on them, bans or times out a user once a violation is
confirmed, promotes a trusted community member to moderator, and — as a
bonus for raid nights — flips on Shield Mode. Each step uses one real,
documented `Twitchy.Moderation` function; the complete assistant at the end
ties them together into a module you can drop straight into a project.

### Step 1: Set Up the Client

Everything here runs with a broadcaster's user access token. A broadcaster's
own token can always moderate their own channel, so — as in the other
tutorials in this guide — we use the same ID for both `broadcaster_id` and
`moderator_id`:

```elixir
client =
  Twitchy.new(
    client_id: System.fetch_env!("TWITCH_CLIENT_ID"),
    client_secret: System.fetch_env!("TWITCH_CLIENT_SECRET"),
    refresh_token: System.fetch_env!("TWITCH_MOD_REFRESH_TOKEN")
  )

{:ok, client} = Twitchy.refresh_token(client)

broadcaster_id = "123456"
moderator_id = broadcaster_id
```

The token needs `moderation:read`, `moderator:manage:banned_users`,
`channel:manage:moderators`, and `moderator:manage:shield_mode` scopes for
the four steps below — see [Scopes Used](#scopes-used) at the end for exactly
which step needs which.

### Step 2: Screen Reported Messages with AutoMod

Before banning anyone, run their reported messages past AutoMod so the
decision is based on Twitch's own judgment of the content, not just a mod's
gut feeling. `Twitchy.Moderation.check_automod_status/2` takes a list of
`%{msg_id:, msg_text:, user_id:}` maps and checks all of them in one request:

```elixir
{:ok, response} =
  Twitchy.Moderation.check_automod_status(client,
    broadcaster_id: broadcaster_id,
    messages: [
      %{msg_id: "1001", msg_text: "check out my totally legit crypto giveaway", user_id: "555"},
      %{msg_id: "1002", msg_text: "gg well played everyone", user_id: "556"}
    ]
  )

flagged_msg_ids =
  response["data"]
  |> Enum.reject(& &1["is_permitted"])
  |> Enum.map(& &1["msg_id"])

IO.inspect(flagged_msg_ids, label: "Messages AutoMod would hold")
```

`check_automod_status/2` only requires the `moderation:read` scope — it's a
read-only check, so it's safe to run speculatively on anything a viewer
reports without taking any action yet.

### Step 3: Ban or Time Out a Confirmed Violator

Once a message is confirmed as a violation (by the AutoMod check above, a
mod's own judgment, or both), `Twitchy.Moderation.ban_user/2` handles both
permanent bans and timeouts — the only difference is whether you pass a
`:duration`:

```elixir
# A clear, repeat violation: permanent ban.
:ok =
  Twitchy.Moderation.ban_user(client,
    broadcaster_id: broadcaster_id,
    moderator_id: moderator_id,
    user_id: "555",
    reason: "Crypto scam link, repeat offense"
  )

# A first-time, lower-severity violation: 10-minute timeout instead.
:ok =
  Twitchy.Moderation.ban_user(client,
    broadcaster_id: broadcaster_id,
    moderator_id: moderator_id,
    user_id: "556",
    duration: 600,
    reason: "Excessive caps"
  )
```

Omitting `:duration` bans the user permanently; including it (1–1,209,600
seconds) turns the same call into a timeout instead. This needs the
`moderator:manage:banned_users` scope.

### Step 4: Keep the Moderator List in Sync

Moderation isn't only about removing bad actors — it's also about
deputizing trusted ones. `Twitchy.Moderation.add_channel_moderator/2` adds a
community member to the channel's moderator list:

```elixir
:ok =
  Twitchy.Moderation.add_channel_moderator(client,
    broadcaster_id: broadcaster_id,
    user_id: "777"
  )
```

This requires the `channel:manage:moderators` scope, and it's worth pairing
with `Twitchy.Moderation.get_moderators/2` beforehand if you're syncing
against an external list of "trusted" users, so you don't re-add someone
who's already a mod.

### Step 5 (Bonus): Enable Shield Mode During a Raid

When a hate raid or a wave of ban-evading accounts hits the channel all at
once, individually banning each one doesn't scale. `Twitchy.Moderation.update_shield_mode_status/2`
turns on the broadcaster's pre-configured Shield Mode protections in a
single call:

```elixir
{:ok, response} =
  Twitchy.Moderation.update_shield_mode_status(client,
    broadcaster_id: broadcaster_id,
    moderator_id: moderator_id,
    is_active: true
  )

IO.puts("Shield Mode active: #{response["data"] |> List.first() |> Map.get("is_active")}")
```

Unlike `ban_user/2` and `add_channel_moderator/2`, this call returns
`{:ok, map()}` with the updated status rather than a bare `:ok` — useful for
confirming the toggle actually took effect. Turning it back off afterward is
the same call with `is_active: false`. This requires the
`moderator:manage:shield_mode` scope.

### The Complete Example

Putting all four pieces together as a small toolkit module. Each public
function wraps exactly one `Twitchy.Moderation` call plus the bit of logic
that makes it useful on its own — no supervision tree required, just call
these from `iex`, a scheduled job, or a chat command handler:

```elixir
defmodule MyApp.ModerationAssistant do
  @moduledoc """
  A small toolkit for reviewing reported messages, acting on confirmed
  violations, syncing the moderator list, and toggling Shield Mode during
  raids.
  """

  require Logger

  @doc """
  Runs a batch of reported messages through AutoMod and returns the
  `msg_id`s AutoMod would hold, so a human mod can decide what to do next.
  """
  def screen_messages(client, broadcaster_id, messages) do
    case Twitchy.Moderation.check_automod_status(client,
           broadcaster_id: broadcaster_id,
           messages: messages
         ) do
      {:ok, %{"data" => results}} ->
        flagged = results |> Enum.reject(& &1["is_permitted"]) |> Enum.map(& &1["msg_id"])
        {:ok, flagged}

      {:error, error} ->
        Logger.error("AutoMod check failed: #{Exception.message(error)}")
        {:error, error}
    end
  end

  @doc """
  Bans a user permanently, or times them out when `duration` (in seconds)
  is given.
  """
  def take_action(client, broadcaster_id, moderator_id, user_id, reason, duration \\ nil) do
    params =
      [broadcaster_id: broadcaster_id, moderator_id: moderator_id, user_id: user_id, reason: reason]
      |> maybe_put_duration(duration)

    case Twitchy.Moderation.ban_user(client, params) do
      :ok ->
        Logger.info("Actioned #{user_id}#{if duration, do: " (#{duration}s timeout)", else: " (ban)"}")
        :ok

      {:error, error} ->
        Logger.error("Failed to action #{user_id}: #{Exception.message(error)}")
        {:error, error}
    end
  end

  defp maybe_put_duration(params, nil), do: params
  defp maybe_put_duration(params, duration), do: Keyword.put(params, :duration, duration)

  @doc """
  Promotes a trusted community member to moderator, skipping anyone who's
  already on the moderator list.
  """
  def promote_to_moderator(client, broadcaster_id, user_id) do
    with {:ok, %{"data" => mods}} <-
           Twitchy.Moderation.get_moderators(client, broadcaster_id: broadcaster_id) do
      if Enum.any?(mods, &(&1["user_id"] == user_id)) do
        Logger.info("#{user_id} is already a moderator")
        :ok
      else
        Twitchy.Moderation.add_channel_moderator(client,
          broadcaster_id: broadcaster_id,
          user_id: user_id
        )
      end
    end
  end

  @doc """
  Turns Shield Mode on or off and returns whether it's now active.
  """
  def set_shield_mode(client, broadcaster_id, moderator_id, active?) do
    case Twitchy.Moderation.update_shield_mode_status(client,
           broadcaster_id: broadcaster_id,
           moderator_id: moderator_id,
           is_active: active?
         ) do
      {:ok, %{"data" => [status | _]}} ->
        Logger.info("Shield Mode is now #{status["is_active"]}")
        {:ok, status["is_active"]}

      {:error, error} ->
        Logger.error("Failed to update Shield Mode: #{Exception.message(error)}")
        {:error, error}
    end
  end
end
```

Using it during a raid, from `iex -S mix`:

```elixir
alias MyApp.ModerationAssistant, as: Mod

broadcaster_id = "123456"
moderator_id = broadcaster_id

# 1. Screen a batch of reported messages.
{:ok, flagged} =
  Mod.screen_messages(client, broadcaster_id, [
    %{msg_id: "1001", msg_text: "check out my totally legit crypto giveaway", user_id: "555"}
  ])

# 2. Ban the clear violator AutoMod flagged.
:ok = Mod.take_action(client, broadcaster_id, moderator_id, "555", "Crypto scam link")

# 3. Deputize a trusted community member.
:ok = Mod.promote_to_moderator(client, broadcaster_id, "777")

# 4. A hate raid starts — lock the channel down.
{:ok, true} = Mod.set_shield_mode(client, broadcaster_id, moderator_id, true)

# ...later, once it's over...
{:ok, false} = Mod.set_shield_mode(client, broadcaster_id, moderator_id, false)
```

### Scopes Used

| Step | Function | Required Scope |
| ---- | -------- | --------------- |
| Screen messages | `check_automod_status/2` | `moderation:read` |
| Ban / time out | `ban_user/2` | `moderator:manage:banned_users` |
| Sync moderator list | `get_moderators/2`, `add_channel_moderator/2` | `moderation:read` or `channel:manage:moderators`; `channel:manage:moderators` |
| Shield Mode | `update_shield_mode_status/2` | `moderator:manage:shield_mode` |

## Best Practices

1. **Rate limit chat messages** - Don't spam the chat
2. **Cache moderator list** - Check locally before API calls
3. **Use AutoMod** - Let Twitch handle basic moderation
4. **Log mod actions** - Keep audit trail of bans/timeouts
5. **Warn before timeout** - Give users a chance to correct behavior
6. **Respect slow mode** - Honor chat rate limits
7. **Handle permissions** - Check scopes before mod actions

## See Also

- [Users & Streams API](USERS_STREAMS.md)
- [EventSub Guide](../../EVENTSUB_EXAMPLES.md)
- [Usage Guide](../../USAGE_GUIDE.md)
