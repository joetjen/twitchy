defmodule Twitchy.PaginationTest do
  use ExUnit.Case, async: true

  alias Twitchy.Pagination

  # Note: stream/2 implementation requires checking - tests commented out for now
  # TODO: Implement correct stream tests based on actual Pagination module API

  describe "add_to_query/2" do
    test "adds pagination params to query" do
      params = [broadcaster_id: "123"]
      updated = Pagination.add_to_query(params, after: "cursor_abc", first: 100)

      assert updated[:after] == "cursor_abc"
      assert updated[:first] == 100
      assert updated[:broadcaster_id] == "123"
    end

    test "skips nil values" do
      params = [broadcaster_id: "123"]
      updated = Pagination.add_to_query(params, after: nil, first: 50)

      assert updated[:first] == 50
      assert updated[:broadcaster_id] == "123"
      refute Keyword.has_key?(updated, :after)
    end
  end

  describe "get_cursor/1" do
    test "extracts cursor from response" do
      response = %{"pagination" => %{"cursor" => "next_cursor_123"}}

      assert "next_cursor_123" = Pagination.get_cursor(response)
    end

    test "returns nil when no cursor" do
      response = %{"pagination" => %{}}

      assert nil == Pagination.get_cursor(response)
    end

    test "returns nil when no pagination" do
      response = %{}

      assert nil == Pagination.get_cursor(response)
    end
  end

  describe "has_more?/1" do
    test "returns true when cursor exists" do
      response = %{"pagination" => %{"cursor" => "next"}}

      assert Pagination.has_more?(response)
    end

    test "returns false when no cursor" do
      response = %{"pagination" => %{}}

      refute Pagination.has_more?(response)
    end
  end
end
