# Predictions, Polls & HypeTrain API

Documentation for interactive features: Predictions, Polls, and Hype Trains.

## Predictions API

### Create Prediction

Start a Channel Points prediction (requires `channel:manage:predictions` scope).

```elixir
{:ok, response} = Twitchy.Predictions.create_prediction(client,
  broadcaster_id: "123456",
  title: "Will we beat the boss?",
  outcomes: [
    %{title: "Yes"},
    %{title: "No"}
  ],
  prediction_window: 300  # 5 minutes
)

prediction = List.first(response["data"])
IO.puts("Prediction created! ID: #{prediction["id"]}")
IO.puts("Blue: #{List.first(prediction["outcomes"])["title"]}")
IO.puts("Pink: #{List.last(prediction["outcomes"])["title"]}")
```

### Get Predictions

Get active or recent predictions.

```elixir
{:ok, response} = Twitchy.Predictions.get_predictions(client,
  broadcaster_id: "123456",
  first: 20
)

Enum.each(response["data"], fn pred ->
  IO.puts("#{pred["title"]} - Status: #{pred["status"]}")

  Enum.each(pred["outcomes"], fn outcome ->
    IO.puts("  #{outcome["title"]}: #{outcome["users"]} users, #{outcome["channel_points"]} points")
  end)
end)
```

### End Prediction

Lock and resolve a prediction.

```elixir
# Get the winning outcome ID first
{:ok, response} = Twitchy.Predictions.get_predictions(client,
  broadcaster_id: "123456"
)

prediction = List.first(response["data"])
winning_outcome_id = List.first(prediction["outcomes"])["id"]

# End the prediction
{:ok, response} = Twitchy.Predictions.end_prediction(client,
  broadcaster_id: "123456",
  id: prediction["id"],
  status: "RESOLVED",  # or "CANCELED" to refund all
  winning_outcome_id: winning_outcome_id
)
```

## Polls API

### Create Poll

Create a poll (requires `channel:manage:polls` scope).

```elixir
{:ok, response} = Twitchy.Polls.create_poll(client,
  broadcaster_id: "123456",
  title: "What game should we play next?",
  choices: [
    %{title: "League of Legends"},
    %{title: "Valorant"},
    %{title: "CS:GO"},
    %{title: "Just Chatting"}
  ],
  duration: 300,  # 5 minutes
  channel_points_voting_enabled: true,
  channel_points_per_vote: 100
)

poll = List.first(response["data"])
IO.puts("Poll created! ID: #{poll["id"]}")
```

### Get Polls

Get active or recent polls.

```elixir
{:ok, response} = Twitchy.Polls.get_polls(client,
  broadcaster_id: "123456",
  first: 20
)

Enum.each(response["data"], fn poll ->
  IO.puts("#{poll["title"]} - Status: #{poll["status"]}")
  IO.puts("Duration: #{poll["duration"]}s | Points voting: #{poll["channel_points_voting_enabled"]}")

  Enum.with_index(poll["choices"], 1) |> Enum.each(fn {choice, index} ->
    IO.puts("  #{index}. #{choice["title"]}: #{choice["votes"]} votes")

    if poll["channel_points_voting_enabled"] do
      IO.puts("     Channel Points: #{choice["channel_points_votes"]}")
    end
  end)
end)
```

### End Poll

Terminate a poll early.

```elixir
{:ok, response} = Twitchy.Polls.end_poll(client,
  broadcaster_id: "123456",
  id: "poll_id",
  status: "TERMINATED"  # or "ARCHIVED"
)
```

## HypeTrain API

### Get Hype Train Events

Get information about Hype Train events.

