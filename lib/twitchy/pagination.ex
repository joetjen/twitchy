defmodule Twitchy.Pagination do
  @moduledoc """
  Handles cursor-based pagination for Twitch API responses.

  Twitch uses cursor-based pagination with `after` and `before` cursors.
  This module provides utilities for handling paginated requests and
  streaming results lazily.

  ## Telemetry Events

  Emits `[:twitchy, :pagination, :fetch]` events with metadata:
  - `cursor` - Current pagination cursor
  - `page_number` - Page number being fetched
  - `total_fetched` - Total items fetched so far
  - `endpoint` - API endpoint being paginated

  ## Examples

      # Manual pagination
      response = Twitchy.Users.get_users(client, login: ["user1", "user2"])
      next_cursor = get_in(response, ["pagination", "cursor"])

      # Lazy streaming (fetches pages as needed)
      client
      |> Twitchy.Users.stream_followers(broadcaster_id: "12345")
      |> Stream.take(100)
      |> Enum.to_list()
  """

  @type cursor :: String.t() | nil
  @type page_response :: {:ok, list(), cursor()} | {:error, term()}

  @doc """
  Streams paginated results lazily.

  Given a function that fetches a page, returns a Stream that will automatically
  fetch subsequent pages as needed.

  ## Parameters

  - `fetch_page_fn` - Function that takes a cursor and returns `{:ok, items, next_cursor}`
  - `initial_cursor` - Optional starting cursor. Defaults to `nil`, which fetches the first
    page (not "no more pages" — the stream only halts once a fetch returns a `nil`
    `next_cursor` or an empty item list)

  ## Examples

      fetch_fn = fn cursor ->
        case Twitchy.Users.get_followers(client, broadcaster_id: "12345", after: cursor) do
          {:ok, response} ->
            items = response["data"]
            next_cursor = get_in(response, ["pagination", "cursor"])
            {:ok, items, next_cursor}
          error ->
            error
        end
      end

      stream = Twitchy.Pagination.stream(fetch_fn)
      followers = stream |> Enum.take(50)
  """
  @spec stream((cursor() -> page_response()), cursor()) :: Enumerable.t()
  def stream(fetch_page_fn, initial_cursor \\ nil) do
    Stream.resource(
      fn -> {0, 0, initial_cursor, :fetch} end,
      fn
        {_page, _total, _cursor, :halt} ->
          {:halt, nil}

        {page_num, total_fetched, cursor, :fetch} ->
          start_time = System.monotonic_time()

          case fetch_page_fn.(cursor) do
            {:ok, [], _next_cursor} ->
              {:halt, nil}

            {:ok, items, next_cursor} ->
              handle_page(items, next_cursor, page_num, total_fetched, cursor, start_time)

            {:error, reason} ->
              raise "Pagination error: #{inspect(reason)}"
          end
      end,
      fn _ -> :ok end
    )
  end

  defp handle_page(items, next_cursor, page_num, total_fetched, cursor, start_time) do
    page_num = page_num + 1
    total_fetched = total_fetched + length(items)
    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      [:twitchy, :pagination, :fetch],
      %{duration: duration, count: length(items)},
      %{
        cursor: cursor,
        page_number: page_num,
        total_fetched: total_fetched
      }
    )

    next_action = if is_nil(next_cursor), do: :halt, else: :fetch

    {items, {page_num, total_fetched, next_cursor, next_action}}
  end

  @doc """
  Fetches all pages and concatenates results.

  **Warning**: This will fetch all available pages. Use with caution for endpoints
  that may return large amounts of data. Consider using `stream/2` with `Enum.take/2` instead.

  ## Examples

      iex> fetch_fn = fn cursor -> {:ok, items, next_cursor} end
      iex> {:ok, all_items} = Twitchy.Pagination.fetch_all(fetch_fn)
      {:ok, [...]}
  """
  @spec fetch_all((cursor() -> page_response()), cursor()) :: {:ok, list()} | {:error, term()}
  def fetch_all(fetch_page_fn, initial_cursor \\ nil) do
    items =
      fetch_page_fn
      |> stream(initial_cursor)
      |> Enum.to_list()

    {:ok, items}
  rescue
    error -> {:error, error}
  end

  @doc """
  Adds pagination parameters to a query.

  ## Examples

      iex> Twitchy.Pagination.add_to_query([first: 20], after: "cursor123")
      [first: 20, after: "cursor123"]

      iex> Twitchy.Pagination.add_to_query([], first: 100, after: "cursor")
      [first: 100, after: "cursor"]
  """
  @spec add_to_query(keyword(), keyword()) :: keyword()
  def add_to_query(query, pagination_opts) do
    pagination_opts =
      pagination_opts
      |> Keyword.take([:first, :after, :before])
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    Keyword.merge(query, pagination_opts)
  end

  @doc """
  Extracts pagination cursor from API response.

  ## Examples

      iex> response = %{"pagination" => %{"cursor" => "eyJiIjp7Ik9..."}}
      iex> Twitchy.Pagination.get_cursor(response)
      "eyJiIjp7Ik9..."

      iex> response = %{"data" => []}
      iex> Twitchy.Pagination.get_cursor(response)
      nil
  """
  @spec get_cursor(map()) :: cursor()
  def get_cursor(response) when is_map(response) do
    get_in(response, ["pagination", "cursor"])
  end

  @doc """
  Checks if there are more pages available.

  ## Examples

      iex> response = %{"pagination" => %{"cursor" => "abc123"}}
      iex> Twitchy.Pagination.has_more?(response)
      true

      iex> response = %{"data" => []}
      iex> Twitchy.Pagination.has_more?(response)
      false
  """
  @spec has_more?(map()) :: boolean()
  def has_more?(response) when is_map(response) do
    not is_nil(get_cursor(response))
  end
end
