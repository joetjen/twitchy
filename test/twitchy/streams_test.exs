defmodule Twitchy.StreamsTest do
  use ExUnit.Case, async: true

  alias Twitchy.Streams
  import Twitchy.{TestHelpers, BypassHelpers}

  setup do
    bypass = Bypass.open()
    client = authenticated_client(%{base_url: "http://localhost:#{bypass.port}"})

    {:ok, bypass: bypass, client: client}
  end

  describe "get_streams/2" do
    test "fetches live streams", %{bypass: bypass, client: client} do
      streams = [mock_stream(), mock_stream(%{"id" => "222"})]
      response = mock_api_response(streams)

      expect_helix_get(bypass, "/streams", response)

      assert {:ok, result} = Streams.get_streams(client, first: 20)
      assert length(result["data"]) == 2
    end
  end
end
