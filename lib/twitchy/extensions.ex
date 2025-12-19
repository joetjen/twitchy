defmodule Twitchy.Extensions do
  @moduledoc """
  Twitch Extensions API endpoints.

  Provides functions for retrieving extension information and managing
  extension configuration.

  ## Examples

      # Get extensions
      {:ok, response} = Twitchy.Extensions.get_extensions(client,
        extension_id: "extension-id"
      )

      # Get released extensions
      {:ok, response} = Twitchy.Extensions.get_released_extensions(client,
        extension_id: "extension-id"
      )
  """

  alias Twitchy.HTTP

  @doc """
  Gets information about an extension.

  ## Parameters

  - `:extension_id` - Extension ID (required)
  - `:extension_version` - Extension version

  ## Examples

      {:ok, response} = Twitchy.Extensions.get_extensions(client,
        extension_id: "extension-id",
        extension_version: "1.0.0"
      )
  """
  @spec get_extensions(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_extensions(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/extensions", query: query)
  end

  @doc """
  Gets information about released extensions.

  ## Parameters

  - `:extension_id` - Extension ID (required)
  - `:extension_version` - Extension version

  ## Examples

      {:ok, response} = Twitchy.Extensions.get_released_extensions(client,
        extension_id: "extension-id"
      )
  """
  @spec get_released_extensions(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_released_extensions(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/extensions/released", query: query)
  end

  @doc """
  Gets extension configuration segment.

  Requires extension JWT.

  ## Parameters

  - `:extension_id` - Extension ID (required)
  - `:segment` - Segment type (`:broadcaster`, `:developer`, `:global`, required)
  - `:broadcaster_id` - Broadcaster ID (required for `:broadcaster` segment)

  ## Examples

      {:ok, response} = Twitchy.Extensions.get_extension_configuration_segment(client,
        extension_id: "extension-id",
        segment: "global"
      )
  """
  @spec get_extension_configuration_segment(Twitchy.t(), keyword()) ::
          {:ok, map()} | {:error, Exception.t()}
  def get_extension_configuration_segment(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/extensions/configurations", query: query)
  end

  @doc """
  Sets extension configuration segment.

  Requires extension JWT.

  ## Parameters

  - `:extension_id` - Extension ID (required)
  - `:segment` - Segment type (`:broadcaster`, `:developer`, `:global`, required)
  - `:broadcaster_id` - Broadcaster ID (required for `:broadcaster` segment)
  - `:content` - Configuration content string (required)
  - `:version` - Configuration version

  ## Examples

      {:ok, _} = Twitchy.Extensions.set_extension_configuration_segment(client,
        extension_id: "extension-id",
        segment: "global",
        content: "{\"config\": \"value\"}"
      )
  """
  @spec set_extension_configuration_segment(Twitchy.t(), keyword()) ::
          {:ok, map()} | {:error, Exception.t()}
  def set_extension_configuration_segment(client, params) do
    {segment, params} = Keyword.pop!(params, :segment)
    query = [segment: segment]
    body = Map.new(params)

    HTTP.put(client, "/extensions/configurations", query: query, json: body)
  end

  @doc """
  Sends an extension PubSub message.

  Requires extension JWT.

  ## Parameters

  - `:target` - Message targets (list of `:broadcast`, `:global`, `:whisper-<user-id>`, required)
  - `:broadcaster_id` - Broadcaster ID (required for `:broadcast` target)
  - `:is_global_broadcast` - Send to all channels (for `:global`)
  - `:message` - Message string (required)

  ## Examples

      :ok = Twitchy.Extensions.send_extension_pubsub_message(client,
        target: ["broadcast"],
        broadcaster_id: "12345",
        message: "{\"event\": \"update\"}"
      )
  """
  @spec send_extension_pubsub_message(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def send_extension_pubsub_message(client, params) do
    body = Map.new(params)

    case HTTP.post(client, "/extensions/pubsub", json: body) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Gets live channels with the extension activated.

  ## Parameters

  - `:extension_id` - Extension ID (required)
  - `:first` - Number of results per page (max 100, default 20)
  - `:after` - Cursor for pagination

  ## Examples

      {:ok, response} = Twitchy.Extensions.get_extension_live_channels(client,
        extension_id: "extension-id"
      )
  """
  @spec get_extension_live_channels(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_extension_live_channels(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/extensions/live", query: query)
  end

  @doc """
  Gets extension secrets.

  Requires extension owner JWT.

  ## Parameters

  - `:extension_id` - Extension ID (required)

  ## Examples

      {:ok, response} = Twitchy.Extensions.get_extension_secrets(client,
        extension_id: "extension-id"
      )
  """
  @spec get_extension_secrets(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_extension_secrets(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/extensions/jwt/secrets", query: query)
  end

  @doc """
  Creates a new extension secret.

  Requires extension owner JWT.

  ## Parameters

  - `:extension_id` - Extension ID (required)
  - `:delay` - Delay in seconds before activation (300 default)

  ## Examples

      {:ok, response} = Twitchy.Extensions.create_extension_secret(client,
        extension_id: "extension-id",
        delay: 300
      )
  """
  @spec create_extension_secret(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def create_extension_secret(client, params) do
    query = HTTP.build_query(params)
    HTTP.post(client, "/extensions/jwt/secrets", query: query)
  end
end
