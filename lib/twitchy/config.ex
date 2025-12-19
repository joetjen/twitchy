defmodule Twitchy.Config do
  @moduledoc """
  Configuration struct for Twitchy client instances.

  Holds all configuration for API requests, authentication, and EventSub connections.
  """

  @type auth_type :: :app_access | :user_access | nil
  @type token_store :: module() | {module(), keyword()} | nil

  @type t :: %__MODULE__{
          # Credentials
          client_id: String.t() | nil,
          client_secret: String.t() | nil,
          redirect_uri: String.t() | nil,

          # Authentication state
          access_token: String.t() | nil,
          refresh_token: String.t() | nil,
          token_type: auth_type(),
          expires_at: DateTime.t() | nil,
          scopes: [String.t()],

          # HTTP configuration
          base_url: String.t(),
          timeout: timeout(),
          retry_attempts: non_neg_integer(),
          finch_pool: atom(),

          # Token storage
          token_store: token_store(),
          token_store_opts: keyword(),

          # EventSub configuration
          eventsub_secret: String.t() | nil,
          eventsub_callback_url: String.t() | nil,

          # Custom middleware and options
          req_options: keyword(),
          custom_headers: map()
        }

  defstruct client_id: nil,
            client_secret: nil,
            redirect_uri: nil,
            access_token: nil,
            refresh_token: nil,
            token_type: nil,
            expires_at: nil,
            scopes: [],
            base_url: "https://api.twitch.tv/helix",
            timeout: 30_000,
            retry_attempts: 3,
            finch_pool: Twitchy.Finch,
            token_store: Twitchy.TokenStore.Memory,
            token_store_opts: [],
            eventsub_secret: nil,
            eventsub_callback_url: nil,
            req_options: [],
            custom_headers: %{}

  @doc """
  Creates a new configuration from environment variables and options.

  ## Environment Variables

  - `TWITCH_CLIENT_ID` - Twitch application client ID
  - `TWITCH_CLIENT_SECRET` - Twitch application client secret
  - `TWITCH_REDIRECT_URI` - OAuth redirect URI for user authentication
  - `TWITCH_EVENTSUB_SECRET` - Secret for EventSub webhook signature verification
  - `TWITCH_EVENTSUB_CALLBACK_URL` - Public URL for EventSub webhooks

  ## Options

  All struct fields can be passed as options and will override environment variables.

  ## Examples

      iex> Twitchy.Config.new()
      %Twitchy.Config{client_id: "your_client_id", ...}

      iex> Twitchy.Config.new(client_id: "custom_id", timeout: 60_000)
      %Twitchy.Config{client_id: "custom_id", timeout: 60_000, ...}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    env_config = %{
      client_id: System.get_env("TWITCH_CLIENT_ID"),
      client_secret: System.get_env("TWITCH_CLIENT_SECRET"),
      redirect_uri: System.get_env("TWITCH_REDIRECT_URI"),
      eventsub_secret: System.get_env("TWITCH_EVENTSUB_SECRET"),
      eventsub_callback_url: System.get_env("TWITCH_EVENTSUB_CALLBACK_URL")
    }

    config =
      %__MODULE__{}
      |> Map.merge(env_config)
      |> Map.merge(Map.new(opts))

    config
  end

  @doc """
  Validates that required configuration is present for the given operation type.

  ## Examples

      iex> Twitchy.Config.validate(%Twitchy.Config{client_id: "id"}, :app_auth)
      {:error, "client_secret is required for app authentication"}

      iex> Twitchy.Config.validate(%Twitchy.Config{client_id: "id", client_secret: "secret"}, :app_auth)
      :ok
  """
  @spec validate(t(), :app_auth | :user_auth | :api_call) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = config, :app_auth) do
    with :ok <- require_field(config, :client_id, "app authentication"),
         :ok <- require_field(config, :client_secret, "app authentication") do
      :ok
    end
  end

  def validate(%__MODULE__{} = config, :user_auth) do
    with :ok <- require_field(config, :client_id, "user authentication"),
         :ok <- require_field(config, :client_secret, "user authentication"),
         :ok <- require_field(config, :redirect_uri, "user authentication") do
      :ok
    end
  end

  def validate(%__MODULE__{} = config, :api_call) do
    with :ok <- require_field(config, :client_id, "API calls"),
         :ok <- require_field(config, :access_token, "API calls") do
      :ok
    end
  end

  defp require_field(config, field, operation) do
    if Map.get(config, field) do
      :ok
    else
      {:error, "#{field} is required for #{operation}"}
    end
  end

  @doc """
  Updates the configuration with new token information.

  ## Examples

      iex> config = Twitchy.Config.new()
      iex> Twitchy.Config.put_token(config, "new_token", expires_in: 3600, token_type: :app_access)
      %Twitchy.Config{access_token: "new_token", token_type: :app_access, ...}
  """
  @spec put_token(t(), String.t(), keyword()) :: t()
  def put_token(%__MODULE__{} = config, token, opts \\ []) do
    expires_at =
      case Keyword.get(opts, :expires_in) do
        nil -> nil
        seconds -> DateTime.utc_now() |> DateTime.add(seconds, :second)
      end

    %{
      config
      | access_token: token,
        refresh_token: Keyword.get(opts, :refresh_token),
        token_type: Keyword.get(opts, :token_type),
        expires_at: expires_at,
        scopes: Keyword.get(opts, :scopes, config.scopes)
    }
  end

  @doc """
  Checks if the access token is expired or will expire soon.

  Returns `true` if the token is expired or will expire within the buffer time (default 5 minutes).

  ## Examples

      iex> config = %Twitchy.Config{expires_at: DateTime.add(DateTime.utc_now(), -60, :second)}
      iex> Twitchy.Config.token_expired?(config)
      true

      iex> config = %Twitchy.Config{expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)}
      iex> Twitchy.Config.token_expired?(config)
      false
  """
  @spec token_expired?(t(), non_neg_integer()) :: boolean()
  def token_expired?(config, buffer_seconds \\ 300)

  def token_expired?(%__MODULE__{expires_at: nil}, _buffer_seconds), do: false

  def token_expired?(%__MODULE__{expires_at: expires_at}, buffer_seconds) do
    now = DateTime.utc_now()
    buffer_time = DateTime.add(now, buffer_seconds, :second)
    DateTime.compare(expires_at, buffer_time) == :lt
  end
end
