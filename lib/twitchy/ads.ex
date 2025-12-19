defmodule Twitchy.Ads do
  @moduledoc """
  Twitch Ads API endpoints.

  Provides functions for starting commercial breaks.

  ## Examples

      # Start 30-second commercial
      {:ok, response} = Twitchy.Ads.start_commercial(client,
        broadcaster_id: "12345",
        length: 30
      )
  """

  alias Twitchy.HTTP

  @doc """
  Starts a commercial break on the broadcaster's channel.

  Requires the `channel:edit:commercial` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:length` - Commercial length in seconds (30, 60, 90, 120, 150, or 180)

  ## Examples

      {:ok, response} = Twitchy.Ads.start_commercial(client,
        broadcaster_id: "12345",
        length: 60
      )
  """
  @spec start_commercial(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def start_commercial(client, params) do
    body = Map.new(params)
    HTTP.post(client, "/channels/commercial", json: body)
  end

  @doc """
  Gets ad schedule information for the broadcaster.

  Requires the `channel:read:ads` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)

  ## Examples

      {:ok, response} = Twitchy.Ads.get_ad_schedule(client, broadcaster_id: "12345")
  """
  @spec get_ad_schedule(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_ad_schedule(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/channels/ads", query: query)
  end

  @doc """
  Delays running scheduled ads for the broadcaster.

  Requires the `channel:manage:ads` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:duration` - Delay duration in seconds (60-180, required)

  ## Examples

      {:ok, response} = Twitchy.Ads.snooze_next_ad(client,
        broadcaster_id: "12345",
        duration: 60
      )
  """
  @spec snooze_next_ad(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def snooze_next_ad(client, params) do
    query = HTTP.build_query(params)
    HTTP.post(client, "/channels/ads/schedule/snooze", query: query)
  end
end
