# Twitchy Examples

Real-world examples demonstrating common use cases and patterns.

## Quick Examples

### Get User Information

```elixir
client = Twitchy.new()
{:ok, client} = Twitchy.authenticate(client, :app_access)

{:ok, response} = Twitchy.Users.get_user(client, login: "ninja")
user = List.first(response["data"])

IO.puts("User: #{user["display_name"]}")
IO.puts("Bio: #{user["description"]}")
IO.puts("Followers: #{user["view_count"]}")
```

### Check if Streamer is Live

```elixir
def is_live?(client, username) do
  case Twitchy.Streams.get_streams(client, user_login: username) do
    {:ok, %{"data" => [stream | _]}} ->
      {:ok, true, stream}
    {:ok, %{"data" => []}} ->
      {:ok, false, nil}
    {:error, error} ->
      {:error, error}
  end
end

# Usage
case is_live?(client, "ninja") do
  {:ok, true, stream} ->
    IO.puts("#{stream["user_name"]} is live playing #{stream["game_name"]}!")
  {:ok, false, _} ->
    IO.puts("Not currently streaming")
  {:error, error} ->
    IO.puts("Error: #{inspect(error)}")
end
```

### Get Top Games

```elixir
{:ok, response} = Twitchy.Games.get_top_games(client, first: 10)

Enum.each(response["data"], fn game ->
  IO.puts("#{game["name"]} - #{game["id"]}")
end)
```

### Get Latest Clips

```elixir
{:ok, user} = Twitchy.Users.get_user(client, login: "shroud")
broadcaster_id = List.first(user["data"])["id"]

{:ok, response} = Twitchy.Clips.get_clips(client,
  broadcaster_id: broadcaster_id,
  first: 20
)

Enum.each(response["data"], fn clip ->
  IO.puts("#{clip["title"]} - #{clip["view_count"]} views")
  IO.puts("  #{clip["url"]}")
end)
```

## Complete Applications

### Stream Notifier

Monitor streamers and send notifications when they go live.

```elixir
defmodule MyApp.StreamNotifier do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    client = Keyword.fetch!(opts, :client)
    streamers = Keyword.fetch!(opts, :streamers)

    {:ok, _pid} = Twitchy.EventSub.Declarative.start_link(
      client: client,
      handler: __MODULE__,
      subscriptions: build_subscriptions(streamers)
    )

    {:ok, %{client: client, streamers: streamers}}
  end

  defp build_subscriptions(streamers) do
    Enum.map(streamers, fn streamer_id ->
      %{
        type: "stream.online",
        condition: %{"broadcaster_user_id" => streamer_id}
      }
    end)
  end

  def handle_event("stream.online", event, _metadata) do
    Logger.info("#{event["broadcaster_user_name"]} went live!")

    # Send notification (Discord, Slack, email, etc.)
    send_notification(%{
      title: "#{event["broadcaster_user_name"]} is now live!",
      url: "https://twitch.tv/#{event["broadcaster_user_login"]}"
    })

    :ok
  end

  def handle_event(_type, _event, _metadata), do: :ok

  defp send_notification(data) do
    # Implement your notification logic
    IO.inspect(data, label: "Notification")
  end
end

# Start the notifier
{:ok, client} = Twitchy.new() |> Twitchy.authenticate(:app_access)
MyApp.StreamNotifier.start_link(
  client: client,
  streamers: ["123456", "789012"]
)
```

See [Users & Streams API Documentation](docs/api/USERS_STREAMS.md) for more stream monitoring examples.

### Clip Compilation Bot

Automatically compile top clips into a video.

