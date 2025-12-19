defmodule Twitchy.Application do
  @moduledoc """
  The Twitchy Application.

  Supervises the default Finch pool for HTTP connections to the Twitch API.
  Custom Finch pools can be specified per client instance using `Twitchy.with_finch_pool/2`.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch,
       name: Twitchy.Finch,
       pools: %{
         default: [
           size: 25,
           count: 1,
           conn_opts: [
             transport_opts: [
               timeout: 30_000
             ]
           ]
         ]
       }},
      Twitchy.EventSub.Supervisor
    ]

    opts = [strategy: :one_for_one, name: Twitchy.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
