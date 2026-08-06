defmodule Twitchy.Auth do
  @moduledoc """
  OAuth 2.0 authentication for Twitch API.

  Supports both authentication flows:
  - **App Access Tokens** (Client Credentials Flow) - For server-to-server requests
  - **User Access Tokens** (Authorization Code Flow) - For user-authenticated requests

  ## Telemetry Events

  All authentication operations emit telemetry events:

  - `[:twitchy, :auth, :token, :start]` - Token request started
  - `[:twitchy, :auth, :token, :stop]` - Token request completed
  - `[:twitchy, :auth, :token, :exception]` - Token request failed

  Metadata includes:
  - `token_type` - `:app_access` or `:user_access`
  - `scopes` - List of requested scopes
  - `expires_in` - Token expiration time in seconds

  ## Examples

      # App Access Token (Client Credentials)
      {:ok, client} = Twitchy.new(client_id: "id", client_secret: "secret")
                      |> Twitchy.authenticate(:app_access)

      # User Access Token (Authorization Code Flow)
      # Step 1: Generate authorization URL
      auth_url = Twitchy.Auth.authorization_url(client, [
        "user:read:email",
        "channel:read:subscriptions"
      ])

      # Step 2: Redirect user to auth_url, they approve, Twitch redirects back with code

      # Step 3: Exchange code for token
      {:ok, client} = Twitchy.Auth.exchange_code(client, code)
  """

  alias Twitchy.{Config, Error}
  require Logger

  defp token_url(config), do: "#{config.auth_base_url}/token"
  defp authorize_url(config), do: "#{config.auth_base_url}/authorize"
  defp validate_url(config), do: "#{config.auth_base_url}/validate"
  defp revoke_url(config), do: "#{config.auth_base_url}/revoke"

  @doc """
  Obtains an app access token using the Client Credentials flow.

  This token type is used for server-to-server requests and doesn't require user authorization.

  ## Examples

      iex> config = Twitchy.Config.new(client_id: "id", client_secret: "secret")
      iex> {:ok, new_config} = Twitchy.Auth.get_app_access_token(config)
      {:ok, %Twitchy.Config{access_token: "token", token_type: :app_access, ...}}
  """
  @spec get_app_access_token(Config.t()) :: {:ok, Config.t()} | {:error, Exception.t()}
  def get_app_access_token(%Config{} = config) do
    case Config.validate(config, :app_auth) do
      :ok ->
        metadata = %{
          token_type: :app_access,
          client_id: config.client_id
        }

        :telemetry.span(
          [:twitchy, :auth, :token],
          metadata,
          fn ->
            result = do_get_app_access_token(config)
            {result, merge_token_metadata(result, metadata)}
          end
        )

      {:error, reason} ->
        {:error, %Error.ValidationError{message: reason}}
    end
  end

  defp merge_token_metadata({:ok, new_config}, metadata) do
    Map.merge(metadata, %{
      expires_in: calculate_expires_in(new_config.expires_at),
      scopes: new_config.scopes
    })
  end

  defp merge_token_metadata({:error, _}, metadata), do: metadata

  defp do_get_app_access_token(config) do
    body = %{
      client_id: config.client_id,
      client_secret: config.client_secret,
      grant_type: "client_credentials"
    }

    case Req.post(token_url(config), json: body) do
      {:ok, %{status: 200, body: response}} ->
        config =
          Config.put_token(config, response["access_token"],
            token_type: :app_access,
            expires_in: response["expires_in"],
            scopes: response["scope"] || []
          )

        # Store token if token store is configured
        if config.token_store do
          store_token(config)
        end

        {:ok, config}

      {:ok, %{status: status, body: body}} ->
        {:error,
         %Error.AuthError{
           message: "Failed to obtain app access token",
           reason: body["message"] || body["error"] || "Unknown error",
           status: status
         }}

      {:error, exception} ->
        {:error, %Error.HTTPError{message: "Failed to request token", reason: exception}}
    end
  end

  @doc """
  Generates an authorization URL for the OAuth Authorization Code flow.

  The user should be redirected to this URL to authorize your application.
  After authorization, Twitch will redirect back to your `redirect_uri` with a code parameter.

  ## Parameters

  - `config` - Client configuration with `redirect_uri` set
  - `scopes` - List of permission scopes to request
  - `opts` - Additional options:
    - `:state` - CSRF protection token (recommended)
    - `:force_verify` - Force user to re-authorize (default: false)

  ## Examples

      iex> config = Twitchy.Config.new(client_id: "id", redirect_uri: "http://localhost:4000/auth/callback")
      iex> Twitchy.Auth.authorization_url(config, ["user:read:email"], state: "random_string")
      "https://id.twitch.tv/oauth2/authorize?client_id=id&redirect_uri=..."
  """
  @spec authorization_url(Config.t(), [String.t()], keyword()) :: String.t()
  def authorization_url(%Config{} = config, scopes, opts \\ []) do
    params = %{
      client_id: config.client_id,
      redirect_uri: config.redirect_uri,
      response_type: "code",
      scope: Enum.join(scopes, " ")
    }

    params =
      if state = Keyword.get(opts, :state) do
        Map.put(params, :state, state)
      else
        params
      end

    params =
      if Keyword.get(opts, :force_verify, false) do
        Map.put(params, :force_verify, "true")
      else
        params
      end

    query = URI.encode_query(params)
    "#{authorize_url(config)}?#{query}"
  end

  @doc """
  Exchanges an authorization code for a user access token.

  After the user authorizes your application, Twitch redirects to your `redirect_uri`
  with a `code` parameter. Use this function to exchange the code for an access token.

  ## Examples

      iex> config = Twitchy.Config.new(client_id: "id", client_secret: "secret", redirect_uri: "...")
      iex> {:ok, new_config} = Twitchy.Auth.exchange_code(config, "authorization_code_from_twitch")
      {:ok, %Twitchy.Config{access_token: "user_token", token_type: :user_access, ...}}
  """
  @spec exchange_code(Config.t(), String.t()) :: {:ok, Config.t()} | {:error, Exception.t()}
  def exchange_code(%Config{} = config, code) do
    case Config.validate(config, :user_auth) do
      :ok ->
        metadata = %{
          token_type: :user_access,
          client_id: config.client_id
        }

        :telemetry.span(
          [:twitchy, :auth, :token],
          metadata,
          fn ->
            result = do_exchange_code(config, code)
            {result, merge_token_metadata(result, metadata)}
          end
        )

      {:error, reason} ->
        {:error, %Error.ValidationError{message: reason}}
    end
  end

  defp do_exchange_code(config, code) do
    body = %{
      client_id: config.client_id,
      client_secret: config.client_secret,
      code: code,
      grant_type: "authorization_code",
      redirect_uri: config.redirect_uri
    }

    case Req.post(token_url(config), form: body) do
      {:ok, %{status: 200, body: response}} ->
        config =
          Config.put_token(config, response["access_token"],
            token_type: :user_access,
            refresh_token: response["refresh_token"],
            expires_in: response["expires_in"],
            scopes: response["scope"] || []
          )

        # Store token if token store is configured
        if config.token_store do
          store_token(config)
        end

        {:ok, config}

      {:ok, %{status: status, body: body}} ->
        {:error,
         %Error.AuthError{
           message: "Failed to exchange authorization code",
           reason: body["message"] || body["error"] || "Unknown error",
           status: status
         }}

      {:error, exception} ->
        {:error, %Error.HTTPError{message: "Failed to exchange code", reason: exception}}
    end
  end

  @doc """
  Refreshes a user access token using a refresh token.

  User access tokens expire after a certain time. Use the refresh token to obtain
  a new access token without requiring the user to re-authorize.

  ## Examples

      iex> config = %Twitchy.Config{refresh_token: "refresh_token", ...}
      iex> {:ok, new_config} = Twitchy.Auth.refresh_token(config)
      {:ok, %Twitchy.Config{access_token: "new_token", ...}}
  """
  @spec refresh_token(Config.t()) :: {:ok, Config.t()} | {:error, Exception.t()}
  def refresh_token(%Config{refresh_token: nil}) do
    {:error, %Error.ValidationError{message: "No refresh token available", field: :refresh_token}}
  end

  def refresh_token(%Config{} = config) do
    metadata = %{
      token_type: :user_access,
      client_id: config.client_id,
      operation: :refresh
    }

    :telemetry.span(
      [:twitchy, :auth, :token],
      metadata,
      fn ->
        result = do_refresh_token(config)
        {result, merge_token_metadata(result, metadata)}
      end
    )
  end

  defp do_refresh_token(config) do
    body = %{
      client_id: config.client_id,
      client_secret: config.client_secret,
      grant_type: "refresh_token",
      refresh_token: config.refresh_token
    }

    case Req.post(token_url(config), json: body) do
      {:ok, %{status: 200, body: response}} ->
        config =
          Config.put_token(config, response["access_token"],
            token_type: :user_access,
            refresh_token: response["refresh_token"] || config.refresh_token,
            expires_in: response["expires_in"],
            scopes: response["scope"] || config.scopes
          )

        # Store token if token store is configured
        if config.token_store do
          store_token(config)
        end

        {:ok, config}

      {:ok, %{status: status, body: body}} ->
        {:error,
         %Error.AuthError{
           message: "Failed to refresh token",
           reason: body["message"] || body["error"] || "Unknown error",
           status: status
         }}

      {:error, exception} ->
        {:error, %Error.HTTPError{message: "Failed to refresh token", reason: exception}}
    end
  end

  @doc """
  Validates an access token and returns information about it.

  Useful for checking if a token is still valid and retrieving token metadata.

  ## Examples

      iex> config = %Twitchy.Config{access_token: "token", ...}
      iex> {:ok, info} = Twitchy.Auth.validate_token(config)
      {:ok, %{
        "client_id" => "your_client_id",
        "login" => "username",
        "scopes" => ["user:read:email"],
        "user_id" => "12345",
        "expires_in" => 3600
      }}
  """
  @spec validate_token(Config.t()) :: {:ok, map()} | {:error, Exception.t()}
  def validate_token(%Config{access_token: nil}) do
    {:error, %Error.ValidationError{message: "No access token to validate", field: :access_token}}
  end

  def validate_token(%Config{} = config) do
    headers = [{"Authorization", "OAuth #{config.access_token}"}]

    case Req.get(validate_url(config), headers: headers) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 401}} ->
        {:error, %Error.AuthError{message: "Token is invalid or expired", reason: :invalid_token, status: 401}}

      {:ok, %{status: status, body: body}} ->
        {:error,
         %Error.AuthError{
           message: "Failed to validate token",
           reason: body["message"] || "Unknown error",
           status: status
         }}

      {:error, exception} ->
        {:error, %Error.HTTPError{message: "Failed to validate token", reason: exception}}
    end
  end

  @doc """
  Revokes an access token.

  After revocation, the token can no longer be used.

  ## Examples

      iex> config = %Twitchy.Config{access_token: "token", client_id: "id"}
      iex> :ok = Twitchy.Auth.revoke_token(config)
  """
  @spec revoke_token(Config.t()) :: :ok | {:error, Exception.t()}
  def revoke_token(%Config{access_token: nil}) do
    {:error, %Error.ValidationError{message: "No access token to revoke", field: :access_token}}
  end

  def revoke_token(%Config{} = config) do
    body = %{
      client_id: config.client_id,
      token: config.access_token
    }

    case Req.post(revoke_url(config), json: body) do
      {:ok, %{status: 200}} ->
        # Remove from token store if configured
        if config.token_store && config.client_id do
          delete_token(config)
        end

        :ok

      {:ok, %{status: status, body: body}} ->
        {:error,
         %Error.AuthError{
           message: "Failed to revoke token",
           reason: body["message"] || body["error"] || "Unknown error",
           status: status
         }}

      {:error, exception} ->
        {:error, %Error.HTTPError{message: "Failed to revoke token", reason: exception}}
    end
  end

  # Token Store Helpers

  defp store_token(%Config{token_store: nil}), do: :ok

  defp store_token(%Config{} = config) do
    token_data = %{
      access_token: config.access_token,
      refresh_token: config.refresh_token,
      token_type: config.token_type,
      expires_at: config.expires_at,
      scopes: config.scopes
    }

    case config.token_store do
      module when is_atom(module) ->
        module.put_token(config.client_id, token_data)

      {module, name} ->
        module.put_token(name, config.client_id, token_data)
    end
  end

  defp delete_token(%Config{token_store: nil}), do: :ok

  defp delete_token(%Config{} = config) do
    case config.token_store do
      module when is_atom(module) ->
        module.delete_token(config.client_id)

      {module, name} ->
        module.delete_token(name, config.client_id)
    end
  end

  defp calculate_expires_in(nil), do: nil

  defp calculate_expires_in(expires_at) do
    DateTime.diff(expires_at, DateTime.utc_now(), :second)
  end
end
