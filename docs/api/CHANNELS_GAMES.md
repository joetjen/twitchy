# Channels & Games API

Documentation for Twitch Channels and Games APIs.

## Channels API

### Get Channel Information

Get channel information for users.

```elixir
{:ok, response} = Twitchy.Channels.get_channel_information(client,
  broadcaster_id: "123456"
)

channel = List.first(response["data"])
IO.puts("Title: #{channel["title"]}")
IO.puts("Game: #{channel["game_name"]}")
IO.puts("Language: #{channel["broadcaster_language"]}")
```

### Modify Channel Information

Update channel metadata (requires `channel:manage:broadcast` scope).

```elixir
{:ok, response} = Twitchy.Channels.modify_channel_information(client,
  broadcaster_id: "123456",
  game_id: "509658",  # Just Chatting
  title: "New stream title! Come hang out!",
  broadcaster_language: "en",
  tags: ["English", "Chill", "Chat"]
)
```

### Get Channel Editors

Get list of users who can edit the channel.

```elixir
{:ok, response} = Twitchy.Channels.get_channel_editors(client,
  broadcaster_id: "123456"
)

Enum.each(response["data"], fn editor ->
  IO.puts("Editor: #{editor["user_name"]} (added #{editor["created_at"]})")
end)
```

### Get Followed Channels

Get list of channels a user follows.

```elixir
{:ok, response} = Twitchy.Users.get_followed_channels(client,
  user_id: "123456",
  first: 100
)

followed = response["data"]
IO.puts("Following #{length(followed)} channels")

Enum.each(followed, fn channel ->
  IO.puts("#{channel["broadcaster_name"]} - Followed since #{channel["followed_at"]}")
end)
```

## Games API

### Get Top Games

Get games sorted by number of current viewers on Twitch.

```elixir
{:ok, response} = Twitchy.Games.get_top_games(client, first: 20)

Enum.with_index(response["data"], 1) |> Enum.each(fn {game, rank} ->
  IO.puts("#{rank}. #{game["name"]} (#{game["id"]})")
end)
```

### Get Games

Get game information by name or ID.

```elixir
# By ID
{:ok, response} = Twitchy.Games.get_games(client, id: ["509658", "33214"])

# By name
{:ok, response} = Twitchy.Games.get_games(client, name: ["Just Chatting", "League of Legends"])

Enum.each(response["data"], fn game ->
  IO.puts("#{game["name"]} - #{game["id"]}")
  IO.puts("  Box Art: #{game["box_art_url"]}")
end)
```

## Examples

### Channel Title Updater

Automatically update stream title based on game.

```elixir
defmodule MyApp.TitleUpdater do
  def update_title_for_game(client, broadcaster_id, game_name) do
    # Get game info
    {:ok, games_resp} = Twitchy.Games.get_games(client, name: [game_name])
    game = List.first(games_resp["data"])

    return {:error, :game_not_found} unless game

    # Generate title based on game
    title = generate_title(game_name)

    # Update channel
    {:ok, _} = Twitchy.Channels.modify_channel_information(client,
      broadcaster_id: broadcaster_id,
      game_id: game["id"],
      title: title
    )

    {:ok, title}
  end

  defp generate_title("League of Legends"), do: "🎮 Ranked Grind - Road to Masters!"
  defp generate_title("Valorant"), do: "💥 Competitive Valorant - Let's Rank Up!"
  defp generate_title("Just Chatting"), do: "💬 Chill Chat & Community Hangout"
  defp generate_title(game), do: "Playing #{game}!"
end

# Usage
{:ok, client} = Twitchy.authenticate(client, :user_access, code: code)
MyApp.TitleUpdater.update_title_for_game(client, "123456", "League of Legends")
```

### Game Directory Monitor

Track viewership changes across top games.

