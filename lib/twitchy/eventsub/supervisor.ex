defmodule Twitchy.EventSub.Supervisor do
  @moduledoc """
  Supervisor for EventSub WebSocket connections.

  Manages multiple EventSub WebSocket connections using a DynamicSupervisor
  and Registry for name-based lookups.

  ## Usage

      # Start the supervisor (usually done in your application supervision tree)
      {:ok, _pid} = Twitchy.EventSub.Supervisor.start_link()

      # Start a new WebSocket connection
      {:ok, pid} = Twitchy.EventSub.Supervisor.start_websocket(
        name: :my_connection,
        client: client,
        handler: {MyApp.EventHandler, :handle_event, []}
      )

      # Look up a connection by name
      {:ok, pid} = Twitchy.EventSub.Supervisor.whereis(:my_connection)

      # Stop a connection
      :ok = Twitchy.EventSub.Supervisor.stop_websocket(:my_connection)

      # List all active connections
      connections = Twitchy.EventSub.Supervisor.list_connections()
  """

  use Supervisor

  alias Twitchy.EventSub.WebSocket

  @registry_name Twitchy.EventSub.Registry
  @supervisor_name Twitchy.EventSub.DynamicSupervisor

  ## Client API

  @doc """
  Starts the EventSub supervisor.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Starts a new EventSub WebSocket connection.

  ## Options

  - `:name` - Unique name for the connection (required)
  - `:client` - Twitchy client config (required)
  - `:handler` - Event handler as `{module, function, args}` or `pid` (required)

  ## Examples

      {:ok, pid} = Twitchy.EventSub.Supervisor.start_websocket(
        name: :my_bot,
        client: client,
        handler: {MyApp.Handler, :handle_event, []}
      )
  """
  @spec start_websocket(keyword()) :: DynamicSupervisor.on_start_child()
  def start_websocket(opts) do
    name = Keyword.fetch!(opts, :name)

    child_spec = %{
      id: name,
      start: {Twitchy.EventSub.WebSocket, :start_link, [Keyword.put(opts, :name, via_tuple(name))]},
      restart: :transient
    }

    DynamicSupervisor.start_child(@supervisor_name, child_spec)
  end

  @doc """
  Stops an EventSub WebSocket connection.

  ## Examples

      :ok = Twitchy.EventSub.Supervisor.stop_websocket(:my_bot)
  """
  @spec stop_websocket(atom()) :: :ok | {:error, :not_found}
  def stop_websocket(name) do
    case whereis(name) do
      {:ok, pid} ->
        DynamicSupervisor.terminate_child(@supervisor_name, pid)

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Looks up a WebSocket connection by name.

  ## Examples

      {:ok, pid} = Twitchy.EventSub.Supervisor.whereis(:my_bot)
  """
  @spec whereis(atom()) :: {:ok, pid()} | {:error, :not_found}
  def whereis(name) do
    case Registry.lookup(@registry_name, name) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all active WebSocket connections.

  Returns a list of `{name, pid}` tuples.

  ## Examples

      connections = Twitchy.EventSub.Supervisor.list_connections()
      # => [{:my_bot, #PID<0.123.0>}, {:another_bot, #PID<0.124.0>}]
  """
  @spec list_connections() :: [{atom(), pid()}]
  def list_connections do
    Registry.select(@registry_name, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
  end

  @doc """
  Gets the session ID for a WebSocket connection.

  ## Examples

      {:ok, session_id} = Twitchy.EventSub.Supervisor.get_session_id(:my_bot)
  """
  @spec get_session_id(atom()) :: {:ok, String.t()} | {:error, :not_found | :not_connected}
  def get_session_id(name) do
    case whereis(name) do
      {:ok, pid} -> WebSocket.get_session_id(pid)
      error -> error
    end
  end

  @doc """
  Gets the subscriptions for a WebSocket connection.

  ## Examples

      {:ok, subscriptions} = Twitchy.EventSub.Supervisor.get_subscriptions(:my_bot)
  """
  @spec get_subscriptions(atom()) :: {:ok, [map()]} | {:error, :not_found}
  def get_subscriptions(name) do
    case whereis(name) do
      {:ok, pid} -> WebSocket.get_subscriptions(pid)
      error -> error
    end
  end

  ## Supervisor Callbacks

  @impl true
  def init(_opts) do
    children = [
      {Registry, keys: :unique, name: @registry_name},
      {DynamicSupervisor, strategy: :one_for_one, name: @supervisor_name}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  ## Private Functions

  defp via_tuple(name) do
    {:via, Registry, {@registry_name, name}}
  end
end
