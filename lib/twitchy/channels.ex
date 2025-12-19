defmodule Twitchy.Channels do
  @moduledoc """
  Twitch Channels API endpoints.

  Provides functions for managing channel information, editors, and followers.

  ## Examples

      # Get channel information
      {:ok, response} = Twitchy.Channels.get_channel_information(client, broadcaster_id: "12345")

      # Update channel information
      {:ok, response} = Twitchy.Channels.modify_channel_information(client,
        broadcaster_id: "12345",
        game_id: "21779",
        title: "New stream title"
      )

      # Get channel editors
      {:ok, response} = Twitchy.Channels.get_channel_editors(client, broadcaster_id: "12345")
  """

  alias Twitchy.HTTP

  @doc """
  Gets channel information for one or more broadcasters.

  ## Parameters

  - `:broadcaster_id` - Broadcaster user ID(s) (max 100, required)

  ## Examples

      # Single channel
      {:ok, response} = Twitchy.Channels.get_channel_information(client, broadcaster_id: "12345")

      # Multiple channels
      {:ok, response} = Twitchy.Channels.get_channel_information(client,
        broadcaster_id: ["12345", "67890"]
      )
  """
  @spec get_channel_information(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_channel_information(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/channels", query: query)
  end

  @doc """
  Modifies channel information.

  Requires the `channel:manage:broadcast` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster user ID (required)
  - `:game_id` - Game/category ID
  - `:broadcaster_language` - Broadcaster's language (ISO 639-1 code)
  - `:title` - Stream title (max 140 characters)
  - `:delay` - Stream delay in seconds
  - `:tags` - List of content classification label IDs
  - `:content_classification_labels` - List of CCL IDs
  - `:is_branded_content` - Whether stream contains branded content

  ## Examples

      {:ok, _} = Twitchy.Channels.modify_channel_information(client,
        broadcaster_id: "12345",
        game_id: "21779",
        title: "Speedrunning League of Legends!",
        tags: ["English"]
      )
  """
  @spec modify_channel_information(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def modify_channel_information(client, params) do
    broadcaster_id = Keyword.fetch!(params, :broadcaster_id)
    body = params |> Keyword.delete(:broadcaster_id) |> Map.new()

    query = [broadcaster_id: broadcaster_id]
    HTTP.patch(client, "/channels", query: query, json: body)
  end

  @doc """
  Gets a list of channel editors.

  Requires the `channel:read:editors` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster user ID (required)

  ## Examples

      {:ok, %{"data" => editors}} = Twitchy.Channels.get_channel_editors(client, broadcaster_id: "12345")
  """
  @spec get_channel_editors(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_channel_editors(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/channels/editors", query: query)
  end

  @doc """
  Gets the broadcaster's list of active goals.

  Requires the `channel:read:goals` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster user ID (required)

  ## Examples

      {:ok, response} = Twitchy.Channels.get_creator_goals(client, broadcaster_id: "12345")
  """
  @spec get_creator_goals(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_creator_goals(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/goals", query: query)
  end

  @doc """
  Gets the broadcaster's VIPs.

  Requires the `channel:read:vips` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster user ID (required)
  - `:user_id` - Filter by specific user ID(s)
  - `:first` - Number of results per page (max 100, default 20)
  - `:after` - Cursor for pagination

  ## Examples

      {:ok, response} = Twitchy.Channels.get_vips(client, broadcaster_id: "12345")
  """
  @spec get_vips(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_vips(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/channels/vips", query: query)
  end

  @doc """
  Adds a VIP to the broadcaster's channel.

  Requires the `channel:manage:vips` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster user ID (required)
  - `:user_id` - User ID to add as VIP (required)

  ## Examples

      :ok = Twitchy.Channels.add_channel_vip(client,
        broadcaster_id: "12345",
        user_id: "67890"
      )
  """
  @spec add_channel_vip(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def add_channel_vip(client, params) do
    query = HTTP.build_query(params)

    case HTTP.post(client, "/channels/vips", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Removes a VIP from the broadcaster's channel.

  Requires the `channel:manage:vips` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster user ID (required)
  - `:user_id` - User ID to remove as VIP (required)

  ## Examples

      :ok = Twitchy.Channels.remove_channel_vip(client,
        broadcaster_id: "12345",
        user_id: "67890"
      )
  """
  @spec remove_channel_vip(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def remove_channel_vip(client, params) do
    query = HTTP.build_query(params)

    case HTTP.delete(client, "/channels/vips", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end
end
