defmodule Twitchy.Games do
  @moduledoc """
  Twitch Games API endpoints.

  Provides functions for retrieving game and category information.

  ## Examples

      # Get game by ID
      {:ok, response} = Twitchy.Games.get_games(client, id: ["21779"])

      # Get game by name
      {:ok, response} = Twitchy.Games.get_games(client, name: ["League of Legends"])

      # Get top games
      {:ok, response} = Twitchy.Games.get_top_games(client, first: 20)

      # Stream all top games
      top_games = client
                  |> Twitchy.Games.stream_top_games()
                  |> Stream.take(100)
                  |> Enum.to_list()
  """

  alias Twitchy.{HTTP, Pagination}

  @doc """
  Gets games by ID or name.

  ## Parameters

  - `:id` - Game ID(s) (max 100)
  - `:name` - Game name(s) (max 100)
  - `:igdb_id` - IGDB ID(s) (max 100)

  ## Examples

      # By ID
      {:ok, response} = Twitchy.Games.get_games(client, id: ["21779", "32982"])

      # By name
      {:ok, response} = Twitchy.Games.get_games(client, name: ["League of Legends"])

      # By IGDB ID
      {:ok, response} = Twitchy.Games.get_games(client, igdb_id: ["1234"])
  """
  @spec get_games(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_games(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/games", query: query)
  end

  @doc """
  Gets a single game by ID or name.

  Convenience function that returns the first game or nil.

  ## Examples

      {:ok, game} = Twitchy.Games.get_game(client, name: "League of Legends")
  """
  @spec get_game(Twitchy.t(), keyword()) :: {:ok, map() | nil} | {:error, Exception.t()}
  def get_game(client, params) do
    case get_games(client, params) do
      {:ok, %{"data" => [game | _]}} -> {:ok, game}
      {:ok, %{"data" => []}} -> {:ok, nil}
      error -> error
    end
  end

  @doc """
  Gets the top games by viewer count.

  ## Parameters

  - `:first` - Number of results per page (max 100, default 20)
  - `:before` - Cursor for backwards pagination
  - `:after` - Cursor for forward pagination

  ## Examples

      {:ok, response} = Twitchy.Games.get_top_games(client, first: 100)
  """
  @spec get_top_games(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_top_games(client, params \\ []) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/games/top", query: query)
  end

  @doc """
  Streams top games lazily, fetching pages as needed.

  ## Parameters

  - `:first` - Number of results per page (max 100, default 100)

  ## Examples

      top_100 = client
                |> Twitchy.Games.stream_top_games()
                |> Stream.take(100)
                |> Enum.to_list()
  """
  @spec stream_top_games(Twitchy.t(), keyword()) :: Enumerable.t()
  def stream_top_games(client, params \\ []) do
    fetch_fn = fn cursor ->
      params = Pagination.add_to_query(params, after: cursor, first: params[:first] || 100)

      case get_top_games(client, params) do
        {:ok, response} ->
          {:ok, response["data"], Pagination.get_cursor(response)}

        error ->
          error
      end
    end

    Pagination.stream(fetch_fn)
  end
end
