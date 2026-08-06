defmodule Twitchy.EventSub.WebSocket do
  @moduledoc """
  EventSub WebSocket client implementation.

  Manages persistent WebSocket connections to Twitch EventSub, handling:
  - Connection lifecycle (connect, reconnect, disconnect)
  - Session management with welcome/reconnect messages
  - Keepalive heartbeat monitoring
  - Automatic reconnection on failures
  - Message dispatching to subscribed processes
  - Telemetry instrumentation

  ## Usage

      # Start a WebSocket connection
      {:ok, pid} = Twitchy.EventSub.WebSocket.start_link(
        client: client,
        handler: {MyApp.EventHandler, :handle_event, [extra_arg]}
      )

      # Subscribe to events in the handler module
      defmodule MyApp.EventHandler do
        def handle_event(event, extra_arg) do
          IO.inspect(event, label: "Received event")
          :ok
        end
      end

  ## Telemetry Events

  - `[:twitchy, :eventsub, :websocket, :connected]` - Connection established
  - `[:twitchy, :eventsub, :websocket, :disconnected]` - Connection closed
  - `[:twitchy, :eventsub, :websocket, :message]` - Message received
  - `[:twitchy, :eventsub, :websocket, :keepalive]` - Keepalive received
  - `[:twitchy, :eventsub, :websocket, :reconnect]` - Reconnection initiated
  - `[:twitchy, :eventsub, :websocket, :error]` - Error occurred
  """

  use GenServer
  require Logger

  @websocket_url "wss://eventsub.wss.twitch.tv/ws"
  @keepalive_timeout_ms 10_000 + 1_000
  @reconnect_delay_ms 1_000

  defstruct [
    :client,
    :handler,
    :conn,
    :websocket,
    :session_id,
    :reconnect_url,
    :keepalive_timer,
    :request_ref,
    subscriptions: []
  ]

  ## Client API

  @doc """
  Starts a WebSocket connection.

  ## Options

  - `:client` - Twitchy client config (required)
  - `:handler` - Event handler as `{module, function, args}` or `pid` (required)
  - `:name` - Registered name for the process
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    if name do
      GenServer.start_link(__MODULE__, opts, name: name)
    else
      GenServer.start_link(__MODULE__, opts)
    end
  end

  @doc """
  Gets the current session ID.
  """
  @spec get_session_id(GenServer.server()) :: {:ok, String.t()} | {:error, :not_connected}
  def get_session_id(server) do
    GenServer.call(server, :get_session_id)
  end

  @doc """
  Gets the list of active subscriptions.
  """
  @spec get_subscriptions(GenServer.server()) :: {:ok, [map()]}
  def get_subscriptions(server) do
    GenServer.call(server, :get_subscriptions)
  end

  @doc """
  Closes the WebSocket connection gracefully.
  """
  @spec close(GenServer.server()) :: :ok
  def close(server) do
    GenServer.call(server, :close)
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    client = Keyword.fetch!(opts, :client)
    handler = Keyword.fetch!(opts, :handler)

    state = %__MODULE__{
      client: client,
      handler: handler
    }

    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    case connect(state) do
      {:ok, new_state} ->
        {:noreply, new_state}

      {:error, reason} ->
        emit_telemetry(:error, %{reason: reason}, state)
        Logger.error("Failed to connect EventSub WebSocket: #{inspect(reason)}")
        schedule_reconnect()
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:get_session_id, _from, %{session_id: nil} = state) do
    {:reply, {:error, :not_connected}, state}
  end

  def handle_call(:get_session_id, _from, %{session_id: session_id} = state) do
    {:reply, {:ok, session_id}, state}
  end

  def handle_call(:get_subscriptions, _from, %{subscriptions: subs} = state) do
    {:reply, {:ok, subs}, state}
  end

  def handle_call(:close, _from, state) do
    new_state = disconnect(state)
    {:stop, :normal, :ok, new_state}
  end

  @impl true
  def handle_info(:connect, state) do
    case connect(state) do
      {:ok, new_state} ->
        {:noreply, new_state}

      {:error, reason} ->
        emit_telemetry(:error, %{reason: reason}, state)
        Logger.error("Failed to reconnect EventSub WebSocket: #{inspect(reason)}")
        schedule_reconnect()
        {:noreply, state}
    end
  end

  def handle_info(:keepalive_timeout, state) do
    Logger.warning("EventSub WebSocket keepalive timeout, reconnecting")
    emit_telemetry(:error, %{reason: :keepalive_timeout}, state)

    new_state = disconnect(state)
    schedule_reconnect()
    {:noreply, new_state}
  end

  def handle_info(message, %{conn: conn, websocket: websocket} = state)
      when conn != nil and websocket != nil do
    case Mint.WebSocket.stream(conn, message) do
      {:ok, conn, responses} ->
        state = %{state | conn: conn}
        handle_responses(responses, state)

      {:error, conn, reason, _responses} ->
        emit_telemetry(:error, %{reason: reason}, state)
        Logger.error("EventSub WebSocket stream error: #{inspect(reason)}")

        new_state = %{state | conn: conn} |> disconnect()
        schedule_reconnect()
        {:noreply, new_state}

      :unknown ->
        {:noreply, state}
    end
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    disconnect(state)
    :ok
  end

  ## Private Functions

  defp connect(%{reconnect_url: reconnect_url} = state) when reconnect_url != nil do
    connect_to_url(reconnect_url, state)
  end

  defp connect(state) do
    connect_to_url(@websocket_url, state)
  end

  defp connect_to_url(url, state) do
    uri = URI.parse(url)
    http_scheme = if uri.scheme == "wss", do: :https, else: :http

    with {:ok, conn} <- Mint.HTTP.connect(http_scheme, uri.host, uri.port || 443),
         {:ok, conn, ref} <- Mint.WebSocket.upgrade(:wss, conn, uri.path || "/", []) do
      state = %{state | conn: conn, request_ref: ref}
      {:ok, state}
    else
      {:error, reason} ->
        {:error, reason}

      {:error, conn, reason} ->
        Mint.HTTP.close(conn)
        {:error, reason}
    end
  end

  defp disconnect(%{conn: nil} = state), do: state

  defp disconnect(%{conn: conn, keepalive_timer: timer} = state) do
    if timer, do: Process.cancel_timer(timer)
    Mint.HTTP.close(conn)

    emit_telemetry(:disconnected, %{}, state)

    %{state | conn: nil, websocket: nil, keepalive_timer: nil}
  end

  defp handle_responses(responses, state) do
    Enum.reduce(responses, {:noreply, state}, fn
      response, {:noreply, state} ->
        handle_response(response, state)

      _response, result ->
        result
    end)
  end

  defp handle_response({:status, ref, status}, %{request_ref: ref} = state) do
    if status != 200 do
      Logger.error("EventSub WebSocket upgrade failed with status: #{status}")
      emit_telemetry(:error, %{reason: {:http_status, status}}, state)
      {:stop, {:error, {:http_status, status}}, state}
    else
      {:noreply, state}
    end
  end

  defp handle_response({:headers, ref, _headers}, %{request_ref: ref} = state) do
    {:noreply, state}
  end

  defp handle_response({:done, ref}, %{request_ref: ref} = state) do
    {:noreply, state}
  end

  defp handle_response({:upgrade, ref, ["websocket"]}, %{request_ref: ref, conn: conn} = state) do
    {:ok, websocket} = Mint.WebSocket.new(conn, ref, :client, [])
    state = %{state | websocket: websocket, request_ref: nil}

    emit_telemetry(:connected, %{url: @websocket_url}, state)
    Logger.info("EventSub WebSocket connected")

    {:noreply, reset_keepalive_timer(state)}
  end

  defp handle_response({:data, ref, data}, %{request_ref: ref, websocket: websocket} = state)
       when websocket != nil do
    case Mint.WebSocket.decode(websocket, data) do
      {:ok, websocket, frames} ->
        state = %{state | websocket: websocket}
        handle_frames(frames, state)

      {:error, websocket, reason} ->
        emit_telemetry(:error, %{reason: reason}, state)
        Logger.error("EventSub WebSocket decode error: #{inspect(reason)}")
        state = %{state | websocket: websocket}
        {:noreply, state}
    end
  end

  defp handle_response(_response, state) do
    {:noreply, state}
  end

  defp handle_frames(frames, state) do
    Enum.reduce(frames, {:noreply, state}, fn
      frame, {:noreply, state} ->
        handle_frame(frame, state)

      _frame, result ->
        result
    end)
  end

  defp handle_frame({:text, text}, state) do
    state = reset_keepalive_timer(state)

    case Jason.decode(text) do
      {:ok, message} ->
        handle_message(message, state)

      {:error, reason} ->
        emit_telemetry(:error, %{reason: {:json_decode, reason}}, state)
        Logger.error("Failed to decode EventSub message: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  defp handle_frame({:close, code, reason}, state) do
    Logger.info("EventSub WebSocket closed: #{code} - #{reason}")
    emit_telemetry(:disconnected, %{code: code, reason: reason}, state)

    new_state = disconnect(state)
    schedule_reconnect()
    {:noreply, new_state}
  end

  defp handle_frame({:ping, data}, %{conn: conn, websocket: websocket} = state) do
    {:ok, websocket, frame} = Mint.WebSocket.encode(websocket, {:pong, data})
    {:ok, conn} = Mint.WebSocket.stream_request_body(conn, state.request_ref, frame)

    {:noreply, %{state | conn: conn, websocket: websocket}}
  end

  defp handle_frame(_frame, state) do
    {:noreply, state}
  end

  defp handle_message(%{"metadata" => %{"message_type" => "session_welcome"}} = message, state) do
    session_id = get_in(message, ["payload", "session", "id"])
    keepalive_timeout = get_in(message, ["payload", "session", "keepalive_timeout_seconds"])
    reconnect_url = get_in(message, ["payload", "session", "reconnect_url"])

    Logger.info("EventSub WebSocket session established: #{session_id}")

    state = %{state | session_id: session_id, reconnect_url: reconnect_url}
    state = if keepalive_timeout, do: update_keepalive_timeout(state, keepalive_timeout), else: state

    emit_telemetry(:message, %{type: "session_welcome", session_id: session_id}, state)
    dispatch_event(message, state)

    {:noreply, state}
  end

  defp handle_message(%{"metadata" => %{"message_type" => "session_keepalive"}}, state) do
    emit_telemetry(:keepalive, %{session_id: state.session_id}, state)
    {:noreply, state}
  end

  defp handle_message(%{"metadata" => %{"message_type" => "session_reconnect"}} = message, state) do
    reconnect_url = get_in(message, ["payload", "session", "reconnect_url"])
    Logger.info("EventSub WebSocket reconnect requested: #{reconnect_url}")

    state = %{state | reconnect_url: reconnect_url}
    emit_telemetry(:reconnect, %{reconnect_url: reconnect_url}, state)

    # Close current connection and reconnect to new URL
    new_state = disconnect(state)
    send(self(), :connect)

    {:noreply, new_state}
  end

  defp handle_message(%{"metadata" => %{"message_type" => "notification"}} = message, state) do
    subscription = get_in(message, ["payload", "subscription"])
    _event = get_in(message, ["payload", "event"])

    # Add subscription to list if not already present
    state =
      if subscription && !Enum.find(state.subscriptions, &(&1["id"] == subscription["id"])) do
        %{state | subscriptions: [subscription | state.subscriptions]}
      else
        state
      end

    emit_telemetry(
      :message,
      %{
        type: "notification",
        subscription_type: subscription["type"],
        subscription_id: subscription["id"]
      },
      state
    )

    dispatch_event(message, state)

    {:noreply, state}
  end

  defp handle_message(%{"metadata" => %{"message_type" => "revocation"}} = message, state) do
    subscription = get_in(message, ["payload", "subscription"])
    subscription_id = subscription["id"]

    Logger.warning("EventSub subscription revoked: #{subscription_id}")

    state = %{state | subscriptions: Enum.reject(state.subscriptions, &(&1["id"] == subscription_id))}

    emit_telemetry(
      :message,
      %{
        type: "revocation",
        subscription_id: subscription_id
      },
      state
    )

    dispatch_event(message, state)

    {:noreply, state}
  end

  defp handle_message(message, state) do
    Logger.warning("Unknown EventSub message type: #{inspect(message)}")
    {:noreply, state}
  end

  defp dispatch_event(event, %{handler: {module, function, args}}) do
    apply(module, function, [event | args])
  rescue
    error ->
      Logger.error("Error in EventSub handler: #{inspect(error)}")
      Logger.error(Exception.format_stacktrace(__STACKTRACE__))
  end

  defp dispatch_event(event, %{handler: pid}) when is_pid(pid) do
    send(pid, {:eventsub_event, event})
  end

  defp reset_keepalive_timer(%{keepalive_timer: timer} = state) do
    if timer, do: Process.cancel_timer(timer)
    timer = Process.send_after(self(), :keepalive_timeout, @keepalive_timeout_ms)
    %{state | keepalive_timer: timer}
  end

  defp update_keepalive_timeout(state, timeout_seconds) do
    timeout_ms = timeout_seconds * 1000 + 1_000
    if state.keepalive_timer, do: Process.cancel_timer(state.keepalive_timer)
    timer = Process.send_after(self(), :keepalive_timeout, timeout_ms)
    %{state | keepalive_timer: timer}
  end

  defp schedule_reconnect do
    Process.send_after(self(), :connect, @reconnect_delay_ms)
  end

  defp emit_telemetry(event, measurements, state) do
    :telemetry.execute(
      [:twitchy, :eventsub, :websocket, event],
      Map.merge(%{system_time: System.system_time()}, measurements),
      %{
        session_id: state.session_id,
        subscription_count: length(state.subscriptions)
      }
    )
  end
end
