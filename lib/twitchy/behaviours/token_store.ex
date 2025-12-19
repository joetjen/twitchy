defmodule Twitchy.Behaviours.TokenStore do
  @moduledoc """
  Behaviour for implementing custom token storage backends.

  Token stores are responsible for persisting and retrieving OAuth tokens,
  enabling token sharing across processes and token refresh management.

  ## Built-in Implementations

  - `Twitchy.TokenStore.Memory` - In-memory GenServer storage (default)

  ## Custom Implementations

  You can implement this behaviour to store tokens in:
  - Redis
  - Database (PostgreSQL, MySQL, etc.)
  - File system
  - External key-value stores

  ## Example Implementation

      defmodule MyApp.RedisTokenStore do
        @behaviour Twitchy.Behaviours.TokenStore

        @impl true
        def init(opts) do
          redis_url = Keyword.fetch!(opts, :redis_url)
          {:ok, conn} = Redix.start_link(redis_url)
          {:ok, %{conn: conn}}
        end

        @impl true
        def get_token(state, client_id) do
          case Redix.command(state.conn, ["GET", "twitchy:token:\#{client_id}"]) do
            {:ok, nil} -> {:ok, nil, state}
            {:ok, json} -> {:ok, Jason.decode!(json), state}
            {:error, reason} -> {:error, reason, state}
          end
        end

        @impl true
        def put_token(state, client_id, token_data) do
          json = Jason.encode!(token_data)
          case Redix.command(state.conn, ["SET", "twitchy:token:\#{client_id}", json]) do
            {:ok, _} -> {:ok, state}
            {:error, reason} -> {:error, reason, state}
          end
        end

        @impl true
        def delete_token(state, client_id) do
          case Redix.command(state.conn, ["DEL", "twitchy:token:\#{client_id}"]) do
            {:ok, _} -> {:ok, state}
            {:error, reason} -> {:error, reason, state}
          end
        end
      end

  ## Token Data Format

  Token data is stored as a map with the following keys:

      %{
        access_token: "token_string",
        refresh_token: "refresh_token_string",  # Optional
        token_type: :app_access | :user_access,
        expires_at: ~U[2024-01-01 12:00:00Z],  # DateTime
        scopes: ["user:read:email"]
      }
  """

  @type state :: term()
  @type client_id :: String.t()
  @type token_data :: %{
          access_token: String.t(),
          refresh_token: String.t() | nil,
          token_type: :app_access | :user_access,
          expires_at: DateTime.t() | nil,
          scopes: [String.t()]
        }
  @type init_opts :: keyword()

  @doc """
  Initialize the token store with the given options.

  Called when the token store is first started. Should return `{:ok, state}`
  where state is any term that will be passed to subsequent callbacks.

  ## Examples

      def init(opts) do
        db_conn = Keyword.fetch!(opts, :database)
        {:ok, %{conn: db_conn}}
      end
  """
  @callback init(init_opts()) :: {:ok, state()} | {:error, term()}

  @doc """
  Retrieve a token for the given client ID.

  Should return:
  - `{:ok, token_data, new_state}` if token found
  - `{:ok, nil, new_state}` if no token found
  - `{:error, reason, new_state}` if an error occurred
  """
  @callback get_token(state(), client_id()) ::
              {:ok, token_data() | nil, state()} | {:error, term(), state()}

  @doc """
  Store a token for the given client ID.

  Should return:
  - `{:ok, new_state}` if successful
  - `{:error, reason, new_state}` if an error occurred
  """
  @callback put_token(state(), client_id(), token_data()) ::
              {:ok, state()} | {:error, term(), state()}

  @doc """
  Delete a token for the given client ID.

  Should return:
  - `{:ok, new_state}` if successful
  - `{:error, reason, new_state}` if an error occurred
  """
  @callback delete_token(state(), client_id()) ::
              {:ok, state()} | {:error, term(), state()}
end
