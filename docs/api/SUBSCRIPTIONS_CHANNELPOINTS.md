# Subscriptions & Channel Points API

Documentation for Twitch Subscriptions and Channel Points APIs.

## Subscriptions API

### Get Broadcaster Subscriptions

Get list of subscribers to a channel (requires `channel:read:subscriptions` scope).

```elixir
{:ok, response} = Twitchy.Subscriptions.get_broadcaster_subscriptions(client,
  broadcaster_id: "123456",
  first: 100
)

IO.puts("Total subscribers: #{response["total"]}")
IO.puts("Points: #{response["points"]}")  # Subscriber points

Enum.each(response["data"], fn sub ->
  IO.puts("#{sub["user_name"]} - Tier #{sub["tier"]}")
  IO.puts("  Gifter: #{sub["gifter_name"] || "Not gifted"}")
end)
```

### Check User Subscription

Check if specific users are subscribed.

```elixir
{:ok, response} = Twitchy.Subscriptions.check_user_subscription(client,
  broadcaster_id: "123456",
  user_id: "789"
)

case response["data"] do
  [sub | _] ->
    IO.puts("User is subscribed!")
    IO.puts("Tier: #{sub["tier"]}")
    IO.puts("Gifted: #{sub["is_gift"]}")

  [] ->
    IO.puts("User is not subscribed")
end
```

## Channel Points API

### Create Custom Reward

Create a Channel Points reward (requires `channel:manage:redemptions` scope).

```elixir
{:ok, response} = Twitchy.ChannelPoints.create_custom_reward(client,
  broadcaster_id: "123456",
  title: "Hydration Reminder",
  cost: 1000,
  prompt: "Remind the streamer to drink water!",
  is_enabled: true,
  background_color: "#00FF00",
  is_user_input_required: false,
  is_max_per_stream_enabled: true,
  max_per_stream: 10,
  is_global_cooldown_enabled: true,
  global_cooldown_seconds: 300  # 5 minutes
)

reward = List.first(response["data"])
IO.puts("Created reward: #{reward["title"]} (#{reward["id"]})")
```

### Update Custom Reward

Update an existing reward.

```elixir
{:ok, response} = Twitchy.ChannelPoints.update_custom_reward(client,
  broadcaster_id: "123456",
  id: "reward_id",
  title: "Updated Hydration Reminder",
  cost: 500,
  is_enabled: true
)
```

### Delete Custom Reward

Remove a Channel Points reward.

```elixir
:ok = Twitchy.ChannelPoints.delete_custom_reward(client,
  broadcaster_id: "123456",
  id: "reward_id"
)
```

### Get Custom Rewards

List all Channel Points rewards for a channel.

```elixir
{:ok, response} = Twitchy.ChannelPoints.get_custom_rewards(client,
  broadcaster_id: "123456",
  only_manageable_rewards: true
)

Enum.each(response["data"], fn reward ->
  IO.puts("#{reward["title"]} - #{reward["cost"]} points")
  IO.puts("  Status: #{if reward["is_enabled"], do: "✅ Enabled", else: "❌ Disabled"}")
  IO.puts("  Redeemed: #{reward["redemptions_redeemed_current_stream"] || 0} times this stream")
end)
```

### Get Custom Reward Redemptions

Get redemption history for a reward.

```elixir
{:ok, response} = Twitchy.ChannelPoints.get_custom_reward_redemptions(client,
  broadcaster_id: "123456",
  reward_id: "reward_id",
  status: "UNFULFILLED",
  first: 50
)

Enum.each(response["data"], fn redemption ->
  IO.puts("#{redemption["user_name"]} redeemed #{redemption["reward"]["title"]}")
  IO.puts("  Status: #{redemption["status"]}")
  IO.puts("  User input: #{redemption["user_input"]}")
  IO.puts("  Redeemed at: #{redemption["redeemed_at"]}")
end)
```

### Update Redemption Status

Mark redemptions as fulfilled or canceled.

