# Bits, Teams, Schedule & Raids API

Documentation for Bits, Teams, Schedule, and Raids APIs.

## Bits API

### Get Bits Leaderboard

Get leaderboard of top cheerers (requires OAuth with `bits:read` scope).

```elixir
{:ok, response} = Twitchy.Bits.get_bits_leaderboard(client,
  count: 10,
  period: "week"  # "day", "week", "month", "year", "all"
)

Enum.with_index(response["data"], 1) |> Enum.each(fn {entry, rank} ->
  IO.puts("#{rank}. #{entry["user_name"]}: #{entry["score"]} bits")
end)

IO.puts("\nDate range: #{response["date_range"]["started_at"]} to #{response["date_range"]["ended_at"]}")
IO.puts("Total: #{response["total"]}")
```

### Get Cheermotes

Get available Cheermotes for a channel.

```elixir
{:ok, response} = Twitchy.Bits.get_cheermotes(client,
  broadcaster_id: "123456"
)

Enum.each(response["data"], fn cheermote ->
  IO.puts("Cheermote: #{cheermote["prefix"]}")

  Enum.each(cheermote["tiers"], fn tier ->
    IO.puts("  #{tier["min_bits"]} bits: #{tier["id"]}")
    IO.puts("    Color: #{tier["color"]}")
    IO.puts("    Images: #{inspect(Map.keys(tier["images"]))}")
  end)
end)
```

### Get Extension Transactions

Get list of Bits transactions for an extension.

```elixir
{:ok, response} = Twitchy.Bits.get_extension_transactions(client,
  extension_id: "ext_id",
  first: 20
)

Enum.each(response["data"], fn txn ->
  IO.puts("Transaction: #{txn["id"]}")
  IO.puts("  User: #{txn["user_name"]}")
  IO.puts("  Product: #{txn["product"]["sku"]}")
  IO.puts("  Cost: #{txn["product"]["cost"]["amount"]} bits")
  IO.puts("  Time: #{txn["timestamp"]}")
end)
```

## Teams API

### Get Channel Teams

Get teams that a channel belongs to.

```elixir
{:ok, response} = Twitchy.Teams.get_channel_teams(client,
  broadcaster_id: "123456"
)

Enum.each(response["data"], fn team ->
  IO.puts("Team: #{team["team_name"]}")
  IO.puts("  Display Name: #{team["team_display_name"]}")
  IO.puts("  Info: #{team["info"]}")
  IO.puts("  Banner: #{team["banner"]}")
  IO.puts("  Background: #{team["background_image_url"]}")
end)
```

### Get Team

Get information about a specific team.

```elixir
# By team name
{:ok, response} = Twitchy.Teams.get_teams(client, name: "team_name")

# By team ID
{:ok, response} = Twitchy.Teams.get_teams(client, id: "team_id")

team = List.first(response["data"])
IO.puts("Team: #{team["team_display_name"]}")
IO.puts("Members: #{length(team["users"])}")

Enum.each(team["users"], fn user ->
  IO.puts("  - #{user["user_name"]}")
end)
```

## Schedule API

### Get Channel Stream Schedule

Get a channel's streaming schedule.

```elixir
{:ok, response} = Twitchy.Schedule.get_channel_stream_schedule(client,
  broadcaster_id: "123456",
  first: 20
)

IO.puts("Schedule for: #{response["data"]["broadcaster_name"]}")
IO.puts("Vacation: #{if response["data"]["vacation"], do: "Yes", else: "No"}")

Enum.each(response["data"]["segments"], fn segment ->
  IO.puts("\n#{segment["title"]}")
  IO.puts("  Start: #{segment["start_time"]}")
  IO.puts("  Duration: #{segment["duration"]} minutes")
  IO.puts("  Category: #{segment["category"]["name"] || "Not set"}")
  IO.puts("  Recurring: #{segment["is_recurring"]}")
end)
```

### Get Channel iCalendar

Get iCalendar URL for a channel's schedule.

