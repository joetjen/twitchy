defmodule Twitchy.EventSub.WebhookTest do
  use ExUnit.Case, async: true

  alias Twitchy.EventSub.Webhook
  import Twitchy.TestHelpers

  @secret "test_webhook_secret_1234567890"

  describe "verify_signature/5" do
    test "verifies valid signature" do
      message_id = "test_msg_123"
      timestamp = "2024-12-19T12:00:00Z"
      body = ~s({"test": "data"})

      signature = compute_webhook_signature(message_id, timestamp, body, @secret)

      assert :ok = Webhook.verify_signature(message_id, timestamp, body, signature, @secret)
    end

    test "rejects invalid signature" do
      message_id = "test_msg_123"
      timestamp = "2024-12-19T12:00:00Z"
      body = ~s({"test": "data"})

      invalid_signature = "sha256=invalid_signature"

      assert {:error, :invalid_signature} =
               Webhook.verify_signature(message_id, timestamp, body, invalid_signature, @secret)
    end

    test "rejects tampered body" do
      message_id = "test_msg_123"
      timestamp = "2024-12-19T12:00:00Z"
      original_body = ~s({"test": "data"})
      tampered_body = ~s({"test": "tampered"})

      signature = compute_webhook_signature(message_id, timestamp, original_body, @secret)

      assert {:error, :invalid_signature} =
               Webhook.verify_signature(message_id, timestamp, tampered_body, signature, @secret)
    end
  end

  describe "verify_timestamp/2" do
    test "accepts recent timestamp" do
      timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

      assert :ok = Webhook.verify_timestamp(timestamp)
    end

    test "rejects old timestamp" do
      timestamp = DateTime.utc_now() |> DateTime.add(-700, :second) |> DateTime.to_iso8601()

      assert {:error, :timestamp_too_old} = Webhook.verify_timestamp(timestamp)
    end

    test "skips check when option provided" do
      timestamp = DateTime.utc_now() |> DateTime.add(-700, :second) |> DateTime.to_iso8601()

      assert :ok = Webhook.verify_timestamp(timestamp, skip_timestamp_check: true)
    end

    test "rejects invalid timestamp format" do
      assert {:error, :invalid_timestamp} = Webhook.verify_timestamp("invalid")
    end
  end

  describe "handle_challenge/1" do
    test "extracts challenge string" do
      payload = %{"challenge" => "test_challenge_string_12345"}

      assert "test_challenge_string_12345" = Webhook.handle_challenge(payload)
    end
  end
end
