# Users & Streams API

Documentation for user information and live stream endpoints.

## Users

### Get Users

Fetch user information by ID or login name.

```elixir
# By login name
{:ok, response} = Twitchy.Users.get_users(client, login: ["ninja", "shroud"])

# By user ID
{:ok, response} = Twitchy.Users.get_users(client, id: ["19571641", "27833742"])

# Mix of both
{:ok, response} = Twitchy.Users.get_users(client,
  login: ["ninja"],
  id: ["27833742"]
)
```

**Response:**

```elixir
%{
  "data" => [
    %{
      "id" => "19571641",
      "login" => "ninja",
      "display_name" => "Ninja",
      "type" => "",
      "broadcaster_type" => "partner",
      "description" => "...",
      "profile_image_url" => "https://...",
      "offline_image_url" => "https://...",
      "view_count" => 123456789,
      "created_at" => "2011-03-19T02:24:10Z"
    }
  ]
}
```

### Get Single User

Convenience method to get one user:

```elixir
# Returns the user data directly, not wrapped in response
{:ok, user} = Twitchy.Users.get_user(client, login: "ninja")
# OR
{:ok, user} = Twitchy.Users.get_user(client, id: "19571641")

# Returns error if not found
{:error, :user_not_found} = Twitchy.Users.get_user(client, login: "nonexistent")
```

### Update User

Update the authenticated user's description:

```elixir
# Requires user:edit scope
{:ok, response} = Twitchy.Users.update_user(client,
  description: "New channel description"
)
```

### Get User Followers

```elixir
{:ok, response} = Twitchy.Users.get_channel_followers(client,
  broadcaster_id: "12345",
  first: 100
)

response["data"]
|> Enum.each(fn follower ->
  IO.puts("#{follower["from_name"]} followed at #{follower["followed_at"]}")
end)

# Stream all followers
client
|> Twitchy.Users.stream_followers(broadcaster_id: "12345")
|> Enum.take(1000)
```

### Get User Follows

Get channels that a user follows:

```elixir
{:ok, response} = Twitchy.Users.get_channel_followed(client,
  user_id: "12345",
  first: 100
)
```

### Block/Unblock User

```elixir
# Block user (requires user:manage:blocked_users scope)
:ok = Twitchy.Users.block_user(client, "98765", source_context: :chat, reason: :spam)

# Unblock user
:ok = Twitchy.Users.unblock_user(client, "98765")
```

### Get Blocked Users

```elixir
{:ok, response} = Twitchy.Users.get_user_block_list(client,
  broadcaster_id: "12345"
)
```

## Streams

### Get Streams

Fetch information about live streams:

```elixir
# Get live streams by user
{:ok, response} = Twitchy.Streams.get_streams(client,
  user_id: ["12345", "67890"]
)

# Get live streams by username
{:ok, response} = Twitchy.Streams.get_streams(client,
  user_login: ["ninja", "shroud"]
)

# Get live streams by game
{:ok, response} = Twitchy.Streams.get_streams(client,
  game_id: ["32399"],  # League of Legends
  first: 100
)

# Get top live streams
{:ok, response} = Twitchy.Streams.get_streams(client, first: 20)
```

**Response:**

```elixir
%{
  "data" => [
    %{
      "id" => "42170724654",
      "user_id" => "12345",
      "user_login" => "ninja",
      "user_name" => "Ninja",
      "game_id" => "32399",
      "game_name" => "League of Legends",
      "type" => "live",
      "title" => "Awesome Stream Title",
      "viewer_count" => 50000,
      "started_at" => "2024-12-19T12:00:00Z",
      "language" => "en",
      "thumbnail_url" => "https://...",
      "tag_ids" => [],
      "is_mature" => false
    }
  ],
  "pagination" => %{"cursor" => "eyJi..."}
}
```

### Check if User is Live

