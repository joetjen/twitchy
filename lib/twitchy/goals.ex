defmodule Twitchy.Goals do
  @moduledoc """
  Twitch Creator Goals API endpoints.

  Provides functions for retrieving creator goals information.

  ## Examples

      # Get creator goals
      {:ok, response} = Twitchy.Goals.get_creator_goals(client,
        broadcaster_id: "12345"
      )
  """

  alias Twitchy.HTTP

  @doc """
  Gets the broadcaster's list of active goals.

  Requires the `channel:read:goals` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)

  ## Examples

      {:ok, response} = Twitchy.Goals.get_creator_goals(client,
        broadcaster_id: "12345"
      )
  """
  @spec get_creator_goals(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_creator_goals(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/goals", query: query)
  end
end
