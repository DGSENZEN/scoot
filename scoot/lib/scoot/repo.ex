defmodule Scoot.Repo do
  use Ecto.Repo,
    otp_app: :scoot,
    adapter: Ecto.Adapters.Postgres
end
