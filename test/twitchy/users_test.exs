defmodule Twitchy.UsersTest do
  use ExUnit.Case, async: true

  alias Twitchy.Users
  import Twitchy.{TestHelpers, BypassHelpers}

  setup do
    bypass = Bypass.open()
    client = authenticated_client(%{base_url: "http://localhost:#{bypass.port}"})

    {:ok, bypass: bypass, client: client}
  end

  describe "get_users/2" do
    test "fetches users by ID", %{bypass: bypass, client: client} do
      users = [mock_user(%{"id" => "123"}), mock_user(%{"id" => "456"})]
      response = mock_api_response(users)

      expect_helix_get(bypass, "/users", response)

      assert {:ok, result} = Users.get_users(client, id: ["123", "456"])
      assert result["data"] == users
    end

    test "fetches users by login", %{bypass: bypass, client: client} do
      users = [mock_user(%{"login" => "user1"})]
      response = mock_api_response(users)

      expect_helix_get(bypass, "/users", response)

      assert {:ok, result} = Users.get_users(client, login: ["user1"])
      assert length(result["data"]) == 1
    end
  end

  describe "get_user/2" do
    test "fetches single user by ID", %{bypass: bypass, client: client} do
      user = mock_user(%{"id" => "123"})
      response = mock_api_response([user])

      expect_helix_get(bypass, "/users", response)

      assert {:ok, result} = Users.get_user(client, id: "123")
      assert result["id"] == "123"
    end

    test "returns error when user not found", %{bypass: bypass, client: client} do
      response = mock_api_response([])

      expect_helix_get(bypass, "/users", response)

      assert {:error, :user_not_found} = Users.get_user(client, id: "nonexistent")
    end
  end

  describe "update_user/2" do
    test "updates user description", %{bypass: bypass, client: client} do
      user = mock_user(%{"description" => "New description"})
      response = mock_api_response([user])

      Bypass.expect_once(bypass, "PUT", "/users", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["description"] == "New description"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response))
      end)

      assert {:ok, result} = Users.update_user(client, description: "New description")
      assert result["data"] |> List.first() |> Map.get("description") == "New description"
    end
  end

  describe "block_user/3" do
    test "blocks user", %{bypass: bypass, client: client} do
      expect_helix_put(bypass, "/users/blocks")

      assert :ok = Users.block_user(client, "67890")
    end
  end

  describe "unblock_user/2" do
    test "unblocks user", %{bypass: bypass, client: client} do
      expect_helix_delete(bypass, "/users/blocks")

      assert :ok = Users.unblock_user(client, target_user_id: "67890")
    end
  end

  defp expect_helix_put(bypass, path) do
    Bypass.expect_once(bypass, "PUT", path, fn conn ->
      Plug.Conn.resp(conn, 204, "")
    end)
  end
end
