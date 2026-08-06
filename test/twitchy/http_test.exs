defmodule Twitchy.HTTPTest do
  use ExUnit.Case, async: true

  alias Twitchy.HTTP
  import Twitchy.TestHelpers

  setup do
    bypass = Bypass.open()
    client = authenticated_client(%{base_url: "http://localhost:#{bypass.port}"})

    {:ok, bypass: bypass, client: client}
  end

  describe "get/3" do
    test "makes GET request with auth headers", %{bypass: bypass, client: client} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        assert ["Bearer " <> _] = Plug.Conn.get_req_header(conn, "authorization")
        assert [_] = Plug.Conn.get_req_header(conn, "client-id")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, %{"data" => []}} = HTTP.get(client, "/test")
    end

    test "includes query parameters", %{bypass: bypass, client: client} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        assert conn.query_string =~ "foo=bar"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{}))
      end)

      assert {:ok, _} = HTTP.get(client, "/test", params: [foo: "bar"])
    end
  end

  describe "post/3" do
    test "makes POST request with body", %{bypass: bypass, client: client} do
      Bypass.expect_once(bypass, "POST", "/test", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body == Jason.encode!(%{"key" => "value"})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"success" => true}))
      end)

      assert {:ok, %{"success" => true}} = HTTP.post(client, "/test", json: %{"key" => "value"})
    end
  end
end
