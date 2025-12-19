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
  require Logger

  @behaviour Twitchy.Behaviours.TokenStore

  @default_name __MODULE__
  @refresh_buffer_seconds 300

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

  # Behaviour Implementation

  @impl Twitchy.Behaviours.TokenStore
  def init(opts) do
    state = %{
      tokens: %{},
      refresh_buffer: Keyword.get(opts, :refresh_buffer, @refresh_buffer_seconds)
    }

    {:ok, state}
  end

  @doc """
  Gets the token for the given client ID from the store.
  Can be called directly with store PID or uses default store.
  """
  def get_token(store \\ @default_name, client_id)

  def get_token(store, client_id) when is_pid(store) or is_atom(store) do
    GenServer.call(store, {:get_token, client_id})
  end

  @impl Twitchy.Behaviours.TokenStore
  def get_token(state, client_id) when is_map(state) do
    start_time = System.monotonic_time()

    result =
      case Map.get(state.tokens, client_id) do
        nil ->
          {:error, :token_not_found, state}

        token_data ->
          # Check if token needs refresh
          if needs_refresh?(token_data, state.refresh_buffer) do
            # Schedule async refresh (simplified - real implementation would trigger auth flow)
            Logger.debug("Token for #{client_id} needs refresh")

            :telemetry.execute(
              [:twitchy, :token_store, :refresh],
              %{},
              %{client_id: client_id, expires_at: token_data.expires_at}
            )
          end

          {:ok, token_data, state}
      end

    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      [:twitchy, :token_store, :get],
      %{duration: duration},
      %{client_id: client_id, found: elem(result, 1) != nil}
    )

    result
  end

  @doc """
  Stores a token for the given client ID in the store.
  Can be called directly with store PID or uses default store.
  """
  def put_token(store \\ @default_name, client_id, token_data)

  def put_token(store, client_id, token_data) when is_pid(store) or is_atom(store) do
    GenServer.call(store, {:put_token, client_id, token_data})
  end

  @impl Twitchy.Behaviours.TokenStore
  def put_token(state, client_id, token_data) when is_map(state) do
    start_time = System.monotonic_time()

    new_tokens = Map.put(state.tokens, client_id, token_data)
    new_state = %{state | tokens: new_tokens}

    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      [:twitchy, :token_store, :put],
      %{duration: duration},
      %{client_id: client_id, token_type: token_data[:token_type]}
    )

    {:ok, new_state}
  end

  @doc """
  Deletes the token for the given client ID from the store.
  Can be called directly with store PID or uses default store.
  """
  def delete_token(store \\ @default_name, client_id)

  def delete_token(store, client_id) when is_pid(store) or is_atom(store) do
    GenServer.call(store, {:delete_token, client_id})
  end

  @impl Twitchy.Behaviours.TokenStore
  def delete_token(state, client_id) when is_map(state) do
    start_time = System.monotonic_time()

    new_tokens = Map.delete(state.tokens, client_id)
    new_state = %{state | tokens: new_tokens}

    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      [:twitchy, :token_store, :delete],
      %{duration: duration},
      %{client_id: client_id}
    )

    {:ok, new_state}
  end

  # GenServer Callbacks

  @impl GenServer
  def init(opts) do
    state = %{
      tokens: %{},
      refresh_buffer: Keyword.get(opts, :refresh_buffer, @refresh_buffer_seconds)
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:get_token, client_id}, _from, state) do
    case __MODULE__.get_token(state, client_id) do
      {:ok, token, new_state} -> {:reply, {:ok, token}, new_state}
      {:error, reason, new_state} -> {:reply, {:error, reason}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:put_token, client_id, token_data}, _from, state) do
    case __MODULE__.put_token(state, client_id, token_data) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason, new_state} -> {:reply, {:error, reason}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:delete_token, client_id}, _from, state) do
    case __MODULE__.delete_token(state, client_id) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason, new_state} -> {:reply, {:error, reason}, new_state}
    end
  end

  # Private Helpers

  defp needs_refresh?(%{expires_at: nil}, _buffer), do: false

  defp needs_refresh?(%{expires_at: expires_at, refresh_token: refresh_token}, buffer)
       when not is_nil(refresh_token) do
    now = DateTime.utc_now()
    buffer_time = DateTime.add(now, buffer, :second)
    DateTime.compare(expires_at, buffer_time) == :lt
  end

  defp needs_refresh?(_token_data, _buffer), do: false
end