```elixir
defmodule MyApp.ClipCompiler do
  def compile_top_clips(client, broadcaster_id, opts \\ []) do
    days = Keyword.get(opts, :days, 7)
    max_clips = Keyword.get(opts, :max_clips, 10)

    started_at = DateTime.utc_now() |> DateTime.add(-days * 86400, :second)

    with {:ok, clips} <- fetch_top_clips(client, broadcaster_id, started_at, max_clips),
         {:ok, video_paths} <- download_clips(clips),
         {:ok, output} <- compile_video(video_paths) do
      {:ok, output}
    end
  end

  defp fetch_top_clips(client, broadcaster_id, started_at, max_clips) do
    {:ok, response} = Twitchy.Clips.get_clips(client,
      broadcaster_id: broadcaster_id,
      started_at: DateTime.to_iso8601(started_at),
      first: max_clips
    )

    clips = response["data"]
    |> Enum.sort_by(& &1["view_count"], :desc)
    |> Enum.take(max_clips)

    {:ok, clips}
  end

  defp download_clips(clips) do
    paths = Enum.map(clips, fn clip ->
      download_clip(clip["thumbnail_url"], clip["id"])
    end)

    {:ok, paths}
  end

  defp download_clip(thumbnail_url, clip_id) do
    # Convert thumbnail URL to video URL and download
    video_url = String.replace(thumbnail_url, "-preview-", "-")
    |> String.replace(~r/-\d+x\d+\.jpg$/, ".mp4")

    output_path = "/tmp/clip_#{clip_id}.mp4"
    System.cmd("curl", ["-o", output_path, video_url])
    output_path
  end

  defp compile_video(video_paths) do
    # Use FFmpeg to compile clips
    list_file = "/tmp/clips_list.txt"
    File.write!(list_file, Enum.map_join(video_paths, "\n", &"file '#{&1}'"))

    output = "/tmp/compilation_#{DateTime.utc_now() |> DateTime.to_unix()}.mp4"
    System.cmd("ffmpeg", [
      "-f", "concat",
      "-safe", "0",
      "-i", list_file,
      "-c", "copy",
      output
    ])

    {:ok, output}
  end
end
```

See [Videos & Clips API Documentation](docs/api/VIDEOS_CLIPS.md) for more clip examples.

### Chat Bot

Basic chat bot with commands.

```elixir
defmodule MyApp.ChatBot do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    client = Keyword.fetch!(opts, :client)
    broadcaster_id = Keyword.fetch!(opts, :broadcaster_id)

    {:ok, _pid} = Twitchy.EventSub.Declarative.start_link(
      client: client,
      handler: __MODULE__,
      subscriptions: [
        %{
          type: "channel.chat.message",
          condition: %{
            "broadcaster_user_id" => broadcaster_id,
            "user_id" => broadcaster_id
          }
        }
      ]
    )

    {:ok, %{client: client, broadcaster_id: broadcaster_id}}
  end

  def handle_event("channel.chat.message", event, _metadata) do
    message = event["message"]["text"]
    user = event["chatter_user_name"]

    cond do
      String.starts_with?(message, "!uptime") ->
        handle_uptime_command(event)
      String.starts_with?(message, "!game") ->
        handle_game_command(event)
      true ->
        :ok
    end
  end

  defp handle_uptime_command(event) do
    # Implementation
    :ok
  end

  defp handle_game_command(event) do
    # Implementation
    :ok
  end
end
```

See [Chat & Moderation API Documentation](docs/api/CHAT_MODERATION.md) for a complete chat bot implementation.

### Analytics Dashboard

Track stream analytics over time.

```elixir
defmodule MyApp.AnalyticsDashboard do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    client = Keyword.fetch!(opts, :client)
    broadcaster_id = Keyword.fetch!(opts, :broadcaster_id)

    # Schedule periodic analytics collection
    schedule_collection()

    {:ok, %{
      client: client,
      broadcaster_id: broadcaster_id,
      stats: []
    }}
  end

  def handle_info(:collect, state) do
    stats = collect_analytics(state.client, state.broadcaster_id)
    new_stats = [stats | state.stats]

    # Store to database
    store_stats(stats)

    schedule_collection()
    {:noreply, %{state | stats: new_stats}}
  end

  defp collect_analytics(client, broadcaster_id) do
    with {:ok, stream} <- get_stream_info(client, broadcaster_id),
         {:ok, followers} <- get_follower_count(client, broadcaster_id),
         {:ok, subs} <- get_sub_count(client, broadcaster_id) do
      %{
        timestamp: DateTime.utc_now(),
        viewers: stream["viewer_count"],
        followers: followers,
        subscribers: subs
      }
    end
  end

  defp schedule_collection do
    Process.send_after(self(), :collect, :timer.minutes(5))
  end
end
```

See [Analytics & Search API Documentation](docs/api/ANALYTICS_SEARCH_ADS_MISC.md) for more analytics examples.

### Moderation Assistant

Automated moderation with custom rules.

