defmodule Twitchy.Whispers do
  @moduledoc """
  Twitch Whispers API endpoints.

  Provides functions for sending whispers (direct messages).

  ## Examples

      # Send whisper
      :ok = Twitchy.Whispers.send_whisper(client,
        from_user_id: "12345",
        to_user_id: "67890",
        message: "Hello!"
      )
  """

  alias Twitchy.HTTP

  @doc """
  Sends a whisper from one user to another.

  Requires the `user:manage:whispers` scope.

  ## Parameters

  - `:from_user_id` - Sender's user ID (required, must match token user)
  - `:to_user_id` - Recipient's user ID (required)
  - `:message` - Message text (required, max 500 characters)

  ## Examples

      :ok = Twitchy.Whispers.send_whisper(client,
        from_user_id: "12345",
        to_user_id: "67890",
        message: "Hello from the API!"
      )
  """
  @spec send_whisper(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def send_whisper(client, params) do
    {from_user_id, params} = Keyword.pop!(params, :from_user_id)
    {to_user_id, params} = Keyword.pop!(params, :to_user_id)

    query = [from_user_id: from_user_id, to_user_id: to_user_id]
    body = Map.new(params)

    case HTTP.post(client, "/whispers", query: query, json: body) do
      {:ok, _} -> :ok
      error -> error
    end
  end
end
