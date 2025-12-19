defmodule TwitchyTest do
  use ExUnit.Case
  doctest Twitchy

  alias Twitchy.Config

  test "creates a new client" do
    client = Twitchy.new(client_id: "test", client_secret: "secret")
    assert %Config{} = client
    assert client.client_id == "test"
  end

  test "builds client with method chain" do
    client =
      Twitchy.new(client_id: "test", client_secret: "secret")
      |> Twitchy.with_token_store(Twitchy.TokenStore.Memory)

    assert client.token_store == Twitchy.TokenStore.Memory
  end
end
