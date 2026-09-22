# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     BlankSlate.Repo.insert!(%BlankSlate.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias BlankSlate.Podcasts.Podcast
alias BlankSlate.Repo

podcasts = [
  %{
    title: "The Daily Byte",
    host: "Alex Rivera",
    description: "A quick daily rundown of what matters in tech, in ten minutes or less.",
    category: "Technology",
    artwork_url: "https://picsum.photos/seed/daily-byte/200"
  },
  %{
    title: "Slow Cooking Sundays",
    host: "Maria Torres",
    description: "Unhurried conversations about seasonal cooking and the recipes behind them.",
    category: "Food",
    artwork_url: "https://picsum.photos/seed/slow-cooking/200"
  },
  %{
    title: "Marginal Gains",
    host: "Priya Nair",
    description: "Endurance athletes and coaches on the tiny habits that add up to big results.",
    category: "Sports",
    artwork_url: "https://picsum.photos/seed/marginal-gains/200"
  },
  %{
    title: "Court of Public Opinion",
    host: "Jordan Blake",
    description: "A weekly look at the legal cases shaping the headlines.",
    category: "News",
    artwork_url: "https://picsum.photos/seed/court-of-public-opinion/200"
  },
  %{
    title: "Backyard Naturalist",
    host: "Sam Okafor",
    description: "Field notes on the birds, bugs, and plants living in your own backyard.",
    category: "Science",
    artwork_url: "https://picsum.photos/seed/backyard-naturalist/200"
  },
  %{
    title: "Founders on Founders",
    host: "Lena Park",
    description: "Startup founders interview each other about the decisions that mattered most.",
    category: "Business",
    artwork_url: "https://picsum.photos/seed/founders-on-founders/200"
  },
  %{
    title: "Bedtime for Grownups",
    host: "The Quiet Hour Collective",
    description: "Slow, calming stories designed to help you drift off to sleep.",
    category: "Health",
    artwork_url: "https://picsum.photos/seed/bedtime-for-grownups/200"
  },
  %{
    title: "Retro Replay",
    host: "Chris Dawson",
    description: "Two lifelong gamers revisit the classics that defined a generation.",
    category: "Games",
    artwork_url: "https://picsum.photos/seed/retro-replay/200"
  },
  %{
    title: "Paint by Numbers",
    host: "Dana Whitfield",
    description: "An art historian breaks down a single painting, brushstroke by brushstroke.",
    category: "Arts",
    artwork_url: "https://picsum.photos/seed/paint-by-numbers/200"
  },
  %{
    title: "The Long Commute",
    host: "Marcus Webb",
    description: "Long-form interviews built for your longest drive of the week.",
    category: "Society & Culture",
    artwork_url: "https://picsum.photos/seed/the-long-commute/200"
  }
]

now = DateTime.utc_now() |> DateTime.truncate(:second)

entries =
  Enum.map(podcasts, fn attrs ->
    Map.merge(attrs, %{inserted_at: now, updated_at: now})
  end)

Repo.insert_all(Podcast, entries)
