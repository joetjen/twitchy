defmodule TwitchyTest do
  use ExUnit.Case
  doctest Twitchy

  test "greets the world" do
    assert Twitchy.hello() == :world
  end
end
