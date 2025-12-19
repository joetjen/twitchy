#!/usr/bin/env elixir

# Clip Downloader Example
#
# Downloads top clips from a Twitch broadcaster.
#
# Usage:
#   export TWITCH_CLIENT_ID="your_client_id"
#   export TWITCH_CLIENT_SECRET="your_client_secret"
#   elixir examples/clip_downloader.exs --broadcaster ninja --days 7 --count 10

Mix.install([
  {:twitchy, path: Path.expand("..", __DIR__)},
  {:jason, "~> 1.4"}
])

defmodule ClipDownloader do
  @moduledoc """
  Downloads top Twitch clips for a broadcaster.
  """

  require Logger

  defstruct [:client, :broadcaster_id, :broadcaster_name, :output_dir]

  def new(opts) do
    client_id = System.get_env("TWITCH_CLIENT_ID")
    client_secret = System.get_env("TWITCH_CLIENT_SECRET")

    unless client_id && client_secret do
      raise "Missing TWITCH_CLIENT_ID or TWITCH_CLIENT_SECRET environment variables"
    end

    # Authenticate
    {:ok, client} =
      Twitchy.new(client_id: client_id, client_secret: client_secret)
      |> Twitchy.authenticate(:app_access)

    %__MODULE__{
      client: client,
      broadcaster_id: Keyword.get(opts, :broadcaster_id),
      broadcaster_name: Keyword.get(opts, :broadcaster_name),
      output_dir: Keyword.get(opts, :output_dir, "./clips")
    }
  end

  def find_broadcaster(downloader, username) do
    IO.write("Looking up broadcaster: #{username}... ")

    case Twitchy.Users.get_user(downloader.client, login: username) do
      {:ok, %{"data" => [user | _]}} ->
        IO.puts("✓")

        %{
          downloader
          | broadcaster_id: user["id"],
            broadcaster_name: user["display_name"]
        }

      {:ok, %{"data" => []}} ->
        IO.puts("✗")
        raise "Broadcaster not found: #{username}"

      {:error, error} ->
        IO.puts("✗")
        raise "Error looking up broadcaster: #{inspect(error)}"
    end
  end

  def fetch_clips(downloader, opts) do
    days = Keyword.get(opts, :days, 7)
    max_clips = Keyword.get(opts, :count, 10)

    started_at =
      DateTime.utc_now()
      |> DateTime.add(-days * 86400, :second)
      |> DateTime.to_iso8601()

    IO.puts("\nFetching top #{max_clips} clips from the last #{days} days...")

    params = [
      broadcaster_id: downloader.broadcaster_id,
      started_at: started_at,
      first: min(max_clips, 100)
    ]

    case Twitchy.Clips.get_clips(downloader.client, params) do
      {:ok, response} ->
        clips =
          response["data"]
          |> Enum.sort_by(& &1["view_count"], :desc)
          |> Enum.take(max_clips)

        IO.puts("✓ Found #{length(clips)} clips\n")
        {:ok, clips}

      {:error, error} ->
        {:error, error}
    end
  end

  def download_clips(downloader, clips) do
    # Create output directory
    File.mkdir_p!(downloader.output_dir)

    IO.puts("Downloading to: #{downloader.output_dir}\n")

    results =
      clips
      |> Enum.with_index(1)
      |> Enum.map(fn {clip, index} ->
        download_clip(downloader, clip, index, length(clips))
      end)

    successful = Enum.count(results, &match?({:ok, _}, &1))
    failed = length(results) - successful

    IO.puts("""

    ╔═══════════════════════════════════════════╗
    ║  Download Complete!                       ║
    ╚═══════════════════════════════════════════╝

    Successful: #{successful}
    Failed:     #{failed}
    Total:      #{length(results)}

    Clips saved to: #{downloader.output_dir}
    """)

    {:ok, results}
  end

  defp download_clip(downloader, clip, index, total) do
    title = clip["title"] |> String.slice(0, 50)
    views = format_number(clip["view_count"])
    clip_id = clip["id"]

    IO.write("[#{index}/#{total}] #{title} (#{views} views)... ")

    # Get video URL from thumbnail URL
    video_url =
      clip["thumbnail_url"]
      |> String.replace("-preview-", "-")
      |> String.replace(~r/-\d+x\d+\.jpg$/, ".mp4")

    # Create safe filename
    filename =
      "#{downloader.broadcaster_name}_#{clip_id}_#{sanitize_filename(clip["title"])}.mp4"

    output_path = Path.join(downloader.output_dir, filename)

    # Download using curl (cross-platform)
    case System.cmd("curl", ["-s", "-f", "-o", output_path, video_url], stderr_to_stdout: true) do
      {_, 0} ->
        IO.puts("✓")
        {:ok, output_path}

      {error, _} ->
        IO.puts("✗")
        Logger.error("Failed to download #{clip_id}: #{error}")
        {:error, error}
    end
  end

  defp sanitize_filename(name) do
    name
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "_")
    |> String.slice(0, 50)
  end

  defp format_number(num) when num >= 1_000_000, do: "#{div(num, 1_000_000)}M"
  defp format_number(num) when num >= 1_000, do: "#{div(num, 1_000)}K"
  defp format_number(num), do: "#{num}"

  def print_clip_list(clips) do
    IO.puts("""
    ╔═══════════════════════════════════════════╗
    ║  Top Clips                                ║
    ╚═══════════════════════════════════════════╝
    """)

    clips
    |> Enum.with_index(1)
    |> Enum.each(fn {clip, index} ->
      title = String.pad_trailing(String.slice(clip["title"], 0, 40), 40)
      views = format_number(clip["view_count"]) |> String.pad_leading(6)
      creator = clip["creator_name"]
      date = clip["created_at"] |> String.slice(0, 10)

      IO.puts("#{String.pad_leading("#{index}", 2)}. #{title} | #{views} views | by #{creator} | #{date}")
    end)

    IO.puts("")
  end
end

# Parse command line arguments
defmodule CLI do
  def parse_args(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          broadcaster: :string,
          days: :integer,
          count: :integer,
          output: :string,
          list: :boolean,
          help: :boolean
        ],
        aliases: [
          b: :broadcaster,
          d: :days,
          c: :count,
          o: :output,
          l: :list,
          h: :help
        ]
      )

    opts
  end

  def show_help do
    IO.puts("""
    Twitch Clip Downloader

    Usage:
      elixir clip_downloader.exs [OPTIONS]

    Options:
      -b, --broadcaster USER   Twitch username (required)
      -d, --days DAYS          Number of days to look back (default: 7)
      -c, --count COUNT        Number of clips to download (default: 10)
      -o, --output DIR         Output directory (default: ./clips)
      -l, --list               Only list clips, don't download
      -h, --help               Show this help

    Environment Variables:
      TWITCH_CLIENT_ID         Your Twitch application client ID
      TWITCH_CLIENT_SECRET     Your Twitch application client secret

    Examples:
      # Download top 10 clips from last 7 days
      elixir clip_downloader.exs -b ninja -d 7 -c 10

      # Just list clips without downloading
      elixir clip_downloader.exs -b shroud --list

      # Download to custom directory
      elixir clip_downloader.exs -b pokimane -o ~/Downloads/clips
    """)
  end
