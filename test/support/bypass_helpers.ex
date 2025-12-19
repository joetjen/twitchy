defmodule Twitchy.BypassHelpers do
  @moduledoc """
  Helpers for testing with Bypass HTTP mocking.
  """

  @doc """
  Sets up a Bypass server for OAuth token endpoint.
  """
  def expect_oauth_token(bypass, response) do
    Bypass.expect_once(bypass, "POST", "/oauth2/token", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(response))
    end)
  end

  @doc """
  Sets up a Bypass server for OAuth validation endpoint.
  """
  def expect_oauth_validate(bypass, response) do
    Bypass.expect_once(bypass, "GET", "/oauth2/validate", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(response))
    end)
  end

  @doc """
  Sets up a Bypass server for a generic Helix API endpoint.
  """
  def expect_helix_get(bypass, path, response, status \\ 200) do
    Bypass.expect_once(bypass, "GET", path, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(status, Jason.encode!(response))
    end)
  end

  @doc """
  Sets up a Bypass server for a Helix POST endpoint.
  """
  def expect_helix_post(bypass, path, response, status \\ 200) do
    Bypass.expect_once(bypass, "POST", path, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(status, Jason.encode!(response))
    end)
  end

  @doc """
  Sets up a Bypass server for a Helix DELETE endpoint.
  """
  def expect_helix_delete(bypass, path, response \\ %{}, status \\ 204) do
    Bypass.expect_once(bypass, "DELETE", path, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(status, Jason.encode!(response))
    end)
  end

  @doc """
  Sets up rate limit headers.
  """
  def with_rate_limit_headers(conn, remaining \\ 800, limit \\ 800) do
    conn
    |> Plug.Conn.put_resp_header("ratelimit-limit", "#{limit}")
    |> Plug.Conn.put_resp_header("ratelimit-remaining", "#{remaining}")
    |> Plug.Conn.put_resp_header("ratelimit-reset", "#{DateTime.utc_now() |> DateTime.to_unix()}")
  end

  @doc """
  Verifies authorization header is present.
  """
  def verify_auth_header(conn, expected_token) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> ^expected_token] -> :ok
      _ -> raise "Invalid or missing authorization header"
    end

    conn
  end

  @doc """
  Verifies Client-ID header is present.
  """
  def verify_client_id_header(conn, expected_client_id) do
    case Plug.Conn.get_req_header(conn, "client-id") do
      [^expected_client_id] -> :ok
      _ -> raise "Invalid or missing client-id header"
    end

    conn
  end
end
