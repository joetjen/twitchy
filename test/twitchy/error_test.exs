defmodule Twitchy.ErrorTest do
  use ExUnit.Case, async: true

  alias Twitchy.Error.{
    APIError,
    AuthError,
    RateLimitError,
    ValidationError
  }

  describe "exception messages" do
    test "APIError formats message correctly" do
      error = %APIError{message: "Not found", status: 404}
      message = Exception.message(error)

      assert message =~ "404"
    end

    test "AuthError includes reason" do
      error = %AuthError{message: "Invalid token", reason: "token_expired", status: 401}
      message = Exception.message(error)

      assert message =~ "Invalid token"
      assert message =~ "token_expired"
    end

    test "RateLimitError includes message" do
      error = %RateLimitError{message: "Rate limited"}
      message = Exception.message(error)

      assert message =~ "Rate limited"
    end

    test "ValidationError shows field information" do
      error = %ValidationError{message: "Invalid field"}
      message = Exception.message(error)

      assert message =~ "Invalid field"
    end
  end
end
