defmodule Twitchy.TokenStore.Memory do
  @moduledoc """
  In-memory token storage implementation using a GenServer.

  This is the default token store for Twitchy. Tokens are stored in process memory
  and will be lost when the application restarts.

  ## Features

  - Automatic token refresh before expiration
  - Process-based storage (survives across client instances)
  - Telemetry events for token operations

  ## Usage

      # Using default memory store
      client = Twitchy.new(client_id: "id", client_secret: "secret")

      # Using custom memory store with options
      client = Twitchy.new(
        client_id: "id",
        token_store: {Twitchy.TokenStore.Memory, name: MyApp.TwitchTokenStore}
      )

  ## Telemetry Events

  - `[:twitchy, :token_store, :get]` - Token retrieval
  - `[:twitchy, :token_store, :put]` - Token storage
  - `[:twitchy, :token_store, :delete]` - Token deletion
  - `[:twitchy, :token_store, :refresh]` - Automatic token refresh
  """

  use GenServer

  alias Twitchy.TokenStore.Memory.State

  @default_name __MODULE__

  # Client API

  @doc """
  Starts the token store GenServer.

  ## Options

  - `:name` - Name to register the GenServer (default: `Twitchy.TokenStore.Memory`)
  - `:refresh_buffer` - Seconds before expiration to trigger refresh (default: 300)
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @default_name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Gets the token for the given client ID from the store.
  Can be called directly with store PID or uses default store.
  """
  def get_token(store \\ @default_name, client_id) do
    GenServer.call(store, {:get_token, client_id})
  end

  @doc """
  Stores a token for the given client ID in the store.
  Can be called directly with store PID or uses default store.
  """
  def put_token(store \\ @default_name, client_id, token_data) do
    GenServer.call(store, {:put_token, client_id, token_data})
  end

  @doc """
  Deletes the token for the given client ID from the store.
  Can be called directly with store PID or uses default store.
  """
  def delete_token(store \\ @default_name, client_id) do
    GenServer.call(store, {:delete_token, client_id})
  end

  # GenServer Callbacks

  @impl GenServer
  def init(opts) do
    State.init(opts)
  end

  @impl GenServer
  def handle_call({:get_token, client_id}, _from, state) do
    case State.get_token(state, client_id) do
      {:ok, token, new_state} -> {:reply, {:ok, token}, new_state}
      {:error, reason, new_state} -> {:reply, {:error, reason}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:put_token, client_id, token_data}, _from, state) do
    {:ok, new_state} = State.put_token(state, client_id, token_data)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:delete_token, client_id}, _from, state) do
    {:ok, new_state} = State.delete_token(state, client_id)
    {:reply, :ok, new_state}
  end
end
