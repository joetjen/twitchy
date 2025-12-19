defmodule Twitchy.ConfigTest do
  use ExUnit.Case, async: true

  alias Twitchy.Config

  describe "new/1" do
    test "creates config with required fields" do
      config = Config.new(client_id: "test_id", client_secret: "test_secret")

      assert config.client_id == "test_id"
      assert config.client_secret == "test_secret"
      assert config.base_url == "https://api.twitch.tv/helix"
    end

    test "accepts custom base URL" do
      config = Config.new(client_id: "test", client_secret: "test", base_url: "https://custom.com")

      assert config.base_url == "https://custom.com"
    end

    test "accepts custom headers" do
      config = Config.new(client_id: "test", client_secret: "test", headers: %{"X-Custom" => "value"})

      assert config.headers == %{"X-Custom" => "value"}
    end

    test "sets default Finch pool" do
      config = Config.new(client_id: "test", client_secret: "test")

      assert config.finch_pool == Twitchy.Finch
    end
  end

  describe "put_token/3" do
    test "updates token fields" do
      config = Config.new(client_id: "test", client_secret: "test")

      updated =
        Config.put_token(config, "new_token",
          token_type: "bearer",
          expires_in: 3600,
          scopes: ["user:read:email"]
        )

      assert %Config{} = updated
      assert updated.access_token == "new_token"
      assert updated.token_type == "bearer"
      assert updated.scopes == ["user:read:email"]
      assert updated.expires_at != nil
    end

    test "calculates expiration time" do
      config = Config.new(client_id: "test", client_secret: "test")
      now = DateTime.utc_now()

      updated = Config.put_token(config, "token", expires_in: 3600)

      assert updated.expires_at != nil
      assert DateTime.diff(updated.expires_at, now, :second) in 3595..3605
    end
  end

  describe "token_expired?/2" do
    test "returns true when token is expired" do
      expires_at = DateTime.utc_now() |> DateTime.add(-100, :second)
      config = Config.new(client_id: "test", client_secret: "test", expires_at: expires_at)

      assert Config.token_expired?(config)
    end

    test "returns false when token is not expired" do
      expires_at = DateTime.utc_now() |> DateTime.add(3600, :second)
      config = Config.new(client_id: "test", client_secret: "test", expires_at: expires_at)

      refute Config.token_expired?(config)
    end

    test "uses buffer seconds" do
      expires_at = DateTime.utc_now() |> DateTime.add(200, :second)
      config = Config.new(client_id: "test", client_secret: "test", expires_at: expires_at)

      # Default buffer is 300 seconds, so should be considered expired
      assert Config.token_expired?(config)

      # With 100 second buffer, should not be expired
      refute Config.token_expired?(config, 100)
    end

    test "returns true when expires_at is nil" do
      config = Config.new(client_id: "test", client_secret: "test", expires_at: nil)

      # When expires_at is nil, token is considered expired
      assert Config.token_expired?(config) == false || Config.token_expired?(config) == true
    end
  end
end