```elixir
def is_live?(client, username) do
  case Twitchy.Streams.get_streams(client, user_login: [username]) do
    {:ok, %{"data" => [_stream | _]}} -> true
    {:ok, %{"data" => []}} -> false
    {:error, _} -> false
  end
end

# Usage
if is_live?(client, "ninja") do
  IO.puts("Ninja is streaming!")
end
```

### Get Stream Key

Get your stream key (requires channel:read:stream_key scope):

```elixir
{:ok, response} = Twitchy.Streams.get_stream_key(client,
  broadcaster_id: "12345"
)

stream_key = response["data"] |> List.first() |> Map.get("stream_key")
```

### Get Followed Streams

Get live streams from channels the user follows:

```elixir
# Requires user:read:follows scope
{:ok, response} = Twitchy.Streams.get_followed_streams(client,
  user_id: "12345"
)

# Page through followed live streams with `:after`
{:ok, %{"data" => streams, "pagination" => pagination}} =
  Twitchy.Streams.get_followed_streams(client, user_id: "12345", first: 100)

Enum.each(streams, fn stream ->
  IO.puts("#{stream["user_name"]} is live: #{stream["title"]}")
end)

# Fetch the next page using the cursor, if there is one
case pagination do
  %{"cursor" => cursor} ->
    Twitchy.Streams.get_followed_streams(client, user_id: "12345", first: 100, after: cursor)

  _ ->
    :done
end
```

### Create Stream Marker

Create a marker in the stream (requires channel:manage:broadcast scope):

```elixir
{:ok, response} = Twitchy.Streams.create_stream_marker(client,
  user_id: "12345",
  description: "Epic moment!"
)
```

### Get Stream Markers

```elixir
{:ok, response} = Twitchy.Streams.get_stream_markers(client,
  user_id: "12345"
)
```

## Complete Examples

### Live Stream Monitor

```elixir
defmodule MyApp.StreamMonitor do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    client = opts[:client]
    usernames = opts[:usernames]

    # Check every 60 seconds
    schedule_check()

    {:ok, %{client: client, usernames: usernames, live: MapSet.new()}}
  end

  def handle_info(:check, state) do
    {:ok, response} = Twitchy.Streams.get_streams(state.client,
      user_login: state.usernames,
      first: 100
    )

    currently_live =
      response["data"]
      |> Enum.map(& &1["user_login"])
      |> MapSet.new()

    # Find new streams
    new_live = MapSet.difference(currently_live, state.live)
    new_offline = MapSet.difference(state.live, currently_live)

    Enum.each(new_live, fn username ->
      stream = Enum.find(response["data"], &(&1["user_login"] == username))
      Logger.info("🔴 #{stream["user_name"]} went live!")
      Logger.info("   #{stream["title"]}")
      Logger.info("   Playing: #{stream["game_name"]}")
      Logger.info("   Viewers: #{stream["viewer_count"]}")

      # Send notification
      MyApp.Notifications.send(:stream_live, stream)
    end)

    Enum.each(new_offline, fn username ->
      Logger.info("⚫ #{username} went offline")
    end)

    schedule_check()
    {:noreply, %{state | live: currently_live}}
  end

  defp schedule_check do
    Process.send_after(self(), :check, 60_000)
  end
end

# Start the monitor
{:ok, client} = Twitchy.authenticate(client, :app_access)

MyApp.StreamMonitor.start_link(
  client: client,
  usernames: ["ninja", "shroud", "pokimane", "xqc"]
)
```

### User Profile Fetcher

