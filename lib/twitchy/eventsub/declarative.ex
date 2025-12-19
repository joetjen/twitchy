defmodule Twitchy.EventSub.Declarative do
  @moduledoc """
  Declarative EventSub subscription management.

  Provides a high-level, configuration-based approach to managing EventSub
  subscriptions. Automatically creates, updates, and removes subscriptions
  to match the declared configuration.

  ## Usage

      # Define your desired subscriptions
      config = [
        %{
          type: "channel.follow",
          version: "2",
          condition: %{
            broadcaster_user_id: "12345",
            moderator_user_id: "12345"
          }
        },
        %{
          type: "stream.online",
          version: "1",
          condition: %{
            broadcaster_user_id: "12345"
          }
        }
      ]

      # Start a managed WebSocket connection
      {:ok, pid} = Twitchy.EventSub.Declarative.start_link(
        name: :my_bot,
        client: client,
        subscriptions: config,
        handler: {MyApp.EventHandler, :handle_event, []}
      )

      # Update subscriptions dynamically
      new_config = [
        %{
          type: "channel.update",
          version: "2",
          condition: %{broadcaster_user_id: "12345"}
        }
      ]
      :ok = Twitchy.EventSub.Declarative.update_subscriptions(:my_bot, new_config)

  ## Features

  - **Declarative configuration**: Define subscriptions as data
  - **Automatic reconciliation**: Syncs actual state with desired state
  - **Idempotent**: Safe to call multiple times with same config
  - **Error handling**: Retries failed subscription creation
  - **Telemetry**: Emits events for subscription lifecycle
  """

  use GenServer
  require Logger

  alias Twitchy.EventSub

  defstruct [
    :name,
    :client,
    :websocket_pid,
    :handler,
    :session_id,
    desired_subscriptions: [],
    actual_subscriptions: [],
    pending_subscriptions: []
  ]

  ## Client API

  @doc """
  Starts a declarative EventSub manager.

  ## Options

  - `:name` - Unique name for this manager (required)
  - `:client` - Twitchy client config (required)
  - `:subscriptions` - List of subscription configurations (required)
  - `:handler` - Event handler as `{module, function, args}` or `pid` (required)

  ## Examples

      {:ok, pid} = Twitchy.EventSub.Declarative.start_link(
        name: :my_bot,
        client: client,
        subscriptions: [
          %{
            type: "channel.follow",
            version: "2",
            condition: %{
              broadcaster_user_id: "12345",
              moderator_user_id: "12345"
            }
          }
        ],
        handler: {MyApp.EventHandler, :handle_event, []}
      )
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  @doc """
  Updates the desired subscriptions.

  Reconciles the new configuration with existing subscriptions, creating
  new ones and removing obsolete ones.

  ## Examples

      :ok = Twitchy.EventSub.Declarative.update_subscriptions(:my_bot, [
        %{type: "stream.online", version: "1", condition: %{broadcaster_user_id: "12345"}}
      ])
  """
  @spec update_subscriptions(atom(), [map()]) :: :ok
  def update_subscriptions(name, subscriptions) do
    GenServer.call(via_tuple(name), {:update_subscriptions, subscriptions})
  end

  @doc """
  Gets the current state of subscriptions.

  Returns a map with `:desired`, `:actual`, and `:pending` subscriptions.

  ## Examples

      state = Twitchy.EventSub.Declarative.get_state(:my_bot)
      # => %{
      #   desired: [...],
      #   actual: [...],
      #   pending: [...]
      # }
  """
  @spec get_state(atom()) :: map()
  def get_state(name) do
    GenServer.call(via_tuple(name), :get_state)
  end

  @doc """
  Triggers an immediate reconciliation of subscriptions.

  ## Examples

      :ok = Twitchy.EventSub.Declarative.reconcile(:my_bot)
  """
  @spec reconcile(atom()) :: :ok
  def reconcile(name) do
    GenServer.cast(via_tuple(name), :reconcile)
  end

  @doc """
  Stops the declarative manager and cleans up subscriptions.

  ## Examples

      :ok = Twitchy.EventSub.Declarative.stop(:my_bot)
  """
  @spec stop(atom()) :: :ok
  def stop(name) do
    GenServer.stop(via_tuple(name))
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    client = Keyword.fetch!(opts, :client)
    subscriptions = Keyword.fetch!(opts, :subscriptions)
    handler = Keyword.fetch!(opts, :handler)

    # Wrap the handler to intercept session_welcome messages
    wrapped_handler = {__MODULE__, :handle_websocket_event, [self(), handler]}

    # Start WebSocket connection
    case Twitchy.EventSub.Supervisor.start_websocket(
           name: :"#{name}_websocket",
           client: client,
           handler: wrapped_handler
         ) do
      {:ok, websocket_pid} ->
        state = %__MODULE__{
          name: name,
          client: client,
          websocket_pid: websocket_pid,
          handler: handler,
          desired_subscriptions: normalize_subscriptions(subscriptions)
        }

        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:update_subscriptions, subscriptions}, _from, state) do
    state = %{state | desired_subscriptions: normalize_subscriptions(subscriptions)}
    send(self(), :reconcile)
    {:reply, :ok, state}
  end

  def handle_call(:get_state, _from, state) do
    result = %{
      desired: state.desired_subscriptions,
      actual: state.actual_subscriptions,
      pending: state.pending_subscriptions
    }

    {:reply, result, state}
  end

  @impl true
  def handle_cast(:reconcile, state) do
    state = reconcile_subscriptions(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:session_ready, session_id}, state) do
    Logger.info("EventSub session ready: #{session_id}")
    state = %{state | session_id: session_id}
    state = reconcile_subscriptions(state)
    {:noreply, state}
  end

  def handle_info(:reconcile, state) do
    state = reconcile_subscriptions(state)
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Clean up all subscriptions
    Enum.each(state.actual_subscriptions, fn sub ->
      case EventSub.delete_subscription(state.client, id: sub["id"]) do
        :ok -> :ok
        {:error, reason} -> Logger.error("Failed to delete subscription: #{inspect(reason)}")
      end
    end)

    # Stop WebSocket connection
    if state.websocket_pid do
      Twitchy.EventSub.WebSocket.close(state.websocket_pid)
    end

    :ok
  end

  ## WebSocket Event Handler

  @doc false
  def handle_websocket_event(event, manager_pid, handler) do
    # Check if this is a session_welcome message
    case get_in(event, ["metadata", "message_type"]) do
      "session_welcome" ->
        session_id = get_in(event, ["payload", "session", "id"])
        send(manager_pid, {:session_ready, session_id})

      _ ->
        :ok
    end

    # Forward to the actual handler
    case handler do
      {module, function, args} ->
        apply(module, function, [event | args])

      pid when is_pid(pid) ->
        send(pid, {:eventsub_event, event})
    end
  end

  ## Private Functions

  defp via_tuple(name) do
    {:via, Registry, {Twitchy.EventSub.Registry, {:declarative, name}}}
  end

  defp normalize_subscriptions(subscriptions) do
    Enum.map(subscriptions, fn sub ->
      %{
        "type" => sub[:type] || sub["type"],
        "version" => sub[:version] || sub["version"],
        "condition" => normalize_condition(sub[:condition] || sub["condition"])
      }
    end)
  end

  defp normalize_condition(condition) when is_map(condition) do
    Map.new(condition, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp reconcile_subscriptions(%{session_id: nil} = state) do
    # Wait for session to be established
    state
  end

  defp reconcile_subscriptions(state) do
    # Fetch current subscriptions from API
    case EventSub.get_subscriptions(state.client) do
      {:ok, response} ->
        api_subscriptions = response["data"] || []

        # Filter to only websocket subscriptions for this session
        actual_subscriptions =
          Enum.filter(api_subscriptions, fn sub ->
            get_in(sub, ["transport", "method"]) == "websocket" &&
              get_in(sub, ["transport", "session_id"]) == state.session_id
          end)

        state = %{state | actual_subscriptions: actual_subscriptions}

        # Determine what needs to be created and deleted
        {to_create, to_delete} = diff_subscriptions(state.desired_subscriptions, actual_subscriptions)

        # Delete obsolete subscriptions
        Enum.each(to_delete, fn sub ->
          Logger.info("Deleting subscription: #{sub["type"]} (#{sub["id"]})")

          case EventSub.delete_subscription(state.client, id: sub["id"]) do
            :ok ->
              emit_telemetry(:subscription_deleted, %{subscription_id: sub["id"]}, state)

            {:error, reason} ->
              Logger.error("Failed to delete subscription: #{inspect(reason)}")
              emit_telemetry(:error, %{reason: reason, action: :delete}, state)
          end
        end)

        # Create new subscriptions
        pending =
          Enum.map(to_create, fn desired ->
            Logger.info("Creating subscription: #{desired["type"]}")

            transport = %{
              method: "websocket",
              session_id: state.session_id
            }

            params = [
              type: desired["type"],
              version: desired["version"],
              condition: desired["condition"],
              transport: transport
            ]

            case EventSub.create_subscription(state.client, params) do
              {:ok, response} ->
                subscription = response["data"] |> List.first()
                emit_telemetry(:subscription_created, %{subscription_id: subscription["id"]}, state)
                {:ok, subscription}

              {:error, reason} ->
                Logger.error("Failed to create subscription: #{inspect(reason)}")
                emit_telemetry(:error, %{reason: reason, action: :create}, state)
                {:error, desired}
            end
          end)

        # Update state with pending/failed subscriptions
        newly_created =
          Enum.flat_map(pending, fn
            {:ok, sub} -> [sub]
            _ -> []
          end)

        failed =
          Enum.flat_map(pending, fn
            {:error, desired} -> [desired]
            _ -> []
          end)

        state = %{
          state
          | actual_subscriptions: actual_subscriptions ++ newly_created,
            pending_subscriptions: failed
        }

        # Schedule retry if there are failed subscriptions
        if length(failed) > 0 do
          Process.send_after(self(), :reconcile, 5_000)
        end

        state

      {:error, reason} ->
        Logger.error("Failed to fetch subscriptions: #{inspect(reason)}")
        state
    end
  end

  defp diff_subscriptions(desired, actual) do
    # Find subscriptions to create (in desired but not in actual)
    to_create =
      Enum.reject(desired, fn desired_sub ->
        Enum.any?(actual, fn actual_sub ->
          subscription_matches?(desired_sub, actual_sub)
        end)
      end)

    # Find subscriptions to delete (in actual but not in desired)
    to_delete =
      Enum.reject(actual, fn actual_sub ->
        Enum.any?(desired, fn desired_sub ->
          subscription_matches?(desired_sub, actual_sub)
        end)
      end)

    {to_create, to_delete}
  end

  defp subscription_matches?(desired, actual) do
    desired["type"] == actual["type"] &&
      desired["version"] == actual["version"] &&
      conditions_match?(desired["condition"], actual["condition"])
  end

  defp conditions_match?(desired, actual) do
    # Compare conditions as normalized maps
    desired == actual
  end

  defp emit_telemetry(event, measurements, state) do
    :telemetry.execute(
      [:twitchy, :eventsub, :declarative, event],
      Map.merge(%{system_time: System.system_time()}, measurements),
      %{
        name: state.name,
        session_id: state.session_id,
        desired_count: length(state.desired_subscriptions),
        actual_count: length(state.actual_subscriptions),
        pending_count: length(state.pending_subscriptions)
      }
    )
  end
end