```elixir
# Fulfill redemption
:ok = Twitchy.ChannelPoints.update_redemption_status(client,
  broadcaster_id: "123456",
  reward_id: "reward_id",
  id: ["redemption_id_1", "redemption_id_2"],
  status: "FULFILLED"
)

# Cancel redemption (refunds points)
:ok = Twitchy.ChannelPoints.update_redemption_status(client,
  broadcaster_id: "123456",
  reward_id: "reward_id",
  id: ["redemption_id_3"],
  status: "CANCELED"
)
```

## Examples

### Subscriber Alert System

Notify about new subscribers in real-time.

```elixir
defmodule MyApp.SubAlerts do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    client = opts[:client]
    channel_id = opts[:channel_id]

    # Subscribe to subscription events
    {:ok, _} = Twitchy.EventSub.Declarative.start_link(
      client: client,
      handler: __MODULE__,
      subscriptions: [
        %{
          type: "channel.subscribe",
          condition: %{"broadcaster_user_id" => channel_id}
        },
        %{
          type: "channel.subscription.gift",
          condition: %{"broadcaster_user_id" => channel_id}
        },
        %{
          type: "channel.subscription.message",
          condition: %{"broadcaster_user_id" => channel_id}
        }
      ]
    )

    {:ok, %{client: client, channel_id: channel_id}}
  end

  # New subscriber
  def handle_event("channel.subscribe", event, _meta) do
    user = event["user_name"]
    tier = event["tier"]
    is_gift = event["is_gift"]

    message = if is_gift do
      "🎁 #{user} received a gifted Tier #{parse_tier(tier)} sub!"
    else
      "⭐ #{user} just subscribed at Tier #{parse_tier(tier)}!"
    end

    send_alert(message)
    :ok
  end

  # Subscription gift
  def handle_event("channel.subscription.gift", event, _meta) do
    gifter = event["user_name"]
    total = event["total"]
    tier = event["tier"]

    message = "🎁🎁 #{gifter} just gifted #{total} Tier #{parse_tier(tier)} subs!"

    send_alert(message)
    :ok
  end

  # Re-sub with message
  def handle_event("channel.subscription.message", event, _meta) do
    user = event["user_name"]
    months = event["cumulative_months"]
    tier = event["tier"]
    message = event["message"]["text"]

    alert = "💎 #{user} re-subscribed for #{months} months at Tier #{parse_tier(tier)}!"

    if message && String.length(message) > 0 do
      alert = alert <> "\n  Message: \"#{message}\""
    end

    send_alert(alert)
    :ok
  end

  defp parse_tier("1000"), do: "1"
  defp parse_tier("2000"), do: "2"
  defp parse_tier("3000"), do: "3"
  defp parse_tier(_), do: "?"

  defp send_alert(message) do
    IO.puts(message)

    # Send to overlay, Discord, etc.
    MyApp.OverlayServer.send_alert(message)
    MyApp.Discord.send_notification(message)
  end
end
```

### Channel Points Reward Manager

Automated reward management system.

