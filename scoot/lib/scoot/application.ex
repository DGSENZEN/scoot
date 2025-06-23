defmodule Scoot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ScootWeb.Telemetry,
      Scoot.Repo,
      {DNSCluster, query: Application.get_env(:scoot, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Scoot.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Scoot.Finch},
      # Start a worker by calling: Scoot.Worker.start_link(arg)
      # {Scoot.Worker, arg},
      # Start to serve requests, typically the last entry
      ScootWeb.Endpoint,
      Scoot.TFAPoller
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Scoot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ScootWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
