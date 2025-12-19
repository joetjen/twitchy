defmodule Twitchy.RateLimit do
  @moduledoc """
  Rate limiting tracking and enforcement for Twitch API.

  Twitch uses a point-based rate limiting system:
  - 800 points per minute per client ID
  - Different endpoints cost different points
  - Rate limit info is returned in response headers

  ## Telemetry Events

  Emits `[:twitchy, :rate_limit, :check]` events with metadata:
  - `remaining` - Points remaining in current window
  - `limit` - Total points allowed per window
  - `reset_at` - DateTime when limit resets
  - `endpoint` - API endpoint being called
  """

  require Logger

  @type t :: %__MODULE__{
          remaining: integer(),
          limit: integer(),
          reset_at: DateTime.t() | nil
        }

  defstruct remaining: 800,
            limit: 800,
            reset_at: nil

  @doc """
  Creates a new rate limit tracker from response headers.

  ## Examples

      iex> headers = %{
      ...>   "ratelimit-limit" => "800",
      ...>   "ratelimit-remaining" => "799",
      ...>   "ratelimit-reset" => "1640000000"
      ...> }
      iex> Twitchy.RateLimit.from_headers(headers)
      %Twitchy.RateLimit{remaining: 799, limit: 800, reset_at: ~U[2021-12-20 11:33:20Z]}
  """
  @spec from_headers(map()) :: t()
  def from_headers(headers) do
    %__MODULE__{
      remaining: parse_int(headers["ratelimit-remaining"]) || 800,
      limit: parse_int(headers["ratelimit-limit"]) || 800,
      reset_at: parse_timestamp(headers["ratelimit-reset"])
    }
  end

  @doc """
  Checks if rate limit is approaching and emits telemetry.

  Returns `:ok` if safe to proceed, or `{:error, rate_limit}` if limit exceeded.

  ## Examples

      iex> rate_limit = %Twitchy.RateLimit{remaining: 10, limit: 800}
      iex> Twitchy.RateLimit.check(rate_limit, "/users")
      :ok

      iex> rate_limit = %Twitchy.RateLimit{remaining: 0, limit: 800, reset_at: ~U[2024-01-01 12:00:00Z]}
      iex> Twitchy.RateLimit.check(rate_limit, "/users")
      {:error, %Twitchy.Error.RateLimitError{...}}
  """
  @spec check(t(), String.t()) :: :ok | {:error, Twitchy.Error.RateLimitError.t()}
  def check(%__MODULE__{} = rate_limit, endpoint) do
    :telemetry.execute(
      [:twitchy, :rate_limit, :check],
      %{remaining: rate_limit.remaining},
      %{
        endpoint: endpoint,
        limit: rate_limit.limit,
        reset_at: rate_limit.reset_at
      }
    )

    cond do
      rate_limit.remaining == 0 ->
        {:error,
         %Twitchy.Error.RateLimitError{
           message: "Rate limit exceeded",
           remaining: rate_limit.remaining,
           limit: rate_limit.limit,
           reset_at: rate_limit.reset_at
         }}

      rate_limit.remaining < 50 ->
        Logger.warning("Rate limit low: #{rate_limit.remaining}/#{rate_limit.limit} points remaining for #{endpoint}")

        :ok

      true ->
        :ok
    end
  end

  @doc """
  Calculates time until rate limit reset.

  Returns seconds until reset, or `nil` if no reset time is set.

  ## Examples

      iex> reset_at = DateTime.add(DateTime.utc_now(), 60, :second)
      iex> rate_limit = %Twitchy.RateLimit{reset_at: reset_at}
      iex> Twitchy.RateLimit.time_until_reset(rate_limit)
      60
  """
  @spec time_until_reset(t()) :: integer() | nil
  def time_until_reset(%__MODULE__{reset_at: nil}), do: nil

  def time_until_reset(%__MODULE__{reset_at: reset_at}) do
    DateTime.diff(reset_at, DateTime.utc_now(), :second)
  end

  # Private Helpers

  defp parse_int(nil), do: nil

  defp parse_int(value) when is_integer(value), do: value

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_timestamp(nil), do: nil

  defp parse_timestamp(value) when is_integer(value) do
    case DateTime.from_unix(value) do
      {:ok, dt} -> dt
      _ -> nil
    end
  end

  defp parse_timestamp(value) when is_binary(value) do
    case Integer.parse(value) do
      {unix, _} -> parse_timestamp(unix)
      :error -> nil
    end
  end
end
