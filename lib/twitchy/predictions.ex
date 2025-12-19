defmodule Twitchy.Predictions do
  @moduledoc """
  Twitch Predictions API endpoints.

  Provides functions for creating and managing channel Predictions.

  ## Examples

      # Create prediction
      {:ok, response} = Twitchy.Predictions.create_prediction(client,
        broadcaster_id: "12345",
        title: "Will I beat this boss?",
        outcomes: [%{title: "Yes"}, %{title: "No"}],
        prediction_window: 120
      )

      # End prediction
      {:ok, response} = Twitchy.Predictions.end_prediction(client,
        broadcaster_id: "12345",
        id: "prediction-id",
        status: "RESOLVED",
        winning_outcome_id: "outcome-id"
      )
  """

  alias Twitchy.HTTP

  @doc """
  Creates a Prediction.

  Requires the `channel:manage:predictions` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:title` - Prediction title (required, max 45 characters)
  - `:outcomes` - List of outcome maps with `:title` (required, 2-10 outcomes)
  - `:prediction_window` - Duration in seconds (15-1800, required)

  ## Examples

      {:ok, response} = Twitchy.Predictions.create_prediction(client,
        broadcaster_id: "12345",
        title: "Will we win this match?",
        outcomes: [
          %{title: "Victory!"},
          %{title: "Defeat..."}
        ],
        prediction_window: 300
      )
  """
  @spec create_prediction(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def create_prediction(client, params) do
    body = Map.new(params)
    HTTP.post(client, "/predictions", json: body)
  end

  @doc """
  Gets Predictions.

  Requires the `channel:read:predictions` or `channel:manage:predictions` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:id` - Filter by prediction ID(s) (max 100)
  - `:first` - Number of results per page (max 20, default 20)
  - `:after` - Cursor for pagination

  ## Examples

      {:ok, response} = Twitchy.Predictions.get_predictions(client, broadcaster_id: "12345")
  """
  @spec get_predictions(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_predictions(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/predictions", query: query)
  end

  @doc """
  Ends a Prediction.

  Requires the `channel:manage:predictions` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:id` - Prediction ID (required)
  - `:status` - Status (`:RESOLVED`, `:CANCELED`, `:LOCKED`, required)
  - `:winning_outcome_id` - Winning outcome ID (required if status is `:RESOLVED`)

  ## Examples

      # Resolve with winner
      {:ok, response} = Twitchy.Predictions.end_prediction(client,
        broadcaster_id: "12345",
        id: "prediction-id",
        status: "RESOLVED",
        winning_outcome_id: "outcome-id"
      )

      # Cancel prediction
      {:ok, response} = Twitchy.Predictions.end_prediction(client,
        broadcaster_id: "12345",
        id: "prediction-id",
        status: "CANCELED"
      )
  """
  @spec end_prediction(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def end_prediction(client, params) do
    body = Map.new(params)
    HTTP.patch(client, "/predictions", json: body)
  end
end