```elixir
defmodule MyApp.RewardManager do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    client = opts[:client]
    channel_id = opts[:channel_id]

    # Create default rewards if they don't exist
    setup_default_rewards(client, channel_id)

    # Subscribe to redemption events
    {:ok, _} = Twitchy.EventSub.Declarative.start_link(
      client: client,
      handler: __MODULE__,
      subscriptions: [
        %{
          type: "channel.channel_points_custom_reward_redemption.add",
          condition: %{"broadcaster_user_id" => channel_id}
        }
      ]
    )

    {:ok, %{client: client, channel_id: channel_id, reward_handlers: build_handlers()}}
  end

  def handle_event("channel.channel_points_custom_reward_redemption.add", event, _meta) do
    reward_title = event["reward"]["title"]
    user_name = event["user_name"]
    user_input = event["user_input"]
    redemption_id = event["id"]
    reward_id = event["reward"]["id"]

    state = :sys.get_state(__MODULE__)

    # Handle redemption
    result = case Map.get(state.reward_handlers, reward_title) do
      nil ->
        {:error, :unknown_reward}

      handler ->
        handler.(user_name, user_input)
    end

    # Update redemption status
    status = case result do
      :ok -> "FULFILLED"
      {:ok, _} -> "FULFILLED"
      {:error, _} -> "CANCELED"
    end

    Twitchy.ChannelPoints.update_redemption_status(state.client,
      broadcaster_id: state.channel_id,
      reward_id: reward_id,
      id: [redemption_id],
      status: status
    )

    :ok
  end

  defp setup_default_rewards(client, channel_id) do
    rewards = [
      %{
        title: "Hydration Check",
        cost: 500,
        prompt: "Remind the streamer to drink water!",
        is_user_input_required: false
      },
      %{
        title: "Song Request",
        cost: 2000,
        prompt: "Request a song (please include song name and artist)",
        is_user_input_required: true,
        should_redemptions_skip_request_queue: false
      },
      %{
        title: "Highlight Moment",
        cost: 5000,
        prompt: "Create a clip of the last 30 seconds",
        is_user_input_required: false,
        is_max_per_stream_enabled: true,
        max_per_stream: 10
      }
    ]

    Enum.each(rewards, fn reward_params ->
      case Twitchy.ChannelPoints.create_custom_reward(client,
        [broadcaster_id: channel_id] ++ Map.to_list(reward_params)
      ) do
        {:ok, _} -> IO.puts("Created reward: #{reward_params.title}")
        {:error, _} -> :ok  # Reward might already exist
      end
    end)
  end

  defp build_handlers do
    %{
      "Hydration Check" => fn user, _input ->
        send_chat_message("💧 Hydration check! Thanks #{user}!")
        :ok
      end,

      "Song Request" => fn user, song ->
        if song && String.length(song) > 0 do
          MyApp.MusicQueue.add_song(song, requested_by: user)
          send_chat_message("🎵 Added \"#{song}\" to the queue! Requested by #{user}")
          :ok
        else
          {:error, :no_song_specified}
        end
      end,

      "Highlight Moment" => fn user, _input ->
        state = :sys.get_state(__MODULE__)

        case Twitchy.Clips.create_clip(state.client,
          broadcaster_id: state.channel_id
        ) do
          {:ok, response} ->
            clip = List.first(response["data"])
            send_chat_message("🎬 Clip created! Thanks #{user}! Edit: #{clip["edit_url"]}")
            :ok

          {:error, _} ->
            {:error, :clip_creation_failed}
        end
      end
    }
  end

  defp send_chat_message(message) do
    state = :sys.get_state(__MODULE__)

    Twitchy.Chat.send_chat_message(state.client,
      broadcaster_id: state.channel_id,
      sender_id: state.channel_id,
      message: message
    )
  end
end
```

### Subscription Analytics

Track subscription metrics and trends.

