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

### Send Chat Message

Send a message to chat (requires `user:write:chat` scope).

```elixir
{:ok, response} = Twitchy.Chat.send_chat_message(client,
  broadcaster_id: "123456",
  sender_id: "123456",
  message: "Hello chat! PogChamp"
)

sent_message = List.first(response["data"])
IO.puts("Message sent! ID: #{sent_message["message_id"]}")
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
{:ok, response} = Twitchy.Moderation.ban_user(client,
  broadcaster_id: "123456",
  moderator_id: "123456",
  user_id: "789",
  reason: "Spamming"
)

# Temporary timeout (600 seconds = 10 minutes)
{:ok, response} = Twitchy.Moderation.ban_user(client,
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
{:ok, response} = Twitchy.Moderation.unban_user(client,
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
{:ok, _} = Twitchy.Moderation.add_channel_moderator(client,
  broadcaster_id: "123456",
  user_id: "789"
)

# Remove moderator
{:ok, _} = Twitchy.Moderation.remove_channel_moderator(client,
  broadcaster_id: "123456",
  user_id: "789"
)
```

### Block/Unblock Terms

Manage blocked terms (AutoMod).

```elixir
# Add blocked terms
{:ok, response} = Twitchy.Moderation.add_blocked_term(client,
  broadcaster_id: "123456",
  moderator_id: "123456",
  text: "badword"
)

# Get blocked terms
{:ok, response} = Twitchy.Moderation.get_blocked_terms(client,
  broadcaster_id: "123456",
  moderator_id: "123456"
)

# Remove blocked term
{:ok, _} = Twitchy.Moderation.remove_blocked_term(client,
  broadcaster_id: "123456",
  moderator_id: "123456",
  id: "term_id_here"
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

### Manage Held AutoMod Messages

Handle messages held by AutoMod.

```elixir
# Approve message
{:ok, _} = Twitchy.Moderation.manage_held_automod_messages(client,
  user_id: "123456",
  msg_id: "message_id_here",
  action: "ALLOW"
)

# Deny message
{:ok, _} = Twitchy.Moderation.manage_held_automod_messages(client,
  user_id: "123456",
  msg_id: "message_id_here",
  action: "DENY"
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
      client: client,
      handler: __MODULE__,
      subscriptions: [
        %{
          type: "channel.chat.message",
          condition: %{
            "broadcaster_user_id" => channel_id,
            "user_id" => channel_id
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

  # Handle chat messages
  def handle_event("channel.chat.message", event, _meta) do
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

    Twitchy.Chat.send_chat_message(state.client,
      broadcaster_id: state.channel_id,
      sender_id: state.channel_id,
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

  @spam_threshold 5  # Messages per 10 seconds
  @caps_threshold 0.7  # 70% caps = warning

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    client = opts[:client]
    channel_id = opts[:channel_id]

    {:ok, _} = Twitchy.EventSub.Declarative.start_link(
      client: client,
      handler: __MODULE__,
      subscriptions: [
        %{
          type: "channel.chat.message",
          condition: %{
            "broadcaster_user_id" => channel_id,
            "user_id" => channel_id
          }
        },
        %{
          type: "automod.message.hold",
          condition: %{
            "broadcaster_user_id" => channel_id,
            "moderator_user_id" => channel_id
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

  def handle_event("channel.chat.message", event, _meta) do
    message = event["message"]["text"]
    user_id = event["chatter_user_id"]
    user_name = event["chatter_user_name"]

    state = :sys.get_state(__MODULE__)

    # Check for spam
    if is_spam?(state, user_id) do
      timeout_user(state.client, state.channel_id, user_id, 300, "Spam")
      Logger.warn("Timed out #{user_name} for spam")
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

  def handle_event("automod.message.hold", event, _meta) do
    message_id = event["message_id"]
    user_id = event["user_id"]

    state = :sys.get_state(__MODULE__)

    # Auto-deny if user has been warned
    action = if MapSet.member?(state.warned_users, user_id) do
      "DENY"
    else
      "ALLOW"
    end

    Twitchy.Moderation.manage_held_automod_messages(state.client,
      user_id: state.channel_id,
      msg_id: message_id,
      action: action
    )

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
    return false if String.length(message) < 10

    caps_count = message
      |> String.graphemes()
      |> Enum.count(&(&1 =~ ~r/[A-Z]/))

    total_letters = message
      |> String.graphemes()
      |> Enum.count(&(&1 =~ ~r/[A-Za-z]/))

    return false if total_letters == 0

    caps_ratio = caps_count / total_letters
    caps_ratio >= @caps_threshold
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
    Twitchy.Chat.send_chat_message(client,
      broadcaster_id: broadcaster_id,
      sender_id: broadcaster_id,
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
