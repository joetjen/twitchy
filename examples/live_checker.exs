#!/usr/bin/env elixir

# Live Stream Checker Example
#
# Checks if streamers are currently live and displays their stream information.
#
# Usage:
#   export TWITCH_CLIENT_ID="your_client_id"
#   export TWITCH_CLIENT_SECRET="your_client_secret"
#   elixir examples/live_checker.exs ninja shroud pokimane

Mix.install([
  {:twitchy, path: Path.expand("..", __DIR__)},
  {:jason, "~> 1.4"}
])

defmodule LiveChecker do
  @moduledoc """
  Checks if Twitch streamers are currently live.
  """

  require Logger

  def check_streamers(usernames) do
    client = authenticate()

    IO.puts("""
    ╔═══════════════════════════════════════════╗
    ║  Twitch Live Stream Checker               ║
    ╚═══════════════════════════════════════════╝

    Checking #{length(usernames)} streamer(s)...
    """)

    usernames
    |> Enum.map(&check_streamer(client, &1))
    |> print_results()
  end

  defp authenticate do
    client_id = System.get_env("TWITCH_CLIENT_ID")
    client_secret = System.get_env("TWITCH_CLIENT_SECRET")

    unless client_id && client_secret do
      raise "Missing TWITCH_CLIENT_ID or TWITCH_CLIENT_SECRET environment variables"
    end

    {:ok, client} =
      Twitchy.new(client_id: client_id, client_secret: client_secret)
      |> Twitchy.authenticate(:app_access)

    client
  end

  defp check_streamer(client, username) do
    case Twitchy.Streams.get_streams(client, user_login: [username]) do
      {:ok, %{"data" => [stream | _]}} ->
        {:live, stream}

      {:ok, %{"data" => []}} ->
        # Get user info even if offline
        case Twitchy.Users.get_user(client, login: username) do
          {:ok, %{"data" => [user | _]}} ->
            {:offline, user}

          _ ->
            {:not_found, username}
        end

      {:error, _error} ->
        {:error, username}
    end
  end

  defp print_results(results) do
    live_streams = Enum.filter(results, &match?({:live, _}, &1))
    offline_users = Enum.filter(results, &match?({:offline, _}, &1))
    not_found = Enum.filter(results, &match?({:not_found, _}, &1))
    errors = Enum.filter(results, &match?({:error, _}, &1))

    # Print live streams
    if Enum.any?(live_streams) do
      IO.puts("""
      ╔═══════════════════════════════════════════╗
      ║  🔴 LIVE NOW                              ║
      ╚═══════════════════════════════════════════╝
      """)

      Enum.each(live_streams, fn {:live, stream} ->
        print_live_stream(stream)
      end)
    end

    # Print offline users
    if Enum.any?(offline_users) do
      IO.puts("""
      ╔═══════════════════════════════════════════╗
      ║  ⚫ OFFLINE                                ║
      ╚═══════════════════════════════════════════╝
      """)

      Enum.each(offline_users, fn {:offline, user} ->
        IO.puts("  #{user["display_name"]} (@#{user["login"]})")
      end)

      IO.puts("")
    end

    # Print errors
    if Enum.any?(not_found) do
      IO.puts("\n❌ Not found:")

      Enum.each(not_found, fn {:not_found, username} ->
        IO.puts("  - #{username}")
      end)
    end

    if Enum.any?(errors) do
      IO.puts("\n⚠️  Errors:")

      Enum.each(errors, fn {:error, username} ->
        IO.puts("  - #{username}")
      end)
    end

    # Summary
    IO.puts("""

    ╔═══════════════════════════════════════════╗
    ║  Summary                                  ║
    ╚═══════════════════════════════════════════╝

    Live:    #{length(live_streams)}
    Offline: #{length(offline_users)}
    Errors:  #{length(not_found) + length(errors)}
    Total:   #{length(results)}
    """)
  end

  defp print_live_stream(stream) do
    title = stream["title"]
    game = stream["game_name"]
    viewers = format_number(stream["viewer_count"])
    started = format_duration(stream["started_at"])
    url = "https://twitch.tv/#{stream["user_login"]}"

    IO.puts("""
    ┌─────────────────────────────────────────────
    │ 🔴 #{stream["user_name"]} (@#{stream["user_login"]})
    │
    │ #{title}
    │
    │ 🎮 Playing: #{game}
    │ 👥 Viewers: #{viewers}
    │ ⏱️  Started: #{started}
    │ 🔗 #{url}
    └─────────────────────────────────────────────
    """)
  end

  defp format_number(num) when num >= 1_000_000, do: "#{Float.round(num / 1_000_000, 1)}M"
  defp format_number(num) when num >= 1_000, do: "#{Float.round(num / 1_000, 1)}K"
  defp format_number(num), do: "#{num}"

  defp format_duration(started_at_iso) do
    {:ok, started_at, _} = DateTime.from_iso8601(started_at_iso)
    now = DateTime.utc_now()

    seconds = DateTime.diff(now, started_at)
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)

    cond do
      hours > 0 -> "#{hours}h #{minutes}m ago"
      minutes > 0 -> "#{minutes}m ago"
      true -> "just now"
    end
  end
end

# Main execution
case System.argv() do
  [] ->
    IO.puts("""
    Usage: elixir live_checker.exs USERNAME [USERNAME...]

    Examples:
      elixir live_checker.exs ninja
      elixir live_checker.exs ninja shroud pokimane

    Environment Variables:
      TWITCH_CLIENT_ID      Your Twitch application client ID
      TWITCH_CLIENT_SECRET  Your Twitch application client secret
    """)

    System.halt(1)

  usernames ->
    LiveChecker.check_streamers(usernames)
end
