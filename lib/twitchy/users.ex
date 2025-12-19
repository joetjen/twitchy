defmodule Twitchy.Users do
  @moduledoc """
  Twitch Users API endpoints.

  Provides functions for managing and retrieving user information, blocks, and follows.

  ## Scopes Required

  Different endpoints require different scopes:
  - `get_users/2` - No scope required (public data) or `user:read:email` (for email)
  - `update_user/2` - `user:edit`
  - `get_user_block_list/2` - `user:read:blocked_users`
  - `block_user/3` - `user:manage:blocked_users`
  - `unblock_user/2` - `user:manage:blocked_users`
  - `get_user_follows/2` - No scope required (deprecated, use get_channel_followers instead)

  ## Examples

      # Get users by login
      {:ok, response} = Twitchy.Users.get_users(client, login: ["shroud", "ninja"])

      # Get users by ID
      {:ok, response} = Twitchy.Users.get_users(client, id: ["12345", "67890"])

      # Get authenticated user
      {:ok, response} = Twitchy.Users.get_users(client)

      # Stream followers
      client
      |> Twitchy.Users.stream_followers(broadcaster_id: "12345")
      |> Stream.take(100)
      |> Enum.to_list()
  """

  alias Twitchy.{HTTP, Pagination}

  @doc """
  Gets information about one or more users.

  If no parameters are provided, returns the authenticated user's information.

  ## Parameters

  - `:id` - User ID(s) to look up (max 100)
  - `:login` - User login name(s) to look up (max 100)

  ## Examples

      {:ok, %{"data" => users}} = Twitchy.Users.get_users(client, login: ["shroud"])

      {:ok, %{"data" => users}} = Twitchy.Users.get_users(client, id: ["12345", "67890"])
  """
  @spec get_users(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_users(client, params \\ []) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/users", query: query)
  end

  @doc """
  Gets a single user by login name.

  Convenience function that extracts the first user from the response.

  ## Examples

      {:ok, user} = Twitchy.Users.get_user(client, login: "shroud")
  """
  @spec get_user(Twitchy.t(), keyword()) :: {:ok, map() | nil} | {:error, Exception.t()}
  def get_user(client, params) do
    case get_users(client, params) do
      {:ok, %{"data" => [user | _]}} -> {:ok, user}
      {:ok, %{"data" => []}} -> {:ok, nil}
      error -> error
    end
  end

  @doc """
  Updates the authenticated user's description.

  Requires the `user:edit` scope.

  ## Parameters

  - `:description` - New user description (max 300 characters)

  ## Examples

      {:ok, %{"data" => [user]}} = Twitchy.Users.update_user(client, description: "New description")
  """
  @spec update_user(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def update_user(client, params) do
    HTTP.put(client, "/users", params: params)
  end

  @doc """
  Gets the authenticated user's list of blocked users.

  Requires the `user:read:blocked_users` scope.

  ## Parameters

  - `:broadcaster_id` - User ID of the broadcaster (required)
  - `:first` - Number of results per page (max 100, default 20)
  - `:after` - Cursor for pagination

  ## Examples

      {:ok, response} = Twitchy.Users.get_user_block_list(client, broadcaster_id: "12345")
  """
  @spec get_user_block_list(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_user_block_list(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/users/blocks", query: query)
  end

  @doc """
  Blocks a user.

  Requires the `user:manage:blocked_users` scope.

  ## Parameters

  - `target_user_id` - ID of the user to block
  - `opts` - Optional parameters:
    - `:source_context` - Source context (`:chat`, `:whisper`)
    - `:reason` - Reason for blocking (`:spam`, `:harassment`, `:other`)

  ## Examples

      :ok = Twitchy.Users.block_user(client, "67890", source_context: :chat, reason: :spam)
  """
  @spec block_user(Twitchy.t(), String.t(), keyword()) :: :ok | {:error, Exception.t()}
  def block_user(client, target_user_id, opts \\ []) do
    params = Keyword.put(opts, :target_user_id, target_user_id)

    case HTTP.put(client, "/users/blocks", params: params) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Unblocks a user.

  Requires the `user:manage:blocked_users` scope.

  ## Examples

      :ok = Twitchy.Users.unblock_user(client, "67890")
  """
  @spec unblock_user(Twitchy.t(), String.t()) :: :ok | {:error, Exception.t()}
  def unblock_user(client, target_user_id) do
    query = [target_user_id: target_user_id]

    case HTTP.delete(client, "/users/blocks", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Gets the list of users that follow the specified broadcaster.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:user_id` - Filter to check if specific user follows broadcaster
  - `:first` - Number of results per page (max 100, default 20)
  - `:after` - Cursor for pagination

  ## Examples

      {:ok, response} = Twitchy.Users.get_channel_followers(client, broadcaster_id: "12345")
  """
  @spec get_channel_followers(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_channel_followers(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/channels/followers", query: query)
  end

  @doc """
  Gets the list of channels that the specified user follows.

  ## Parameters

  - `:user_id` - User's ID (required)
  - `:broadcaster_id` - Filter to check if user follows specific broadcaster
  - `:first` - Number of results per page (max 100, default 20)
  - `:after` - Cursor for pagination

  ## Examples

      {:ok, response} = Twitchy.Users.get_channel_followed(client, user_id: "12345")
  """
  @spec get_channel_followed(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_channel_followed(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/channels/followed", query: query)
  end

  @doc """
  Streams followers lazily, fetching pages as needed.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:first` - Number of results per page (max 100, default 100)

  ## Examples

      followers = client
                  |> Twitchy.Users.stream_followers(broadcaster_id: "12345")
                  |> Stream.take(500)
                  |> Enum.to_list()
  """
  @spec stream_followers(Twitchy.t(), keyword()) :: Enumerable.t()
  def stream_followers(client, params) do
    fetch_fn = fn cursor ->
      params = Pagination.add_to_query(params, after: cursor, first: params[:first] || 100)

      case get_channel_followers(client, params) do
        {:ok, response} ->
          {:ok, response["data"], Pagination.get_cursor(response)}

        error ->
          error
      end
    end

    Pagination.stream(fetch_fn)
  end

  @doc """
  Streams channels that a user follows, fetching pages as needed.

  ## Parameters

  - `:user_id` - User's ID (required)
  - `:first` - Number of results per page (max 100, default 100)

  ## Examples

      followed = client
                 |> Twitchy.Users.stream_followed(user_id: "12345")
                 |> Enum.to_list()
  """
  @spec stream_followed(Twitchy.t(), keyword()) :: Enumerable.t()
  def stream_followed(client, params) do
    fetch_fn = fn cursor ->
      params = Pagination.add_to_query(params, after: cursor, first: params[:first] || 100)

      case get_channel_followed(client, params) do
        {:ok, response} ->
          {:ok, response["data"], Pagination.get_cursor(response)}

        error ->
          error
      end
    end

    Pagination.stream(fetch_fn)
  end

  @doc """
  Gets the user's active extensions.

  ## Examples

      {:ok, response} = Twitchy.Users.get_user_active_extensions(client, user_id: "12345")
  """
  @spec get_user_active_extensions(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_user_active_extensions(client, params \\ []) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/users/extensions", query: query)
  end

  @doc """
  Updates the user's installed extensions.

  Requires the `user:edit:broadcast` or `user:read:broadcast` scope.

  ## Examples

      {:ok, response} = Twitchy.Users.update_user_extensions(client, data: %{...})
  """
  @spec update_user_extensions(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def update_user_extensions(client, params) do
    data = Keyword.get(params, :data, %{})
    HTTP.put(client, "/users/extensions", json: data)
  end
end
