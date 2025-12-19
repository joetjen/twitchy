# Analytics, Search, Ads & Other APIs

Documentation for Analytics, Search, Ads, Charity, Goals, and other miscellaneous APIs.

## Analytics API

### Get Extension Analytics

Get analytics reports for an extension.

```elixir
{:ok, response} = Twitchy.Analytics.get_extension_analytics(client,
  extension_id: "ext_id",
  first: 20
)

Enum.each(response["data"], fn report ->
  IO.puts("Report Date: #{report["started_at"]} to #{report["ended_at"]}")
  IO.puts("  URL: #{report["URL"]}")
  IO.puts("  Type: #{report["type"]}")
end)
```

### Get Game Analytics

Get analytics reports for games.

```elixir
{:ok, response} = Twitchy.Analytics.get_game_analytics(client,
  game_id: "509658",
  first: 20
)

Enum.each(response["data"], fn report ->
  IO.puts("Report for #{report["game_id"]}")
  IO.puts("  Period: #{report["started_at"]} to #{report["ended_at"]}")
  IO.puts("  Download: #{report["URL"]}")
end)
```

## Search API

### Search Categories

Search for game/category by name.

```elixir
{:ok, response} = Twitchy.Search.search_categories(client,
  query: "league",
  first: 10
)

Enum.each(response["data"], fn category ->
  IO.puts("#{category["name"]} (ID: #{category["id"]})")
  IO.puts("  Box Art: #{category["box_art_url"]}")
end)
```

### Search Channels

Search for channels by username or display name.

```elixir
{:ok, response} = Twitchy.Search.search_channels(client,
  query: "ninja",
  first: 10,
  live_only: true
)

Enum.each(response["data"], fn channel ->
  status = if channel["is_live"], do: "🔴 LIVE", else: "⚫ Offline"

  IO.puts("#{status} #{channel["display_name"]} (@#{channel["broadcaster_login"]})")
  IO.puts("  Game: #{channel["game_name"]}")
  IO.puts("  Title: #{channel["title"]}")

  if channel["is_live"] do
    IO.puts("  Started: #{channel["started_at"]}")
  end
end)
```

## Ads API

### Start Commercial

Run a commercial break (requires `channel:edit:commercial` scope).

```elixir
{:ok, response} = Twitchy.Ads.start_commercial(client,
  broadcaster_id: "123456",
  length: 60  # 30, 60, 90, 120, 150, 180 seconds
)

ad = List.first(response["data"])
IO.puts("Commercial started!")
IO.puts("  Length: #{ad["length"]} seconds")
IO.puts("  Message: #{ad["message"]}")
IO.puts("  Retry after: #{ad["retry_after"]} seconds")
```

### Snooze Next Ad

Snooze upcoming automatic mid-roll ads (requires `channel:manage:ads` scope).

```elixir
{:ok, response} = Twitchy.Ads.snooze_next_ad(client,
  broadcaster_id: "123456"
)

snooze = List.first(response["data"])
IO.puts("Next ad snoozed!")
IO.puts("  Snooze count: #{snooze["snooze_count"]}")
IO.puts("  Snooze refresh at: #{snooze["snooze_refresh_at"]}")
IO.puts("  Next ad at: #{snooze["next_ad_at"]}")
```

## Charity API

### Get Charity Campaign

Get information about active charity campaigns.

```elixir
{:ok, response} = Twitchy.Charity.get_charity_campaign(client,
  broadcaster_id: "123456"
)

case response["data"] do
  [campaign | _] ->
    IO.puts("Charity Campaign: #{campaign["charity_name"]}")
    IO.puts("  Description: #{campaign["charity_description"]}")
    IO.puts("  Current Amount: $#{campaign["current_amount"]["value"]}")
    IO.puts("  Target Amount: $#{campaign["target_amount"]["value"]}")
    IO.puts("  Started: #{campaign["started_at"]}")

  [] ->
    IO.puts("No active charity campaign")
end
```

### Get Charity Donations

Get list of donations to the active charity campaign.

```elixir
{:ok, response} = Twitchy.Charity.get_charity_campaign_donations(client,
  broadcaster_id: "123456",
  first: 100
)

total = Enum.reduce(response["data"], 0, fn donation, acc ->
  acc + donation["amount"]["value"]
end)

IO.puts("Total donations: $#{total}")

Enum.each(response["data"], fn donation ->
  IO.puts("#{donation["user_name"]}: $#{donation["amount"]["value"]}")
end)
```

