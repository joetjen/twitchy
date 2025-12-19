defmodule Twitchy.Charity do
  @moduledoc """
  Twitch Charity API endpoints.

  Provides functions for retrieving charity campaign information.

  ## Examples

      # Get charity campaign
      {:ok, response} = Twitchy.Charity.get_charity_campaign(client,
        broadcaster_id: "12345"
      )

      # Get charity campaign donations
      {:ok, response} = Twitchy.Charity.get_charity_campaign_donations(client,
        broadcaster_id: "12345"
      )
  """

  alias Twitchy.{HTTP, Pagination}

  @doc """
  Gets information about the charity campaign running on the broadcaster's channel.

  Requires the `channel:read:charity` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)

  ## Examples

      {:ok, response} = Twitchy.Charity.get_charity_campaign(client,
        broadcaster_id: "12345"
      )
  """
  @spec get_charity_campaign(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_charity_campaign(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/charity/campaigns", query: query)
  end

  @doc """
  Gets donations made to the broadcaster's charity campaign.

  Requires the `channel:read:charity` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:first` - Number of results per page (max 100, default 20)
  - `:after` - Cursor for pagination

  ## Examples

      {:ok, response} = Twitchy.Charity.get_charity_campaign_donations(client,
        broadcaster_id: "12345",
        first: 100
      )
  """
  @spec get_charity_campaign_donations(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_charity_campaign_donations(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/charity/donations", query: query)
  end

  @doc """
  Streams charity campaign donations lazily.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:first` - Number of results per page (max 100, default 100)

  ## Examples

      donations = client
                  |> Twitchy.Charity.stream_donations(broadcaster_id: "12345")
                  |> Enum.to_list()
  """
  @spec stream_donations(Twitchy.t(), keyword()) :: Enumerable.t()
  def stream_donations(client, params) do
    fetch_fn = fn cursor ->
      params = Pagination.add_to_query(params, after: cursor, first: params[:first] || 100)

      case get_charity_campaign_donations(client, params) do
        {:ok, response} ->
          {:ok, response["data"], Pagination.get_cursor(response)}

        error ->
          error
      end
    end

    Pagination.stream(fetch_fn)
  end
end
