defmodule Twitchy.Polls do
  @moduledoc """
  Twitch Polls API endpoints.

  Provides functions for creating and managing channel Polls.

  ## Examples

      # Create poll
      {:ok, response} = Twitchy.Polls.create_poll(client,
        broadcaster_id: "12345",
        title: "What game should I play next?",
        choices: [%{title: "League"}, %{title: "Valorant"}],
        duration: 300
      )

      # End poll
      {:ok, response} = Twitchy.Polls.end_poll(client,
        broadcaster_id: "12345",
        id: "poll-id",
        status: "TERMINATED"
      )
  """

  alias Twitchy.HTTP

  @doc """
  Creates a Poll.

  Requires the `channel:manage:polls` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:title` - Poll title (required, max 60 characters)
  - `:choices` - List of choice maps with `:title` (required, 2-5 choices, max 25 chars each)
  - `:duration` - Duration in seconds (15-1800, required)
  - `:channel_points_voting_enabled` - Enable Channel Points voting
  - `:channel_points_per_vote` - Channel Points per vote (min 1, max 1000000)

  ## Examples

      {:ok, response} = Twitchy.Polls.create_poll(client,
        broadcaster_id: "12345",
        title: "What should we do?",
        choices: [
          %{title: "Option A"},
          %{title: "Option B"},
          %{title: "Option C"}
        ],
        duration: 300,
        channel_points_voting_enabled: true,
        channel_points_per_vote: 100
      )
  """
  @spec create_poll(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def create_poll(client, params) do
    body = Map.new(params)
    HTTP.post(client, "/polls", json: body)
  end

  @doc """
  Gets Polls.

  Requires the `channel:read:polls` or `channel:manage:polls` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:id` - Filter by poll ID(s) (max 100)
  - `:first` - Number of results per page (max 20, default 20)
  - `:after` - Cursor for pagination

  ## Examples

      {:ok, response} = Twitchy.Polls.get_polls(client, broadcaster_id: "12345")
  """
  @spec get_polls(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_polls(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/polls", query: query)
  end

  @doc """
  Ends a Poll.

  Requires the `channel:manage:polls` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:id` - Poll ID (required)
  - `:status` - Status (`:TERMINATED` or `:ARCHIVED`, required)

  ## Examples

      {:ok, response} = Twitchy.Polls.end_poll(client,
        broadcaster_id: "12345",
        id: "poll-id",
        status: "TERMINATED"
      )
  """
  @spec end_poll(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def end_poll(client, params) do
    body = Map.new(params)
    HTTP.patch(client, "/polls", json: body)
  end
end
