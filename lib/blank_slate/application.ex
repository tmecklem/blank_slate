defmodule BlankSlate.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BlankSlateWeb.Telemetry,
      BlankSlate.Repo,
      {DNSCluster, query: Application.get_env(:blank_slate, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BlankSlate.PubSub},
      # Start a worker by calling: BlankSlate.Worker.start_link(arg)
      # {BlankSlate.Worker, arg},
      # Start to serve requests, typically the last entry
      BlankSlateWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BlankSlate.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BlankSlateWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
