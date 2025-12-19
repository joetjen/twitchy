defmodule Twitchy.Conduits do
  @moduledoc """
  Twitch Conduits API endpoints.

  Provides functions for managing EventSub conduits, which allow managing
  multiple WebSocket connections or webhook endpoints efficiently.

  ## Examples

      # Create conduit
      {:ok, response} = Twitchy.Conduits.create_conduits(client, shard_count: 5)

      # Get conduits
      {:ok, response} = Twitchy.Conduits.get_conduits(client)

      # Update conduit shards
      {:ok, response} = Twitchy.Conduits.update_conduit_shards(client,
        conduit_id: "conduit-id",
        shards: [%{id: "0", transport: %{method: "websocket", session_id: "session-id"}}]
      )
  """

  alias Twitchy.HTTP

  @doc """
  Creates a new conduit.

  ## Parameters

  - `:shard_count` - Number of shards (required, max 10000)

  ## Examples

      {:ok, response} = Twitchy.Conduits.create_conduits(client, shard_count: 5)
  """
  @spec create_conduits(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def create_conduits(client, params) do
    body = Map.new(params)
    HTTP.post(client, "/eventsub/conduits", json: body)
  end

  @doc """
  Gets conduits.

  ## Examples

      {:ok, response} = Twitchy.Conduits.get_conduits(client)
  """
  @spec get_conduits(Twitchy.t()) :: {:ok, map()} | {:error, Exception.t()}
  def get_conduits(client) do
    HTTP.get(client, "/eventsub/conduits")
  end

  @doc """
  Updates a conduit.

  ## Parameters

  - `:id` - Conduit ID (required)
  - `:shard_count` - New number of shards (required, max 10000)

  ## Examples

      {:ok, response} = Twitchy.Conduits.update_conduits(client,
        id: "conduit-id",
        shard_count: 10
      )
  """
  @spec update_conduits(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def update_conduits(client, params) do
    body = Map.new(params)
    HTTP.patch(client, "/eventsub/conduits", json: body)
  end

  @doc """
  Deletes a conduit.

  ## Parameters

  - `:id` - Conduit ID (required)

  ## Examples

      :ok = Twitchy.Conduits.delete_conduit(client, id: "conduit-id")
  """
  @spec delete_conduit(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def delete_conduit(client, params) do
    query = HTTP.build_query(params)

    case HTTP.delete(client, "/eventsub/conduits", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Gets conduit shards.

  ## Parameters

  - `:conduit_id` - Conduit ID (required)
  - `:status` - Filter by status (`:enabled`, `:webhook_callback_verification_pending`, etc.)
  - `:after` - Cursor for pagination

  ## Examples

      {:ok, response} = Twitchy.Conduits.get_conduit_shards(client,
        conduit_id: "conduit-id"
      )
  """
  @spec get_conduit_shards(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_conduit_shards(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/eventsub/conduits/shards", query: query)
  end

  @doc """
  Updates conduit shards.

  ## Parameters

  - `:conduit_id` - Conduit ID (required)
  - `:shards` - List of shard updates (required, max 100)

  ## Examples

      {:ok, response} = Twitchy.Conduits.update_conduit_shards(client,
        conduit_id: "conduit-id",
        shards: [
          %{
            id: "0",
            transport: %{
              method: "websocket",
              session_id: "session-id"
            }
          }
        ]
      )
  """
  @spec update_conduit_shards(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def update_conduit_shards(client, params) do
    body = Map.new(params)
    HTTP.patch(client, "/eventsub/conduits/shards", json: body)
  end
end
