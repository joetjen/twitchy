defmodule Twitchy.ContentClassification do
  @moduledoc """
  Twitch Content Classification Labels API endpoints.

  Provides functions for retrieving content classification labels.

  ## Examples

      # Get content classification labels
      {:ok, response} = Twitchy.ContentClassification.get_content_classification_labels(client)

      # Filter by locale
      {:ok, response} = Twitchy.ContentClassification.get_content_classification_labels(client,
        locale: "en-US"
      )
  """

  alias Twitchy.HTTP

  @doc """
  Gets information about Twitch content classification labels.

  ## Parameters

  - `:locale` - Locale for label descriptions (e.g., "en-US", "es-MX")

  ## Examples

      # Get all labels
      {:ok, response} = Twitchy.ContentClassification.get_content_classification_labels(client)

      # Get labels in Spanish
      {:ok, response} = Twitchy.ContentClassification.get_content_classification_labels(client,
        locale: "es-MX"
      )
  """
  @spec get_content_classification_labels(Twitchy.t(), keyword()) ::
          {:ok, map()} | {:error, Exception.t()}
  def get_content_classification_labels(client, params \\ []) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/content_classification_labels", query: query)
  end
end
