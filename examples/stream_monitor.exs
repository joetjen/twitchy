#!/usr/bin/env elixir

# Stream Monitor Example
#
# Monitors Twitch streamers and notifies when they go live/offline.
#
# Usage:
#   export TWITCH_CLIENT_ID="your_client_id"
#   export TWITCH_CLIENT_SECRET="your_client_secret"
#   elixir examples/stream_monitor.exs
#
# Press Ctrl+C to stop.

Mix.install([
  {:twitchy, path: Path.expand("..", __DIR__)},
  {:jason, "~> 1.4"}
])

defmodule StreamMonitor do
  @moduledoc """
  Monitors Twitch streamers using EventSub WebSocket and reports when they go live.
  """

  use GenServer
  require Logger

  # Configure streamers to monitor (add broadcaster user IDs here)
  @streamers [
    # Example IDs - replace with actual broadcaster IDs
    # "12345678",  # Example streamer 1
    # "87654321",  # Example streamer 2
  ]

  defstruct [:client, :streams, :last_check]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Stream Monitor...")

    # Get credentials from environment
    client_id = System.get_env("TWITCH_CLIENT_ID")
    client_secret = System.get_env("TWITCH_CLIENT_SECRET")

    unless client_id && client_secret do
      raise "Missing TWITCH_CLIENT_ID or TWITCH_CLIENT_SECRET environment variables"
    end

    # Create and authenticate client
    {:ok, client} =
      Twitchy.new(client_id: client_id, client_secret: client_secret)
      |> Twitchy.authenticate(:app_access)

    Logger.info("Authenticated with Twitch API")

    # If streamers are configured, start EventSub monitoring
    state = %__MODULE__{
      client: client,
      streams: %{},
      last_check: DateTime.utc_now()
    }

    if Enum.any?(@streamers) do
      start_eventsub_monitoring(client)
      {:ok, state}
    else
      Logger.warning("""
      No streamers configured to monitor!

      Edit #{__ENV__.file} and add broadcaster IDs to the @streamers list.

      Example:
        @streamers [
          "12345678",  # ninja
          "87654321",  # shroud
        ]

      You can find broadcaster IDs using:
        {:ok, user} = Twitchy.Users.get_user(client, login: "ninja")
        user["data"] |> List.first() |> Map.get("id")
      """)

      {:ok, state}
    end
  end

  defp start_eventsub_monitoring(client) do
    # Build subscriptions for all streamers
    subscriptions =
      Enum.flat_map(@streamers, fn broadcaster_id ->
        [
          # Stream online event
          %{
            type: "stream.online",
            condition: %{"broadcaster_user_id" => broadcaster_id}
          },
          # Stream offline event
          %{
            type: "stream.offline",
            condition: %{"broadcaster_user_id" => broadcaster_id}
          }
        ]
      end)

    Logger.info("Starting EventSub WebSocket connection...")
    Logger.info("Monitoring #{length(@streamers)} streamer(s)")

    # Start EventSub with declarative subscriptions
    {:ok, _pid} =
      Twitchy.EventSub.Declarative.start_link(
        client: client,
        handler: __MODULE__,
        subscriptions: subscriptions
      )

    Logger.info("✓ EventSub WebSocket connected and subscribed")
  end

  # EventSub event handler - called when a streamer goes live
  def handle_event("stream.online", event, _metadata) do
    broadcaster = event["broadcaster_user_name"]
    title = event["title"] || "No title"

    IO.puts("""

    🔴 #{broadcaster} went LIVE!
       Title: #{title}
       Started: #{event["started_at"]}
       Watch: https://twitch.tv/#{event["broadcaster_user_login"]}
    """)

    # You can add integrations here:
    # - Send Discord notification
    # - Send Slack message
    # - Send email
    # - Update database
    # - etc.

    :ok
  end

  # EventSub event handler - called when a streamer goes offline
  def handle_event("stream.offline", event, _metadata) do
    broadcaster = event["broadcaster_user_name"]

    IO.puts("""

    ⚫ #{broadcaster} went offline
       Ended: #{DateTime.utc_now()}
    """)

    :ok
  end

  # Catch-all for other events
  def handle_event(event_type, _event, _metadata) do
    Logger.debug("Received event: #{event_type}")
    :ok
  end
end

# Utility module for finding broadcaster IDs
defmodule StreamMonitor.Utils do
  @moduledoc """
  Helper functions for finding broadcaster IDs.
  """

  def find_broadcaster_id(username) do
    client_id = System.get_env("TWITCH_CLIENT_ID")
    client_secret = System.get_env("TWITCH_CLIENT_SECRET")

    {:ok, client} =
      Twitchy.new(client_id: client_id, client_secret: client_secret)
      |> Twitchy.authenticate(:app_access)

    case Twitchy.Users.get_user(client, login: username) do
      {:ok, %{"data" => [user | _]}} ->
        id = user["id"]
        name = user["display_name"]
        IO.puts("✓ Found: #{name} (ID: #{id})")
        {:ok, id}

      {:ok, %{"data" => []}} ->
        IO.puts("✗ User not found: #{username}")
        {:error, :not_found}

      {:error, error} ->
        IO.puts("✗ Error: #{inspect(error)}")
        {:error, error}
    end
  end
end

# Main execution
case System.argv() do
  ["--find-id", username] ->
    # Helper mode: find broadcaster ID by username
    IO.puts("Looking up broadcaster ID for: #{username}\n")
    StreamMonitor.Utils.find_broadcaster_id(username)

  [] ->
    # Normal mode: start monitoring
    IO.puts("""
    ╔══════════════════════════════════════════════╗
    ║     Twitch Stream Monitor (EventSub)         ║
    ╚══════════════════════════════════════════════╝

    Starting stream monitor...
    Press Ctrl+C to stop.
    """)

    # Start the monitor
    {:ok, _pid} = StreamMonitor.start_link([])

    # Keep the script running
    Process.sleep(:infinity)

  ["--help"] ->
    IO.puts("""
    Twitch Stream Monitor

    Usage:
      elixir stream_monitor.exs                 Start monitoring
      elixir stream_monitor.exs --find-id USER  Find broadcaster ID
      elixir stream_monitor.exs --help          Show this help

    Environment Variables:
      TWITCH_CLIENT_ID      Your Twitch application client ID
      TWITCH_CLIENT_SECRET  Your Twitch application client secret

    Configuration:
      Edit @streamers in #{__ENV__.file}
      Add broadcaster user IDs to monitor

    Example:
      export TWITCH_CLIENT_ID="abc123"
      export TWITCH_CLIENT_SECRET="xyz789"
      elixir stream_monitor.exs
    """)

  _ ->
    IO.puts("Invalid arguments. Use --help for usage information.")
    System.halt(1)
end
