defmodule BlankSlate.PodcastsFixtures do
  @moduledoc false

  def podcast_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        title: "The Daily Byte",
        host: "Alex Rivera",
        description: "A quick daily rundown of what matters in tech.",
        category: "Technology",
        artwork_url: "https://picsum.photos/seed/daily-byte/200"
      })

    %BlankSlate.Podcasts.Podcast{}
    |> Ecto.Changeset.change(attrs)
    |> BlankSlate.Repo.insert!()
  end
end
