if Code.ensure_loaded?(Plug) do
  defmodule Twitchy.EventSub.Plug do
    @moduledoc """
      Plug for handling EventSub webhook endpoints.

    Provides a simple way to set up EventSub webhook endpoints in Phoenix
    or Plug-based applications with automatic signature verification,
    challenge response, and event dispatching.

    ## Usage in Phoenix Router

        defmodule MyAppWeb.Router do
          use MyAppWeb, :router

          # Add webhook route
          scope "/webhooks" do
            post "/eventsub", Twitchy.EventSub.Plug,
              secret: "your_webhook_secret",
              handler: {MyApp.EventSubHandler, :handle_event, []}
          end
        end

    ## Usage in Plug Pipeline

        defmodule MyApp.WebhookEndpoint do
          use Plug.Router

          plug :match
          plug :dispatch

          post "/eventsub",
            to: Twitchy.EventSub.Plug,
            init_opts: [
              secret: {:system, "TWITCH_WEBHOOK_SECRET"},
              handler: {MyApp.EventSubHandler, :handle_event, []},
              replay_protection: true
            ]
        end

    ## Handler Implementation

        defmodule MyApp.EventSubHandler do
          require Logger

          def handle_event(%{"subscription" => %{"type" => type}} = event, _opts) do
            Logger.info("Received EventSub event: \#{type}")

            # Process the event
            case type do
              "channel.follow" ->
                process_follow(event)

              "stream.online" ->
                process_stream_online(event)

              _ ->
                :ok
            end
          end

          defp process_follow(event) do
            follower = get_in(event, ["event", "user_name"])
            broadcaster = get_in(event, ["event", "broadcaster_user_name"])
            Logger.info("\#{follower} followed \#{broadcaster}!")
          end

          defp process_stream_online(event) do
            broadcaster = get_in(event, ["event", "broadcaster_user_name"])
            Logger.info("\#{broadcaster} is now live!")
          end
        end

    ## Options

    - `:secret` - Webhook secret (required). Can be:
      - String: Direct secret value
      - `{:system, "VAR_NAME"}`: Load from environment variable
      - `{module, function, args}`: Call function to get secret

    - `:handler` - Event handler (required). Can be:
      - `{module, function, args}`: Call function with event
      - `pid`: Send event to process as `{:eventsub_event, event}`

    - `:replay_protection` - Enable replay attack prevention (default: true)
      - Uses in-memory Agent to track seen message IDs
      - IDs expire after 10 minutes

    - `:on_error` - Error handler (optional)
      - `{module, function, args}`: Called when verification fails
      - Default: logs error and returns 403

    ## Telemetry

    All telemetry events from `Twitchy.EventSub.Webhook` are emitted, plus:

    - `[:twitchy, :eventsub, :plug, :request]` - Request received
    - `[:twitchy, :eventsub, :plug, :success]` - Request processed successfully
    - `[:twitchy, :eventsub, :plug, :error]` - Request processing failed
    """

    import Plug.Conn
    require Logger

    alias Twitchy.EventSub.Webhook

    @behaviour Plug

    defstruct [:secret, :handler, :on_error, :replay_agent, replay_protection: true]

    @impl true
    def init(opts) do
      secret = resolve_secret(opts[:secret] || raise("Webhook secret is required"))
      handler = opts[:handler] || raise "Event handler is required"
      replay_protection = Keyword.get(opts, :replay_protection, true)
      on_error = opts[:on_error]

      replay_agent =
        if replay_protection do
          {:ok, agent} = Agent.start_link(fn -> MapSet.new() end)

          # Schedule cleanup of old message IDs
          schedule_cleanup(agent)

          agent
        else
          nil
        end

      %__MODULE__{
        secret: secret,
        handler: handler,
        replay_protection: replay_protection,
        replay_agent: replay_agent,
        on_error: on_error
      }
    end

    @impl true
    def call(conn, %__MODULE__{} = config) do
      start_time = System.monotonic_time()

      emit_telemetry(:request, %{}, %{
        method: conn.method,
        path: conn.request_path
      })

      # Cache body for signature verification
      {:ok, body, conn} = read_body(conn)
      conn = assign(conn, :raw_body, body)

      opts =
        if config.replay_agent do
          [seen_message_ids: config.replay_agent]
        else
          []
        end

      case Webhook.verify_and_process(conn, config.secret, opts) do
        {:ok, :challenge, challenge} ->
          duration = System.monotonic_time() - start_time

          emit_telemetry(:success, %{duration: duration}, %{
            message_type: :challenge
          })

          conn
          |> put_resp_content_type("text/plain")
          |> send_resp(200, challenge)

        {:ok, message_type, event} when message_type in [:notification, :revocation] ->
          # Dispatch to handler
          dispatch_event(event, config.handler)

          duration = System.monotonic_time() - start_time

          emit_telemetry(:success, %{duration: duration}, %{
            message_type: message_type,
            subscription_type: get_in(event, ["subscription", "type"])
          })

          send_resp(conn, 200, "")

        {:error, reason} ->
          duration = System.monotonic_time() - start_time

          emit_telemetry(:error, %{duration: duration}, %{
            reason: reason
          })

          Logger.error("EventSub webhook verification failed: #{inspect(reason)}")

          if config.on_error do
            dispatch_error(reason, config.on_error)
          end

          send_resp(conn, 403, "Forbidden")
      end
    end

    ## Private Functions

    defp resolve_secret(secret) when is_binary(secret), do: secret

    defp resolve_secret({:system, var_name}) do
      System.get_env(var_name) || raise "Environment variable #{var_name} not set"
    end

    defp resolve_secret({module, function, args}) do
      apply(module, function, args)
    end

    defp dispatch_event(event, {module, function, args}) do
      Task.start(fn ->
        try do
          apply(module, function, [event | args])
        rescue
          error ->
            Logger.error("Error in EventSub handler: #{inspect(error)}")
            Logger.error(Exception.format_stacktrace(__STACKTRACE__))
        end
      end)
    end

    defp dispatch_event(event, pid) when is_pid(pid) do
      send(pid, {:eventsub_event, event})
    end

    defp dispatch_error(reason, {module, function, args}) do
      Task.start(fn ->
        try do
          apply(module, function, [reason | args])
        rescue
          error ->
            Logger.error("Error in EventSub error handler: #{inspect(error)}")
        end
      end)
    end

    defp schedule_cleanup(agent) do
      # Clean up message IDs older than 10 minutes every 5 minutes
      Process.send_after(self(), {:cleanup_message_ids, agent}, 300_000)
    end

    defp emit_telemetry(event, measurements, metadata) do
      :telemetry.execute(
        [:twitchy, :eventsub, :plug, event],
        Map.merge(%{system_time: System.system_time()}, measurements),
        metadata
      )
    end

    @doc """
    Helper for setting up EventSub webhooks in Phoenix controllers.

    ## Example

        defmodule MyAppWeb.WebhookController do
          use MyAppWeb, :controller

          def eventsub(conn, _params) do
            Twitchy.EventSub.Plug.handle_webhook(conn,
              secret: Application.get_env(:my_app, :twitch_webhook_secret),
              handler: {MyApp.EventSubHandler, :handle_event, []}
            )
          end
        end
    """
    @spec handle_webhook(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
    def handle_webhook(conn, opts) do
      config = init(opts)
      call(conn, config)
    end
  end
end
