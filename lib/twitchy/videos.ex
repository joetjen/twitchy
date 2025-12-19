defmodule Twitchy.Videos do
  @moduledoc """
  Twitch Videos API endpoints.

  Provides functions for retrieving VOD (Video on Demand) information and deleting videos.

  ## Examples

      # Get videos by ID
      {:ok, response} = Twitchy.Videos.get_videos(client, id: ["12345"])

      # Get videos for a user
      {:ok, response} = Twitchy.Videos.get_videos(client, user_id: "67890", first: 20)

      # Get videos for a game
      {:ok, response} = Twitchy.Videos.get_videos(client, game_id: "21779", first: 10)

      # Stream all user videos
      videos = client
               |> Twitchy.Videos.stream_videos(user_id: "12345")
               |> Enum.to_list()
  """

  alias Twitchy.{HTTP, Pagination}

  @doc """
  Gets video information by ID, user ID, or game ID.

  ## Parameters

  - `:id` - Video ID(s) (max 100)
  - `:user_id` - User ID of video owner
  - `:game_id` - Game ID to filter by
  - `:language` - Language code (ISO 639-1)
  - `:period` - Time period (`:all`, `:day`, `:week`, `:month`)
  - `:sort` - Sort order (`:time`, `:trending`, `:views`)
  - `:type` - Video type (`:archive`, `:highlight`, `:upload`, `:all`)
  - `:first` - Number of results per page (max 100, default 20)
  - `:before` - Cursor for backwards pagination
  - `:after` - Cursor for forward pagination

  Note: Must specify `:id`, `:user_id`, or `:game_id`.

  ## Examples

      # By video ID
      {:ok, response} = Twitchy.Videos.get_videos(client, id: ["1234567890"])

      # User's recent videos
      {:ok, response} = Twitchy.Videos.get_videos(client,
        user_id: "12345",
        type: :archive,
        first: 20
      )

      # Trending videos for a game
      {:ok, response} = Twitchy.Videos.get_videos(client,
        game_id: "21779",
        sort: :trending,
        period: :week
      )
  """
  @spec get_videos(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_videos(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/videos", query: query)
  end

  @doc """
  Gets a single video by ID.

  Convenience function that returns the first video or nil.

  ## Examples

      {:ok, video} = Twitchy.Videos.get_video(client, id: "1234567890")
  """
  @spec get_video(Twitchy.t(), keyword()) :: {:ok, map() | nil} | {:error, Exception.t()}
  def get_video(client, params) do
    case get_videos(client, params) do
      {:ok, %{"data" => [video | _]}} -> {:ok, video}
      {:ok, %{"data" => []}} -> {:ok, nil}
      error -> error
    end
  end

  @doc """
  Streams videos lazily, fetching pages as needed.

  ## Parameters

  - `:user_id` - User ID of video owner (required)
  - `:game_id` - Game ID to filter by
  - `:type` - Video type (`:archive`, `:highlight`, `:upload`, `:all`)
  - `:sort` - Sort order (`:time`, `:trending`, `:views`)
  - `:period` - Time period (`:all`, `:day`, `:week`, `:month`)
  - `:first` - Number of results per page (max 100, default 100)

  ## Examples

      all_highlights = client
                       |> Twitchy.Videos.stream_videos(user_id: "12345", type: :highlight)
                       |> Enum.to_list()
  """
  @spec stream_videos(Twitchy.t(), keyword()) :: Enumerable.t()
  def stream_videos(client, params) do
    fetch_fn = fn cursor ->
      params = Pagination.add_to_query(params, after: cursor, first: params[:first] || 100)

      case get_videos(client, params) do
        {:ok, response} ->
          {:ok, response["data"], Pagination.get_cursor(response)}

        error ->
          error
      end
    end

    Pagination.stream(fetch_fn)
  end

  @doc """
  Deletes one or more videos.

  Requires the `channel:manage:videos` scope.

  ## Parameters

  - `:id` - Video ID(s) to delete (max 5)

  ## Examples

      :ok = Twitchy.Videos.delete_videos(client, id: ["1234567890"])

      # Delete multiple videos
      :ok = Twitchy.Videos.delete_videos(client, id: ["123", "456", "789"])
  """
  @spec delete_videos(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def delete_videos(client, params) do
    query = HTTP.build_query(params)

    case HTTP.delete(client, "/videos", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end
end