```elixir
{:ok, response} = Twitchy.HypeTrain.get_hype_train_events(client,
  broadcaster_id: "123456",
  first: 20
)

Enum.each(response["data"], fn event ->
  IO.puts("Hype Train Event ID: #{event["id"]}")
  IO.puts("Level: #{event["level"]}")
  IO.puts("Total: #{event["total"]}")
  IO.puts("Progress: #{event["progress"]}/#{event["goal"]}")
  IO.puts("Started: #{event["started_at"]}")

  if event["expires_at"] do
    IO.puts("Expires: #{event["expires_at"]}")
  end

  IO.puts("Top contributions:")
  Enum.take(event["top_contributions"], 5) |> Enum.each(fn contrib ->
    IO.puts("  #{contrib["user"]}: #{contrib["total"]} (#{contrib["type"]})")
  end)

  IO.puts("")
end)
```

## Examples

### Prediction Bot

Automated prediction management based on game events.

```elixir
defmodule MyApp.PredictionBot do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    client = opts[:client]
    channel_id = opts[:channel_id]

    # Subscribe to prediction events
    {:ok, _} = Twitchy.EventSub.Declarative.start_link(
      client: client,
      handler: __MODULE__,
      subscriptions: [
        %{
          type: "channel.prediction.begin",
          condition: %{"broadcaster_user_id" => channel_id}
        },
        %{
          type: "channel.prediction.progress",
          condition: %{"broadcaster_user_id" => channel_id}
        },
        %{
          type: "channel.prediction.lock",
          condition: %{"broadcaster_user_id" => channel_id}
        },
        %{
          type: "channel.prediction.end",
          condition: %{"broadcaster_user_id" => channel_id}
        }
      ]
    )

    {:ok, %{
      client: client,
      channel_id: channel_id,
      active_prediction: nil
    }}
  end

  def handle_event("channel.prediction.begin", event, _meta) do
    IO.puts("🎲 Prediction started: #{event["title"]}")

    Enum.with_index(event["outcomes"], 1) |> Enum.each(fn {outcome, index} ->
      color = if index == 1, do: "🔵", else: "🟣"
      IO.puts("  #{color} #{outcome["title"]}")
    end)

    GenServer.cast(__MODULE__, {:set_prediction, event["id"]})
    :ok
  end

  def handle_event("channel.prediction.progress", event, _meta) do
    total_points = Enum.reduce(event["outcomes"], 0, &(&2 + &1["channel_points"]))

    IO.puts("📊 Prediction progress:")
    Enum.each(event["outcomes"], fn outcome ->
      percentage = if total_points > 0 do
        (outcome["channel_points"] / total_points * 100) |> Float.round(1)
      else
        0
      end

      IO.puts("  #{outcome["title"]}: #{outcome["users"]} users (#{percentage}%)")
    end)

    :ok
  end

  def handle_event("channel.prediction.lock", event, _meta) do
    IO.puts("🔒 Prediction locked: #{event["title"]}")
    :ok
  end

  def handle_event("channel.prediction.end", event, _meta) do
    if event["status"] == "RESOLVED" do
      winning = Enum.find(event["outcomes"], &(&1["id"] == event["winning_outcome_id"]))
      IO.puts("✅ Prediction resolved: #{winning["title"]} wins!")
      IO.puts("  Winners: #{winning["users"]} users")
      IO.puts("  Points: #{winning["channel_points"]}")
    else
      IO.puts("❌ Prediction canceled: #{event["title"]}")
    end

    GenServer.cast(__MODULE__, {:set_prediction, nil})
    :ok
  end

  def handle_cast({:set_prediction, prediction_id}, state) do
    {:noreply, %{state | active_prediction: prediction_id}}
  end

  # Public API for auto-creating predictions
  def create_prediction(title, outcomes, duration \\ 300) do
    state = :sys.get_state(__MODULE__)

    outcome_list = Enum.map(outcomes, &%{title: &1})

    Twitchy.Predictions.create_prediction(state.client,
      broadcaster_id: state.channel_id,
      title: title,
      outcomes: outcome_list,
      prediction_window: duration
    )
  end

  def resolve_prediction(winning_outcome_title) do
    state = :sys.get_state(__MODULE__)

    return {:error, :no_active_prediction} unless state.active_prediction

    # Get prediction details
    {:ok, response} = Twitchy.Predictions.get_predictions(state.client,
      broadcaster_id: state.channel_id,
      id: state.active_prediction
    )

    prediction = List.first(response["data"])

    # Find winning outcome
    winning = Enum.find(prediction["outcomes"], &(&1["title"] == winning_outcome_title))

    return {:error, :outcome_not_found} unless winning

    Twitchy.Predictions.end_prediction(state.client,
      broadcaster_id: state.channel_id,
      id: state.active_prediction,
      status: "RESOLVED",
      winning_outcome_id: winning["id"]
    )
  end
end

# Usage
{:ok, client} = Twitchy.authenticate(client, :user_access, code: code)
{:ok, user} = Twitchy.Users.get_user(client, id: client.user_id)

MyApp.PredictionBot.start_link(client: client, channel_id: user["id"])

# Create prediction
MyApp.PredictionBot.create_prediction(
  "Will we win this match?",
  ["Yes", "No"],
  300
)

# Resolve later
MyApp.PredictionBot.resolve_prediction("Yes")
```

