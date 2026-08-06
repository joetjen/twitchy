defmodule Twitchy.AuthTest do
  use ExUnit.Case, async: true

  alias Twitchy.Auth
  import Twitchy.{TestHelpers, BypassHelpers}

  setup do
    bypass = Bypass.open()

    client =
      test_client(%{
        base_url: "http://localhost:#{bypass.port}",
        auth_base_url: "http://localhost:#{bypass.port}/oauth2"
      })

    {:ok, bypass: bypass, client: client}
  end

  describe "get_app_access_token/1" do
    test "requests app access token", %{bypass: bypass, client: client} do
      response = %{
        "access_token" => "app_token_12345",
        "expires_in" => 5_184_000,
        "token_type" => "bearer"
      }

      expect_oauth_token(bypass, response)

      assert {:ok, updated_client} = Auth.get_app_access_token(client)
      assert updated_client.access_token == "app_token_12345"
      assert updated_client.token_type == :app_access
    end

    test "returns error on failure", %{bypass: bypass, client: client} do
      Bypass.expect_once(bypass, "POST", "/oauth2/token", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(400, Jason.encode!(%{"message" => "Invalid client"}))
      end)

      assert {:error, _} = Auth.get_app_access_token(client)
    end
  end

  describe "authorization_url/3" do
    test "generates authorization URL with required params" do
      client = test_client(%{redirect_uri: "http://localhost:4000/auth/callback"})
      scopes = ["user:read:email", "channel:read:subscriptions"]

      url = Auth.authorization_url(client, scopes)

      assert url =~ "https://id.twitch.tv/oauth2/authorize"
      assert url =~ "client_id=test_client_id"
      assert url =~ "redirect_uri=http%3A%2F%2Flocalhost%3A4000%2Fauth%2Fcallback"
      assert url =~ "response_type=code"
      assert url =~ "scope=user%3Aread%3Aemail"
    end

    test "includes state parameter" do
      client = test_client(%{redirect_uri: "http://localhost"})
      url = Auth.authorization_url(client, [], state: "random_state")

      assert url =~ "state=random_state"
    end

    test "includes force_verify parameter" do
      client = test_client(%{redirect_uri: "http://localhost"})
      url = Auth.authorization_url(client, [], force_verify: true)

      assert url =~ "force_verify=true"
    end
  end

  describe "exchange_code/2" do
    test "exchanges authorization code for token", %{bypass: bypass, client: client} do
      client = %{client | redirect_uri: "http://localhost"}

      response = %{
        "access_token" => "user_token_12345",
        "expires_in" => 14_400,
        "token_type" => "bearer",
        "refresh_token" => "refresh_token_12345",
        "scope" => ["user:read:email"]
      }

      expect_oauth_token(bypass, response)

      assert {:ok, updated_client} = Auth.exchange_code(client, "auth_code_123")
      assert updated_client.access_token == "user_token_12345"
      assert updated_client.refresh_token == "refresh_token_12345"
    end
  end

  describe "validate_token/1" do
    test "validates token successfully", %{bypass: bypass, client: client} do
      client = %{client | access_token: "valid_token"}

      response = %{
        "client_id" => "test_client_id",
        "login" => "testuser",
        "scopes" => ["user:read:email"],
        "user_id" => "12345",
        "expires_in" => 3600
      }

      expect_oauth_validate(bypass, response)

      assert {:ok, validation} = Auth.validate_token(client)
      assert validation["client_id"] == "test_client_id"
      assert validation["user_id"] == "12345"
    end

    test "returns error for invalid token", %{bypass: bypass, client: client} do
      client = %{client | access_token: "invalid_token"}

      Bypass.expect_once(bypass, "GET", "/oauth2/validate", fn conn ->
        Plug.Conn.resp(conn, 401, Jason.encode!(%{"message" => "Invalid token"}))
      end)

      assert {:error, _} = Auth.validate_token(client)
    end
  end

  describe "refresh_token/1" do
    test "refreshes access token", %{bypass: bypass, client: client} do
      client = %{client | refresh_token: "refresh_token_123"}

      response = %{
        "access_token" => "new_token_12345",
        "expires_in" => 14_400,
        "token_type" => "bearer",
        "refresh_token" => "new_refresh_token",
        "scope" => ["user:read:email"]
      }

      expect_oauth_token(bypass, response)

      assert {:ok, updated_client} = Auth.refresh_token(client)
      assert updated_client.access_token == "new_token_12345"
      assert updated_client.refresh_token == "new_refresh_token"
    end

    test "returns error when no refresh token", %{client: client} do
      assert {:error, _} = Auth.refresh_token(client)
    end
  end
end