```elixir
{:ok, response} = Twitchy.Schedule.get_channel_icalendar(client,
  broadcaster_id: "123456"
)

ical_url = response["data"]["url"]
IO.puts("iCalendar URL: #{ical_url}")

# Users can subscribe to this URL in their calendar apps
```

### Create/Update Schedule Segment

Manage schedule segments (requires `channel:manage:schedule` scope).

```elixir
# Create a new segment
{:ok, response} = Twitchy.Schedule.create_channel_stream_schedule_segment(client,
  broadcaster_id: "123456",
  start_time: DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.to_iso8601(),
  timezone: "America/New_York",
  duration: "120",  # minutes
  is_recurring: false,
  category_id: "509658",  # Just Chatting
  title: "Weekly Community Hangout"
)

# Update existing segment
{:ok, response} = Twitchy.Schedule.update_channel_stream_schedule_segment(client,
  broadcaster_id: "123456",
  id: "segment_id",
  title: "Updated Title",
  duration: "180"
)

# Delete segment
:ok = Twitchy.Schedule.delete_channel_stream_schedule_segment(client,
  broadcaster_id: "123456",
  id: "segment_id"
)
```

## Raids API

### Start Raid

Raid another channel (requires `channel:manage:raids` scope).

```elixir
:ok = Twitchy.Raids.start_raid(client,
  from_broadcaster_id: "123456",
  to_broadcaster_id: "789"
)

IO.puts("Raid started!")
```

### Cancel Raid

Cancel a pending raid.

```elixir
:ok = Twitchy.Raids.cancel_raid(client,
  broadcaster_id: "123456"
)

IO.puts("Raid canceled")
```

## Examples

### Bits Leaderboard Display

Display top cheerers with real-time updates.

```elixir
defmodule MyApp.BitsLeaderboard do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    client = opts[:client]
    channel_id = opts[:channel_id]

    # Subscribe to cheer events
    {:ok, _} = Twitchy.EventSub.Declarative.start_link(
      client: client,
      handler: __MODULE__,
      subscriptions: [
        %{
          type: "channel.cheer",
          condition: %{"broadcaster_user_id" => channel_id}
        }
      ]
    )

    schedule_update()

    {:ok, %{
      client: client,
      channel_id: channel_id,
      leaderboard: []
    }}
  end

  def handle_event("channel.cheer", event, _meta) do
    bits = event["bits"]
    user = event["user_name"]
    message = event["message"]

    IO.puts("💎 #{user} cheered #{bits} bits!")

    if message do
      IO.puts("   Message: #{message}")
    end

    # Show celebration for large cheers
    cond do
      bits >= 10000 ->
        send_chat_message("🎉🎉🎉 HUGE #{bits} bits from #{user}! 🎉🎉🎉")

      bits >= 1000 ->
        send_chat_message("🎉 Amazing #{bits} bits from #{user}! 🎉")

      bits >= 100 ->
        send_chat_message("💎 #{user} cheered #{bits} bits!")

      true ->
        :ok
    end

    :ok
  end

  def handle_info(:update_leaderboard, state) do
    {:ok, response} = Twitchy.Bits.get_bits_leaderboard(state.client,
      count: 10,
      period: "month"
    )

    new_leaderboard = response["data"]

    # Compare with previous
    if state.leaderboard != [] do
      check_position_changes(state.leaderboard, new_leaderboard)
    end

    schedule_update()
    {:noreply, %{state | leaderboard: new_leaderboard}}
  end

  defp check_position_changes(old, new) do
    old_map = Enum.with_index(old, 1) |> Enum.into(%{}, fn {entry, rank} ->
      {entry["user_id"], rank}
    end)

    Enum.with_index(new, 1) |> Enum.each(fn {entry, new_rank} ->
      old_rank = Map.get(old_map, entry["user_id"])

      if old_rank && old_rank > new_rank do
        change = old_rank - new_rank
        IO.puts("📈 #{entry["user_name"]} moved up #{change} position(s)! Now ##{new_rank}")
      end
    end)
  end

  defp send_chat_message(message) do
    state = :sys.get_state(__MODULE__)

    Twitchy.Chat.send_chat_message(state.client,
      broadcaster_id: state.channel_id,
      sender_id: state.channel_id,
      message: message
    )
  end

  defp schedule_update do
    # Update every 10 minutes
    Process.send_after(self(), :update_leaderboard, 600_000)
  end
end
```

