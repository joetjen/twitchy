defmodule Twitchy.Streams do
  @moduledoc """
  Twitch Streams API endpoints.

  Provides functions for retrieving stream information, managing stream markers,
  and accessing stream metadata.

  ## Examples

      # Get streams for specific users
      {:ok, response} = Twitchy.Streams.get_streams(client, user_login: ["shroud", "ninja"])

      # Get streams by game
      {:ok, response} = Twitchy.Streams.get_streams(client, game_id: "12345", first: 100)

      # Stream all live channels
      live_streams = client
                     |> Twitchy.Streams.stream_streams(game_id: "21779")
                     |> Stream.take(500)
                     |> Enum.to_list()

      # Get followed streams
      {:ok, response} = Twitchy.Streams.get_followed_streams(client, user_id: "12345")
  """

  alias Twitchy.{HTTP, Pagination}

  @doc """
  Gets information about active streams.

  ## Parameters

  - `:user_id` - User ID(s) of broadcaster(s) (max 100)
  - `:user_login` - Login name(s) of broadcaster(s) (max 100)
  - `:game_id` - Game ID(s) to filter by (max 100)
  - `:type` - Stream type (`:all`, `:live`) - default `:all`
  - `:language` - Language code(s) (max 100)
  - `:first` - Number of results per page (max 100, default 20)
  - `:before` - Cursor for backwards pagination
  - `:after` - Cursor for forward pagination

  ## Examples

      # Get specific user's stream
      {:ok, response} = Twitchy.Streams.get_streams(client, user_login: ["shroud"])

      # Get streams by game
      {:ok, response} = Twitchy.Streams.get_streams(client, game_id: "21779", first: 100)

      # Get streams in specific language
      {:ok, response} = Twitchy.Streams.get_streams(client, language: ["en"], first: 50)
  """
  @spec get_streams(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_streams(client, params \\ []) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/streams", query: query)
  end

  @doc """
  Gets a single stream by user ID or login.

  Convenience function that returns the first stream or nil.

  ## Examples

      {:ok, stream} = Twitchy.Streams.get_stream(client, user_login: "shroud")
  """
  @spec get_stream(Twitchy.t(), keyword()) :: {:ok, map() | nil} | {:error, Exception.t()}
  def get_stream(client, params) do
    case get_streams(client, params) do
      {:ok, %{"data" => [stream | _]}} -> {:ok, stream}
      {:ok, %{"data" => []}} -> {:ok, nil}
      error -> error
    end
  end

  @doc """
  Streams live channels lazily, fetching pages as needed.

  ## Parameters

  - `:game_id` - Filter by game ID
  - `:language` - Filter by language(s)
  - `:first` - Number of results per page (max 100, default 100)

  ## Examples

      live_streams = client
                     |> Twitchy.Streams.stream_streams(game_id: "21779", first: 100)
                     |> Stream.take(500)
                     |> Enum.to_list()
  """
  @spec stream_streams(Twitchy.t(), keyword()) :: Enumerable.t()
  def stream_streams(client, params \\ []) do
    fetch_fn = fn cursor ->
      params = Pagination.add_to_query(params, after: cursor, first: params[:first] || 100)

      case get_streams(client, params) do
        {:ok, response} ->
          {:ok, response["data"], Pagination.get_cursor(response)}

        error ->
          error
      end
    end

    Pagination.stream(fetch_fn)
  end

  @doc """
  Gets streams for channels that the authenticated user follows.

  Requires the `user:read:follows` scope.

  ## Parameters

  - `:user_id` - User ID of the authenticated user (required)
  - `:first` - Number of results per page (max 100, default 100)
  - `:after` - Cursor for pagination

  ## Examples

      {:ok, response} = Twitchy.Streams.get_followed_streams(client, user_id: "12345")
  """
  @spec get_followed_streams(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_followed_streams(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/streams/followed", query: query)
  end

  @doc """
  Creates a stream marker at the current timestamp.

  Requires the `channel:manage:broadcast` scope.

  ## Parameters

  - `:user_id` - User ID of the broadcaster (required)
  - `:description` - Optional description (max 140 characters)

  ## Examples

      {:ok, response} = Twitchy.Streams.create_stream_marker(client,
        user_id: "12345",
        description: "Epic moment!"
      )
  """
  @spec create_stream_marker(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def create_stream_marker(client, params) do
    body = Map.new(params)
    HTTP.post(client, "/streams/markers", json: body)
  end

  @doc """
  Gets stream markers for a VOD or stream.

  Requires the `user:read:broadcast` scope.

  ## Parameters

  - `:user_id` - User ID of the broadcaster
  - `:video_id` - VOD/video ID
  - `:first` - Number of results per page (max 100, default 20)
  - `:before` - Cursor for backwards pagination
  - `:after` - Cursor for forward pagination

  Note: Must specify either `:user_id` or `:video_id`.

  ## Examples

      # Get markers for a user's streams
      {:ok, response} = Twitchy.Streams.get_stream_markers(client, user_id: "12345")

      # Get markers for a specific VOD
      {:ok, response} = Twitchy.Streams.get_stream_markers(client, video_id: "67890")
  """
  @spec get_stream_markers(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_stream_markers(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/streams/markers", query: query)
  end

  @doc """
  Gets the broadcaster's stream key.

  Requires the `channel:read:stream_key` scope.

  **Warning**: Keep stream keys confidential! They allow broadcasting to your channel.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)

  ## Examples

      {:ok, %{"data" => [%{"stream_key" => key}]}} =
        Twitchy.Streams.get_stream_key(client, broadcaster_id: "12345")
  """
  @spec get_stream_key(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_stream_key(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/streams/key", query: query)
  end
end