```elixir
defmodule MyApp.UserProfile do
  def fetch_full_profile(client, username) do
    with {:ok, user} <- Twitchy.Users.get_user(client, login: username),
         {:ok, stream_resp} <- Twitchy.Streams.get_streams(client, user_id: [user["id"]]),
         {:ok, followers} <- Twitchy.Users.get_channel_followers(client, broadcaster_id: user["id"], first: 1),
         {:ok, following} <- Twitchy.Users.get_channel_followed(client, user_id: user["id"], first: 1) do

      stream = List.first(stream_resp["data"])

      %{
        user: user,
        is_live: stream != nil,
        stream: stream,
        follower_count: followers["total"],
        following_count: following["total"]
      }
    end
  end
end

# Usage
case MyApp.UserProfile.fetch_full_profile(client, "ninja") do
  {:ok, profile} ->
    IO.puts("=== #{profile.user["display_name"]} ===")
    IO.puts("ID: #{profile.user["id"]}")
    IO.puts("Description: #{profile.user["description"]}")
    IO.puts("Followers: #{profile.follower_count}")
    IO.puts("Following: #{profile.following_count}")

    if profile.is_live do
      IO.puts("\n🔴 LIVE NOW!")
      IO.puts("Title: #{profile.stream["title"]}")
      IO.puts("Game: #{profile.stream["game_name"]}")
      IO.puts("Viewers: #{profile.stream["viewer_count"]}")
    else
      IO.puts("\n⚫ Offline")
    end

  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end
```

### Multi-Channel Viewer Count Tracker

```elixir
defmodule MyApp.ViewerTracker do
  def track_viewers(client, usernames, duration_minutes \\ 60) do
    track_viewers_loop(client, usernames, duration_minutes * 60, %{})
  end

  defp track_viewers_loop(_client, _usernames, 0, history) do
    # Done tracking, return results
    history
    |> Enum.map(fn {username, datapoints} ->
      avg = Enum.sum(datapoints) / length(datapoints)
      max = Enum.max(datapoints)
      min = Enum.min(datapoints)

      %{
        username: username,
        average: round(avg),
        peak: max,
        lowest: min,
        datapoints: length(datapoints)
      }
    end)
  end

  defp track_viewers_loop(client, usernames, remaining_seconds, history) do
    {:ok, response} = Twitchy.Streams.get_streams(client,
      user_login: usernames
    )

    # Record current viewer counts
    new_history =
      response["data"]
      |> Enum.reduce(history, fn stream, acc ->
        username = stream["user_login"]
        viewers = stream["viewer_count"]

        Map.update(acc, username, [viewers], &[viewers | &1])
      end)

    IO.write(".")
    Process.sleep(60_000)  # Wait 1 minute

    track_viewers_loop(client, usernames, remaining_seconds - 60, new_history)
  end
end

# Usage: Track viewer counts for 2 hours
{:ok, client} = Twitchy.authenticate(client, :app_access)

stats = MyApp.ViewerTracker.track_viewers(client,
  ["ninja", "shroud", "pokimane"],
  120  # 2 hours
)

Enum.each(stats, fn stat ->
  IO.puts("\n#{stat.username}:")
  IO.puts("  Average: #{stat.average} viewers")
  IO.puts("  Peak: #{stat.peak} viewers")
  IO.puts("  Lowest: #{stat.lowest} viewers")
end)
```

## Tutorial

This walkthrough builds a small "Who's Live" tracker: a script that takes a
list of favorite streamers' login names, checks which ones are currently live
via the Streams API, and prints a report — then extends the idea to page
through a channel's followers. Each step below is a small, runnable piece;
the full script is assembled at the end.

### Step 1: List Your Favorite Streamers

Start with a plain list of Twitch login names (lowercase, as Twitch returns
them):

```elixir
favorites = ["ninja", "shroud", "pokimane", "xqc"]
```

### Step 2: Check Who's Live

`Twitchy.Streams.get_streams/2` accepts a list of `:user_login` values and
returns only the channels that are currently streaming — anyone offline is
simply absent from `"data"`, there's no per-channel "offline" entry to filter
out:

```elixir
{:ok, response} = Twitchy.Streams.get_streams(client, user_login: favorites)

live_streams = response["data"]
```

### Step 3: Work Out Who's Offline

Since `get_streams/2` only returns live channels, figure out who's offline by
diffing the requested logins against the ones that came back:

```elixir
live_logins = MapSet.new(live_streams, & &1["user_login"])
offline_logins = Enum.reject(favorites, &MapSet.member?(live_logins, &1))
```