```elixir
defmodule MyApp.GameDirectoryMonitor do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    client = opts[:client]
    schedule_check()

    {:ok, %{client: client, history: []}}
  end

  def handle_info(:check_games, state) do
    {:ok, response} = Twitchy.Games.get_top_games(state.client, first: 10)

    top_games = Enum.map(response["data"], fn game ->
      # Get current viewer count for this game
      {:ok, streams} = Twitchy.Streams.get_streams(state.client,
        game_id: game["id"],
        first: 100
      )

      viewer_count = Enum.reduce(streams["data"], 0, &(&2 + &1["viewer_count"]))

      %{
        id: game["id"],
        name: game["name"],
        viewer_count: viewer_count,
        timestamp: DateTime.utc_now()
      }
    end)

    # Compare with previous check
    if length(state.history) > 0 do
      previous = List.first(state.history)
      analyze_changes(previous, top_games)
    end

    new_history = [top_games | Enum.take(state.history, 23)]  # Keep last 24 hours (hourly)

    schedule_check()
    {:noreply, %{state | history: new_history}}
  end

  defp analyze_changes(previous, current) do
    Enum.each(current, fn game ->
      prev_game = Enum.find(previous, &(&1.id == game.id))

      if prev_game do
        change = game.viewer_count - prev_game.viewer_count
        percent = (change / prev_game.viewer_count * 100) |> Float.round(1)

        if abs(percent) >= 10 do
          direction = if change > 0, do: "📈", else: "📉"
          IO.puts("#{direction} #{game.name}: #{percent}% (#{format_viewers(change)})")
        end
      end
    end)
  end

  defp format_viewers(count) when count > 0, do: "+#{count}"
  defp format_viewers(count), do: "#{count}"

  defp schedule_check do
    # Check every hour
    Process.send_after(self(), :check_games, 3_600_000)
  end
end
```

### Multi-Game Stream Finder

Find streamers playing specific games.

```elixir
defmodule MyApp.StreamFinder do
  def find_streams_by_games(client, game_names, opts \\ []) do
    min_viewers = Keyword.get(opts, :min_viewers, 0)
    max_viewers = Keyword.get(opts, :max_viewers, 999_999)
    language = Keyword.get(opts, :language, "en")

    # Get game IDs
    {:ok, games_resp} = Twitchy.Games.get_games(client, name: game_names)
    game_ids = Enum.map(games_resp["data"], & &1["id"])

    # Get streams for each game
    streams =
      Enum.flat_map(game_ids, fn game_id ->
        {:ok, response} = Twitchy.Streams.get_streams(client,
          game_id: game_id,
          language: language,
          first: 100
        )

        response["data"]
      end)
      |> Enum.filter(fn stream ->
        viewers = stream["viewer_count"]
        viewers >= min_viewers && viewers <= max_viewers
      end)
      |> Enum.sort_by(& &1["viewer_count"], :desc)

    {:ok, streams}
  end
end

# Usage
{:ok, client} = Twitchy.authenticate(client, :app_access)

{:ok, streams} = MyApp.StreamFinder.find_streams_by_games(
  client,
  ["League of Legends", "Valorant", "CS:GO"],
  min_viewers: 100,
  max_viewers: 5000,
  language: "en"
)

IO.puts("Found #{length(streams)} streams")

Enum.take(streams, 10) |> Enum.each(fn stream ->
  IO.puts("#{stream["user_name"]} - #{stream["viewer_count"]} viewers")
  IO.puts("  #{stream["title"]}")
  IO.puts("  https://twitch.tv/#{stream["user_login"]}\n")
end)
```

## Best Practices

1. **Cache game IDs** - Game IDs don't change, cache them to reduce API calls
2. **Update title regularly** - Keep your stream title fresh and relevant
3. **Use accurate game categories** - Helps viewers discover your content
4. **Check editor list** - Regularly audit who has editor access
5. **Track game trends** - Monitor what games are growing/declining

## See Also

- [Users & Streams API](USERS_STREAMS.md)
- [Videos & Clips API](VIDEOS_CLIPS.md)
- [Usage Guide](../../USAGE_GUIDE.md)
