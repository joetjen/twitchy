defmodule Twitchy do
  @moduledoc """
  A comprehensive Elixir client for the Twitch Helix API with EventSub support.

  Twitchy provides a pipeline-friendly, struct-based API for interacting with Twitch,
  featuring:

  - **Dual OAuth Support** - Both app access and user access tokens
  - **30+ API Endpoints** - Full Helix API coverage
  - **EventSub** - WebSocket and Webhook support for real-time events
  - **Telemetry** - Comprehensive instrumentation for observability
  - **Rate Limiting** - Automatic tracking and enforcement
  - **Pagination** - Lazy streaming and automatic page fetching
  - **Pluggable Token Storage** - Memory, Redis, database, or custom backends

  ## Quick Start

      # Create a client with app access token
      {:ok, client} = Twitchy.new(client_id: "your_client_id", client_secret: "your_secret")
                      |> Twitchy.authenticate(:app_access)

      # Make API requests
      {:ok, users} = Twitchy.Users.get_users(client, login: ["shroud", "ninja"])

      # Stream paginated results
      followers = client
                  |> Twitchy.Users.stream_followers(broadcaster_id: "12345")
                  |> Stream.take(100)
                  |> Enum.to_list()

  ## Configuration

  Configure via environment variables or runtime options:

      # Environment variables
      export TWITCH_CLIENT_ID="your_client_id"
      export TWITCH_CLIENT_SECRET="your_secret"
      export TWITCH_REDIRECT_URI="http://localhost:4000/auth/callback"

      # Runtime options
      client = Twitchy.new(
        client_id: "id",
        client_secret: "secret",
        timeout: 60_000,
        finch_pool: MyApp.Finch
      )

  ## Authentication

      # App Access Token (server-to-server)
      {:ok, client} = Twitchy.new(client_id: "id", client_secret: "secret")
                      |> Twitchy.authenticate(:app_access)

      # User Access Token (OAuth flow)
      # Step 1: Generate authorization URL
      auth_url = Twitchy.auth_url(client, ["user:read:email", "channel:read:subscriptions"])

      # Step 2: User authorizes, you receive code
      # Step 3: Exchange code for token
      {:ok, client} = Twitchy.authenticate(client, :user_access, code: "auth_code")

  ## Pipeline-Friendly Design

      client
      |> Twitchy.with_token_store(MyApp.RedisTokenStore)
      |> Twitchy.with_finch_pool(MyApp.Finch)
      |> Twitchy.authenticate(:app_access)
      |> case do
        {:ok, client} ->
          client
          |> Twitchy.Users.get_user(login: "shroud")
          |> Twitchy.Streams.get_stream()

        {:error, error} ->
          Logger.error("Auth failed: \#{inspect(error)}")
      end
  """

  alias Twitchy.{Auth, Config}

  @type t :: Config.t()
  @type auth_type :: :app_access | :user_access

  @doc """
  Creates a new Twitchy client instance.

  ## Options

  All `Twitchy.Config` struct fields can be passed as options:

  - `:client_id` - Twitch application client ID (required)
  - `:client_secret` - Twitch application client secret (required for auth)
  - `:redirect_uri` - OAuth redirect URI (required for user auth)
  - `:access_token` - Pre-existing access token (optional)
  - `:refresh_token` - Pre-existing refresh token (optional)
  - `:token_type` - Token type (`:app_access` or `:user_access`)
  - `:base_url` - API base URL (default: "https://api.twitch.tv/helix")
  - `:timeout` - Request timeout in milliseconds (default: 30_000)
  - `:retry_attempts` - Number of retry attempts (default: 3)
  - `:finch_pool` - Finch pool name (default: `Twitchy.Finch`)
  - `:token_store` - Token storage module (default: `Twitchy.TokenStore.Memory`)
  - `:eventsub_secret` - EventSub webhook secret
  - `:eventsub_callback_url` - EventSub webhook callback URL

  Environment variables override defaults (see module documentation).

  ## Examples

      # Minimal configuration (uses environment variables)
      client = Twitchy.new()

      # With explicit options
      client = Twitchy.new(
        client_id: "your_client_id",
        client_secret: "your_secret",
        timeout: 60_000
      )

      # With custom Finch pool
      client = Twitchy.new(client_id: "id", finch_pool: MyApp.Finch)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    Config.new(opts)
  end

  @doc """
  Authenticates the client and obtains an access token.

  ## Auth Types

  - `:app_access` - Client Credentials flow (server-to-server)
  - `:user_access` - Authorization Code flow (requires user authorization)

  ## Options for User Access

  - `:code` - Authorization code from OAuth callback (required)
  - `:scopes` - List of permission scopes (used for URL generation only)

  ## Examples

      # App access token
      {:ok, client} = Twitchy.new(client_id: "id", client_secret: "secret")
                      |> Twitchy.authenticate(:app_access)

      # User access token
      {:ok, client} = Twitchy.authenticate(client, :user_access, code: "auth_code_from_callback")
  """
  @spec authenticate(t(), auth_type(), keyword()) :: {:ok, t()} | {:error, Exception.t()}
  def authenticate(client, auth_type, opts \\ [])

  def authenticate(%Config{} = client, :app_access, _opts) do
    Auth.get_app_access_token(client)
  end

  def authenticate(%Config{} = client, :user_access, opts) do
    case Keyword.fetch(opts, :code) do
      {:ok, code} ->
        Auth.exchange_code(client, code)

      :error ->
        {:error,
         %Twitchy.Error.ValidationError{
           message: "Authorization code is required for user authentication",
           field: :code
         }}
    end
  end

  @doc """
  Generates an OAuth authorization URL for user authentication.

  Users should be redirected to this URL to authorize your application.
  After authorization, Twitch redirects to your `redirect_uri` with a `code` parameter.

  ## Parameters

  - `client` - Client configuration with `redirect_uri` set
  - `scopes` - List of permission scopes to request
  - `opts` - Additional options:
    - `:state` - CSRF protection token (highly recommended)
    - `:force_verify` - Force user to re-authorize (default: false)

  ## Examples

      client = Twitchy.new(
        client_id: "id",
        redirect_uri: "http://localhost:4000/auth/callback"
      )

      # Generate authorization URL
      auth_url = Twitchy.auth_url(client, [
        "user:read:email",
        "channel:read:subscriptions"
      ], state: "random_csrf_token")

      # In Phoenix controller:
      redirect(conn, external: auth_url)
  """
  @spec auth_url(t(), [String.t()], keyword()) :: String.t()
  def auth_url(%Config{} = client, scopes, opts \\ []) do
    Auth.authorization_url(client, scopes, opts)
  end

  @doc """
  Refreshes an expired user access token.

  Uses the refresh token to obtain a new access token without user interaction.
  Requires a `refresh_token` to be present in the client configuration.

  ## Examples

      {:ok, client} = Twitchy.refresh_token(client)
  """
  @spec refresh_token(t()) :: {:ok, t()} | {:error, Exception.t()}
  def refresh_token(%Config{} = client) do
    Auth.refresh_token(client)
  end

  @doc """
  Validates the current access token.

  Returns token information if valid, or an error if expired/invalid.

  ## Examples

      {:ok, token_info} = Twitchy.validate_token(client)
      # token_info contains: client_id, login, scopes, user_id, expires_in
  """
  @spec validate_token(t()) :: {:ok, map()} | {:error, Exception.t()}
  def validate_token(%Config{} = client) do
    Auth.validate_token(client)
  end

  @doc """
  Revokes the current access token.

  After revocation, the token can no longer be used for API requests.

  ## Examples

      :ok = Twitchy.revoke_token(client)
  """
  @spec revoke_token(t()) :: :ok | {:error, Exception.t()}
  def revoke_token(%Config{} = client) do
    Auth.revoke_token(client)
  end

  @doc """
  Sets a custom token store for the client.

  Token stores enable token persistence and sharing across processes.

  ## Examples

      # Use default memory store with custom name
      client = Twitchy.with_token_store(client, {Twitchy.TokenStore.Memory, name: MyTokenStore})

      # Use custom Redis store
      client = Twitchy.with_token_store(client, MyApp.RedisTokenStore)
  """
  @spec with_token_store(t(), module() | {module(), keyword()}) :: t()
  def with_token_store(%Config{} = client, token_store) do
    %{client | token_store: token_store}
  end

  @doc """
  Sets a custom Finch pool for HTTP requests.

  Allows using a separate Finch pool with custom configuration (connection limits,
  timeouts, etc.) for this client instance.

  ## Examples

      client = Twitchy.with_finch_pool(client, MyApp.Finch)
  """
  @spec with_finch_pool(t(), atom()) :: t()
  def with_finch_pool(%Config{} = client, finch_pool) when is_atom(finch_pool) do
    %{client | finch_pool: finch_pool}
  end

  @doc """
  Adds custom headers to all requests made by this client.

  ## Examples

      client = Twitchy.with_headers(client, %{"X-Custom-Header" => "value"})
  """
  @spec with_headers(t(), map()) :: t()
  def with_headers(%Config{} = client, headers) when is_map(headers) do
    %{client | custom_headers: Map.merge(client.custom_headers, headers)}
  end

  @doc """
  Sets the request timeout for this client.

  ## Examples

      client = Twitchy.with_timeout(client, 60_000)
  """
  @spec with_timeout(t(), timeout()) :: t()
  def with_timeout(%Config{} = client, timeout) do
    %{client | timeout: timeout}
  end

  @doc """
  Sets the base URL for API requests.

  Useful for testing or using alternative Twitch API endpoints.

  ## Examples

      client = Twitchy.with_base_url(client, "https://api.test.twitch.tv/helix")
  """
  @spec with_base_url(t(), String.t()) :: t()
  def with_base_url(%Config{} = client, base_url) do
    %{client | base_url: base_url}
  end
end
