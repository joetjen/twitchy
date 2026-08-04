defmodule Twitchy.TokenStore.Memory.State do
  @moduledoc """
  Functional core of `Twitchy.TokenStore.Memory`.

  Implements `Twitchy.Behaviours.TokenStore` as pure functions over a plain
  state map. Kept separate from `Twitchy.TokenStore.Memory` (which adopts
  `GenServer`) because `GenServer` and `Twitchy.Behaviours.TokenStore` both
  declare an `init/1` callback — adopting both behaviours in the same module
  makes that callback ambiguous.
  """

  require Logger

  @behaviour Twitchy.Behaviours.TokenStore

  @refresh_buffer_seconds 300

  @impl Twitchy.Behaviours.TokenStore
  def init(opts) do
    state = %{
      tokens: %{},
      refresh_buffer: Keyword.get(opts, :refresh_buffer, @refresh_buffer_seconds)
    }

    {:ok, state}
  end

  @impl Twitchy.Behaviours.TokenStore
  def get_token(state, client_id) do
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

  @impl Twitchy.Behaviours.TokenStore
  def put_token(state, client_id, token_data) do
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

  @impl Twitchy.Behaviours.TokenStore
  def delete_token(state, client_id) do
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

  defp needs_refresh?(%{expires_at: nil}, _buffer), do: false

  defp needs_refresh?(%{expires_at: expires_at, refresh_token: refresh_token}, buffer)
       when not is_nil(refresh_token) do
    now = DateTime.utc_now()
    buffer_time = DateTime.add(now, buffer, :second)
    DateTime.compare(expires_at, buffer_time) == :lt
  end

  defp needs_refresh?(_token_data, _buffer), do: false
end