```elixir
defmodule MyApp.SubAnalytics do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    client = opts[:client]
    channel_id = opts[:channel_id]

    schedule_update()

    {:ok, %{
      client: client,
      channel_id: channel_id,
      history: []
    }}
  end

  def handle_info(:update_stats, state) do
    {:ok, response} = Twitchy.Subscriptions.get_broadcaster_subscriptions(state.client,
      broadcaster_id: state.channel_id,
      first: 1  # We only need the total
    )

    snapshot = %{
      timestamp: DateTime.utc_now(),
      total_subs: response["total"],
      points: response["points"]
    }

    # Count subs by tier
    {:ok, all_subs} = get_all_subscriptions(state.client, state.channel_id)

    tier_counts = all_subs
      |> Enum.group_by(& &1["tier"])
      |> Enum.map(fn {tier, subs} -> {tier, length(subs)} end)
      |> Map.new()

    snapshot = Map.put(snapshot, :tier_breakdown, tier_counts)

    # Track gifted vs organic
    gifted = Enum.count(all_subs, & &1["is_gift"])
    organic = length(all_subs) - gifted

    snapshot = snapshot
      |> Map.put(:gifted_count, gifted)
      |> Map.put(:organic_count, organic)

    new_history = [snapshot | Enum.take(state.history, 719)]  # Keep 30 days (hourly)

    # Generate report
    if length(new_history) >= 24 do
      generate_report(new_history)
    end

    schedule_update()
    {:noreply, %{state | history: new_history}}
  end

  defp get_all_subscriptions(client, channel_id) do
    get_all_subscriptions(client, channel_id, nil, [])
  end

  defp get_all_subscriptions(client, channel_id, cursor, acc) do
    params = [broadcaster_id: channel_id, first: 100]
    params = if cursor, do: Keyword.put(params, :after, cursor), else: params

    {:ok, response} = Twitchy.Subscriptions.get_broadcaster_subscriptions(client, params)

    new_acc = acc ++ response["data"]

    case response["pagination"]["cursor"] do
      nil -> {:ok, new_acc}
      next_cursor -> get_all_subscriptions(client, channel_id, next_cursor, new_acc)
    end
  end

  defp generate_report(history) do
    latest = List.first(history)
    day_ago = Enum.at(history, 23)

    sub_change = latest.total_subs - day_ago.total_subs
    percent = (sub_change / day_ago.total_subs * 100) |> Float.round(1)

    IO.puts("\n=== Subscription Analytics ===")
    IO.puts("Current subscribers: #{latest.total_subs}")
    IO.puts("Change (24h): #{sub_change} (#{percent}%)")
    IO.puts("Points: #{latest.points}")

    IO.puts("\nTier Breakdown:")
    Enum.each(latest.tier_breakdown, fn {tier, count} ->
      percentage = (count / latest.total_subs * 100) |> Float.round(1)
      IO.puts("  Tier #{parse_tier(tier)}: #{count} (#{percentage}%)")
    end)

    IO.puts("\nGifted vs Organic:")
    IO.puts("  Gifted: #{latest.gifted_count}")
    IO.puts("  Organic: #{latest.organic_count}")
  end

  defp parse_tier("1000"), do: "1"
  defp parse_tier("2000"), do: "2"
  defp parse_tier("3000"), do: "3"
  defp parse_tier(_), do: "?"

  defp schedule_update do
    # Update every hour
    Process.send_after(self(), :update_stats, 3_600_000)
  end
end
```

## Tutorial

### Build a Subscriber & Rewards Dashboard

Two chores tend to eat a broadcaster's time between streams: checking who's
subscribed (often to gate a sub-only giveaway) and clearing out a backlog of
channel points redemptions that piled up while nobody was watching the
queue. This tutorial builds a small **Subscriber & Rewards Dashboard** that
handles both: it pulls the current subscriber count and list via
`Twitchy.Subscriptions.get_broadcaster_subscriptions/2`, checks whether a
specific viewer is subscribed via
`Twitchy.Subscriptions.check_user_subscription/2`, and then clears a backlog
of unfulfilled redemptions in bulk with
`Twitchy.ChannelPoints.get_custom_reward_redemptions/2` (or
`Twitchy.ChannelPoints.stream_redemptions/2` for paging through a large
queue) followed by `Twitchy.ChannelPoints.update_redemption_status/2`.

