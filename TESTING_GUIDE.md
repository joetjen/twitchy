# Testing Guide

## Overview

The Twitchy test suite uses ExUnit with Bypass for HTTP mocking and comprehensive test helpers.

## Test Structure

```
test/
├── support/              # Test helpers
│   ├── test_helpers.ex   # Common test utilities
│   └── bypass_helpers.ex # HTTP mocking helpers
├── twitchy/              # Unit tests
│   ├── config_test.exs
│   ├── auth_test.exs
│   ├── http_test.exs
│   ├── rate_limit_test.exs
│   ├── pagination_test.exs
│   ├── error_test.exs
│   ├── token_store/
│   │   └── memory_test.exs
│   ├── eventsub/
│   │   └── webhook_test.exs
│   ├── users_test.exs
│   └── streams_test.exs
├── integration/          # Integration tests
│   └── setup_test.exs
└── test_helper.exs       # Test configuration
```

## Running Tests

### All Tests

```bash
mix test
```

### Specific Test File

```bash
mix test test/twitchy/config_test.exs
```

### Specific Test

```bash
mix test test/twitchy/config_test.exs:10
```

### With Coverage

```bash
mix coveralls
mix coveralls.html  # Generates HTML report in cover/
```

### Integration Tests

```bash
# Set environment variables
export TWITCH_CLIENT_ID="your_client_id"
export TWITCH_CLIENT_SECRET="your_client_secret"
export TWITCH_RUN_INTEGRATION_TESTS=true

# Run integration tests
mix test --only integration
```

## Test Helpers

### Creating a Test Client

```elixir
# Basic client
client = test_client()

# Authenticated client
client = authenticated_client()

# Custom configuration
client = test_client(%{
  client_id: "custom_id",
  base_url: "http://localhost:1234"
})
```

### Mocking HTTP Responses

```elixir
# Setup Bypass
setup do
  bypass = Bypass.open()
  client = authenticated_client(%{base_url: "http://localhost:#{bypass.port}"})
  {:ok, bypass: bypass, client: client}
end

# Mock GET request
test "fetches data", %{bypass: bypass, client: client} do
  response = mock_api_response([%{"id" => "123"}])
  expect_helix_get(bypass, "/endpoint", response)

  assert {:ok, result} = MyModule.fetch(client)
end

# Mock POST request
test "creates resource", %{bypass: bypass, client: client} do
  response = %{"success" => true}
  expect_helix_post(bypass, "/endpoint", response)

  assert {:ok, result} = MyModule.create(client, %{})
end
```

### Testing Webhooks

```elixir
test "verifies webhook signature" do
  message_id = "msg_123"
  timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
  body = ~s({"event": "data"})
  secret = "webhook_secret"

  # Compute valid signature
  signature = compute_webhook_signature(message_id, timestamp, body, secret)

  # Verify
  assert :ok = Webhook.verify_signature(message_id, timestamp, body, signature, secret)
end
```

### Testing Telemetry

```elixir
test "emits telemetry event" do
  {handler_id, cleanup} = attach_telemetry_handler([:twitchy, :api, :request])

  # Perform action that emits event
  MyModule.call_api(client)

  # Assert event received
  {measurements, metadata} = assert_receive_telemetry([:twitchy, :api, :request])
  assert measurements.duration > 0

  cleanup.()
end
```

## Writing New Tests

### Unit Test Template

```elixir
defmodule Twitchy.MyModuleTest do
  use ExUnit.Case, async: true

  alias Twitchy.MyModule

  describe "my_function/1" do
    test "returns success" do
      assert {:ok, result} = MyModule.my_function("input")
      assert result == "expected"
    end

    test "handles errors" do
      assert {:error, reason} = MyModule.my_function(nil)
      assert reason == :invalid_input
    end
  end
end
```

### API Test Template

```elixir
defmodule Twitchy.MyAPITest do
  use ExUnit.Case, async: true

  alias Twitchy.MyAPI
  import Twitchy.{TestHelpers, BypassHelpers}

  setup do
    bypass = Bypass.open()
    client = authenticated_client(%{base_url: "http://localhost:#{bypass.port}"})
    {:ok, bypass: bypass, client: client}
  end

  describe "get_resource/2" do
    test "fetches resource", %{bypass: bypass, client: client} do
      response = mock_api_response([%{"id" => "123", "name" => "Test"}])
      expect_helix_get(bypass, "/resources", response)

      assert {:ok, result} = MyAPI.get_resource(client, id: "123")
      assert length(result["data"]) == 1
    end
  end
end
```

### Integration Test Template

```elixir
defmodule Twitchy.Integration.MyFeatureTest do
  use ExUnit.Case

  @moduletag :integration

  @client_id System.get_env("TWITCH_CLIENT_ID")
  @client_secret System.get_env("TWITCH_CLIENT_SECRET")

  setup_all do
    unless @client_id && @client_secret do
      :skip
    else
      client = Twitchy.new(client_id: @client_id, client_secret: @client_secret)
      {:ok, authenticated} = Twitchy.Auth.get_app_access_token(client)
      {:ok, client: authenticated}
    end
  end

  @tag :skip  # Remove when ready to run
  test "performs real API call", %{client: client} do
    assert {:ok, response} = Twitchy.MyAPI.get_resource(client)
    assert is_map(response)
  end
end
```

## Best Practices

1. **Use async: true** for unit tests that don't share state
2. **Mock external services** with Bypass
3. **Test both success and error cases**
4. **Verify telemetry events** where applicable
5. **Use descriptive test names** that explain the behavior
6. **Group related tests** in describe blocks
7. **Keep tests focused** - one assertion per test when possible
8. **Tag integration tests** with `@moduletag :integration`
9. **Skip slow/external tests by default** with `@tag :skip`
10. **Clean up test resources** in on_exit callbacks

## Common Patterns

### Testing Errors

```elixir
test "returns error for invalid input" do
  assert {:error, %ValidationError{}} = MyModule.validate(nil)
end

test "raises on critical failure" do
  assert_raise RuntimeError, "message", fn ->
    MyModule.critical_operation()
  end
end
```

### Testing Async Operations

```elixir
test "sends async message" do
  {:ok, pid} = MyGenServer.start_link([])
  MyGenServer.async_call(pid)

  assert_receive {:result, value}, 1000
  assert value == "expected"
end
```

### Testing Streams

```elixir
test "streams paginated results" do
  results = MyModule.stream(client, opts) |> Enum.take(10)

  assert length(results) == 10
  assert Enum.all?(results, &is_map/1)
end
```

## Troubleshooting

### Tests Hanging

- Check for missing Bypass expectations
- Verify async operations have timeouts
- Look for blocking calls without cleanup

### Flaky Tests

- Use deterministic timestamps
- Avoid relying on timing
- Mock random values
- Ensure proper test isolation

### Coverage Gaps

```bash
mix coveralls.detail
# Check report for uncovered lines
```

## CI/CD Integration

```yaml
# .github/workflows/test.yml
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: 1.18
          otp-version: 27
      - run: mix deps.get
      - run: mix compile --warnings-as-errors
      - run: mix test
      - run: mix coveralls.github
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Resources

- [ExUnit Documentation](https://hexdocs.pm/ex_unit/)
- [Bypass Documentation](https://hexdocs.pm/bypass/)
- [ExCoveralls Documentation](https://hexdocs.pm/excoveralls/)
- [Testing Best Practices](https://hexdocs.pm/elixir/testing.html)