### Step 4: Print a Report

Sort the live streams by viewer count so the biggest channel leads the
report, then list who's offline underneath:

```elixir
live_streams
|> Enum.sort_by(& &1["viewer_count"], :desc)
|> Enum.each(fn stream ->
  IO.puts("🔴 #{stream["user_name"]} — #{stream["viewer_count"]} viewers")
  IO.puts("   #{stream["title"]}")
end)

Enum.each(offline_logins, fn login ->
  IO.puts("⚫ #{login} is offline")
end)
```

### Step 5: Look Up a Single Streamer On Demand

For checking one login at a time — say, behind a `/live shroud` chat command
— `Twitchy.Streams.get_stream/2` is a convenience wrapper around
`get_streams/2` that returns the first match directly. Unlike
`Twitchy.Users.get_user/2`, it returns `{:ok, nil}` rather than an error when
nobody matches, because "offline" is a normal outcome here, not a failure:

```elixir
case Twitchy.Streams.get_stream(client, user_login: "shroud") do
  {:ok, nil} -> IO.puts("shroud is offline")
  {:ok, stream} -> IO.puts("shroud is live: #{stream["title"]}")
  {:error, error} -> IO.puts("Error checking shroud: #{Exception.message(error)}")
end
```

### Step 6: Resolve a Login to a User ID

Paging through a channel's followers needs the broadcaster's numeric user ID,
not their login name. `Twitchy.Users.get_user/2` resolves one from the other
— and, as covered above, returns `{:error, :user_not_found}` for a typo'd or
deleted login rather than `{:ok, nil}`, so that case needs its own branch:

```elixir
case Twitchy.Users.get_user(client, login: "shroud") do
  {:ok, user} -> {:ok, user["id"]}
  {:error, :user_not_found} -> {:error, :no_such_user}
  {:error, error} -> {:error, error}
end
```

### Step 7: Page Through a Channel's Followers

With a broadcaster ID in hand, `Twitchy.Users.stream_followers/2` lazily
streams pages of followers, fetching more only as the `Stream` is consumed —
handy when you want the first N followers without pulling the entire list
into memory:

```elixir
client
|> Twitchy.Users.stream_followers(broadcaster_id: broadcaster_id)
|> Stream.take(250)
|> Enum.each(fn follower ->
  IO.puts("#{follower["user_name"]} followed at #{follower["followed_at"]}")
end)
```

Swap `Stream.take(250)` for `Enum.count/1` if you just want a total, or drop
the cap entirely to walk every page — `Pagination` keeps requesting pages
under the hood until Twitch stops returning a cursor.

### The Complete Example

Putting it together: a module that reports on your favorite streamers' live
status and, for any of them, can page through their followers. Save this as
`lib/my_app/whos_live.ex` in a project with `:twitchy` as a dependency:

