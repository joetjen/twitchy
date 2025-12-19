defmodule Twitchy.ChannelPoints do
  @moduledoc """
  Twitch Channel Points API endpoints.

  Provides functions for managing custom rewards and redemptions.

  ## Examples

      # Create custom reward
      {:ok, response} = Twitchy.ChannelPoints.create_custom_reward(client,
        broadcaster_id: "12345",
        title: "Hydrate!",
        cost: 100
      )

      # Get custom rewards
      {:ok, response} = Twitchy.ChannelPoints.get_custom_rewards(client, broadcaster_id: "12345")

      # Update redemption status
      :ok = Twitchy.ChannelPoints.update_redemption_status(client,
        broadcaster_id: "12345",
        reward_id: "reward-id",
        id: ["redemption-id"],
        status: "FULFILLED"
      )
  """

  alias Twitchy.{HTTP, Pagination}

  @doc """
  Creates a custom Channel Points reward.

  Requires the `channel:manage:redemptions` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:title` - Reward title (required, max 45 characters)
  - `:cost` - Channel Points cost (required, min 1)
  - `:prompt` - Description (max 200 characters)
  - `:is_enabled` - Is reward enabled (default true)
  - `:background_color` - Hex color code
  - `:is_user_input_required` - Requires user input
  - `:is_max_per_stream_enabled` - Limit redemptions per stream
  - `:max_per_stream` - Max redemptions per stream
  - `:is_max_per_user_per_stream_enabled` - Limit per user per stream
  - `:max_per_user_per_stream` - Max per user per stream
  - `:is_global_cooldown_enabled` - Enable global cooldown
  - `:global_cooldown_seconds` - Cooldown in seconds
  - `:should_redemptions_skip_request_queue` - Auto-fulfill

  ## Examples

      {:ok, response} = Twitchy.ChannelPoints.create_custom_reward(client,
        broadcaster_id: "12345",
        title: "Hydrate!",
        cost: 100,
        prompt: "Drink some water!",
        is_global_cooldown_enabled: true,
        global_cooldown_seconds: 300
      )
  """
  @spec create_custom_reward(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def create_custom_reward(client, params) do
    {broadcaster_id, params} = Keyword.pop!(params, :broadcaster_id)
    query = [broadcaster_id: broadcaster_id]
    body = Map.new(params)

    HTTP.post(client, "/channel_points/custom_rewards", query: query, json: body)
  end

  @doc """
  Gets custom Channel Points rewards.

  Requires the `channel:read:redemptions` or `channel:manage:redemptions` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:id` - Filter by reward ID(s) (max 50)
  - `:only_manageable_rewards` - Only rewards broadcaster can manage

  ## Examples

      {:ok, response} = Twitchy.ChannelPoints.get_custom_rewards(client,
        broadcaster_id: "12345"
      )
  """
  @spec get_custom_rewards(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_custom_rewards(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/channel_points/custom_rewards", query: query)
  end

  @doc """
  Updates a custom Channel Points reward.

  Requires the `channel:manage:redemptions` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:id` - Reward ID (required)
  - Plus any fields from create_custom_reward/2

  ## Examples

      {:ok, response} = Twitchy.ChannelPoints.update_custom_reward(client,
        broadcaster_id: "12345",
        id: "reward-id",
        cost: 200,
        is_paused: true
      )
  """
  @spec update_custom_reward(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def update_custom_reward(client, params) do
    {broadcaster_id, params} = Keyword.pop!(params, :broadcaster_id)
    {reward_id, params} = Keyword.pop!(params, :id)

    query = [broadcaster_id: broadcaster_id, id: reward_id]
    body = Map.new(params)

    HTTP.patch(client, "/channel_points/custom_rewards", query: query, json: body)
  end

  @doc """
  Deletes a custom Channel Points reward.

  Requires the `channel:manage:redemptions` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:id` - Reward ID (required)

  ## Examples

      :ok = Twitchy.ChannelPoints.delete_custom_reward(client,
        broadcaster_id: "12345",
        id: "reward-id"
      )
  """
  @spec delete_custom_reward(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def delete_custom_reward(client, params) do
    query = HTTP.build_query(params)

    case HTTP.delete(client, "/channel_points/custom_rewards", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Gets custom reward redemptions.

  Requires the `channel:read:redemptions` or `channel:manage:redemptions` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:reward_id` - Reward ID (required)
  - `:id` - Filter by redemption ID(s) (max 50)
  - `:status` - Filter by status (`:UNFULFILLED`, `:FULFILLED`, `:CANCELED`)
  - `:sort` - Sort order (`:OLDEST`, `:NEWEST`)
  - `:first` - Number of results per page (max 50, default 20)
  - `:after` - Cursor for pagination

  ## Examples

      {:ok, response} = Twitchy.ChannelPoints.get_custom_reward_redemptions(client,
        broadcaster_id: "12345",
        reward_id: "reward-id",
        status: :UNFULFILLED
      )
  """
  @spec get_custom_reward_redemptions(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_custom_reward_redemptions(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/channel_points/custom_rewards/redemptions", query: query)
  end

  @doc """
  Updates the status of custom reward redemptions.

  Requires the `channel:manage:redemptions` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:reward_id` - Reward ID (required)
  - `:id` - Redemption ID(s) (max 50, required)
  - `:status` - New status (`:FULFILLED` or `:CANCELED`, required)

  ## Examples

      :ok = Twitchy.ChannelPoints.update_redemption_status(client,
        broadcaster_id: "12345",
        reward_id: "reward-id",
        id: ["redemption-id-1", "redemption-id-2"],
        status: "FULFILLED"
      )
  """
  @spec update_redemption_status(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def update_redemption_status(client, params) do
    {broadcaster_id, params} = Keyword.pop!(params, :broadcaster_id)
    {reward_id, params} = Keyword.pop!(params, :reward_id)
    {redemption_ids, params} = Keyword.pop!(params, :id)

    query = [broadcaster_id: broadcaster_id, reward_id: reward_id, id: redemption_ids]
    body = Map.new(params)

    case HTTP.patch(client, "/channel_points/custom_rewards/redemptions", query: query, json: body) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Streams custom reward redemptions lazily.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:reward_id` - Reward ID (required)
  - `:status` - Filter by status
  - `:sort` - Sort order
  - `:first` - Number of results per page (max 50, default 50)

  ## Examples

      redemptions = client
                    |> Twitchy.ChannelPoints.stream_redemptions(
                      broadcaster_id: "12345",
                      reward_id: "reward-id",
                      status: :UNFULFILLED
                    )
                    |> Enum.to_list()
  """
  @spec stream_redemptions(Twitchy.t(), keyword()) :: Enumerable.t()
  def stream_redemptions(client, params) do
    fetch_fn = fn cursor ->
      params = Pagination.add_to_query(params, after: cursor, first: params[:first] || 50)

      case get_custom_reward_redemptions(client, params) do
        {:ok, response} ->
          {:ok, response["data"], Pagination.get_cursor(response)}

        error ->
          error
      end
    end

    Pagination.stream(fetch_fn)
  end
end
