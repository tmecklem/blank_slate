defmodule BlankSlate.Repo.Migrations.CreatePodcasts do
  use Ecto.Migration

  def change do
    create table(:podcasts) do
      add :title, :string, null: false
      add :host, :string, null: false
      add :description, :text, null: false
      add :category, :string, null: false
      add :artwork_url, :string, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
