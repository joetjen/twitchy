defmodule Twitchy.PaginationTest do
  use ExUnit.Case, async: true

  alias Twitchy.Pagination

  describe "stream/2" do
    test "fetches the first page even with the default nil cursor" do
      pages = %{
        nil => {:ok, [1, 2], "cursor1"},
        "cursor1" => {:ok, [3, 4], "cursor2"},
        "cursor2" => {:ok, [5], nil}
      }

      fetch_fn = fn cursor -> Map.fetch!(pages, cursor) end

      assert Pagination.stream(fetch_fn) |> Enum.to_list() == [1, 2, 3, 4, 5]
    end

    test "starts from the given initial cursor" do
      fetch_fn = fn
        "start_cursor" -> {:ok, [1], nil}
      end

      assert Pagination.stream(fetch_fn, "start_cursor") |> Enum.to_list() == [1]
    end

    test "halts once a page returns no items" do
      fetch_fn = fn
        nil -> {:ok, [1, 2], "cursor1"}
        "cursor1" -> {:ok, [], "cursor2"}
      end

      assert Pagination.stream(fetch_fn) |> Enum.to_list() == [1, 2]
    end

    test "raises when fetch_page_fn returns an error" do
      fetch_fn = fn nil -> {:error, :boom} end

      assert_raise RuntimeError, ~r/Pagination error/, fn ->
        Pagination.stream(fetch_fn) |> Enum.to_list()
      end
    end

    test "works lazily with Enum.take/2 without fetching extra pages" do
      pages = %{
        nil => {:ok, [1, 2], "cursor1"},
        "cursor1" => {:ok, [3, 4], "cursor2"}
      }

      fetch_fn = fn cursor -> Map.fetch!(pages, cursor) end

      assert Pagination.stream(fetch_fn) |> Enum.take(3) == [1, 2, 3]
    end
  end

  describe "fetch_all/2" do
    test "collects all pages into a single list" do
      pages = %{
        nil => {:ok, [1, 2], "cursor1"},
        "cursor1" => {:ok, [3], nil}
      }

      fetch_fn = fn cursor -> Map.fetch!(pages, cursor) end

      assert Pagination.fetch_all(fetch_fn) == {:ok, [1, 2, 3]}
    end

    test "returns an error tuple instead of raising when fetching fails" do
      fetch_fn = fn nil -> {:error, :boom} end

      assert {:error, %RuntimeError{}} = Pagination.fetch_all(fetch_fn)
    end
  end

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
