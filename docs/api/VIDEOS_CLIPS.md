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
  type: :archive  # :archive, :highlight, :upload, :all
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
:ok = Twitchy.Videos.delete_videos(client, id: ["12345", "67890"])

IO.puts("Videos deleted.")
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

## Tutorial

This tutorial builds a **Weekly Highlights Digest**: a script that pulls a
channel's recent VODs from the past week alongside that week's most-viewed
clips, and formats both into a short plain-text report you can paste straight
into a Discord announcement. It's a realistic use of the Videos and Clips APIs
together — VODs tell viewers what they missed, clips show the best moments
from it. A bonus step at the end shows how to programmatically create a clip
while the channel is live.

### Step 1: Resolve the Broadcaster's User ID

Both the Videos and Clips APIs key off a numeric user ID, not a channel login
name, so the first step is always the same: look it up once and pass it
through everything else.

```elixir
{:ok, broadcaster} = Twitchy.Users.get_user(client, login: "your_channel_name")
broadcaster_id = broadcaster["id"]
```

An app access token is enough for everything through Step 4 — no user login
required yet. Only the bonus clip-creation step needs a user token.

### Step 2: Pull the Past Week's VODs

`Twitchy.Videos.get_videos/2` accepts a `:period` filter (`:all`, `:day`,
`:week`, `:month`) alongside `:user_id`, so asking for archived broadcasts
from the last week is a single call — no manual date math needed:

```elixir
{:ok, %{"data" => videos}} =
  Twitchy.Videos.get_videos(client,
    user_id: broadcaster_id,
    type: :archive,
    period: :week,
    sort: :time,
    first: 20
  )

Enum.each(videos, fn video ->
  IO.puts("#{video["title"]} (#{video["view_count"]} views) — #{video["url"]}")
end)
```

`type: :archive` excludes highlights and uploads so the digest only reports
actual stream VODs; `sort: :time` puts the newest broadcast first.

### Step 3: Pull the Week's Top Clips

Clips don't have a `:period` shortcut, but `get_clips/2` takes explicit
`:started_at`/`:ended_at` timestamps (RFC3339), which cover the same week:

```elixir
started_at = DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.to_iso8601()
ended_at = DateTime.utc_now() |> DateTime.to_iso8601()

{:ok, %{"data" => clips}} =
  Twitchy.Clips.get_clips(client,
    broadcaster_id: broadcaster_id,
    started_at: started_at,
    ended_at: ended_at,
    first: 100
  )

top_clips =
  clips
  |> Enum.sort_by(& &1["view_count"], :desc)
  |> Enum.take(5)
```

`get_clips/2` only returns a single page (up to `first: 100`). For a very
clip-heavy channel where a week's clips could exceed 100, swap in
`Twitchy.Clips.stream_clips/2` instead — it paginates lazily, so you can pull
every clip in the window before sorting:

```elixir
top_clips =
  client
  |> Twitchy.Clips.stream_clips(
    broadcaster_id: broadcaster_id,
    started_at: started_at,
    ended_at: ended_at
  )
  |> Enum.to_list()
  |> Enum.sort_by(& &1["view_count"], :desc)
  |> Enum.take(5)
```

### Step 4: Format a Shareable Report

With both lists in hand, assembling the digest is plain string formatting —
nothing Twitchy-specific:

```elixir
report = """
**#{broadcaster["display_name"]}'s Weekly Highlights**

**VODs this week**
#{Enum.map_join(videos, "\n", &"- #{&1["title"]} (#{&1["view_count"]} views) — #{&1["url"]}")}

**Top clips this week**
#{Enum.map_join(top_clips, "\n", &"- #{&1["title"]} by #{&1["creator_name"]} (#{&1["view_count"]} views) — #{&1["url"]}")}
"""

IO.puts(report)
```

That's a complete digest, ready to paste into a Discord channel or pipe to a
webhook.

### Step 5 (Bonus): Create a Clip While Live