**Prerequisites:** this tutorial needs a **user access token** for the
broadcaster, authorized with `channel:read:subscriptions` (subscriber
count/list), `user:read:subscriptions` (checking a single viewer),
`channel:read:redemptions` or `channel:manage:redemptions` (listing
redemptions), and `channel:manage:redemptions` (updating redemption status).
See
[TUTORIAL.md](../../TUTORIAL.md#step-2-get-a-user-access-token-for-the-broadcaster)
for how to obtain one.

### Step 1: Fetch the Subscriber Count and List

`get_broadcaster_subscriptions/2` returns up to one page of subscribers
(`:first`, max 100), but the response's `"total"` and `"points"` fields
always reflect the *whole* channel regardless of how many rows came back on
this page — so a single call is enough for a dashboard header:

```elixir
{:ok, response} =
  Twitchy.Subscriptions.get_broadcaster_subscriptions(client,
    broadcaster_id: broadcaster_id,
    first: 100
  )

IO.puts("Subscribers: #{response["total"]} (#{response["points"]} points)")

Enum.each(response["data"], fn sub ->
  IO.puts("  #{sub["user_name"]} - Tier #{sub["tier"]}")
end)
```

If the channel has more than 100 subscribers and the dashboard needs the
*full* list rather than just the total, page through it lazily with
`stream_subscriptions/2` instead:

```elixir
all_subs =
  client
  |> Twitchy.Subscriptions.stream_subscriptions(broadcaster_id: broadcaster_id)
  |> Enum.to_list()
```

### Step 2: Gate a Giveaway on Subscription Status

`check_user_subscription/2` takes a single `:user_id` (not a list) alongside
`:broadcaster_id`. When the viewer *is* subscribed, the response's `"data"`
holds one entry; when they aren't, Twitch's API responds with a 404, which
Twitchy normalizes into `%Twitchy.Error.APIError{status: 404}` rather than an
`{:ok, ...}` tuple — so that specific error is the "not eligible" case, and
every other error still needs to propagate:

```elixir
defp subscriber?(client, broadcaster_id, user_id) do
  case Twitchy.Subscriptions.check_user_subscription(client,
         broadcaster_id: broadcaster_id,
         user_id: user_id
       ) do
    {:ok, %{"data" => [_sub | _]}} ->
      true

    {:error, %Twitchy.Error.APIError{status: 404}} ->
      false

    {:error, error} ->
      raise error
  end
end
```

With that in place, gating a sub-only giveaway is a one-liner:

```elixir
if subscriber?(client, broadcaster_id, viewer_id) do
  IO.puts("You're in! Good luck.")
else
  IO.puts("Sorry, this giveaway is for subscribers only.")
end
```

### Step 3: List the Unfulfilled Redemption Backlog

`get_custom_reward_redemptions/2` requires both `:broadcaster_id` and
`:reward_id` — redemptions always belong to one specific reward — and
returns up to one page (`:first`, max 50):

```elixir
{:ok, response} =
  Twitchy.ChannelPoints.get_custom_reward_redemptions(client,
    broadcaster_id: broadcaster_id,
    reward_id: reward_id,
    status: :UNFULFILLED,
    first: 50
  )

redemptions = response["data"]
IO.puts("#{length(redemptions)} redemption(s) waiting")
```

A backlog that built up over days can easily be bigger than one page.
`stream_redemptions/2` takes the same filter params but lazily walks every
page, so `Enum.to_list/1` (or any other `Enum`/`Stream` call) pulls the
entire backlog without hand-written cursor tracking:

```elixir
backlog =
  client
  |> Twitchy.ChannelPoints.stream_redemptions(
    broadcaster_id: broadcaster_id,
    reward_id: reward_id,
    status: :UNFULFILLED
  )
  |> Enum.to_list()
```

### Step 4: Bulk-Fulfill Redemptions in Batches of 50

`update_redemption_status/2` accepts up to 50 redemption `:id`s per call and
returns plain `:ok` (not `{:ok, _}`) on success, so a backlog larger than 50
has to be chunked and fulfilled one batch at a time:

```elixir
defp fulfill_all(client, broadcaster_id, reward_id, redemptions) do
  redemptions
  |> Enum.map(& &1["id"])
  |> Enum.chunk_every(50)
  |> Enum.each(fn batch ->
    :ok =
      Twitchy.ChannelPoints.update_redemption_status(client,
        broadcaster_id: broadcaster_id,
        reward_id: reward_id,
        id: batch,
        status: "FULFILLED"
      )
  end)
end
```

`status: "CANCELED"` works the same way and automatically refunds the
viewer's points — useful when the backlog includes redemptions that can no
longer be honored (a song request for a stream that already ended, say).

### The Complete Example

Putting Steps 1-4 together as a small module a broadcaster (or a `mix run
-e` one-liner) can call between streams — print the dashboard, check one
viewer's eligibility, and clear the backlog for a given reward:

```elixir
defmodule MyApp.SubscriberRewardsDashboard do
  @moduledoc """
  Prints a subscriber summary, checks a single viewer's subscription
  status, and bulk-fulfills a channel points redemption backlog.
  """

  require Logger

  @doc """
  Prints the current subscriber count, point total, and roster.
  """
  @spec print_subscriber_summary(Twitchy.t(), String.t()) :: :ok
  def print_subscriber_summary(client, broadcaster_id) do
    case Twitchy.Subscriptions.get_broadcaster_subscriptions(client,
           broadcaster_id: broadcaster_id,
           first: 100
         ) do
      {:ok, response} ->
        IO.puts("Subscribers: #{response["total"]} (#{response["points"]} points)")

        Enum.each(response["data"], fn sub ->
          IO.puts("  #{sub["user_name"]} - Tier #{sub["tier"]}")
        end)

        :ok

      {:error, error} ->
        Logger.error("Failed to fetch subscriptions: #{Exception.message(error)}")
        :ok
    end
  end

  @doc """
  Returns `true` if `user_id` is currently subscribed to `broadcaster_id`.
  """
  @spec subscriber?(Twitchy.t(), String.t(), String.t()) :: boolean()
  def subscriber?(client, broadcaster_id, user_id) do
    case Twitchy.Subscriptions.check_user_subscription(client,
           broadcaster_id: broadcaster_id,
           user_id: user_id
         ) do
      {:ok, %{"data" => [_sub | _]}} ->
        true

      {:error, %Twitchy.Error.APIError{status: 404}} ->
        false

      {:error, error} ->
        Logger.warning("Subscription check failed: #{Exception.message(error)}")
        false
    end
  end

  @doc """
  Fetches every unfulfilled redemption for `reward_id` and marks it
  fulfilled, 50 at a time. Returns the number of redemptions processed.
  """
  @spec fulfill_redemption_backlog(Twitchy.t(), String.t(), String.t()) :: non_neg_integer()
  def fulfill_redemption_backlog(client, broadcaster_id, reward_id) do
    redemptions =
      client
      |> Twitchy.ChannelPoints.stream_redemptions(
        broadcaster_id: broadcaster_id,
        reward_id: reward_id,
        status: :UNFULFILLED
      )
      |> Enum.to_list()

    redemptions
    |> Enum.map(& &1["id"])
    |> Enum.chunk_every(50)
    |> Enum.each(fn batch -> fulfill_batch(client, broadcaster_id, reward_id, batch) end)

    IO.puts("Fulfilled #{length(redemptions)} redemption(s)")
    length(redemptions)
  end

  defp fulfill_batch(client, broadcaster_id, reward_id, batch) do
    case Twitchy.ChannelPoints.update_redemption_status(client,
           broadcaster_id: broadcaster_id,
           reward_id: reward_id,
           id: batch,
           status: "FULFILLED"
         ) do
      :ok ->
        :ok

      {:error, error} ->
        Logger.error("Failed to fulfill batch #{inspect(batch)}: #{Exception.message(error)}")
    end
  end
end

# Usage
{:ok, client} =
  Twitchy.new(client_id: "your_client_id", client_secret: "your_client_secret")
  |> Twitchy.authenticate(:user_access, code: "abcdef123456")

MyApp.SubscriberRewardsDashboard.print_subscriber_summary(client, "123456")

if MyApp.SubscriberRewardsDashboard.subscriber?(client, "123456", "789") do
  IO.puts("Viewer 789 is eligible for the giveaway")
end

MyApp.SubscriberRewardsDashboard.fulfill_redemption_backlog(client, "123456", "reward_id")
```

## Best Practices

1. **Cache subscriber list** - Don't query for each permission check
2. **Handle redemptions promptly** - Process within a reasonable time
3. **Validate user input** - Check song requests, messages, etc.
4. **Set appropriate cooldowns** - Prevent reward spam
5. **Refund when appropriate** - Use CANCELED status if you can't fulfill
6. **Monitor reward costs** - Adjust based on point economy
7. **Track redemption patterns** - Optimize rewards based on usage

## See Also

- [Chat & Moderation API](CHAT_MODERATION.md)
- [Predictions, Polls & Hype Train API](PREDICTIONS_POLLS_HYPETRAIN.md)
- [EventSub Examples](../../EVENTSUB_EXAMPLES.md)
- [Usage Guide](../../USAGE_GUIDE.md)
