defmodule Twitchy.Subscriptions do
  @moduledoc """
  Twitch Subscriptions API endpoints.

  Provides functions for retrieving broadcaster subscriptions.

  ## Examples

      # Get broadcaster subscriptions
      {:ok, response} = Twitchy.Subscriptions.get_broadcaster_subscriptions(client,
        broadcaster_id: "12345"
      )

      # Check specific user's subscription
      {:ok, response} = Twitchy.Subscriptions.get_broadcaster_subscriptions(client,
        broadcaster_id: "12345",
        user_id: ["67890"]
      )

      # Stream all subscriptions
      subs = client
             |> Twitchy.Subscriptions.stream_subscriptions(broadcaster_id: "12345")
             |> Enum.to_list()
  """

  alias Twitchy.{HTTP, Pagination}

  @doc """
  Gets broadcaster's subscriptions.

  Requires the `channel:read:subscriptions` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:user_id` - Filter by specific user ID(s) (max 100)
  - `:first` - Number of results per page (max 100, default 20)
  - `:before` - Cursor for backwards pagination
  - `:after` - Cursor for forward pagination

  ## Examples

      # Get all subscriptions
      {:ok, response} = Twitchy.Subscriptions.get_broadcaster_subscriptions(client,
        broadcaster_id: "12345",
        first: 100
      )

      # Check if specific users are subscribed
      {:ok, response} = Twitchy.Subscriptions.get_broadcaster_subscriptions(client,
        broadcaster_id: "12345",
        user_id: ["67890", "11111"]
      )
  """
  @spec get_broadcaster_subscriptions(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_broadcaster_subscriptions(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/subscriptions", query: query)
  end

  @doc """
  Checks if a user is subscribed to the broadcaster.

  Requires the `user:read:subscriptions` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:user_id` - User's ID (required)

  ## Examples

      {:ok, response} = Twitchy.Subscriptions.check_user_subscription(client,
        broadcaster_id: "12345",
        user_id: "67890"
      )
  """
  @spec check_user_subscription(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def check_user_subscription(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/subscriptions/user", query: query)
  end

  @doc """
  Streams broadcaster subscriptions lazily.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:first` - Number of results per page (max 100, default 100)

  ## Examples

      all_subs = client
                 |> Twitchy.Subscriptions.stream_subscriptions(broadcaster_id: "12345")
                 |> Enum.to_list()
  """
  @spec stream_subscriptions(Twitchy.t(), keyword()) :: Enumerable.t()
  def stream_subscriptions(client, params) do
    fetch_fn = fn cursor ->
      params = Pagination.add_to_query(params, after: cursor, first: params[:first] || 100)

      case get_broadcaster_subscriptions(client, params) do
        {:ok, response} ->
          {:ok, response["data"], Pagination.get_cursor(response)}

        error ->
          error
      end
    end

    Pagination.stream(fetch_fn)
  end
end
