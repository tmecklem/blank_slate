defmodule BlankSlate.PodcastsTest do
  use BlankSlate.DataCase, async: true

  alias BlankSlate.Podcasts

  import BlankSlate.PodcastsFixtures

  describe "list_podcasts/1" do
    test "returns all podcasts when no search term is given" do
      podcast = podcast_fixture()

      assert Podcasts.list_podcasts() == [podcast]
    end

    test "filters podcasts by title, host, or description" do
      match = podcast_fixture(title: "The Daily Byte")

      _other =
        podcast_fixture(
          title: "Gardening Weekly",
          host: "Jo Green",
          description: "Tips for growing vegetables at home."
        )

      assert Podcasts.list_podcasts("daily") == [match]
    end

    test "search is case-insensitive and matches host or description" do
      match = podcast_fixture(host: "Jo Green", description: "Grow a garden in your backyard.")
      _other = podcast_fixture(title: "The Daily Byte")

      assert Podcasts.list_podcasts("GARDEN") == [match]
    end

    test "returns an empty list when nothing matches" do
      podcast_fixture()

      assert Podcasts.list_podcasts("nonexistent") == []
    end
  end
end
