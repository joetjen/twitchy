defmodule Twitchy.Search do
  @moduledoc """
  Twitch Search API endpoints.

  Provides functions for searching channels and categories.

  ## Examples

      # Search for channels
      {:ok, response} = Twitchy.Search.search_channels(client, query: "starcraft", first: 20)

      # Search for categories/games
      {:ok, response} = Twitchy.Search.search_categories(client, query: "league", first: 10)

      # Stream all search results
      results = client
                |> Twitchy.Search.stream_channels(query: "speed")
                |> Stream.take(100)
                |> Enum.to_list()
  """

  alias Twitchy.{HTTP, Pagination}

  @doc """
  Searches for channels by broadcaster name or description.

  ## Parameters

  - `:query` - Search query (required)
  - `:live_only` - Only return live channels (default: false)
  - `:first` - Number of results per page (max 100, default 20)
  - `:after` - Cursor for pagination

  ## Examples

      # Search for any channel
      {:ok, response} = Twitchy.Search.search_channels(client, query: "starcraft")

      # Search for live channels only
      {:ok, response} = Twitchy.Search.search_channels(client,
        query: "speedrun",
        live_only: true,
        first: 50
      )
  """
  @spec search_channels(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def search_channels(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/search/channels", query: query)
  end

  @doc """
  Streams channel search results lazily, fetching pages as needed.

  ## Parameters

  - `:query` - Search query (required)
  - `:live_only` - Only return live channels (default: false)
  - `:first` - Number of results per page (max 100, default 100)

  ## Examples

      channels = client
                 |> Twitchy.Search.stream_channels(query: "minecraft", live_only: true)
                 |> Stream.take(200)
                 |> Enum.to_list()
  """
  @spec stream_channels(Twitchy.t(), keyword()) :: Enumerable.t()
  def stream_channels(client, params) do
    fetch_fn = fn cursor ->
      params = Pagination.add_to_query(params, after: cursor, first: params[:first] || 100)

      case search_channels(client, params) do
        {:ok, response} ->
          {:ok, response["data"], Pagination.get_cursor(response)}

        error ->
          error
      end
    end

    Pagination.stream(fetch_fn)
  end

  @doc """
  Searches for categories (games/content types) by name.

  ## Parameters

  - `:query` - Search query (required)
  - `:first` - Number of results per page (max 100, default 20)
  - `:after` - Cursor for pagination

  ## Examples

      {:ok, response} = Twitchy.Search.search_categories(client, query: "league of")
  """
  @spec search_categories(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def search_categories(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/search/categories", query: query)
  end

  @doc """
  Streams category search results lazily, fetching pages as needed.

  ## Parameters

  - `:query` - Search query (required)
  - `:first` - Number of results per page (max 100, default 100)

  ## Examples

      categories = client
                   |> Twitchy.Search.stream_categories(query: "battle")
                   |> Enum.to_list()
  """
  @spec stream_categories(Twitchy.t(), keyword()) :: Enumerable.t()
  def stream_categories(client, params) do
    fetch_fn = fn cursor ->
      params = Pagination.add_to_query(params, after: cursor, first: params[:first] || 100)

      case search_categories(client, params) do
        {:ok, response} ->
          {:ok, response["data"], Pagination.get_cursor(response)}

        error ->
          error
      end
    end

    Pagination.stream(fetch_fn)
  end
end