### Poll Manager

Interactive poll system with analytics.

```elixir
defmodule MyApp.PollManager do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    client = opts[:client]
    channel_id = opts[:channel_id]

    # Subscribe to poll events
    {:ok, _} = Twitchy.EventSub.Declarative.start_link(
      client: client,
      handler: __MODULE__,
      subscriptions: [
        %{
          type: "channel.poll.begin",
          condition: %{"broadcaster_user_id" => channel_id}
        },
        %{
          type: "channel.poll.progress",
          condition: %{"broadcaster_user_id" => channel_id}
        },
        %{
          type: "channel.poll.end",
          condition: %{"broadcaster_user_id" => channel_id}
        }
      ]
    )

    {:ok, %{
      client: client,
      channel_id: channel_id,
      poll_history: []
    }}
  end

  def handle_event("channel.poll.begin", event, _meta) do
    IO.puts("📊 Poll started: #{event["title"]}")
    IO.puts("Duration: #{event["duration"]}s")

    Enum.with_index(event["choices"], 1) |> Enum.each(fn {choice, index} ->
      IO.puts("  #{index}. #{choice["title"]}")
    end)

    :ok
  end

  def handle_event("channel.poll.progress", event, _meta) do
    total_votes = Enum.reduce(event["choices"], 0, &(&2 + &1["votes"]))

    IO.puts("\n📊 Poll update:")
    Enum.each(event["choices"], fn choice ->
      percentage = if total_votes > 0 do
        (choice["votes"] / total_votes * 100) |> Float.round(1)
      else
        0
      end

      bar = String.duplicate("█", round(percentage / 5))
      IO.puts("  #{choice["title"]}: #{choice["votes"]} (#{percentage}%) #{bar}")
    end)

    :ok
  end

  def handle_event("channel.poll.end", event, _meta) do
    winner = Enum.max_by(event["choices"], & &1["votes"])

    IO.puts("\n✅ Poll ended: #{event["title"]}")
    IO.puts("Winner: #{winner["title"]} with #{winner["votes"]} votes")

    # Save to history
    result = %{
      timestamp: DateTime.utc_now(),
      title: event["title"],
      winner: winner["title"],
      total_votes: Enum.reduce(event["choices"], 0, &(&2 + &1["votes"])),
      choices: event["choices"]
    }

    GenServer.cast(__MODULE__, {:add_to_history, result})
    :ok
  end

  def handle_cast({:add_to_history, result}, state) do
    new_history = [result | Enum.take(state.poll_history, 99)]
    {:noreply, %{state | poll_history: new_history}}
  end

  # Public API
  def create_poll(title, choices, opts \\ []) do
    state = :sys.get_state(__MODULE__)

    duration = Keyword.get(opts, :duration, 300)
    points_voting = Keyword.get(opts, :points_voting, false)
    points_per_vote = Keyword.get(opts, :points_per_vote, 0)

    choice_list = Enum.map(choices, &%{title: &1})

    Twitchy.Polls.create_poll(state.client,
      broadcaster_id: state.channel_id,
      title: title,
      choices: choice_list,
      duration: duration,
      channel_points_voting_enabled: points_voting,
      channel_points_per_vote: points_per_vote
    )
  end

  def get_history do
    state = :sys.get_state(__MODULE__)
    state.poll_history
  end
end

# Usage
MyApp.PollManager.create_poll(
  "What should we do next?",
  ["Ranked", "Normals", "ARAM", "Custom Game"],
  duration: 180,
  points_voting: true,
  points_per_vote: 50
)
```

