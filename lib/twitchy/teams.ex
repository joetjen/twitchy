defmodule Twitchy.Teams do
  @moduledoc """
  Twitch Teams API endpoints.

  Provides functions for retrieving Team information.

  ## Examples

      # Get team by ID
      {:ok, response} = Twitchy.Teams.get_teams(client, id: "team-id")

      # Get team by name
      {:ok, response} = Twitchy.Teams.get_teams(client, name: "team-name")

      # Get channel teams
      {:ok, response} = Twitchy.Teams.get_channel_teams(client, broadcaster_id: "12345")
  """

  alias Twitchy.HTTP

  @doc """
  Gets Team information by Team ID or Team name.

  ## Parameters

  - `:id` - Team ID
  - `:name` - Team name

  Note: Must specify either `:id` or `:name`.

  ## Examples

      {:ok, response} = Twitchy.Teams.get_teams(client, id: "abc123")

      {:ok, response} = Twitchy.Teams.get_teams(client, name: "myteam")
  """
  @spec get_teams(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_teams(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/teams", query: query)
  end

  @doc """
  Gets Teams to which a broadcaster belongs.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)

  ## Examples

      {:ok, response} = Twitchy.Teams.get_channel_teams(client, broadcaster_id: "12345")
  """
  @spec get_channel_teams(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_channel_teams(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/teams/channel", query: query)
  end
end
