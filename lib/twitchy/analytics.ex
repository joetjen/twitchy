defmodule Twitchy.Analytics do
  @moduledoc """
  Twitch Analytics API endpoints.

  Provides functions for retrieving analytics data for extensions and games.

  ## Examples

      # Get extension analytics
      {:ok, response} = Twitchy.Analytics.get_extension_analytics(client)

      # Get game analytics
      {:ok, response} = Twitchy.Analytics.get_game_analytics(client)
  """

  alias Twitchy.{HTTP, Pagination}

  @doc """
  Gets analytics reports for one or more extensions.

  Requires the `analytics:read:extensions` scope.

  ## Parameters

  - `:extension_id` - Extension ID
  - `:type` - Type of report (`:overview_v2`)
  - `:started_at` - Start date (RFC3339)
  - `:ended_at` - End date (RFC3339)
  - `:first` - Number of results per page (max 100, default 20)
  - `:after` - Cursor for pagination

  ## Examples

      {:ok, response} = Twitchy.Analytics.get_extension_analytics(client,
        extension_id: "my_extension_id",
        type: :overview_v2
      )
  """
  @spec get_extension_analytics(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_extension_analytics(client, params \\ []) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/analytics/extensions", query: query)
  end

  @doc """
  Gets analytics reports for one or more games.

  Requires the `analytics:read:games` scope.

  ## Parameters

  - `:game_id` - Game ID
  - `:type` - Type of report (`:overview_v2`)
  - `:started_at` - Start date (RFC3339)
  - `:ended_at` - End date (RFC3339)
  - `:first` - Number of results per page (max 100, default 20)
  - `:after` - Cursor for pagination

  ## Examples

      {:ok, response} = Twitchy.Analytics.get_game_analytics(client,
        game_id: "21779",
        started_at: "2024-01-01T00:00:00Z",
        ended_at: "2024-01-31T23:59:59Z"
      )
  """
  @spec get_game_analytics(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_game_analytics(client, params \\ []) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/analytics/games", query: query)
  end

  @doc """
  Streams extension analytics reports lazily.

  ## Parameters

  - `:extension_id` - Extension ID
  - `:type` - Type of report (`:overview_v2`)
  - `:first` - Number of results per page (max 100, default 100)

  ## Examples

      reports = client
                |> Twitchy.Analytics.stream_extension_analytics(extension_id: "my_ext")
                |> Enum.to_list()
  """
  @spec stream_extension_analytics(Twitchy.t(), keyword()) :: Enumerable.t()
  def stream_extension_analytics(client, params \\ []) do
    fetch_fn = fn cursor ->
      params = Pagination.add_to_query(params, after: cursor, first: params[:first] || 100)

      case get_extension_analytics(client, params) do
        {:ok, response} ->
          {:ok, response["data"], Pagination.get_cursor(response)}

        error ->
          error
      end
    end

    Pagination.stream(fetch_fn)
  end

  @doc """
  Streams game analytics reports lazily.

  ## Parameters

  - `:game_id` - Game ID
  - `:type` - Type of report (`:overview_v2`)
  - `:first` - Number of results per page (max 100, default 100)

  ## Examples

      reports = client
                |> Twitchy.Analytics.stream_game_analytics(game_id: "21779")
                |> Enum.to_list()
  """
  @spec stream_game_analytics(Twitchy.t(), keyword()) :: Enumerable.t()
  def stream_game_analytics(client, params \\ []) do
    fetch_fn = fn cursor ->
      params = Pagination.add_to_query(params, after: cursor, first: params[:first] || 100)

      case get_game_analytics(client, params) do
        {:ok, response} ->
          {:ok, response["data"], Pagination.get_cursor(response)}

        error ->
          error
      end
    end

    Pagination.stream(fetch_fn)
  end
end
