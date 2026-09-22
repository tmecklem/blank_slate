defmodule BlankSlateWeb.PodcastLive.IndexTest do
  use BlankSlateWeb.ConnCase

  import Phoenix.LiveViewTest
  import BlankSlate.PodcastsFixtures

  describe "Index" do
    test "lists all podcasts on mount", %{conn: conn} do
      podcast = podcast_fixture(title: "The Daily Byte")

      {:ok, view, html} = live(conn, ~p"/")

      assert html =~ podcast.title
      assert has_element?(view, "#podcasts-#{podcast.id}", podcast.title)
    end

    test "shows an empty state when there are no podcasts", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#podcasts", "No podcasts found")
    end

    test "filters podcasts as the user searches", %{conn: conn} do
      match = podcast_fixture(title: "The Daily Byte")

      other =
        podcast_fixture(
          title: "Gardening Weekly",
          host: "Jo Green",
          description: "Tips for growing vegetables at home."
        )

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("#podcast-search-form")
      |> render_change(%{"search" => "daily"})

      assert has_element?(view, "#podcasts-#{match.id}")
      refute has_element?(view, "#podcasts-#{other.id}")
    end

    test "shows an empty state when the search has no matches", %{conn: conn} do
      podcast_fixture(title: "The Daily Byte")

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("#podcast-search-form")
      |> render_change(%{"search" => "nonexistent"})

      assert has_element?(view, "#podcasts", "No podcasts found")
    end
  end
end