### Schedule Manager

Manage streaming schedule programmatically.

```elixir
defmodule MyApp.ScheduleManager do
  def create_weekly_schedule(client, broadcaster_id) do
    # Create standard weekly schedule
    schedule = [
      %{day: 1, time: "18:00", duration: 180, title: "Monday Mayhem", game: "League of Legends"},
      %{day: 3, time: "18:00", duration: 180, title: "Valorant Vibes", game: "Valorant"},
      %{day: 5, time: "18:00", duration: 240, title: "Friday Night Fun", game: "Just Chatting"},
      %{day: 6, time: "14:00", duration: 300, title: "Saturday Marathon", game: "Variety"}
    ]

    Enum.each(schedule, fn slot ->
      # Calculate start time for next occurrence
      start_time = next_weekday(slot.day, slot.time)

      # Get game ID
      {:ok, games} = Twitchy.Games.get_games(client, name: [slot.game])
      game_id = List.first(games["data"])["id"]

      # Create segment
      {:ok, _} = Twitchy.Schedule.create_channel_stream_schedule_segment(client,
        broadcaster_id: broadcaster_id,
        start_time: DateTime.to_iso8601(start_time),
        timezone: "America/New_York",
        duration: to_string(slot.duration),
        is_recurring: true,
        category_id: game_id,
        title: slot.title
      )

      IO.puts("Created schedule: #{slot.title}")
    end)

    :ok
  end

  defp next_weekday(target_day, time_string) do
    now = DateTime.utc_now() |> DateTime.shift_zone!("America/New_York")
    current_day = Date.day_of_week(DateTime.to_date(now))

    # Calculate days until target
    days_ahead = rem(target_day - current_day + 7, 7)
    days_ahead = if days_ahead == 0, do: 7, else: days_ahead

    # Parse time
    [hour, minute] = String.split(time_string, ":") |> Enum.map(&String.to_integer/1)

    # Build datetime
    DateTime.utc_now()
    |> DateTime.shift_zone!("America/New_York")
    |> DateTime.add(days_ahead, :day)
    |> DateTime.new!(Time.new!(hour, minute, 0))
    |> DateTime.shift_zone!("Etc/UTC")
  end
end

# Usage
{:ok, client} = Twitchy.authenticate(client, :user_access, code: code)
{:ok, user} = Twitchy.Users.get_user(client, id: client.user_id)

MyApp.ScheduleManager.create_weekly_schedule(client, user["id"])
```

### Raid Coordinator

Intelligently find and execute raids.