## Goals API

### Get Creator Goals

Get broadcaster's creator goals.

```elixir
{:ok, response} = Twitchy.Goals.get_creator_goals(client,
  broadcaster_id: "123456"
)

Enum.each(response["data"], fn goal ->
  progress_pct = (goal["current_amount"] / goal["target_amount"] * 100) |> round()

  IO.puts("Goal: #{goal["description"]}")
  IO.puts("  Type: #{goal["type"]}")  # follower, subscription, subscription_count, new_subscription, new_subscription_count
  IO.puts("  Progress: #{goal["current_amount"]}/#{goal["target_amount"]} (#{progress_pct}%)")
  IO.puts("  Created: #{goal["created_at"]}")
end)
```

## Whispers API

### Send Whisper

Send a whisper/direct message to another user (requires `user:manage:whispers` scope).

```elixir
{:ok, response} = Twitchy.Whispers.send_whisper(client,
  from_user_id: "123456",
  to_user_id: "789",
  message: "Hey! Thanks for the follow!"
)

IO.puts("Whisper sent!")
```

## Examples

### Channel Discovery Tool

Help users find new channels to watch.

```elixir
defmodule MyApp.ChannelDiscovery do
  def find_channels(client, opts \\ []) do
    query = Keyword.get(opts, :query, "")
    game = Keyword.get(opts, :game)
    language = Keyword.get(opts, :language, "en")
    live_only = Keyword.get(opts, :live_only, true)

    results = []

    # Search by query if provided
    results = if String.length(query) > 0 do
      {:ok, search_resp} = Twitchy.Search.search_channels(client,
        query: query,
        live_only: live_only,
        first: 20
      )

      search_resp["data"]
    else
      results
    end

    # Search by game if provided
    results = if game do
      # Get game ID
      {:ok, games_resp} = Twitchy.Search.search_categories(client, query: game, first: 1)

      case games_resp["data"] do
        [game_info | _] ->
          {:ok, streams_resp} = Twitchy.Streams.get_streams(client,
            game_id: game_info["id"],
            language: language,
            first: 20
          )

          results ++ streams_resp["data"]

        [] ->
          results
      end
    else
      results
    end

    # Remove duplicates and sort
    results
    |> Enum.uniq_by(&(&1["user_id"] || &1["broadcaster_id"]))
    |> Enum.sort_by(&(&1["viewer_count"] || 0), :desc)
  end

  def display_results(results) do
    IO.puts("\n=== Channel Discovery Results ===\n")

    Enum.take(results, 10) |> Enum.with_index(1) |> Enum.each(fn {channel, index} ->
      name = channel["display_name"] || channel["broadcaster_name"]
      login = channel["broadcaster_login"] || channel["user_login"]
      game = channel["game_name"]
      viewers = channel["viewer_count"] || 0

      status = if channel["is_live"] || Map.has_key?(channel, "started_at") do
        "🔴 LIVE"
      else
        "⚫ Offline"
      end

      IO.puts("#{index}. #{status} #{name} (@#{login})")
      IO.puts("   Game: #{game || "N/A"} | Viewers: #{viewers}")

      title = channel["title"]
      if title && String.length(title) > 0 do
        IO.puts("   \"#{String.slice(title, 0, 60)}\"")
      end

      IO.puts("   https://twitch.tv/#{login}\n")
    end)
  end
end

# Usage
{:ok, client} = Twitchy.authenticate(client, :app_access)

# Find League of Legends channels
results = MyApp.ChannelDiscovery.find_channels(client,
  game: "League of Legends",
  language: "en",
  live_only: true
)

MyApp.ChannelDiscovery.display_results(results)

# Find channels by name
results = MyApp.ChannelDiscovery.find_channels(client,
  query: "speedrun",
  live_only: true
)

MyApp.ChannelDiscovery.display_results(results)
```

### Ad Break Manager

Intelligently schedule and manage commercial breaks.

