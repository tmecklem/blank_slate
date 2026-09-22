defmodule BlankSlateWeb.PodcastLive.Index do
  use BlankSlateWeb, :live_view

  alias BlankSlate.Podcasts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:search, "")
     |> stream(:podcasts, Podcasts.list_podcasts())}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply,
     socket
     |> assign(:search, search)
     |> stream(:podcasts, Podcasts.list_podcasts(search), reset: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Blank Slate
        <:subtitle>Find good podcasts.</:subtitle>
      </.header>

      <form id="podcast-search-form" phx-change="search">
        <.input
          id="podcast-search-input"
          type="search"
          name="search"
          value={@search}
          placeholder="Search by title, host, or topic"
          phx-debounce="300"
        />
      </form>

      <div id="podcasts" phx-update="stream" class="space-y-4">
        <div
          id="podcasts-empty"
          class="hidden only:block rounded-box border border-base-300 bg-base-200 p-8 text-center text-base-content/70"
        >
          No podcasts found.
        </div>
        <div
          :for={{id, podcast} <- @streams.podcasts}
          id={id}
          class="flex gap-4 rounded-box border border-base-300 bg-base-200 p-4"
        >
          <img src={podcast.artwork_url} alt="" class="size-16 shrink-0 rounded-lg object-cover" />
          <div>
            <h2 class="font-semibold">{podcast.title}</h2>
            <p class="text-sm text-base-content/70">{podcast.host}</p>
            <p class="text-sm text-base-content/70">{podcast.description}</p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