### Hype Train Monitor

Track and celebrate Hype Train events.

```elixir
defmodule MyApp.HypeTrainMonitor do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    client = opts[:client]
    channel_id = opts[:channel_id]

    # Subscribe to Hype Train events
    {:ok, _} = Twitchy.EventSub.Declarative.start_link(
      client: client,
      handler: __MODULE__,
      subscriptions: [
        %{
          type: "channel.hype_train.begin",
          condition: %{"broadcaster_user_id" => channel_id}
        },
        %{
          type: "channel.hype_train.progress",
          condition: %{"broadcaster_user_id" => channel_id}
        },
        %{
          type: "channel.hype_train.end",
          condition: %{"broadcaster_user_id" => channel_id}
        }
      ]
    )

    {:ok, %{
      client: client,
      channel_id: channel_id,
      current_hype_train: nil
    }}
  end

  def handle_event("channel.hype_train.begin", event, _meta) do
    IO.puts("🚂 HYPE TRAIN STARTING!")
    IO.puts("Level: #{event["level"]}")
    IO.puts("Goal: #{event["goal"]}")

    send_celebration("Hype Train starting! All aboard! 🚂🚂🚂")

    GenServer.cast(__MODULE__, {:set_hype_train, event})
    :ok
  end

  def handle_event("channel.hype_train.progress", event, _meta) do
    progress_pct = (event["progress"] / event["goal"] * 100) |> round()

    IO.puts("🚂 Hype Train Level #{event["level"]}: #{event["progress"]}/#{event["goal"]} (#{progress_pct}%)")

    # Show top contributors
    IO.puts("Top Contributors:")
    Enum.take(event["top_contributions"], 3) |> Enum.each(fn contrib ->
      IO.puts("  #{contrib["user"]}: #{contrib["total"]}")
    end)

    # Level up celebration
    state = :sys.get_state(__MODULE__)
    if state.current_hype_train && event["level"] > state.current_hype_train["level"] do
      send_celebration("🎉 LEVEL #{event["level"]}! Keep it going!")
    end

    GenServer.cast(__MODULE__, {:set_hype_train, event})
    :ok
  end

  def handle_event("channel.hype_train.end", event, _meta) do
    IO.puts("🏁 Hype Train Complete!")
    IO.puts("Final Level: #{event["level"]}")
    IO.puts("Total: #{event["total"]}")

    send_celebration("Hype Train complete at Level #{event["level"]}! Thanks everyone! 🎉")

    # Show final leaderboard
    IO.puts("\nFinal Leaderboard:")
    Enum.with_index(event["top_contributions"], 1) |> Enum.each(fn {contrib, rank} ->
      medal = case rank do
        1 -> "🥇"
        2 -> "🥈"
        3 -> "🥉"
        _ -> "  "
      end

      IO.puts("#{medal} #{rank}. #{contrib["user"]}: #{contrib["total"]}")
    end)

    GenServer.cast(__MODULE__, {:set_hype_train, nil})
    :ok
  end

  def handle_cast({:set_hype_train, event}, state) do
    {:noreply, %{state | current_hype_train: event}}
  end

  defp send_celebration(message) do
    IO.puts(message)

    state = :sys.get_state(__MODULE__)

    # Send to chat
    Twitchy.Chat.send_chat_message(state.client,
      broadcaster_id: state.channel_id,
      sender_id: state.channel_id,
      message: message
    )

    # Send to overlay
    MyApp.OverlayServer.send_alert(message)
  end
end
```