```elixir
defmodule MyApp.AdBreakManager do
  use GenServer

  @ad_cooldown 480  # 8 minutes between ads (in seconds)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    client = opts[:client]
    channel_id = opts[:channel_id]
    auto_ads = Keyword.get(opts, :auto_ads, false)

    # Subscribe to ad break events
    {:ok, _} = Twitchy.EventSub.Declarative.start_link(
      client: client,
      handler: __MODULE__,
      subscriptions: [
        %{
          type: "channel.ad_break.begin",
          condition: %{"broadcaster_user_id" => channel_id}
        }
      ]
    )

    state = %{
      client: client,
      channel_id: channel_id,
      auto_ads: auto_ads,
      last_ad: nil,
      cooldown_timer: nil
    }

    if auto_ads do
      schedule_next_ad(state)
    end

    {:ok, state}
  end

  def handle_event("channel.ad_break.begin", event, _meta) do
    duration = event["duration_seconds"]
    IO.puts("📺 Ad break started (#{duration}s)")

    GenServer.cast(__MODULE__, {:ad_started, DateTime.utc_now()})
    :ok
  end

  def handle_cast({:ad_started, time}, state) do
    # Cancel existing timer if any
    if state.cooldown_timer do
      Process.cancel_timer(state.cooldown_timer)
    end

    # Schedule next ad if auto mode
    new_state = %{state | last_ad: time}

    if state.auto_ads do
      new_state = schedule_next_ad(new_state)
    end

    {:noreply, new_state}
  end

  def handle_info(:run_ad, state) do
    # Check if stream is live
    {:ok, streams_resp} = Twitchy.Streams.get_streams(state.client,
      user_id: [state.channel_id]
    )

    case streams_resp["data"] do
      [_stream | _] ->
        # Stream is live, run ad
        case Twitchy.Ads.start_commercial(state.client,
          broadcaster_id: state.channel_id,
          length: 60
        ) do
          {:ok, _} ->
            IO.puts("📺 Auto ad break started (60s)")

          {:error, error} ->
            IO.puts("Failed to start ad: #{inspect(error)}")
        end

      [] ->
        IO.puts("Stream offline, skipping ad")
    end

    {:noreply, state}
  end

  # Public API
  def run_ad_now(length \\ 60) do
    state = :sys.get_state(__MODULE__)

    # Check cooldown
    if state.last_ad do
      elapsed = DateTime.diff(DateTime.utc_now(), state.last_ad, :second)

      if elapsed < @ad_cooldown do
        remaining = @ad_cooldown - elapsed
        IO.puts("Ad on cooldown. #{remaining}s remaining.")
        return {:error, :cooldown}
      end
    end

    case Twitchy.Ads.start_commercial(state.client,
      broadcaster_id: state.channel_id,
      length: length
    ) do
      {:ok, response} ->
        ad = List.first(response["data"])
        IO.puts("Ad started: #{ad["length"]}s")
        {:ok, ad}

      {:error, error} ->
        {:error, error}
    end
  end

  defp schedule_next_ad(state) do
    # Schedule next ad in 8-10 minutes (randomized)
    delay = (@ad_cooldown + :rand.uniform(120)) * 1000
    timer = Process.send_after(self(), :run_ad, delay)

    %{state | cooldown_timer: timer}
  end
end

# Usage
{:ok, client} = Twitchy.authenticate(client, :user_access, code: code)
{:ok, user} = Twitchy.Users.get_user(client, id: client.user_id)

# Start with auto ads enabled
MyApp.AdBreakManager.start_link(
  client: client,
  channel_id: user["id"],
  auto_ads: true
)

# Manually trigger ad
MyApp.AdBreakManager.run_ad_now(90)
```

### Charity Campaign Tracker

Monitor and celebrate charity donations.