```elixir
defmodule MyApp.RaidCoordinator do
  def find_raid_targets(client, current_channel_id, opts \\ []) do
    min_viewers = Keyword.get(opts, :min_viewers, 50)
    max_viewers = Keyword.get(opts, :max_viewers, 5000)
    same_game = Keyword.get(opts, :same_game, false)

    # Get current game if needed
    current_game_id = if same_game do
      {:ok, channel_resp} = Twitchy.Channels.get_channel_information(client,
        broadcaster_id: current_channel_id
      )

      List.first(channel_resp["data"])["game_id"]
    else
      nil
    end

    # Get followed channels
    {:ok, followed_resp} = Twitchy.Users.get_followed_channels(client,
      user_id: current_channel_id,
      first: 100
    )

    followed_ids = Enum.map(followed_resp["data"], & &1["broadcaster_id"])

    # Get live streams from followed channels
    {:ok, streams_resp} = Twitchy.Streams.get_streams(client,
      user_id: followed_ids,
      first: 100
    )

    # Filter candidates
    candidates = streams_resp["data"]
      |> Enum.filter(fn stream ->
        viewers = stream["viewer_count"]
        game_match = !same_game || stream["game_id"] == current_game_id

        viewers >= min_viewers && viewers <= max_viewers && game_match
      end)
      |> Enum.map(&score_raid_target/1)
      |> Enum.sort_by(& &1.score, :desc)

    {:ok, candidates}
  end

  defp score_raid_target(stream) do
    # Score based on various factors
    viewer_score = min(stream["viewer_count"] / 100, 10)

    language_score = if stream["language"] == "en", do: 5, else: 0

    title_keywords = ["tournament", "charity", "birthday", "debut"]
    title_score = if title_contains_any?(stream["title"], title_keywords), do: 5, else: 0

    %{
      stream: stream,
      score: viewer_score + language_score + title_score
    }
  end

  defp title_contains_any?(title, keywords) do
    title_lower = String.downcase(title)
    Enum.any?(keywords, &String.contains?(title_lower, &1))
  end

  def execute_raid(client, from_id, to_id, delay_seconds \\ 10) do
    # Announce raid
    {:ok, target_resp} = Twitchy.Users.get_users(client, id: [to_id])
    target = List.first(target_resp["data"])

    IO.puts("🎯 Preparing to raid #{target["display_name"]}!")

    Twitchy.Chat.send_chat_message(client,
      broadcaster_id: from_id,
      sender_id: from_id,
      message: "We're raiding #{target["display_name"]} in #{delay_seconds} seconds! Get ready! 🎉"
    )

    # Wait
    Process.sleep(delay_seconds * 1000)

    # Execute raid
    case Twitchy.Raids.start_raid(client,
      from_broadcaster_id: from_id,
      to_broadcaster_id: to_id
    ) do
      :ok ->
        IO.puts("✅ Raid started successfully!")
        :ok

      {:error, error} ->
        IO.puts("❌ Raid failed: #{inspect(error)}")
        {:error, error}
    end
  end
end

# Usage
{:ok, client} = Twitchy.authenticate(client, :user_access, code: code)
{:ok, user} = Twitchy.Users.get_user(client, id: client.user_id)

# Find raid targets
{:ok, targets} = MyApp.RaidCoordinator.find_raid_targets(client, user["id"],
  min_viewers: 100,
  max_viewers: 3000,
  same_game: false
)

case targets do
  [best | _] ->
    IO.puts("Best raid target: #{best.stream["user_name"]}")
    IO.puts("  Game: #{best.stream["game_name"]}")
    IO.puts("  Viewers: #{best.stream["viewer_count"]}")
    IO.puts("  Title: #{best.stream["title"]}")
    IO.puts("  Score: #{Float.round(best.score, 1)}")

    # Execute raid
    MyApp.RaidCoordinator.execute_raid(client, user["id"], best.stream["user_id"], 15)

  [] ->
    IO.puts("No suitable raid targets found")
end
```

## Tutorial

### Build a Stream Schedule & End-of-Stream Raid Tool

This tutorial builds a small script that follows one stream through its
lifecycle: before going live it adds this week's slot to the channel's
schedule, while live it checks the Bits leaderboard so you can shout out the
top cheerer, and when signing off it raids a friend's channel to send viewers
their way. It's a compact tour of three APIs that each own a different moment
of a broadcast — planning, in-stream engagement, and hand-off.

### Step 1: Authenticate with the Right Scopes

Each part of the tool needs its own scope: `channel:manage:schedule` to write
to the schedule, `bits:read` to read the leaderboard, and
`channel:manage:raids` to start a raid. Request all three up front so the
resulting user token can drive the whole script:

```elixir
client =
  Twitchy.new(
    client_id: System.fetch_env!("TWITCH_CLIENT_ID"),
    client_secret: System.fetch_env!("TWITCH_CLIENT_SECRET"),
    redirect_uri: "http://localhost:4000/auth/callback"
  )

auth_url =
  Twitchy.auth_url(client, [
    "channel:manage:schedule",
    "bits:read",
    "channel:manage:raids"
  ])

IO.puts(auth_url)
```

