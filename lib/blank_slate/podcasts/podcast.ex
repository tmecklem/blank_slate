defmodule BlankSlate.Podcasts.Podcast do
  use Ecto.Schema

  schema "podcasts" do
    field :title, :string
    field :host, :string
    field :description, :string
    field :category, :string
    field :artwork_url, :string

    timestamps(type: :utc_datetime)
  end
end
