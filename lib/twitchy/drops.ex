defmodule Twitchy.Drops do
  @moduledoc """
  Twitch Drops API endpoints.

  Provides functions for managing Drops entitlements.

  ## Examples

      # Get Drops entitlements
      {:ok, response} = Twitchy.Drops.get_drops_entitlements(client,
        user_id: "12345"
      )

      # Update entitlements
      {:ok, response} = Twitchy.Drops.update_drops_entitlements(client,
        entitlement_ids: ["entitlement-1", "entitlement-2"],
        fulfillment_status: "CLAIMED"
      )
  """

  alias Twitchy.{HTTP, Pagination}

  @doc """
  Gets Drops entitlements for an organization or user.

  Requires app access token or user access token with appropriate scope.

  ## Parameters

  - `:id` - Filter by entitlement ID(s)
  - `:user_id` - Filter by user ID
  - `:game_id` - Filter by game ID
  - `:fulfillment_status` - Filter by status (`:CLAIMED`, `:FULFILLED`)
  - `:first` - Number of results per page (max 1000, default 20)
  - `:after` - Cursor for pagination

  ## Examples

      {:ok, response} = Twitchy.Drops.get_drops_entitlements(client,
        user_id: "12345",
        fulfillment_status: :CLAIMED
      )
  """
  @spec get_drops_entitlements(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_drops_entitlements(client, params \\ []) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/entitlements/drops", query: query)
  end

  @doc """
  Updates the fulfillment status of Drops entitlements.

  ## Parameters

  - `:entitlement_ids` - Entitlement IDs to update (max 100, required)
  - `:fulfillment_status` - New status (`:CLAIMED` or `:FULFILLED`, required)

  ## Examples

      {:ok, response} = Twitchy.Drops.update_drops_entitlements(client,
        entitlement_ids: ["entitlement-1", "entitlement-2"],
        fulfillment_status: "FULFILLED"
      )
  """
  @spec update_drops_entitlements(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def update_drops_entitlements(client, params) do
    body = Map.new(params)
    HTTP.patch(client, "/entitlements/drops", json: body)
  end

  @doc """
  Streams Drops entitlements lazily.

  ## Parameters

  - `:user_id` - Filter by user ID
  - `:game_id` - Filter by game ID
  - `:fulfillment_status` - Filter by status
  - `:first` - Number of results per page (max 1000, default 1000)

  ## Examples

      entitlements = client
                     |> Twitchy.Drops.stream_entitlements(user_id: "12345")
                     |> Enum.to_list()
  """
  @spec stream_entitlements(Twitchy.t(), keyword()) :: Enumerable.t()
  def stream_entitlements(client, params \\ []) do
    fetch_fn = fn cursor ->
      params = Pagination.add_to_query(params, after: cursor, first: params[:first] || 1000)

      case get_drops_entitlements(client, params) do
        {:ok, response} ->
          {:ok, response["data"], Pagination.get_cursor(response)}

        error ->
          error
      end
    end

    Pagination.stream(fetch_fn)
  end
end
