defmodule Garage.Repo do
  use Ecto.Repo,
    otp_app: :garage,
    adapter: Ecto.Adapters.SQLite3
end
