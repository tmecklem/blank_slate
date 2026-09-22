defmodule BlankSlate.Repo do
  use Ecto.Repo,
    otp_app: :blank_slate,
    adapter: Ecto.Adapters.Postgres
end
