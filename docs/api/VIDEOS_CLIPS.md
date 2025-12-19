# Videos & Clips API

Documentation for Twitch Videos and Clips APIs.

## Videos API

### Get Videos

Get videos (VODs, uploads, archives, highlights) from a broadcaster.

```elixir
# Get recent videos from a user
{:ok, response} = Twitchy.Videos.get_videos(client,
  user_id: "123456",
  first: 20,
  type: "archive"  # "archive", "highlight", "upload"
)

Enum.each(response["data"], fn video ->
  IO.puts("#{video["title"]}")
  IO.puts("  Duration: #{video["duration"]} | Views: #{video["view_count"]}")
  IO.puts("  URL: #{video["url"]}")
  IO.puts("  Published: #{video["published_at"]}\n")
end)
```

### Delete Videos

Delete videos from your channel (requires `channel:manage:videos` scope).

```elixir
# Delete one or more videos
{:ok, response} = Twitchy.Videos.delete_videos(client, id: ["12345", "67890"])

IO.puts("Deleted videos: #{inspect(response)}")
```

## Clips API

### Get Clips

Get clips for a broadcaster or game.

```elixir
# Get recent clips from a broadcaster
{:ok, response} = Twitchy.Clips.get_clips(client,
  broadcaster_id: "123456",
  first: 20
)

Enum.each(response["data"], fn clip ->
  IO.puts("#{clip["title"]} by #{clip["creator_name"]}")
  IO.puts("  Views: #{clip["view_count"]} | Created: #{clip["created_at"]}")
  IO.puts("  URL: #{clip["url"]}\n")
end)
```

```elixir
# Get clips from a specific time period
started_at = DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.to_iso8601()
ended_at = DateTime.utc_now() |> DateTime.to_iso8601()

{:ok, response} = Twitchy.Clips.get_clips(client,
  broadcaster_id: "123456",
  started_at: started_at,
  ended_at: ended_at,
  first: 100
)
```

### Create Clip

Create a clip from a live stream (requires `clips:edit` scope).

```elixir
{:ok, response} = Twitchy.Clips.create_clip(client,
  broadcaster_id: "123456",
  has_delay: false  # If true, adds a delay before capturing
)

clip = List.first(response["data"])
IO.puts("Clip created! ID: #{clip["id"]}")
IO.puts("Edit URL: #{clip["edit_url"]}")
```

## Examples

### VOD Highlighter

Automatically create clips from peak moments in VODs.

```elixir
defmodule MyApp.VODHighlighter do
  def create_highlights_from_vod(client, broadcaster_id, vod_id) do
    # Get video info
    {:ok, video_resp} = Twitchy.Videos.get_videos(client, id: [vod_id])
    video = List.first(video_resp["data"])

    # Analyze chat activity or use other metrics to find peaks
    peak_timestamps = analyze_peak_moments(video)

    # Create clips at peak timestamps
    clips =
      Enum.map(peak_timestamps, fn timestamp ->
        # Seek to timestamp and create clip
        create_clip_at_timestamp(client, broadcaster_id, timestamp)
      end)

    {:ok, clips}
  end

  defp analyze_peak_moments(video) do
    # In production, analyze chat logs, viewer count, etc.
    # For now, return some sample timestamps
    duration = parse_duration(video["duration"])

    # Create clips at 10%, 30%, 50%, 70%, 90% of video
    [0.1, 0.3, 0.5, 0.7, 0.9]
    |> Enum.map(&(&1 * duration))
    |> Enum.map(&round/1)
  end

  defp create_clip_at_timestamp(client, broadcaster_id, _timestamp) do
    # In production, you'd seek to the timestamp first
    # Twitch API creates clip from live stream only
    # For VODs, you'd need additional processing

    {:ok, response} = Twitchy.Clips.create_clip(client,
      broadcaster_id: broadcaster_id
    )

    List.first(response["data"])
  end

  defp parse_duration(duration_str) do
    # Parse "1h2m3s" format to seconds
    # Simplified implementation
    3600  # Return 1 hour for demo
  end
end
```

### Clip Compilation Generator

Download top clips and create a compilation video.

```elixir
defmodule MyApp.ClipCompilation do
  def generate_weekly_compilation(client, broadcaster_id) do
    # Get clips from past week
    started_at = DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.to_iso8601()
    ended_at = DateTime.utc_now() |> DateTime.to_iso8601()

    {:ok, response} = Twitchy.Clips.get_clips(client,
      broadcaster_id: broadcaster_id,
      started_at: started_at,
      ended_at: ended_at,
      first: 100
    )

    # Sort by view count and get top 10
    top_clips =
      response["data"]
      |> Enum.sort_by(& &1["view_count"], :desc)
      |> Enum.take(10)

    # Download clips
    IO.puts("Downloading #{length(top_clips)} clips...")

    clip_files =
      top_clips
      |> Enum.with_index()
      |> Enum.map(fn {clip, index} ->
        download_clip(clip, index)
      end)

    # Compile into single video
    output_file = "weekly_top_#{Date.utc_today()}.mp4"
    compile_clips(clip_files, output_file)

    IO.puts("✅ Compilation saved to #{output_file}")
    {:ok, output_file}
  end

  defp download_clip(clip, index) do
    # Get MP4 URL from thumbnail URL
    video_url = clip["thumbnail_url"]
      |> String.replace("-preview-480x272.jpg", ".mp4")

    filename = "/tmp/clip_#{index}_#{clip["id"]}.mp4"

    # Download using HTTPoison or similar
    %{body: body} = HTTPoison.get!(video_url)
    File.write!(filename, body)

    IO.puts("  Downloaded: #{clip["title"]}")
    filename
  end

  defp compile_clips(files, output) do
    # Create FFmpeg concat file
    list_file = "/tmp/clips_list.txt"
    list_content = Enum.map_join(files, "\n", &"file '#{&1}'")
    File.write!(list_file, list_content)

    # Compile using FFmpeg
    System.cmd("ffmpeg", [
      "-f", "concat",
      "-safe", "0",
      "-i", list_file,
      "-c", "copy",
      output
    ])

    # Cleanup
    File.rm!(list_file)
    Enum.each(files, &File.rm!/1)
  end
end

# Usage
{:ok, client} = Twitchy.authenticate(client, :user_access, code: code)
{:ok, user} = Twitchy.Users.get_user(client, id: client.user_id)

MyApp.ClipCompilation.generate_weekly_compilation(client, user["id"])
```

