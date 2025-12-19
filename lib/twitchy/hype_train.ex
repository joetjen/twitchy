defmodule Twitchy.HypeTrain do
  @moduledoc """
  Twitch Hype Train API endpoints.

  Provides functions for retrieving Hype Train events.

  ## Examples

      # Get Hype Train events
      {:ok, response} = Twitchy.HypeTrain.get_hype_train_events(client,
        broadcaster_id: "12345"
      )
  """

  alias Twitchy.{HTTP, Pagination}

  @doc """
  Gets Hype Train events for a broadcaster.

  Requires the `channel:read:hype_train` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:id` - Filter by specific Hype Train event ID
  - `:first` - Number of results per page (max 100, default 1)
  - `:cursor` - Cursor for pagination

  ## Examples

      {:ok, response} = Twitchy.HypeTrain.get_hype_train_events(client,
        broadcaster_id: "12345",
        first: 20
      )
  """
  @spec get_hype_train_events(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_hype_train_events(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/hypetrain/events", query: query)
  end

  @doc """
  Streams Hype Train events lazily.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:first` - Number of results per page (max 100, default 100)

  ## Examples

      events = client
               |> Twitchy.HypeTrain.stream_events(broadcaster_id: "12345")
               |> Enum.to_list()
  """
  @spec stream_events(Twitchy.t(), keyword()) :: Enumerable.t()
  def stream_events(client, params) do
    fetch_fn = fn cursor ->
      params =
        if cursor do
          Keyword.put(params, :cursor, cursor)
        else
          params
        end

      params = Keyword.put_new(params, :first, 100)

      case get_hype_train_events(client, params) do
        {:ok, response} ->
          cursor = get_in(response, ["pagination", "cursor"])
          {:ok, response["data"], cursor}

        error ->
          error
      end
    end

    Pagination.stream(fetch_fn)
  end
end
