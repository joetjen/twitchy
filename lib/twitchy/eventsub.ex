defmodule Twitchy.EventSub do
  @moduledoc """
  Twitch EventSub Subscription Management API endpoints.

  Provides functions for managing EventSub subscriptions (webhooks and conduits).
  For EventSub WebSocket connections, see `Twitchy.EventSub.WebSocket`.
  For EventSub webhook handling, see `Twitchy.EventSub.Webhook`.

  ## Examples

      # Create subscription
      {:ok, response} = Twitchy.EventSub.create_subscription(client,
        type: "channel.follow",
        version: "2",
        condition: %{
          broadcaster_user_id: "12345",
          moderator_user_id: "12345"
        },
        transport: %{
          method: "webhook",
          callback: "https://example.com/webhooks",
          secret: "your-secret"
        }
      )

      # List subscriptions
      {:ok, response} = Twitchy.EventSub.get_subscriptions(client)

      # Delete subscription
      :ok = Twitchy.EventSub.delete_subscription(client, id: "subscription-id")
  """

  alias Twitchy.{HTTP, Pagination}

  @doc """
  Creates an EventSub subscription.

  ## Parameters

  - `:type` - Subscription type (e.g., "channel.follow", "stream.online", required)
  - `:version` - Subscription version (required)
  - `:condition` - Condition map (required, varies by type)
  - `:transport` - Transport configuration (required)
    - `:method` - "webhook", "websocket", or "conduit"
    - For webhook: `:callback` (URL) and `:secret` (10-100 chars)
    - For websocket: `:session_id`
    - For conduit: `:conduit_id`

  ## Examples

      # Webhook subscription
      {:ok, response} = Twitchy.EventSub.create_subscription(client,
        type: "channel.follow",
        version: "2",
        condition: %{
          broadcaster_user_id: "12345",
          moderator_user_id: "12345"
        },
        transport: %{
          method: "webhook",
          callback: "https://example.com/webhooks",
          secret: "your-webhook-secret-here"
        }
      )

      # WebSocket subscription
      {:ok, response} = Twitchy.EventSub.create_subscription(client,
        type: "stream.online",
        version: "1",
        condition: %{broadcaster_user_id: "12345"},
        transport: %{
          method: "websocket",
          session_id: "websocket-session-id"
        }
      )

      # Conduit subscription
      {:ok, response} = Twitchy.EventSub.create_subscription(client,
        type: "channel.update",
        version: "2",
        condition: %{broadcaster_user_id: "12345"},
        transport: %{
          method: "conduit",
          conduit_id: "conduit-id"
        }
      )
  """
  @spec create_subscription(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def create_subscription(client, params) do
    body = Map.new(params)
    HTTP.post(client, "/eventsub/subscriptions", json: body)
  end

  @doc """
  Deletes an EventSub subscription.

  ## Parameters

  - `:id` - Subscription ID (required)

  ## Examples

      :ok = Twitchy.EventSub.delete_subscription(client, id: "subscription-id")
  """
  @spec delete_subscription(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def delete_subscription(client, params) do
    query = HTTP.build_query(params)

    case HTTP.delete(client, "/eventsub/subscriptions", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Gets EventSub subscriptions.

  ## Parameters

  - `:status` - Filter by status (`:enabled`, `:webhook_callback_verification_pending`, etc.)
  - `:type` - Filter by type (e.g., "channel.follow")
  - `:user_id` - Filter by user ID in condition
  - `:after` - Cursor for pagination

  ## Examples

      # Get all subscriptions
      {:ok, response} = Twitchy.EventSub.get_subscriptions(client)

      # Get subscriptions by type
      {:ok, response} = Twitchy.EventSub.get_subscriptions(client,
        type: "channel.follow"
      )

      # Get subscriptions by status
      {:ok, response} = Twitchy.EventSub.get_subscriptions(client,
        status: "enabled"
      )
  """
  @spec get_subscriptions(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_subscriptions(client, params \\ []) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/eventsub/subscriptions", query: query)
  end

  @doc """
  Streams EventSub subscriptions lazily.

  ## Parameters

  - `:status` - Filter by status
  - `:type` - Filter by type
  - `:user_id` - Filter by user ID

  ## Examples

      subscriptions = client
                      |> Twitchy.EventSub.stream_subscriptions(type: "channel.follow")
                      |> Enum.to_list()
  """
  @spec stream_subscriptions(Twitchy.t(), keyword()) :: Enumerable.t()
  def stream_subscriptions(client, params \\ []) do
    fetch_fn = fn cursor ->
      params = Pagination.add_to_query(params, after: cursor)

      case get_subscriptions(client, params) do
        {:ok, response} ->
          {:ok, response["data"], Pagination.get_cursor(response)}

        error ->
          error
      end
    end

    Pagination.stream(fetch_fn)
  end
end