Open the URL, authorize as the broadcaster, and exchange the returned `code`
for a token exactly as in
[TUTORIAL.md](../../TUTORIAL.md#step-2-get-a-user-access-token-for-the-broadcaster):

```elixir
{:ok, client} = Twitchy.authenticate(client, :user_access, code: "the_code_from_the_redirect")
```

Save `client.refresh_token` so future runs of the script can call
`Twitchy.refresh_token/1` instead of repeating the browser flow.

### Step 2: Look Up the Broadcaster

Every call below needs the broadcaster's user ID:

```elixir
{:ok, broadcaster} = Twitchy.Users.get_user(client, login: "your_channel_name")
broadcaster_id = broadcaster["id"]
```

### Step 3: Add This Week's Stream to the Schedule

`Twitchy.Schedule.create_channel_stream_schedule_segment/2` requires
`broadcaster_id`, `start_time` (RFC3339), `timezone` (IANA), and `duration`
(minutes, as a string, max `1440`); `category_id`, `title`, and
`is_recurring` are optional but worth setting so the segment is useful to
viewers browsing the schedule:

```elixir
{:ok, _response} =
  Twitchy.Schedule.create_channel_stream_schedule_segment(client,
    broadcaster_id: broadcaster_id,
    start_time: "2026-08-14T20:00:00Z",
    timezone: "America/New_York",
    duration: "180",
    is_recurring: false,
    category_id: "509658",
    title: "Friday Night Stream"
  )

IO.puts("Scheduled Friday Night Stream")
```

Computing "this Friday at 8pm" instead of hardcoding a date is just date
math — the complete example below wraps it in a small helper so it can be
called on any day of the week.

### Step 4: Shout Out the Top Cheerer Mid-Stream

`Twitchy.Bits.get_bits_leaderboard/2` requires the `bits:read` scope and
accepts `:count` and `:period` (one of `:day`, `:week`, `:month`, `:year`,
`:all`). Asking for `count: 1, period: :day` gets today's single top cheerer
— cheap enough to poll every few minutes during a stream:

```elixir
case Twitchy.Bits.get_bits_leaderboard(client, count: 1, period: :day) do
  {:ok, %{"data" => [top | _]}} ->
    IO.puts("🎉 Today's top cheerer: #{top["user_name"]} with #{top["score"]} bits!")

  {:ok, %{"data" => []}} ->
    IO.puts("No cheers yet today.")

  {:error, error} ->
    IO.puts("Couldn't fetch leaderboard: #{Exception.message(error)}")
end
```

An empty `"data"` list is the normal case early in a stream, not an error —
match it explicitly rather than assuming there's always a leader.

### Step 5: Raid a Friend When Signing Off

`Twitchy.Raids.start_raid/2` requires `channel:manage:raids` and takes
`:from_broadcaster_id` and `:to_broadcaster_id`. Unlike most Twitchy calls it
returns a bare `:ok` rather than `{:ok, response}` — there's no response body
to unpack:

```elixir
{:ok, friend} = Twitchy.Users.get_user(client, login: "a_friend_channel")

case Twitchy.Raids.start_raid(client,
       from_broadcaster_id: broadcaster_id,
       to_broadcaster_id: friend["id"]
     ) do
  :ok -> IO.puts("🚀 Raiding #{friend["display_name"]}!")
  {:error, error} -> IO.puts("Raid failed: #{Exception.message(error)}")
end
```

### The Complete Example

Everything above assembled into a small module plus a script that drives it.
Drop the module into `lib/my_app/schedule_and_raid_tool.ex` in a project with
`:twitchy` as a dependency:

```elixir
defmodule MyApp.ScheduleAndRaidTool do
  @moduledoc """
  A stream-lifecycle helper: add this week's slot to the schedule before
  going live, shout out the top cheerer while live, and raid a friend when
  signing off.
  """

  require Logger

  @doc "Adds this week's stream to the broadcaster's schedule."
  def schedule_this_week(client, broadcaster_id, opts \\ []) do
    weekday = Keyword.get(opts, :weekday, 5)
    hour = Keyword.get(opts, :hour, 20)
    title = Keyword.get(opts, :title, "Weekly Stream")

    Twitchy.Schedule.create_channel_stream_schedule_segment(client,
      broadcaster_id: broadcaster_id,
      start_time: next_occurrence(weekday, hour, 0),
      timezone: "America/New_York",
      duration: "180",
      is_recurring: false,
      category_id: "509658",
      title: title
    )
  end

  @doc "Logs a shoutout for today's top cheerer, if there is one."
  def shoutout_top_cheerer(client) do
    case Twitchy.Bits.get_bits_leaderboard(client, count: 1, period: :day) do
      {:ok, %{"data" => [top | _]}} ->
        IO.puts("🎉 Today's top cheerer: #{top["user_name"]} with #{top["score"]} bits!")
        :ok

      {:ok, %{"data" => []}} ->
        IO.puts("No cheers yet today.")
        :ok

      {:error, error} ->
        Logger.warning("Couldn't fetch leaderboard: #{Exception.message(error)}")
        {:error, error}
    end
  end

  @doc "Raids a friend's channel when signing off."
  def raid_friend(client, broadcaster_id, friend_login) do
    with {:ok, friend} <- Twitchy.Users.get_user(client, login: friend_login),
         :ok <-
           Twitchy.Raids.start_raid(client,
             from_broadcaster_id: broadcaster_id,
             to_broadcaster_id: friend["id"]
           ) do
      IO.puts("🚀 Raiding #{friend["display_name"]}!")
      :ok
    else
      {:error, error} ->
        Logger.warning("Raid failed: #{Exception.message(error)}")
        {:error, error}
    end
  end

  defp next_occurrence(weekday, hour, minute) do
    today = Date.utc_today()
    days_ahead = rem(weekday - Date.day_of_week(today) + 7, 7)
    days_ahead = if days_ahead == 0, do: 7, else: days_ahead

    today
    |> Date.add(days_ahead)
    |> DateTime.new!(Time.new!(hour, minute, 0), "Etc/UTC")
    |> DateTime.to_iso8601()
  end
end
```

And the script that drives it across a stream's lifecycle:

```elixir
# schedule_and_raid.exs — run with: mix run schedule_and_raid.exs
client =
  Twitchy.new(
    client_id: System.fetch_env!("TWITCH_CLIENT_ID"),
    client_secret: System.fetch_env!("TWITCH_CLIENT_SECRET"),
    refresh_token: System.fetch_env!("TWITCH_REFRESH_TOKEN")
  )

{:ok, client} = Twitchy.refresh_token(client)

{:ok, broadcaster} =
  Twitchy.Users.get_user(client, login: System.fetch_env!("TWITCH_BROADCASTER_LOGIN"))

broadcaster_id = broadcaster["id"]

# Run before going live
{:ok, _} = MyApp.ScheduleAndRaidTool.schedule_this_week(client, broadcaster_id, title: "Friday Night Stream")

# Run periodically while live
MyApp.ScheduleAndRaidTool.shoutout_top_cheerer(client)

# Run when signing off
MyApp.ScheduleAndRaidTool.raid_friend(client, broadcaster_id, "a_friend_channel")
```

Each function stands on its own, so a real bot would call
`schedule_this_week/3` from a startup task, `shoutout_top_cheerer/1` from a
timer, and `raid_friend/3` from a "going offline" hook — there's no need to
run all three in one process just because this script does.

## Best Practices

1. **Celebrate bits** - Acknowledge cheerers appropriately
2. **Keep schedules updated** - Maintain accurate streaming schedule
3. **Choose raid targets wisely** - Consider viewer count and content
4. **Use teams for collaboration** - Join relevant communities
5. **Track bits analytics** - Monitor top supporters
6. **Announce raids** - Give chat time to prepare
7. **Respect raid targets** - Ensure appropriate content match

## See Also

- [Users & Streams API](USERS_STREAMS.md)
- [Channels & Games API](CHANNELS_GAMES.md)
- [Chat & Moderation API](CHAT_MODERATION.md)
- [Usage Guide](../../USAGE_GUIDE.md)
