defmodule Twitchy.HTTP do
  @moduledoc """
  HTTP client for Twitch API using Req.

  Provides a configured Req client with:
  - Authentication headers
  - Rate limit tracking
  - Telemetry instrumentation
  - Error normalization
  - Retry logic

  ## Telemetry Events

  All API requests emit telemetry spans:

  - `[:twitchy, :api, :request, :start]` - Request started
  - `[:twitchy, :api, :request, :stop]` - Request completed
  - `[:twitchy, :api, :request, :exception]` - Request failed

  Metadata includes:
  - `method` - HTTP method (:get, :post, :put, :patch, :delete)
  - `endpoint` - API endpoint path
  - `status` - HTTP status code (in :stop event)
  - `user_id` - User ID if present in response
  - `broadcaster_id` - Broadcaster ID if present in response
  - `request_id` - Twitch request ID from response headers
  """

  alias Twitchy.{Config, Error, RateLimit}

  @doc """
  Performs a GET request to the Twitch API.

  ## Examples

      iex> Twitchy.HTTP.get(client, "/users", query: [login: "shroud"])
      {:ok, %{"data" => [%{"id" => "12345", ...}], ...}}
  """
  @spec get(Config.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get(%Config{} = config, path, opts \\ []) do
    request(config, :get, path, opts)
  end

  @doc """
  Performs a POST request to the Twitch API.

  ## Examples

      iex> Twitchy.HTTP.post(client, "/eventsub/subscriptions", json: %{type: "channel.follow", ...})
      {:ok, %{"data" => [%{...}]}}
  """
  @spec post(Config.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def post(%Config{} = config, path, opts \\ []) do
    request(config, :post, path, opts)
  end

  @doc """
  Performs a PUT request to the Twitch API.
  """
  @spec put(Config.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def put(%Config{} = config, path, opts \\ []) do
    request(config, :put, path, opts)
  end

  @doc """
  Performs a PATCH request to the Twitch API.
  """
  @spec patch(Config.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def patch(%Config{} = config, path, opts \\ []) do
    request(config, :patch, path, opts)
  end

  @doc """
  Performs a DELETE request to the Twitch API.
  """
  @spec delete(Config.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def delete(%Config{} = config, path, opts \\ []) do
    request(config, :delete, path, opts)
  end

  @doc """
  Performs an HTTP request with full telemetry and error handling.
  """
  @spec request(Config.t(), atom(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Exception.t()}
  def request(%Config{} = config, method, path, opts \\ []) do
    case Config.validate(config, :api_call) do
      :ok ->
        metadata = %{
          method: method,
          endpoint: path,
          client_id: config.client_id
        }

        :telemetry.span(
          [:twitchy, :api, :request],
          metadata,
          fn ->
            result = do_request(config, method, path, opts)
            {result, merge_result_metadata(result, metadata)}
          end
        )

      {:error, reason} ->
        {:error, %Error.ValidationError{message: reason}}
    end
  end

  defp merge_result_metadata({:ok, response}, metadata), do: Map.merge(metadata, extract_metadata(response))
  defp merge_result_metadata({:error, _}, metadata), do: metadata

  defp do_request(config, method, path, opts) do
    url = build_url(config.base_url, path)

    # Extract and rename query to params for Req compatibility
    opts =
      if Keyword.has_key?(opts, :query) do
        {query, opts} = Keyword.pop(opts, :query)
        Keyword.put(opts, :params, query)
      else
        opts
      end

    req_opts =
      [
        method: method,
        url: url,
        headers: build_headers(config),
        finch: config.finch_pool,
        retry: :transient,
        max_retries: config.retry_attempts,
        receive_timeout: config.timeout
      ]
      |> Keyword.merge(config.req_options)
      |> Keyword.merge(opts)

    case Req.request(req_opts) do
      {:ok, %Req.Response{status: status, body: body, headers: headers}} when status in 200..299 ->
        # Track rate limits
        rate_limit = RateLimit.from_headers(headers_to_map(headers))
        RateLimit.check(rate_limit, path)

        {:ok, body}

      {:ok, %Req.Response{status: status, body: body, headers: headers}} ->
        error_response = %{
          status: status,
          body: body,
          headers: headers_to_map(headers)
        }

        {:error, Error.normalize({:error, error_response})}

      {:error, exception} ->
        {:error, Error.normalize({:error, exception})}
    end
  end

  defp build_url(base_url, path) do
    path = String.trim_leading(path, "/")
    "#{base_url}/#{path}"
  end

  defp build_headers(%Config{} = config) do
    base_headers = [
      {"Client-Id", config.client_id},
      {"Authorization", "Bearer #{config.access_token}"},
      {"Content-Type", "application/json"}
    ]

    custom_headers = Enum.to_list(config.custom_headers)
    base_headers ++ custom_headers
  end

  defp headers_to_map(headers) when is_list(headers) do
    headers
    |> Enum.map(fn {k, v} -> {String.downcase(k), v} end)
    |> Map.new()
  end

  defp headers_to_map(headers) when is_map(headers), do: headers

  defp extract_metadata(response) when is_map(response) do
    metadata = %{
      status: 200
    }

    # Extract user_id if present
    metadata =
      case get_in(response, ["data"]) do
        [%{"user_id" => user_id} | _] -> Map.put(metadata, :user_id, user_id)
        _ -> metadata
      end

    # Extract broadcaster_id if present
    metadata =
      case get_in(response, ["data"]) do
        [%{"broadcaster_user_id" => broadcaster_id} | _] ->
          Map.put(metadata, :broadcaster_id, broadcaster_id)

        _ ->
          metadata
      end

    metadata
  end

  defp extract_metadata(_response), do: %{status: 200}

  @doc """
  Builds query parameters from a keyword list or map.

  Filters out nil values and converts atoms to strings. List values are expanded
  into repeated `key=value` pairs (e.g. `id: ["1", "2"]` becomes `id=1&id=2`),
  which is how the Twitch Helix API expects array parameters.

  ## Examples

      iex> Twitchy.HTTP.build_query(user_id: "12345", login: nil)
      [user_id: "12345"]

      iex> Twitchy.HTTP.build_query(%{first: 20, after: "cursor"})
      [first: "20", after: "cursor"]

      iex> Twitchy.HTTP.build_query(id: ["123", "456"])
      [id: "123", id: "456"]
  """
  @spec build_query(keyword() | map()) :: keyword()
  def build_query(params) when is_list(params) do
    params
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.flat_map(fn
      {k, v} when is_list(v) -> Enum.map(v, &{k, to_string(&1)})
      {k, v} -> [{k, to_string(v)}]
    end)
  end

  def build_query(params) when is_map(params) do
    params
    |> Enum.to_list()
    |> build_query()
  end
end