`Twitchy.Clips.create_clip/2` requests a clip of the broadcaster's *current*
stream — it only works while the channel is live, and it requires the
`clips:edit` scope on a user access token (an app access token can't call it):

```elixir
{:ok, %{"data" => [%{"id" => clip_id, "edit_url" => edit_url}]}} =
  Twitchy.Clips.create_clip(user_client, broadcaster_id: broadcaster_id)

IO.puts("Clip requested! Finish editing at: #{edit_url}")
```

Two things to keep in mind: if the channel isn't live, `create_clip/2` returns
an error rather than a clip. And even when it succeeds, Twitch needs a few
seconds to finish processing the clip — calling `get_clip/2` with the new
`clip_id` immediately after tends to return `{:ok, nil}`. Give it a moment (or
poll a few times with a short delay) before you rely on it being fetchable, as
shown in the complete example below.

### The Complete Example

```elixir
defmodule MyApp.WeeklyDigest do
  @moduledoc """
  Builds a "Weekly Highlights Digest": a broadcaster's VODs from the past
  week and their most-viewed clips from the same period, formatted as a
  plain-text report ready to paste into Discord.
  """

  @top_clip_count 5

  @doc """
  Builds the digest for `broadcaster_login` and returns it as text.
  """
  @spec build(Twitchy.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def build(client, broadcaster_login) do
    with {:ok, broadcaster} <- Twitchy.Users.get_user(client, login: broadcaster_login),
         broadcaster_id = broadcaster["id"],
         {:ok, videos} <- fetch_week_videos(client, broadcaster_id),
         {:ok, top_clips} <- fetch_week_top_clips(client, broadcaster_id) do
      {:ok, format_report(broadcaster["display_name"], videos, top_clips)}
    end
  end

  defp fetch_week_videos(client, broadcaster_id) do
    case Twitchy.Videos.get_videos(client,
           user_id: broadcaster_id,
           type: :archive,
           period: :week,
           sort: :time,
           first: 20
         ) do
      {:ok, %{"data" => videos}} -> {:ok, videos}
      error -> error
    end
  end

  defp fetch_week_top_clips(client, broadcaster_id) do
    started_at = DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.to_iso8601()
    ended_at = DateTime.utc_now() |> DateTime.to_iso8601()

    case Twitchy.Clips.get_clips(client,
           broadcaster_id: broadcaster_id,
           started_at: started_at,
           ended_at: ended_at,
           first: 100
         ) do
      {:ok, %{"data" => clips}} ->
        top_clips =
          clips
          |> Enum.sort_by(& &1["view_count"], :desc)
          |> Enum.take(@top_clip_count)

        {:ok, top_clips}

      error ->
        error
    end
  end

  defp format_report(display_name, videos, clips) do
    """
    **#{display_name}'s Weekly Highlights**

    **VODs this week (#{length(videos)})**
    #{format_list(videos, &"- #{&1["title"]} (#{&1["view_count"]} views) — #{&1["url"]}")}

    **Top clips this week**
    #{format_list(clips, &"- #{&1["title"]} by #{&1["creator_name"]} (#{&1["view_count"]} views) — #{&1["url"]}")}
    """
  end

  defp format_list([], _formatter), do: "_Nothing this week._"
  defp format_list(items, formatter), do: Enum.map_join(items, "\n", formatter)

  @doc """
  Bonus: creates a clip of the broadcaster's current stream.

  Requires a user access token with the `clips:edit` scope, and the
  broadcaster's channel must be live — `create_clip/2` fails otherwise.
  Twitch also needs a moment to process the clip, so this polls
  `get_clip/2` a few times with a short delay rather than fetching it
  immediately.
  """
  @spec create_live_clip(Twitchy.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def create_live_clip(user_client, broadcaster_id) do
    with {:ok, %{"data" => [%{"id" => clip_id, "edit_url" => edit_url} | _]}} <-
           Twitchy.Clips.create_clip(user_client, broadcaster_id: broadcaster_id) do
      IO.puts("Clip requested (##{clip_id}). Finish editing at: #{edit_url}")
      wait_for_clip(user_client, clip_id)
    end
  end

  defp wait_for_clip(client, clip_id, attempts \\ 5)

  defp wait_for_clip(_client, clip_id, 0), do: {:error, {:clip_not_ready, clip_id}}

  defp wait_for_clip(client, clip_id, attempts) do
    case Twitchy.Clips.get_clip(client, id: clip_id) do
      {:ok, nil} ->
        Process.sleep(3_000)
        wait_for_clip(client, clip_id, attempts - 1)

      {:ok, clip} ->
        {:ok, clip}

      error ->
        error
    end
  end
end
```

Usage — the digest only needs an app access token:

```elixir
{:ok, client} = Twitchy.authenticate(client, :app_access)

{:ok, report} = MyApp.WeeklyDigest.build(client, "your_channel_name")
IO.puts(report)
```

The bonus step needs a user access token for the broadcaster (see
[TUTORIAL.md](../../TUTORIAL.md) for how to obtain one) and only does
anything useful while the channel is actually streaming:

```elixir
{:ok, user_client} = Twitchy.authenticate(client, :user_access, code: code)

{:ok, clip} = MyApp.WeeklyDigest.create_live_clip(user_client, broadcaster_id)
IO.puts("Clip ready: #{clip["url"]}")
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