```elixir
defmodule MyApp.CharityTracker do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    client = opts[:client]
    channel_id = opts[:channel_id]

    # Subscribe to charity events
    {:ok, _} = Twitchy.EventSub.Declarative.start_link(
      client: client,
      handler: __MODULE__,
      subscriptions: [
        %{
          type: "channel.charity_campaign.donate",
          condition: %{"broadcaster_user_id" => channel_id}
        },
        %{
          type: "channel.charity_campaign.start",
          condition: %{"broadcaster_user_id" => channel_id}
        },
        %{
          type: "channel.charity_campaign.progress",
          condition: %{"broadcaster_user_id" => channel_id}
        },
        %{
          type: "channel.charity_campaign.stop",
          condition: %{"broadcaster_user_id" => channel_id}
        }
      ]
    )

    schedule_update()

    {:ok, %{
      client: client,
      channel_id: channel_id,
      campaign: nil,
      milestones: [1000, 5000, 10000, 25000, 50000, 100000]
    }}
  end

  def handle_event("channel.charity_campaign.start", event, _meta) do
    IO.puts("💚 Charity Campaign Started!")
    IO.puts("   Charity: #{event["charity_name"]}")
    IO.puts("   Goal: $#{event["target_amount"]["value"]}")

    send_chat_message("💚 Starting charity stream for #{event["charity_name"]}! Let's make a difference!")
    :ok
  end

  def handle_event("channel.charity_campaign.donate", event, _meta) do
    amount = event["amount"]["value"]
    donor = event["user_name"]

    IO.puts("💚 #{donor} donated $#{amount}!")

    message = case amount do
      x when x >= 100 -> "💚💚💚 HUGE $#{amount} donation from #{donor}! Thank you so much! 💚💚💚"
      x when x >= 50 -> "💚💚 Amazing $#{amount} donation from #{donor}! 💚💚"
      x when x >= 10 -> "💚 Thank you #{donor} for donating $#{amount}! 💚"
      _ -> nil
    end

    if message do
      send_chat_message(message)
    end

    :ok
  end

  def handle_event("channel.charity_campaign.progress", event, _meta) do
    current = event["current_amount"]["value"]
    target = event["target_amount"]["value"]

    # Check for milestone
    state = :sys.get_state(__MODULE__)

    previous = if state.campaign do
      state.campaign["current_amount"]["value"]
    else
      0
    end

    milestone_reached = Enum.find(state.milestones, fn milestone ->
      previous < milestone && current >= milestone
    end)

    if milestone_reached do
      percentage = (current / target * 100) |> round()
      send_chat_message("🎉 Milestone reached! $#{milestone_reached} raised (#{percentage}% of goal)! 🎉")
    end

    GenServer.cast(__MODULE__, {:update_campaign, event})
    :ok
  end

  def handle_event("channel.charity_campaign.stop", event, _meta) do
    final_amount = event["current_amount"]["value"]
    target = event["target_amount"]["value"]
    percentage = (final_amount / target * 100) |> round()

    IO.puts("💚 Charity Campaign Ended!")
    IO.puts("   Total Raised: $#{final_amount} (#{percentage}% of goal)")

    message = if final_amount >= target do
      "🎉🎉🎉 We did it! Raised $#{final_amount} for #{event["charity_name"]}! Thank you all! 💚"
    else
      "💚 Charity stream complete! Raised $#{final_amount} for #{event["charity_name"]}! Every bit helps! 💚"
    end

    send_chat_message(message)

    GenServer.cast(__MODULE__, {:update_campaign, nil})
    :ok
  end

  def handle_cast({:update_campaign, campaign}, state) do
    {:noreply, %{state | campaign: campaign}}
  end

  def handle_info(:update_progress, state) do
    # Fetch current campaign state
    {:ok, response} = Twitchy.Charity.get_charity_campaign(state.client,
      broadcaster_id: state.channel_id
    )

    case response["data"] do
      [campaign | _] ->
        current = campaign["current_amount"]["value"]
        target = campaign["target_amount"]["value"]
        percentage = (current / target * 100) |> Float.round(1)

        IO.puts("💚 Charity Progress: $#{current}/$#{target} (#{percentage}%)")

      [] ->
        :ok
    end

    schedule_update()
    {:noreply, state}
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
    # Update every 5 minutes
    Process.send_after(self(), :update_progress, 300_000)
  end
end
```

## Best Practices

1. **Search efficiently** - Use specific queries to reduce API calls
2. **Schedule ads wisely** - Don't interrupt key moments
3. **Celebrate charity milestones** - Engage viewers with progress
4. **Track analytics** - Monitor trends and patterns
5. **Respect ad cooldowns** - Follow Twitch guidelines
6. **Use goals for motivation** - Set and track creator goals
7. **Whisper sparingly** - Don't spam users with DMs

## See Also

- [Users & Streams API](USERS_STREAMS.md)
- [Channels & Games API](CHANNELS_GAMES.md)
- [Chat & Moderation API](CHAT_MODERATION.md)
- [Usage Guide](../../USAGE_GUIDE.md)