## Tutorial

### Building an Interactive Stream Events Announcer

This walkthrough builds a small script that turns a match into an interactive
segment for chat: it opens a Channel Points Prediction on whether the
broadcaster wins, resolves that Prediction once the match is over, hands off
to a Poll so chat decides what happens next, and checks in on the Hype Train
while all of that is happening. Each step below adds one function; the final
module puts them all together into something you can copy into a project and
call from `iex`.

Everything here needs a **user access token** for the broadcaster, authorized
with:

- `channel:manage:predictions` — create and resolve Predictions
- `channel:manage:polls` — create and end Polls
- `channel:read:hype_train` — read Hype Train status

See [TUTORIAL.md](../../TUTORIAL.md#step-2-get-a-user-access-token-for-the-broadcaster)
for how to walk through the OAuth flow and get that token; the rest of this
guide assumes you already have an authenticated `client` and the
broadcaster's `broadcaster_id`.

### Step 1: Start the Prediction

Kick things off by asking viewers to call the outcome. `create_prediction/2`
returns the created Prediction, including its `"outcomes"` — hang onto that
list, since each outcome's `"id"` is what you'll need later to resolve it:

```elixir
{:ok, %{"data" => [prediction | _]}} =
  Twitchy.Predictions.create_prediction(client,
    broadcaster_id: broadcaster_id,
    title: "Will I win this match?",
    outcomes: [
      %{title: "Yes"},
      %{title: "No"}
    ],
    prediction_window: 300
  )

IO.puts("🎲 Prediction live: #{prediction["title"]}")
```

### Step 2: Resolve the Prediction

Once the match ends, find the outcome that matches what actually happened and
resolve the Prediction with `end_prediction/2`. Passing `status: "RESOLVED"`
pays out everyone who backed the winning outcome; if the match got called off
entirely, `status: "CANCELED"` refunds everyone instead:

```elixir
winning_outcome = Enum.find(prediction["outcomes"], &(&1["title"] == "Yes"))

{:ok, _response} =
  Twitchy.Predictions.end_prediction(client,
    broadcaster_id: broadcaster_id,
    id: prediction["id"],
    status: "RESOLVED",
    winning_outcome_id: winning_outcome["id"]
  )

IO.puts("✅ Prediction resolved: #{winning_outcome["title"]} won!")
```

If the script restarted between Step 1 and Step 2 and you no longer have
`prediction` in hand, `get_predictions/2` looks it up by ID:

```elixir
{:ok, %{"data" => [prediction | _]}} =
  Twitchy.Predictions.get_predictions(client,
    broadcaster_id: broadcaster_id,
    id: prediction_id
  )
```

### Step 3: Ask Chat What's Next

With the Prediction settled, open a Poll so chat decides the next move.
`create_poll/2` takes the same `choices`/`title` shape as `outcomes` above —
a list of maps with a `:title` key — plus a `:duration` and, optionally,
Channel Points voting:

```elixir
{:ok, %{"data" => [poll | _]}} =
  Twitchy.Polls.create_poll(client,
    broadcaster_id: broadcaster_id,
    title: "What should I do next?",
    choices: [
      %{title: "Run it back"},
      %{title: "Try a different game"},
      %{title: "Take a break"}
    ],
    duration: 120,
    channel_points_voting_enabled: true,
    channel_points_per_vote: 50
  )

IO.puts("📊 Poll live: #{poll["title"]}")
```

### Step 4: End the Poll and Announce the Winner

Let the poll run for its `duration`, or cut it short with `end_poll/2` once
chat has clearly made up its mind. Either way, the response's `"choices"`
list carries each option's final `"votes"` count:

```elixir
{:ok, %{"data" => [ended_poll | _]}} =
  Twitchy.Polls.end_poll(client,
    broadcaster_id: broadcaster_id,
    id: poll["id"],
    status: "TERMINATED"
  )

winner = Enum.max_by(ended_poll["choices"], & &1["votes"])
IO.puts("🏆 Chat picked: #{winner["title"]} (#{winner["votes"]} votes)")
```

### Step 5: Watch the Hype Train

While the Prediction and Poll are running, viewers might also kick off a Hype
Train. `get_hype_train_events/2` with `first: 1` gets just the most recent
event, which is enough to track whether a train is currently active and what
level it's at:

```elixir
{:ok, %{"data" => data}} =
  Twitchy.HypeTrain.get_hype_train_events(client, broadcaster_id: broadcaster_id, first: 1)

case data do
  [event | _] ->
    IO.puts("🚂 Hype Train Level #{event["level"]}: #{event["progress"]}/#{event["goal"]}")

  [] ->
    IO.puts("No active Hype Train.")
end
```

Checking that periodically — every 15-30 seconds while your stream events are
running — is enough to announce each level-up as it happens; the complete
example below wraps this in a small recursive loop. If you instead need the
full history of past Hype Trains rather than just the latest one,
`stream_events/2` pages through all of them lazily:

```elixir
events =
  client
  |> Twitchy.HypeTrain.stream_events(broadcaster_id: broadcaster_id)
  |> Enum.to_list()
```

### The Complete Example

Everything above, assembled into one module. Drop this into
`lib/my_app/events_announcer.ex` in a project with `:twitchy` as a
dependency, then drive it a few functions at a time from `iex -S mix`.

```elixir
defmodule MyApp.EventsAnnouncer do
  @moduledoc """
  Runs a Channel Points Prediction, follows it with a chat Poll, and
  periodically reports Hype Train progress — a minimal "interactive stream
  events" script built on `Twitchy.Predictions`, `Twitchy.Polls`, and
  `Twitchy.HypeTrain`.
  """

  require Logger

  @doc """
  Starts a Prediction asking whether the broadcaster will win. Returns
  `{:ok, prediction}`, including `"outcomes"` so you can resolve it later.
  """
  def start_win_prediction(client, broadcaster_id) do
    case Twitchy.Predictions.create_prediction(client,
           broadcaster_id: broadcaster_id,
           title: "Will I win this match?",
           outcomes: [%{title: "Yes"}, %{title: "No"}],
           prediction_window: 300
         ) do
      {:ok, %{"data" => [prediction | _]}} ->
        IO.puts("🎲 Prediction live: #{prediction["title"]}")
        {:ok, prediction}

      {:error, error} ->
        Logger.error("Failed to start prediction: #{Exception.message(error)}")
        {:error, error}
    end
  end

  @doc """
  Resolves a Prediction. `outcomes` is the list from the prediction returned
  by `start_win_prediction/2`; `winning_title` picks which one paid out.
  """
  def resolve_prediction(client, broadcaster_id, prediction_id, outcomes, winning_title) do
    case Enum.find(outcomes, &(&1["title"] == winning_title)) do
      %{"id" => winning_outcome_id} ->
        case Twitchy.Predictions.end_prediction(client,
               broadcaster_id: broadcaster_id,
               id: prediction_id,
               status: "RESOLVED",
               winning_outcome_id: winning_outcome_id
             ) do
          {:ok, _response} ->
            IO.puts("✅ Prediction resolved: #{winning_title} won!")
            :ok

          {:error, error} ->
            Logger.error("Failed to resolve prediction: #{Exception.message(error)}")
            {:error, error}
        end

      nil ->
        {:error, :outcome_not_found}
    end
  end

  @doc """
  Launches the "what happens next" Poll for chat to vote on.
  """
  def start_next_poll(client, broadcaster_id) do
    case Twitchy.Polls.create_poll(client,
           broadcaster_id: broadcaster_id,
           title: "What should I do next?",
           choices: [
             %{title: "Run it back"},
             %{title: "Try a different game"},
             %{title: "Take a break"}
           ],
           duration: 120,
           channel_points_voting_enabled: true,
           channel_points_per_vote: 50
         ) do
      {:ok, %{"data" => [poll | _]}} ->
        IO.puts("📊 Poll live: #{poll["title"]}")
        {:ok, poll}

      {:error, error} ->
        Logger.error("Failed to start poll: #{Exception.message(error)}")
        {:error, error}
    end
  end

  @doc """
  Terminates the poll early and reports the winning choice.
  """
  def end_poll_and_announce(client, broadcaster_id, poll_id) do
    case Twitchy.Polls.end_poll(client,
           broadcaster_id: broadcaster_id,
           id: poll_id,
           status: "TERMINATED"
         ) do
      {:ok, %{"data" => [poll | _]}} ->
        winner = Enum.max_by(poll["choices"], & &1["votes"])
        IO.puts("🏆 Chat picked: #{winner["title"]} (#{winner["votes"]} votes)")
        {:ok, winner}

      {:error, error} ->
        Logger.error("Failed to end poll: #{Exception.message(error)}")
        {:error, error}
    end
  end

  @doc """
  Polls `get_hype_train_events/2` every `interval_ms` and prints progress
  whenever the level changes, stopping once no Hype Train is active. Run
  this inside a `Task` so it doesn't block the rest of your script.
  """
  def watch_hype_train(client, broadcaster_id, interval_ms \\ 15_000, last_level \\ nil) do
    case Twitchy.HypeTrain.get_hype_train_events(client,
           broadcaster_id: broadcaster_id,
           first: 1
         ) do
      {:ok, %{"data" => [event | _]}} ->
        if event["level"] != last_level do
          IO.puts("🚂 Hype Train Level #{event["level"]}: #{event["progress"]}/#{event["goal"]}")
        end

        Process.sleep(interval_ms)
        watch_hype_train(client, broadcaster_id, interval_ms, event["level"])

      {:ok, %{"data" => []}} ->
        IO.puts("No active Hype Train.")
        :ok

      {:error, error} ->
        Logger.error("Failed to check Hype Train: #{Exception.message(error)}")
        {:error, error}
    end
  end
end
```

Wire it together from `iex -S mix`:

```elixir
{:ok, task} = Task.start_link(fn -> MyApp.EventsAnnouncer.watch_hype_train(client, broadcaster_id) end)

{:ok, prediction} = MyApp.EventsAnnouncer.start_win_prediction(client, broadcaster_id)

# ... match happens ...
:ok = MyApp.EventsAnnouncer.resolve_prediction(client, broadcaster_id, prediction["id"], prediction["outcomes"], "Yes")

{:ok, poll} = MyApp.EventsAnnouncer.start_next_poll(client, broadcaster_id)

# ... let chat vote for a bit ...
{:ok, _winner} = MyApp.EventsAnnouncer.end_poll_and_announce(client, broadcaster_id, poll["id"])

Task.shutdown(task)
```

## Best Practices

1. **Auto-close predictions** - Set reasonable time windows
2. **Clear poll options** - Make choices unambiguous
3. **Monitor Hype Trains** - Celebrate milestones
4. **Track outcomes** - Analyze what predictions/polls work best
5. **Handle cancellations gracefully** - Refund points when appropriate
6. **Set cooldowns** - Don't spam predictions/polls
7. **Engage with results** - Discuss outcomes with chat

## See Also

- [Subscriptions & Channel Points API](SUBSCRIPTIONS_CHANNELPOINTS.md)
- [Chat & Moderation API](CHAT_MODERATION.md)
- [EventSub Examples](../../EVENTSUB_EXAMPLES.md)
- [Usage Guide](../../USAGE_GUIDE.md)
