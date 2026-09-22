defmodule BlankSlate.Podcasts do
  @moduledoc """
  The Podcasts context.
  """

  import Ecto.Query, warn: false
  alias BlankSlate.Repo
  alias BlankSlate.Podcasts.Podcast

  @doc """
  Returns podcasts ordered by title, optionally filtered by a search term
  matched against title, host, and description.
  """
  def list_podcasts(search \\ nil) do
    Podcast
    |> filter_by_search(search)
    |> order_by(asc: :title)
    |> Repo.all()
  end

  defp filter_by_search(query, search) when search in [nil, ""], do: query

  defp filter_by_search(query, search) do
    term = "%#{search}%"

    where(
      query,
      [p],
      ilike(p.title, ^term) or ilike(p.host, ^term) or ilike(p.description, ^term)
    )
  end
end
