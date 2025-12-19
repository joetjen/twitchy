defmodule Twitchy.Clips do
  @moduledoc """
  Twitch Clips API endpoints.

  Provides functions for creating and retrieving clips.

  ## Examples

      # Create a clip
      {:ok, response} = Twitchy.Clips.create_clip(client, broadcaster_id: "12345")

      # Get clips by broadcaster
      {:ok, response} = Twitchy.Clips.get_clips(client, broadcaster_id: "12345")

      # Get clips by game
      {:ok, response} = Twitchy.Clips.get_clips(client, game_id: "21779")

      # Stream all clips for a broadcaster
      clips = client
              |> Twitchy.Clips.stream_clips(broadcaster_id: "12345")
              |> Enum.to_list()
  """

  alias Twitchy.{HTTP, Pagination}

  @doc """
  Creates a clip from the broadcaster's stream.

  Requires the `clips:edit` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:has_delay` - Whether to add a delay before capturing (default: false)

  ## Examples

      {:ok, %{"data" => [%{"id" => clip_id, "edit_url" => url}]}} =
        Twitchy.Clips.create_clip(client, broadcaster_id: "12345")
  """
  @spec create_clip(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def create_clip(client, params) do
    query = HTTP.build_query(params)
    HTTP.post(client, "/clips", query: query)
  end

  @doc """
  Gets clips by broadcaster, game, or clip IDs.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID
  - `:game_id` - Game ID
  - `:id` - Clip ID(s) (max 100)
  - `:started_at` - Start date/time (RFC3339)
  - `:ended_at` - End date/time (RFC3339)
  - `:first` - Number of results per page (max 100, default 20)
  - `:before` - Cursor for backwards pagination
  - `:after` - Cursor for forward pagination
  - `:is_featured` - Filter by featured clips

  Note: Must specify `:broadcaster_id`, `:game_id`, or `:id`.

  ## Examples

      # Get clips by ID
      {:ok, response} = Twitchy.Clips.get_clips(client, id: ["AwkwardHelplessSalamanderSwiftRage"])

      # Get clips for broadcaster
      {:ok, response} = Twitchy.Clips.get_clips(client,
        broadcaster_id: "12345",
        first: 20
      )

      # Get clips for game in date range
      {:ok, response} = Twitchy.Clips.get_clips(client,
        game_id: "21779",
        started_at: "2024-01-01T00:00:00Z",
        ended_at: "2024-01-31T23:59:59Z"
      )
  """
  @spec get_clips(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_clips(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/clips", query: query)
  end

  @doc """
  Gets a single clip by ID.

  Convenience function that returns the first clip or nil.

  ## Examples

      {:ok, clip} = Twitchy.Clips.get_clip(client, id: "AwkwardHelplessSalamanderSwiftRage")
  """
  @spec get_clip(Twitchy.t(), keyword()) :: {:ok, map() | nil} | {:error, Exception.t()}
  def get_clip(client, params) do
    case get_clips(client, params) do
      {:ok, %{"data" => [clip | _]}} -> {:ok, clip}
      {:ok, %{"data" => []}} -> {:ok, nil}
      error -> error
    end
  end

  @doc """
  Streams clips lazily, fetching pages as needed.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:game_id` - Game ID
  - `:started_at` - Start date/time (RFC3339)
  - `:ended_at` - End date/time (RFC3339)
  - `:first` - Number of results per page (max 100, default 100)

  ## Examples

      all_clips = client
                  |> Twitchy.Clips.stream_clips(broadcaster_id: "12345")
                  |> Enum.to_list()

      recent_clips = client
                     |> Twitchy.Clips.stream_clips(
                       game_id: "21779",
                       started_at: "2024-01-01T00:00:00Z"
                     )
                     |> Stream.take(100)
                     |> Enum.to_list()
  """
  @spec stream_clips(Twitchy.t(), keyword()) :: Enumerable.t()
  def stream_clips(client, params) do
    fetch_fn = fn cursor ->
      params = Pagination.add_to_query(params, after: cursor, first: params[:first] || 100)

      case get_clips(client, params) do
        {:ok, response} ->
          {:ok, response["data"], Pagination.get_cursor(response)}

        error ->
          error
      end
    end

    Pagination.stream(fetch_fn)
  end
end
