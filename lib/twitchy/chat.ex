defmodule Twitchy.Chat do
  @moduledoc """
  Twitch Chat API endpoints.

  Provides functions for managing chat settings, emotes, badges, announcements, and shoutouts.

  ## Examples

      # Get chat settings
      {:ok, response} = Twitchy.Chat.get_chat_settings(client, broadcaster_id: "12345")

      # Update chat settings
      {:ok, response} = Twitchy.Chat.update_chat_settings(client,
        broadcaster_id: "12345",
        moderator_id: "67890",
        slow_mode: true,
        slow_mode_wait_time: 30
      )

      # Send chat announcement
      :ok = Twitchy.Chat.send_chat_announcement(client,
        broadcaster_id: "12345",
        moderator_id: "67890",
        message: "Stream starting in 5 minutes!"
      )
  """

  alias Twitchy.{HTTP, Pagination}

  @doc """
  Gets chat settings for a broadcaster's chat room.

  Requires the `moderator:read:chat_settings` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required if using user token)

  ## Examples

      {:ok, response} = Twitchy.Chat.get_chat_settings(client, broadcaster_id: "12345")
  """
  @spec get_chat_settings(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_chat_settings(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/chat/settings", query: query)
  end

  @doc """
  Updates chat settings.

  Requires the `moderator:manage:chat_settings` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required)
  - `:emote_mode` - Enable emote-only mode
  - `:follower_mode` - Enable follower-only mode
  - `:follower_mode_duration` - Minutes user must follow before chatting
  - `:non_moderator_chat_delay` - Non-moderator chat delay
  - `:non_moderator_chat_delay_duration` - Delay duration in seconds
  - `:slow_mode` - Enable slow mode
  - `:slow_mode_wait_time` - Seconds between messages
  - `:subscriber_mode` - Enable subscriber-only mode
  - `:unique_chat_mode` - Enable unique chat mode

  ## Examples

      {:ok, response} = Twitchy.Chat.update_chat_settings(client,
        broadcaster_id: "12345",
        moderator_id: "67890",
        slow_mode: true,
        slow_mode_wait_time: 10
      )
  """
  @spec update_chat_settings(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def update_chat_settings(client, params) do
    {broadcaster_id, params} = Keyword.pop!(params, :broadcaster_id)
    {moderator_id, params} = Keyword.pop!(params, :moderator_id)

    query = [broadcaster_id: broadcaster_id, moderator_id: moderator_id]
    body = Map.new(params)

    HTTP.patch(client, "/chat/settings", query: query, json: body)
  end

  @doc """
  Sends an announcement to the broadcaster's chat room.

  Requires the `moderator:manage:announcements` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required)
  - `:message` - Announcement message (max 500 characters, required)
  - `:color` - Color (`:blue`, `:green`, `:orange`, `:purple`, `:primary`)

  ## Examples

      :ok = Twitchy.Chat.send_chat_announcement(client,
        broadcaster_id: "12345",
        moderator_id: "67890",
        message: "Welcome to the stream!",
        color: :blue
      )
  """
  @spec send_chat_announcement(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def send_chat_announcement(client, params) do
    {broadcaster_id, params} = Keyword.pop!(params, :broadcaster_id)
    {moderator_id, params} = Keyword.pop!(params, :moderator_id)

    query = [broadcaster_id: broadcaster_id, moderator_id: moderator_id]
    body = Map.new(params)

    case HTTP.post(client, "/chat/announcements", query: query, json: body) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Sends a Shoutout to the specified broadcaster.

  Requires the `moderator:manage:shoutouts` scope.

  ## Parameters

  - `:from_broadcaster_id` - Broadcaster's user ID (required)
  - `:to_broadcaster_id` - Broadcaster to shoutout (required)
  - `:moderator_id` - Moderator's user ID (required)

  ## Examples

      :ok = Twitchy.Chat.send_shoutout(client,
        from_broadcaster_id: "12345",
        to_broadcaster_id: "67890",
        moderator_id: "12345"
      )
  """
  @spec send_shoutout(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def send_shoutout(client, params) do
    query = HTTP.build_query(params)

    case HTTP.post(client, "/chat/shoutouts", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Gets the broadcaster's chat badges.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)

  ## Examples

      {:ok, response} = Twitchy.Chat.get_channel_chat_badges(client, broadcaster_id: "12345")
  """
  @spec get_channel_chat_badges(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_channel_chat_badges(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/chat/badges", query: query)
  end

  @doc """
  Gets global chat badges.

  ## Examples

      {:ok, response} = Twitchy.Chat.get_global_chat_badges(client)
  """
  @spec get_global_chat_badges(Twitchy.t()) :: {:ok, map()} | {:error, Exception.t()}
  def get_global_chat_badges(client) do
    HTTP.get(client, "/chat/badges/global")
  end

  @doc """
  Gets emotes for a specific emote set.

  ## Parameters

  - `:emote_set_id` - Emote set ID(s) (max 25, required)

  ## Examples

      {:ok, response} = Twitchy.Chat.get_emote_sets(client, emote_set_id: ["300374282"])
  """
  @spec get_emote_sets(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_emote_sets(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/chat/emotes/set", query: query)
  end

  @doc """
  Gets channel emotes.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)

  ## Examples

      {:ok, response} = Twitchy.Chat.get_channel_emotes(client, broadcaster_id: "12345")
  """
  @spec get_channel_emotes(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_channel_emotes(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/chat/emotes", query: query)
  end

  @doc """
  Gets global emotes.

  ## Examples

      {:ok, response} = Twitchy.Chat.get_global_emotes(client)
  """
  @spec get_global_emotes(Twitchy.t()) :: {:ok, map()} | {:error, Exception.t()}
  def get_global_emotes(client) do
    HTTP.get(client, "/chat/emotes/global")
  end

  @doc """
  Gets the list of users chatting in the broadcaster's chat room.

  Requires the `moderator:read:chatters` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required)
  - `:first` - Number of results per page (max 1000, default 100)
  - `:after` - Cursor for pagination

  ## Examples

      {:ok, response} = Twitchy.Chat.get_chatters(client,
        broadcaster_id: "12345",
        moderator_id: "67890"
      )
  """
  @spec get_chatters(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_chatters(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/chat/chatters", query: query)
  end

  @doc """
  Streams chatters lazily, fetching pages as needed.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required)
  - `:first` - Number of results per page (max 1000, default 1000)

  ## Examples

      all_chatters = client
                     |> Twitchy.Chat.stream_chatters(
                       broadcaster_id: "12345",
                       moderator_id: "67890"
                     )
                     |> Enum.to_list()
  """
  @spec stream_chatters(Twitchy.t(), keyword()) :: Enumerable.t()
  def stream_chatters(client, params) do
    fetch_fn = fn cursor ->
      params = Pagination.add_to_query(params, after: cursor, first: params[:first] || 1000)

      case get_chatters(client, params) do
        {:ok, response} ->
          {:ok, response["data"], Pagination.get_cursor(response)}

        error ->
          error
      end
    end

    Pagination.stream(fetch_fn)
  end

  @doc """
  Gets the color used for the user's name in chat.

  ## Parameters

  - `:user_id` - User ID(s) (max 100, required)

  ## Examples

      {:ok, response} = Twitchy.Chat.get_user_chat_color(client, user_id: ["12345"])
  """
  @spec get_user_chat_color(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_user_chat_color(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/chat/color", query: query)
  end

  @doc """
  Updates the color used for the user's name in chat.

  Requires the `user:manage:chat_color` scope.

  ## Parameters

  - `:user_id` - User ID (required)
  - `:color` - Color name or hex code (required)

  ## Examples

      :ok = Twitchy.Chat.update_user_chat_color(client,
        user_id: "12345",
        color: "blue"
      )
  """
  @spec update_user_chat_color(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def update_user_chat_color(client, params) do
    query = HTTP.build_query(params)

    case HTTP.put(client, "/chat/color", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end
end
