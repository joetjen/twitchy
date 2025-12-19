defmodule Twitchy.Raids do
  @moduledoc """
  Twitch Raids API endpoints.

  Provides functions for starting raids.

  ## Examples

      # Start a raid
      :ok = Twitchy.Raids.start_raid(client,
        from_broadcaster_id: "12345",
        to_broadcaster_id: "67890"
      )

      # Cancel a raid
      :ok = Twitchy.Raids.cancel_raid(client, broadcaster_id: "12345")
  """

  alias Twitchy.HTTP

  @doc """
  Starts a raid from the broadcaster's channel to another channel.

  Requires the `channel:manage:raids` scope.

  ## Parameters

  - `:from_broadcaster_id` - Raiding broadcaster's user ID (required)
  - `:to_broadcaster_id` - Target broadcaster's user ID (required)

  ## Examples

      :ok = Twitchy.Raids.start_raid(client,
        from_broadcaster_id: "12345",
        to_broadcaster_id: "67890"
      )
  """
  @spec start_raid(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def start_raid(client, params) do
    query = HTTP.build_query(params)

    case HTTP.post(client, "/raids", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Cancels a pending raid.

  Requires the `channel:manage:raids` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)

  ## Examples

      :ok = Twitchy.Raids.cancel_raid(client, broadcaster_id: "12345")
  """
  @spec cancel_raid(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def cancel_raid(client, params) do
    query = HTTP.build_query(params)

    case HTTP.delete(client, "/raids", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end
end
