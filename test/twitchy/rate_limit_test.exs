defmodule Twitchy.RateLimitTest do
  use ExUnit.Case, async: true

  alias Twitchy.RateLimit

  describe "from_headers/1" do
    test "parses rate limit headers from map" do
      headers = %{
        "ratelimit-limit" => "800",
        "ratelimit-remaining" => "750",
        "ratelimit-reset" => "1734616800"
      }

      rate_limit = RateLimit.from_headers(headers)

      assert rate_limit.limit == 800
      assert rate_limit.remaining == 750
      assert rate_limit.reset_at == DateTime.from_unix!(1_734_616_800)
    end

    test "handles missing headers" do
      rate_limit = RateLimit.from_headers(%{})

      assert rate_limit.limit == 800
      assert rate_limit.remaining == 800
      assert rate_limit.reset_at == nil
    end

    test "handles invalid header values" do
      headers = %{
        "ratelimit-limit" => "invalid",
        "ratelimit-remaining" => "750"
      }

      rate_limit = RateLimit.from_headers(headers)

      assert rate_limit.limit == 800
      assert rate_limit.remaining == 750
    end
  end

  describe "time_until_reset/1" do
    test "calculates time until reset" do
      reset_time = DateTime.utc_now() |> DateTime.add(300, :second)
      rate_limit = %RateLimit{reset_at: reset_time}

      seconds = RateLimit.time_until_reset(rate_limit)

      assert seconds in 295..305
    end

    test "returns negative when reset time has passed" do
      reset_time = DateTime.utc_now() |> DateTime.add(-100, :second)
      rate_limit = %RateLimit{reset_at: reset_time}

      assert RateLimit.time_until_reset(rate_limit) < 0
    end

    test "returns nil when reset_at is nil" do
      rate_limit = %RateLimit{}

      assert RateLimit.time_until_reset(rate_limit) == nil
    end
  end
end
