defmodule Twitchy.Bits do
  @moduledoc """
  Twitch Bits API endpoints.

  Provides functions for retrieving Bits leaderboards and Cheermotes.

  ## Examples

      # Get Bits leaderboard
      {:ok, response} = Twitchy.Bits.get_bits_leaderboard(client, count: 10, period: :all)

      # Get Cheermotes
      {:ok, response} = Twitchy.Bits.get_cheermotes(client, broadcaster_id: "12345")
  """

  alias Twitchy.HTTP

  @doc """
  Gets the Bits leaderboard for the authenticated broadcaster.

  Requires the `bits:read` scope.

  ## Parameters

  - `:count` - Number of results (1-100, default 10)
  - `:period` - Time period (`:day`, `:week`, `:month`, `:year`, `:all`)
  - `:started_at` - Start date (RFC3339, only with `:all` period)
  - `:user_id` - Filter to specific user ID

  ## Examples

      # Top 10 all-time
      {:ok, response} = Twitchy.Bits.get_bits_leaderboard(client, count: 10, period: :all)

      # Weekly leaderboard
      {:ok, response} = Twitchy.Bits.get_bits_leaderboard(client, period: :week)

      # Check specific user's rank
      {:ok, response} = Twitchy.Bits.get_bits_leaderboard(client, user_id: "12345")
  """
  @spec get_bits_leaderboard(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_bits_leaderboard(client, params \\ []) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/bits/leaderboard", query: query)
  end

  @doc """
  Gets Cheermotes that users can use in the broadcaster's chat.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (for custom Cheermotes)

  ## Examples

      # Get global Cheermotes
      {:ok, response} = Twitchy.Bits.get_cheermotes(client)

      # Get Cheermotes including broadcaster's custom ones
      {:ok, response} = Twitchy.Bits.get_cheermotes(client, broadcaster_id: "12345")
  """
  @spec get_cheermotes(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_cheermotes(client, params \\ []) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/bits/cheermotes", query: query)
  end

  @doc """
  Gets a list of Bits products that belong to an Extension.

  Requires the Extension's JWT.

  ## Parameters

  - `:should_include_all` - Include all products (not just active)

  ## Examples

      {:ok, response} = Twitchy.Bits.get_extension_transactions(client)
  """
  @spec get_extension_transactions(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_extension_transactions(client, params \\ []) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/extensions/transactions", query: query)
  end
end
