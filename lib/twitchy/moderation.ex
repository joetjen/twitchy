defmodule Twitchy.Moderation do
  @moduledoc """
  Twitch Moderation API endpoints.

  Provides functions for moderation actions, bans, timeouts, moderators, AutoMod, and Shield Mode.

  ## Examples

      # Ban a user
      :ok = Twitchy.Moderation.ban_user(client,
        broadcaster_id: "12345",
        moderator_id: "67890",
        user_id: "99999",
        reason: "Spam"
      )

      # Get banned users
      {:ok, response} = Twitchy.Moderation.get_banned_users(client,
        broadcaster_id: "12345"
      )

      # Get moderators
      {:ok, response} = Twitchy.Moderation.get_moderators(client,
        broadcaster_id: "12345"
      )
  """

  alias Twitchy.HTTP

  @doc """
  Bans or times out a user.

  Requires the `moderator:manage:banned_users` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required)
  - `:user_id` - User to ban (required)
  - `:duration` - Timeout duration in seconds (1-1209600). Omit for permanent ban
  - `:reason` - Reason for ban (max 500 characters)

  ## Examples

      # Permanent ban
      :ok = Twitchy.Moderation.ban_user(client,
        broadcaster_id: "12345",
        moderator_id: "67890",
        user_id: "99999",
        reason: "Harassment"
      )

      # Timeout for 10 minutes
      :ok = Twitchy.Moderation.ban_user(client,
        broadcaster_id: "12345",
        moderator_id: "67890",
        user_id: "99999",
        duration: 600
      )
  """
  @spec ban_user(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def ban_user(client, params) do
    {broadcaster_id, params} = Keyword.pop!(params, :broadcaster_id)
    {moderator_id, params} = Keyword.pop!(params, :moderator_id)

    query = [broadcaster_id: broadcaster_id, moderator_id: moderator_id]
    body = %{data: Map.new(params)}

    case HTTP.post(client, "/moderation/bans", query: query, json: body) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Removes a ban or timeout from a user.

  Requires the `moderator:manage:banned_users` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required)
  - `:user_id` - User to unban (required)

  ## Examples

      :ok = Twitchy.Moderation.unban_user(client,
        broadcaster_id: "12345",
        moderator_id: "67890",
        user_id: "99999"
      )
  """
  @spec unban_user(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def unban_user(client, params) do
    query = HTTP.build_query(params)

    case HTTP.delete(client, "/moderation/bans", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Gets banned and timed-out users.

  Requires the `moderation:read` or `moderator:read:banned_users` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:user_id` - Filter by specific user ID(s)
  - `:first` - Number of results per page (max 100, default 20)
  - `:before` - Cursor for backwards pagination
  - `:after` - Cursor for forward pagination

  ## Examples

      {:ok, response} = Twitchy.Moderation.get_banned_users(client, broadcaster_id: "12345")
  """
  @spec get_banned_users(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_banned_users(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/moderation/banned", query: query)
  end

  @doc """
  Gets moderators for the broadcaster.

  Requires the `moderation:read` or `channel:manage:moderators` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:user_id` - Filter by specific user ID(s)
  - `:first` - Number of results per page (max 100, default 20)
  - `:after` - Cursor for pagination

  ## Examples

      {:ok, response} = Twitchy.Moderation.get_moderators(client, broadcaster_id: "12345")
  """
  @spec get_moderators(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_moderators(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/moderation/moderators", query: query)
  end

  @doc """
  Adds a moderator to the broadcaster's channel.

  Requires the `channel:manage:moderators` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:user_id` - User to add as moderator (required)

  ## Examples

      :ok = Twitchy.Moderation.add_channel_moderator(client,
        broadcaster_id: "12345",
        user_id: "67890"
      )
  """
  @spec add_channel_moderator(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def add_channel_moderator(client, params) do
    query = HTTP.build_query(params)

    case HTTP.post(client, "/moderation/moderators", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Removes a moderator from the broadcaster's channel.

  Requires the `channel:manage:moderators` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:user_id` - User to remove as moderator (required)

  ## Examples

      :ok = Twitchy.Moderation.remove_channel_moderator(client,
        broadcaster_id: "12345",
        user_id: "67890"
      )
  """
  @spec remove_channel_moderator(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def remove_channel_moderator(client, params) do
    query = HTTP.build_query(params)

    case HTTP.delete(client, "/moderation/moderators", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Checks AutoMod status for messages.

  Requires the `moderation:read` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:messages` - List of messages to check (required)

  ## Examples

      {:ok, response} = Twitchy.Moderation.check_automod_status(client,
        broadcaster_id: "12345",
        messages: [
          %{msg_id: "1", msg_text: "Test message", user_id: "67890"}
        ]
      )
  """
  @spec check_automod_status(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def check_automod_status(client, params) do
    {broadcaster_id, params} = Keyword.pop!(params, :broadcaster_id)
    query = [broadcaster_id: broadcaster_id]
    body = %{data: Keyword.fetch!(params, :messages)}

    HTTP.post(client, "/moderation/enforcements/status", query: query, json: body)
  end

  @doc """
  Gets AutoMod settings.

  Requires the `moderator:read:automod_settings` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required)

  ## Examples

      {:ok, response} = Twitchy.Moderation.get_automod_settings(client,
        broadcaster_id: "12345",
        moderator_id: "67890"
      )
  """
  @spec get_automod_settings(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_automod_settings(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/moderation/automod/settings", query: query)
  end

  @doc """
  Updates AutoMod settings.

  Requires the `moderator:manage:automod_settings` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required)
  - Plus AutoMod level fields (0-4): `:aggression`, `:bullying`, `:disability`,
    `:misogyny`, `:overall_level`, `:race_ethnicity_or_religion`, `:sex_based_terms`,
    `:sexuality_sex_or_gender`, `:swearing`

  ## Examples

      {:ok, response} = Twitchy.Moderation.update_automod_settings(client,
        broadcaster_id: "12345",
        moderator_id: "67890",
        overall_level: 2
      )
  """
  @spec update_automod_settings(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def update_automod_settings(client, params) do
    {broadcaster_id, params} = Keyword.pop!(params, :broadcaster_id)
    {moderator_id, params} = Keyword.pop!(params, :moderator_id)

    query = [broadcaster_id: broadcaster_id, moderator_id: moderator_id]
    body = Map.new(params)

    HTTP.put(client, "/moderation/automod/settings", query: query, json: body)
  end

  @doc """
  Gets Shield Mode status.

  Requires the `moderator:read:shield_mode` or `moderator:manage:shield_mode` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required)

  ## Examples

      {:ok, response} = Twitchy.Moderation.get_shield_mode_status(client,
        broadcaster_id: "12345",
        moderator_id: "67890"
      )
  """
  @spec get_shield_mode_status(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_shield_mode_status(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/moderation/shield_mode", query: query)
  end

  @doc """
  Updates Shield Mode status.

  Requires the `moderator:manage:shield_mode` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required)
  - `:is_active` - Whether Shield Mode is active (required)

  ## Examples

      {:ok, response} = Twitchy.Moderation.update_shield_mode_status(client,
        broadcaster_id: "12345",
        moderator_id: "67890",
        is_active: true
      )
  """
  @spec update_shield_mode_status(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def update_shield_mode_status(client, params) do
    {broadcaster_id, params} = Keyword.pop!(params, :broadcaster_id)
    {moderator_id, params} = Keyword.pop!(params, :moderator_id)

    query = [broadcaster_id: broadcaster_id, moderator_id: moderator_id]
    body = Map.new(params)

    HTTP.put(client, "/moderation/shield_mode", query: query, json: body)
  end

  @doc """
  Deletes chat messages.

  Requires the `moderator:manage:chat_messages` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required)
  - `:message_id` - Message ID to delete (omit to clear all chat)

  ## Examples

      # Delete specific message
      :ok = Twitchy.Moderation.delete_chat_messages(client,
        broadcaster_id: "12345",
        moderator_id: "67890",
        message_id: "abc-123"
      )

      # Clear all chat
      :ok = Twitchy.Moderation.delete_chat_messages(client,
        broadcaster_id: "12345",
        moderator_id: "67890"
      )
  """
  @spec delete_chat_messages(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def delete_chat_messages(client, params) do
    query = HTTP.build_query(params)

    case HTTP.delete(client, "/moderation/chat", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end
end