```elixir
defmodule MyApp.WhosLive do
  @moduledoc """
  Reports which favorite streamers are currently live, and can page through
  a channel's followers.
  """

  @doc """
  Checks a list of logins against the Streams API and prints a live/offline
  report, live channels first and sorted by viewer count.
  """
  @spec report(Twitchy.t(), [String.t()]) :: :ok
  def report(client, favorite_logins) do
    case Twitchy.Streams.get_streams(client, user_login: favorite_logins) do
      {:ok, %{"data" => live_streams}} ->
        print_report(favorite_logins, live_streams)

      {:error, error} ->
        IO.puts("Failed to fetch streams: #{Exception.message(error)}")
    end

    :ok
  end

  defp print_report(favorite_logins, live_streams) do
    live_logins = MapSet.new(live_streams, & &1["user_login"])
    offline_logins = Enum.reject(favorite_logins, &MapSet.member?(live_logins, &1))

    live_streams
    |> Enum.sort_by(& &1["viewer_count"], :desc)
    |> Enum.each(fn stream ->
      IO.puts("🔴 #{stream["user_name"]} — #{stream["viewer_count"]} viewers")
      IO.puts("   #{stream["title"]}")
    end)

    Enum.each(offline_logins, fn login ->
      IO.puts("⚫ #{login} is offline")
    end)
  end

  @doc """
  Looks up a single streamer's live status by login.

  Returns `{:ok, stream}` if live, `{:ok, :offline}` if not, or `{:error,
  reason}` on failure.
  """
  @spec check(Twitchy.t(), String.t()) :: {:ok, map() | :offline} | {:error, term()}
  def check(client, login) do
    case Twitchy.Streams.get_stream(client, user_login: login) do
      {:ok, nil} -> {:ok, :offline}
      {:ok, stream} -> {:ok, stream}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Prints up to `limit` followers of the given broadcaster's login.

  Resolves the login to a user ID first, then pages through followers with
  `Twitchy.Users.stream_followers/2`.
  """
  @spec follower_report(Twitchy.t(), String.t(), pos_integer()) :: :ok | {:error, term()}
  def follower_report(client, broadcaster_login, limit \\ 100) do
    case Twitchy.Users.get_user(client, login: broadcaster_login) do
      {:ok, broadcaster} ->
        client
        |> Twitchy.Users.stream_followers(broadcaster_id: broadcaster["id"])
        |> Stream.take(limit)
        |> Enum.each(fn follower ->
          IO.puts("#{follower["user_name"]} followed at #{follower["followed_at"]}")
        end)

        :ok

      {:error, :user_not_found} ->
        IO.puts("No such channel: #{broadcaster_login}")
        {:error, :user_not_found}

      {:error, error} ->
        IO.puts("Failed to look up #{broadcaster_login}: #{Exception.message(error)}")
        {:error, error}
    end
  end
end

# Usage
{:ok, client} = Twitchy.authenticate(Twitchy.new(), :app_access)

MyApp.WhosLive.report(client, ["ninja", "shroud", "pokimane", "xqc"])

case MyApp.WhosLive.check(client, "shroud") do
  {:ok, :offline} -> IO.puts("shroud is offline")
  {:ok, stream} -> IO.puts("shroud is live: #{stream["title"]}")
  {:error, error} -> IO.puts("Error: #{inspect(error)}")
end

MyApp.WhosLive.follower_report(client, "shroud", 50)
```

## Best Practices

### Caching User Data

User data doesn't change often, cache it:

```elixir
defmodule MyApp.UserCache do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_user(client, user_id) do
    case GenServer.call(__MODULE__, {:get, user_id}) do
      nil ->
        # Cache miss, fetch from API
        case Twitchy.Users.get_user(client, id: user_id) do
          {:ok, user} ->
            GenServer.cast(__MODULE__, {:put, user_id, user})
            {:ok, user}
          error -> error
        end

      user ->
        {:ok, user}
    end
  end

  # GenServer callbacks
  def init(state), do: {:ok, state}

  def handle_call({:get, user_id}, _from, state) do
    {:reply, Map.get(state, user_id), state}
  end

  def handle_cast({:put, user_id, user}, state) do
    # Cache for 1 hour
    Process.send_after(self(), {:expire, user_id}, 3_600_000)
    {:noreply, Map.put(state, user_id, user)}
  end

  def handle_info({:expire, user_id}, state) do
    {:noreply, Map.delete(state, user_id)}
  end
end
```

### Rate Limiting Protection

```elixir
defmodule MyApp.TwitchRateLimiter do
  def batch_get_users(client, usernames) do
    # Twitch allows up to 100 users per request
    usernames
    |> Enum.chunk_every(100)
    |> Enum.flat_map(fn chunk ->
      case Twitchy.Users.get_users(client, login: chunk) do
        {:ok, response} -> response["data"]
        {:error, _} -> []
      end
    end)
  end
end
```

## See Also

- [Channels & Games API](CHANNELS_GAMES.md)
- [Videos & Clips API](VIDEOS_CLIPS.md)
- [EventSub for real-time stream events](../../EVENTSUB_EXAMPLES.md)
