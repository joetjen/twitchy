defmodule Twitchy.Integration.SetupTest do
  use ExUnit.Case

  @moduletag :integration

  # Integration tests require real Twitch credentials
  # Set TWITCH_RUN_INTEGRATION_TESTS=true to enable

  @twitch_client_id System.get_env("TWITCH_CLIENT_ID")
  @twitch_client_secret System.get_env("TWITCH_CLIENT_SECRET")

  setup_all do
    unless @twitch_client_id && @twitch_client_secret do
      :skip
    else
      {:ok, client_id: @twitch_client_id, client_secret: @twitch_client_secret}
    end
  end

  describe "OAuth flows" do
    @tag :skip
    test "obtains app access token", %{client_id: client_id, client_secret: client_secret} do
      client = Twitchy.new(client_id: client_id, client_secret: client_secret)

      assert {:ok, authenticated} = Twitchy.Auth.get_app_access_token(client)
      assert authenticated.access_token != nil
      assert authenticated.token_type != nil
    end

    @tag :skip
    test "validates token", %{client_id: client_id, client_secret: client_secret} do
      client = Twitchy.new(client_id: client_id, client_secret: client_secret)
      {:ok, authenticated} = Twitchy.Auth.get_app_access_token(client)

      assert {:ok, validation} = Twitchy.Auth.validate_token(authenticated)
      assert validation["client_id"] == client_id
    end
  end

  describe "API calls" do
    @tag :skip
    test "fetches games", %{client_id: client_id, client_secret: client_secret} do
      client = Twitchy.new(client_id: client_id, client_secret: client_secret)
      {:ok, authenticated} = Twitchy.Auth.get_app_access_token(client)

      assert {:ok, response} = Twitchy.Games.get_top_games(authenticated, first: 10)
      assert is_list(response["data"])
    end
  end
end
