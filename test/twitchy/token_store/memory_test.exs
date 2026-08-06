defmodule Twitchy.TokenStore.MemoryTest do
  use ExUnit.Case, async: false

  alias Twitchy.TokenStore.Memory

  defp unique_store_name do
    :"token_store_test_#{System.unique_integer([:positive])}"
  end

  describe "get_token/2" do
    test "returns token when present" do
      {:ok, pid} = start_supervised({Memory, [name: unique_store_name()]})

      token_data = %{"access_token" => "test_token", "expires_in" => 3600}
      :ok = Memory.put_token(pid, "client_123", token_data)

      assert {:ok, ^token_data} = Memory.get_token(pid, "client_123")
    end

    test "returns error when token not found" do
      {:ok, pid} = start_supervised({Memory, [name: unique_store_name()]})

      assert {:error, :token_not_found} = Memory.get_token(pid, "nonexistent")
    end
  end

  describe "put_token/3" do
    test "stores token data" do
      {:ok, pid} = start_supervised({Memory, [name: unique_store_name()]})

      token_data = %{"access_token" => "new_token"}
      assert :ok = Memory.put_token(pid, "client_123", token_data)

      assert {:ok, ^token_data} = Memory.get_token(pid, "client_123")
    end

    test "updates existing token" do
      {:ok, pid} = start_supervised({Memory, [name: unique_store_name()]})

      token_data_1 = %{"access_token" => "token_1"}
      token_data_2 = %{"access_token" => "token_2"}

      Memory.put_token(pid, "client_123", token_data_1)
      Memory.put_token(pid, "client_123", token_data_2)

      assert {:ok, ^token_data_2} = Memory.get_token(pid, "client_123")
    end
  end

  describe "delete_token/2" do
    test "removes token" do
      {:ok, pid} = start_supervised({Memory, [name: unique_store_name()]})

      token_data = %{"access_token" => "test_token"}
      Memory.put_token(pid, "client_123", token_data)

      assert :ok = Memory.delete_token(pid, "client_123")
      assert {:error, :token_not_found} = Memory.get_token(pid, "client_123")
    end
  end
end