end

# Main execution
opts = CLI.parse_args(System.argv())

cond do
  Keyword.get(opts, :help) ->
    CLI.show_help()

  !Keyword.has_key?(opts, :broadcaster) ->
    IO.puts("Error: --broadcaster option is required\n")
    CLI.show_help()
    System.halt(1)

  true ->
    broadcaster = Keyword.get(opts, :broadcaster)
    days = Keyword.get(opts, :days, 7)
    count = Keyword.get(opts, :count, 10)
    output_dir = Keyword.get(opts, :output, "./clips")
    list_only = Keyword.get(opts, :list, false)

    IO.puts("""
    ╔═══════════════════════════════════════════╗
    ║  Twitch Clip Downloader                   ║
    ╚═══════════════════════════════════════════╝
    """)

    # Create downloader and find broadcaster
    downloader =
      ClipDownloader.new(output_dir: output_dir)
      |> ClipDownloader.find_broadcaster(broadcaster)

    # Fetch clips
    case ClipDownloader.fetch_clips(downloader, days: days, count: count) do
      {:ok, []} ->
        IO.puts("No clips found for the specified criteria.")

      {:ok, clips} ->
        # Print clip list
        ClipDownloader.print_clip_list(clips)

        # Download if not list-only mode
        unless list_only do
          ClipDownloader.download_clips(downloader, clips)
        end

      {:error, error} ->
        IO.puts("Error fetching clips: #{inspect(error)}")
        System.halt(1)
    end
end
