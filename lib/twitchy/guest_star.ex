defmodule Twitchy.GuestStar do
  @moduledoc """
  Twitch Guest Star API endpoints.

  Provides functions for managing Guest Star sessions, allowing streamers to
  bring guests into their streams.

  ## Examples

      # Get channel guest star settings
      {:ok, response} = Twitchy.GuestStar.get_channel_guest_star_settings(client,
        broadcaster_id: "12345"
      )

      # Create guest star session
      {:ok, response} = Twitchy.GuestStar.create_guest_star_session(client,
        broadcaster_id: "12345"
      )
  """

  alias Twitchy.HTTP

  @doc """
  Gets the channel's Guest Star settings.

  Requires the `channel:read:guest_star` or `channel:manage:guest_star` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required)

  ## Examples

      {:ok, response} = Twitchy.GuestStar.get_channel_guest_star_settings(client,
        broadcaster_id: "12345",
        moderator_id: "67890"
      )
  """
  @spec get_channel_guest_star_settings(Twitchy.t(), keyword()) ::
          {:ok, map()} | {:error, Exception.t()}
  def get_channel_guest_star_settings(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/guest_star/channel_settings", query: query)
  end

  @doc """
  Updates the channel's Guest Star settings.

  Requires the `channel:manage:guest_star` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:is_moderator_send_live_enabled` - Allow moderators to send guests live
  - `:slot_count` - Number of slots (1-6)
  - `:is_browser_source_audio_enabled` - Enable browser source audio
  - `:group_layout` - Layout type

  ## Examples

      {:ok, _} = Twitchy.GuestStar.update_channel_guest_star_settings(client,
        broadcaster_id: "12345",
        slot_count: 4,
        is_moderator_send_live_enabled: true
      )
  """
  @spec update_channel_guest_star_settings(Twitchy.t(), keyword()) ::
          {:ok, map()} | {:error, Exception.t()}
  def update_channel_guest_star_settings(client, params) do
    {broadcaster_id, params} = Keyword.pop!(params, :broadcaster_id)
    query = [broadcaster_id: broadcaster_id]
    body = Map.new(params)

    HTTP.put(client, "/guest_star/channel_settings", query: query, json: body)
  end

  @doc """
  Gets information about an active Guest Star session.

  Requires the `channel:read:guest_star` or `channel:manage:guest_star` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required)

  ## Examples

      {:ok, response} = Twitchy.GuestStar.get_guest_star_session(client,
        broadcaster_id: "12345",
        moderator_id: "67890"
      )
  """
  @spec get_guest_star_session(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_guest_star_session(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/guest_star/session", query: query)
  end

  @doc """
  Creates a Guest Star session.

  Requires the `channel:manage:guest_star` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)

  ## Examples

      {:ok, response} = Twitchy.GuestStar.create_guest_star_session(client,
        broadcaster_id: "12345"
      )
  """
  @spec create_guest_star_session(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def create_guest_star_session(client, params) do
    query = HTTP.build_query(params)
    HTTP.post(client, "/guest_star/session", query: query)
  end

  @doc """
  Ends a Guest Star session.

  Requires the `channel:manage:guest_star` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:session_id` - Session ID (required)

  ## Examples

      :ok = Twitchy.GuestStar.end_guest_star_session(client,
        broadcaster_id: "12345",
        session_id: "session-id"
      )
  """
  @spec end_guest_star_session(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def end_guest_star_session(client, params) do
    query = HTTP.build_query(params)

    case HTTP.delete(client, "/guest_star/session", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Gets invites for the broadcaster's Guest Star session.

  Requires the `channel:read:guest_star` or `channel:manage:guest_star` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required)
  - `:session_id` - Session ID (required)

  ## Examples

      {:ok, response} = Twitchy.GuestStar.get_guest_star_invites(client,
        broadcaster_id: "12345",
        moderator_id: "67890",
        session_id: "session-id"
      )
  """
  @spec get_guest_star_invites(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_guest_star_invites(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/guest_star/invites", query: query)
  end

  @doc """
  Sends a Guest Star invite to a user.

  Requires the `channel:manage:guest_star` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required)
  - `:session_id` - Session ID (required)
  - `:guest_id` - Guest's user ID (required)

  ## Examples

      :ok = Twitchy.GuestStar.send_guest_star_invite(client,
        broadcaster_id: "12345",
        moderator_id: "67890",
        session_id: "session-id",
        guest_id: "11111"
      )
  """
  @spec send_guest_star_invite(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def send_guest_star_invite(client, params) do
    query = HTTP.build_query(params)

    case HTTP.post(client, "/guest_star/invites", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Removes a guest from a Guest Star session.

  Requires the `channel:manage:guest_star` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required)
  - `:session_id` - Session ID (required)
  - `:guest_id` - Guest's user ID (required)

  ## Examples

      :ok = Twitchy.GuestStar.delete_guest_star_invite(client,
        broadcaster_id: "12345",
        moderator_id: "67890",
        session_id: "session-id",
        guest_id: "11111"
      )
  """
  @spec delete_guest_star_invite(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def delete_guest_star_invite(client, params) do
    query = HTTP.build_query(params)

    case HTTP.delete(client, "/guest_star/invites", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Assigns a guest to a slot in the Guest Star session.

  Requires the `channel:manage:guest_star` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required)
  - `:session_id` - Session ID (required)
  - `:guest_id` - Guest's user ID (required)
  - `:slot_id` - Slot ID (required, 0-based)

  ## Examples

      :ok = Twitchy.GuestStar.assign_guest_star_slot(client,
        broadcaster_id: "12345",
        moderator_id: "67890",
        session_id: "session-id",
        guest_id: "11111",
        slot_id: 0
      )
  """
  @spec assign_guest_star_slot(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def assign_guest_star_slot(client, params) do
    query = HTTP.build_query(params)

    case HTTP.post(client, "/guest_star/slot", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Updates a guest's state in a Guest Star session slot.

  Requires the `channel:manage:guest_star` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required)
  - `:session_id` - Session ID (required)
  - `:source_slot_id` - Source slot ID (required)
  - `:destination_slot_id` - Destination slot ID

  ## Examples

      :ok = Twitchy.GuestStar.update_guest_star_slot(client,
        broadcaster_id: "12345",
        moderator_id: "67890",
        session_id: "session-id",
        source_slot_id: 0,
        destination_slot_id: 1
      )
  """
  @spec update_guest_star_slot(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def update_guest_star_slot(client, params) do
    query = HTTP.build_query(params)

    case HTTP.patch(client, "/guest_star/slot", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Removes a guest from a Guest Star session slot.

  Requires the `channel:manage:guest_star` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required)
  - `:session_id` - Session ID (required)
  - `:guest_id` - Guest's user ID (required)
  - `:slot_id` - Slot ID (required)

  ## Examples

      :ok = Twitchy.GuestStar.delete_guest_star_slot(client,
        broadcaster_id: "12345",
        moderator_id: "67890",
        session_id: "session-id",
        guest_id: "11111",
        slot_id: 0
      )
  """
  @spec delete_guest_star_slot(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def delete_guest_star_slot(client, params) do
    query = HTTP.build_query(params)

    case HTTP.delete(client, "/guest_star/slot", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Updates settings for a guest in a Guest Star session slot.

  Requires the `channel:manage:guest_star` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:moderator_id` - Moderator's user ID (required)
  - `:session_id` - Session ID (required)
  - `:slot_id` - Slot ID (required)
  - `:is_audio_enabled` - Enable audio
  - `:is_video_enabled` - Enable video
  - `:is_live` - Set guest live
  - `:volume` - Audio volume (0-100)

  ## Examples

      :ok = Twitchy.GuestStar.update_guest_star_slot_settings(client,
        broadcaster_id: "12345",
        moderator_id: "67890",
        session_id: "session-id",
        slot_id: 0,
        is_audio_enabled: true,
        volume: 75
      )
  """
  @spec update_guest_star_slot_settings(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def update_guest_star_slot_settings(client, params) do
    {query_keys, body_keys} =
      {[:broadcaster_id, :moderator_id, :session_id, :slot_id],
       [:is_audio_enabled, :is_video_enabled, :is_live, :volume]}

    query = HTTP.build_query(Keyword.take(params, query_keys))
    body = Map.new(Keyword.take(params, body_keys))

    case HTTP.patch(client, "/guest_star/slot_settings", query: query, json: body) do
      {:ok, _} -> :ok
      error -> error
    end
  end
end