```elixir
defmodule MyApp.ModerationBot do
  use GenServer

  @spam_threshold 5
  @caps_threshold 0.7

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    client = Keyword.fetch!(opts, :client)
    broadcaster_id = Keyword.fetch!(opts, :broadcaster_id)

    {:ok, _pid} = Twitchy.EventSub.Declarative.start_link(
      client: client,
      handler: __MODULE__,
      subscriptions: [
        %{
          type: "channel.chat.message",
          condition: %{
            "broadcaster_user_id" => broadcaster_id,
            "user_id" => broadcaster_id
          }
        }
      ]
    )

    {:ok, %{
      client: client,
      broadcaster_id: broadcaster_id,
      message_history: %{}
    }}
  end

  def handle_event("channel.chat.message", event, _metadata) do
    message = event["message"]["text"]
    user_id = event["chatter_user_id"]

    cond do
      spam_detected?(message, user_id) ->
        ban_user(user_id, "Spam detected")
      excessive_caps?(message) ->
        timeout_user(user_id, 60, "Excessive caps")
      true ->
        :ok
    end
  end

  defp spam_detected?(message, user_id) do
    # Check message frequency
    false
  end

  defp excessive_caps?(message) do
    caps_ratio = count_caps(message) / String.length(message)
    caps_ratio > @caps_threshold && String.length(message) > 10
  end

  defp count_caps(message) do
    message
    |> String.graphemes()
    |> Enum.count(&(&1 == String.upcase(&1) && &1 =~ ~r/[A-Z]/))
  end
end
```

See [Chat & Moderation API Documentation](docs/api/CHAT_MODERATION.md) for a complete moderation bot.

## Common Patterns

### Pagination Helper

```elixir
defmodule MyApp.PaginationHelper do
  def fetch_all(fetch_fn, initial_params \\ []) do
    fetch_all(fetch_fn, initial_params, nil, [])
  end

  defp fetch_all(fetch_fn, params, cursor, acc) do
    params = if cursor, do: Keyword.put(params, :after, cursor), else: params

    case fetch_fn.(params) do
      {:ok, response} ->
        new_acc = acc ++ response["data"]

        case response["pagination"]["cursor"] do
          nil -> {:ok, new_acc}
          next_cursor -> fetch_all(fetch_fn, params, next_cursor, new_acc)
        end

      {:error, error} ->
        {:error, error}
    end
  end
end

# Usage
fetch_fn = fn params ->
  Twitchy.Users.get_followers(client, [broadcaster_id: "123456"] ++ params)
end

{:ok, all_followers} = MyApp.PaginationHelper.fetch_all(fetch_fn, first: 100)
```

### Error Handling with Retry

```elixir
defmodule MyApp.RetryHelper do
  def with_retry(fun, max_attempts \\ 3) do
    with_retry(fun, max_attempts, 1)
  end

  defp with_retry(fun, max_attempts, attempt) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, %{"status" => 429}} when attempt < max_attempts ->
        # Rate limited, wait and retry
        :timer.sleep(:timer.seconds(attempt * 2))
        with_retry(fun, max_attempts, attempt + 1)

      {:error, %{"status" => status}} when status >= 500 and attempt < max_attempts ->
        # Server error, retry with backoff
        :timer.sleep(:timer.seconds(attempt))
        with_retry(fun, max_attempts, attempt + 1)

      {:error, error} ->
        {:error, error}
    end
  end
end

# Usage
MyApp.RetryHelper.with_retry(fn ->
  Twitchy.Users.get_user(client, login: "ninja")
end)
```

### Concurrent Requests

```elixir
defmodule MyApp.ConcurrentFetcher do
  def fetch_multiple_users(client, usernames) do
    usernames
    |> Enum.chunk_every(100) # API limit
    |> Enum.map(fn chunk ->
      Task.async(fn ->
        Twitchy.Users.get_users(client, login: chunk)
      end)
    end)
    |> Task.await_many(10_000)
    |> Enum.reduce({:ok, []}, fn
      {:ok, response}, {:ok, acc} ->
        {:ok, acc ++ response["data"]}
      {:error, error}, _ ->
        {:error, error}
      _, {:error, error} ->
        {:error, error}
    end)
  end
end
```

## See Also

- [Quick Start Guide](QUICKSTART.md)
- [Usage Guide](USAGE_GUIDE.md)
- [API Documentation](docs/api/)
  - [Users & Streams](docs/api/USERS_STREAMS.md)
  - [Channels & Games](docs/api/CHANNELS_GAMES.md)
  - [Videos & Clips](docs/api/VIDEOS_CLIPS.md)
  - [Chat & Moderation](docs/api/CHAT_MODERATION.md)
  - [Subscriptions & Channel Points](docs/api/SUBSCRIPTIONS_CHANNELPOINTS.md)
  - [Predictions, Polls & Hype Train](docs/api/PREDICTIONS_POLLS_HYPETRAIN.md)
  - [Bits, Teams, Schedule & Raids](docs/api/BITS_TEAMS_SCHEDULE_RAIDS.md)
  - [Analytics, Search & More](docs/api/ANALYTICS_SEARCH_ADS_MISC.md)