### Video Stats Tracker

Track video performance metrics over time.

```elixir
defmodule MyApp.VideoStatsTracker do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    client = opts[:client]
    broadcaster_id = opts[:broadcaster_id]

    schedule_update()

    {:ok, %{
      client: client,
      broadcaster_id: broadcaster_id,
      videos: %{}
    }}
  end

  def handle_info(:update_stats, state) do
    # Get recent videos
    {:ok, response} = Twitchy.Videos.get_videos(state.client,
      user_id: state.broadcaster_id,
      first: 100,
      type: "archive"
    )

    # Update stats for each video
    updated_videos =
      Enum.reduce(response["data"], state.videos, fn video, acc ->
        video_id = video["id"]
        current_views = video["view_count"]

        previous = Map.get(acc, video_id, %{initial_views: current_views, history: []})

        new_entry = %{
          timestamp: DateTime.utc_now(),
          views: current_views,
          views_gained: current_views - previous.initial_views
        }

        updated = %{
          previous |
          history: [new_entry | Enum.take(previous.history, 99)]
        }

        Map.put(acc, video_id, updated)
      end)

    # Generate report
    generate_report(updated_videos)

    schedule_update()
    {:noreply, %{state | videos: updated_videos}}
  end

  defp generate_report(videos) do
    # Find top performing videos
    top_performers =
      videos
      |> Enum.map(fn {id, data} ->
        latest = List.first(data.history)
        %{id: id, views_gained: latest.views_gained}
      end)
      |> Enum.sort_by(& &1.views_gained, :desc)
      |> Enum.take(5)

    IO.puts("\n=== Top Performing Videos ===")
    Enum.each(top_performers, fn video ->
      IO.puts("Video #{video.id}: +#{video.views_gained} views")
    end)
  end

  defp schedule_update do
    # Update every 6 hours
    Process.send_after(self(), :update_stats, 21_600_000)
  end
end

# Usage
{:ok, client} = Twitchy.authenticate(client, :user_access, code: code)
{:ok, user} = Twitchy.Users.get_user(client, id: client.user_id)

MyApp.VideoStatsTracker.start_link(
  client: client,
  broadcaster_id: user["id"]
)
```

### Clip Curator

Find and curate best clips across multiple channels.

```elixir
defmodule MyApp.ClipCurator do
  def find_trending_clips(client, opts \\ []) do
    game_id = Keyword.get(opts, :game_id)
    min_views = Keyword.get(opts, :min_views, 1000)
    started_at = Keyword.get(opts, :started_at, default_start_time())

    # Get clips
    params = [
      started_at: started_at,
      first: 100
    ]

    params = if game_id, do: Keyword.put(params, :game_id, game_id), else: params

    {:ok, response} = Twitchy.Clips.get_clips(client, params)

    # Filter and score clips
    trending =
      response["data"]
      |> Enum.filter(&(&1["view_count"] >= min_views))
      |> Enum.map(&score_clip/1)
      |> Enum.sort_by(& &1.score, :desc)

    {:ok, trending}
  end

  defp score_clip(clip) do
    # Calculate freshness (newer = higher score)
    created = DateTime.from_iso8601(clip["created_at"]) |> elem(1)
    age_hours = DateTime.diff(DateTime.utc_now(), created, :hour)
    freshness_score = max(0, 100 - age_hours)

    # Views score (logarithmic)
    views_score = :math.log10(clip["view_count"]) * 10

    # Total score
    score = freshness_score + views_score

    %{
      clip: clip,
      score: score,
      freshness: freshness_score,
      popularity: views_score
    }
  end

  defp default_start_time do
    DateTime.utc_now()
    |> DateTime.add(-24, :hour)
    |> DateTime.to_iso8601()
  end
end

# Usage
{:ok, client} = Twitchy.authenticate(client, :app_access)

# Find trending clips for Just Chatting
{:ok, clips} = MyApp.ClipCurator.find_trending_clips(client,
  game_id: "509658",
  min_views: 500
)

IO.puts("Found #{length(clips)} trending clips")

Enum.take(clips, 10) |> Enum.each(fn %{clip: clip, score: score} ->
  IO.puts("\n#{clip["title"]} (Score: #{Float.round(score, 1)})")
  IO.puts("  By: #{clip["creator_name"]} | Views: #{clip["view_count"]}")
  IO.puts("  #{clip["url"]}")
end)
```

## Best Practices

1. **Respect copyright** - Don't download clips without permission
2. **Cache video metadata** - Reduce API calls by caching video info
3. **Use time filters** - Narrow down clips by time period for better results
4. **Monitor clip trends** - Track which clips get the most views
5. **Batch operations** - Delete multiple videos in one API call
6. **Check permissions** - Ensure you have proper scopes before modifying content

## See Also

- [Channels & Games API](CHANNELS_GAMES.md)
- [Users & Streams API](USERS_STREAMS.md)
- [Usage Guide](../../USAGE_GUIDE.md)
