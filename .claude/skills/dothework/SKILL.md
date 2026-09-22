---
name: dothework
description: End-to-end card workflow. Takes a Launchbox card short code, checks out a fresh branch from main, moves the card to Development, drives the work TDD-style, opens a PR, and finally moves the card to Automated Review. Invoke when the user runs `/dothework <short-code>`.
---

# Do The Work

This skill takes a Launchbox card from "ready to start" to "in automated review" with no shortcuts. You are responsible for delivering tested, reviewed-ready code on a branch with an open PR.

The skill takes one argument: a Launchbox card short code (e.g. `abc-12`). If the user invokes `/dothework` without an argument, ask which card they want to work.

## Talking to Launchbox

Launchbox is reached through the `launchbox` MCP server declared in `.mcp.json` (the code-mode endpoint). It exposes two tools:

- `mcp__launchbox__search` — look up a capability and its argument schema
- `mcp__launchbox__execute` — run a Lua script; call Launchbox tools inside it with `launchbox.call_tool(name, args)`

Every Launchbox tool named below (`search_cards`, `get_board_overview`, `move_card_to_column`, `get_users`, `assign_user`) is called through `execute`. If you're unsure of a tool's arguments, `search` for it first. Batch related reads into one script and return only the fields you need — board overviews can be large.

If the `launchbox` server isn't connected, stop and tell the user.

## Workflow — execute these steps in order

### 1. Sync local main and stash any in-progress work

```
git checkout main && git pull
```

If `git status` shows uncommitted changes after the checkout, run `git stash push -u -m "dothework auto-stash"` to keep the workspace clean. Tell the user you stashed their changes so they can restore them later with `git stash pop`. Do not delete or discard work without permission.

### 2. Look up the card and check out its branch

Call `search_cards` with the short code to find the card. Capture:
- card id
- title
- notes (the card description)
- `suggested_branch_name`
- the board_placement (board id + current column id)

Then create the branch from the just-pulled main:

```
git checkout -b <suggested_branch_name>
```

If the branch already exists locally, check it out and `git pull --ff-only` if there's a remote. If the branch already has unrelated commits, stop and ask the user how to proceed.

### 3. Move the card to Development and assign yourself

Find the Development column on the card's board with `get_board_overview`, then call `move_card_to_column` to move the card there. Skip if it's already in Development.

Then assign the developer running the skill to the card so the board reflects who's working on it:

1. Read the developer's email from git: `git config user.email`.
2. Call `get_users` to list active members of the current organization and find the one whose `email` matches.
3. Call `assign_user` with `card_id` and the matched `user_id`.

`assign_user` is additive — a card can have multiple assignees, so it's safe to run even if someone else has already picked up the card. If the same user is already assigned, the tool returns the error `"User is already assigned to this card"` — treat that string as success and continue, don't fail the workflow.

If no organization member matches the git email (e.g. the developer hasn't been added to the org, or the git email is misconfigured), warn the user and skip the assignment — don't fail the workflow either.

### 4. Read the card description and project documentation

- Re-read the card notes you captured in step 2
- Read `AGENTS.md` at the project root
- Read any other project documentation that looks relevant (e.g. `README.md`, the relevant context module's moduledoc)

The goal is to load enough context that you can make good design decisions without guessing.

### 5. Web research for technical unknowns

If the card touches a library, API, or pattern you're not certain about, look it up. Prefer official docs (hexdocs.pm for Elixir libraries). Write down (in your own working notes, not the codebase) the conclusions you reach so you don't have to re-research later.

### 6. Interview the user for design and product gaps

After research, ask the user any questions you still have about scope, behavior, or design. Use `AskUserQuestion` for choices between concrete options. Skip this step only if the card and docs already give you everything you need.

### 7. Work the card with a TDD red-green-refactor loop

Follow the project's `tdd` skill rigorously:

1. Write a failing test that captures one slice of behavior
2. Run the test, confirm it fails for the right reason
3. Implement the minimum code to make it pass
4. Run the test, confirm it passes
5. Refactor if needed, keeping tests green
6. **Run `mix precommit`** before moving to the next red test — this catches compile warnings, formatting, and test failures while the change is still small
7. Repeat until the slice is done

If `mix precommit` fails, fix it before proceeding. Never accumulate broken state.

**Before moving to the next slice, verify consistency with sibling code:**

- **Match adjacent patterns:** Before writing a new context function, LiveView event handler, or component, read 2-3 existing ones nearby. Match their structure — error formatting, `with` vs `case`, assign naming, broadcast patterns. Most review feedback comes from inconsistency with sibling code.
- **Scope:** If the app has `phx.gen.auth` scopes, context functions that read or mutate user-owned data take `current_scope` as their first argument, and routes live in the correct `live_session` (see `AGENTS.md`).
- **PubSub events in LiveViews:** When subscribing a LiveView to a new event, verify the LiveView actually renders the affected data. If it doesn't, handle the event as a no-op.

### 8. Self-review before committing

Before staging anything, **re-read `AGENTS.md`** (especially the Phoenix, LiveView, Ecto, and Writing Style sections) and check your memory files for prior feedback. Then scan the diff for these patterns that consistently cause review feedback:

- [ ] **No discarded return values.** Every context/Repo call that returns `{:ok, _} | {:error, _}` is handled with `case` or `with` — no bare `=` matches on failable calls.
- [ ] **No LiveView → Repo.** No LiveView aliases or calls `Repo` directly. Queries and transactions live in a context function.
- [ ] **No N+1 loops.** No `Enum.each`/`Enum.map` calling a Repo function inside the body — preload associations and use `Repo.insert_all`/`Repo.update_all` for batch operations.
- [ ] **Streams for collections.** LiveView collections use `stream/3`, with `phx-update="stream"` and a DOM id on the parent.
- [ ] **Template conventions.** LiveView templates start with `<Layouts.app flash={@flash} ...>`, forms use `to_form/2` + `<.input>`, icons use `<.icon>`, and key elements have unique DOM ids that the tests reference.
- [ ] **No programmatic fields in `cast`.** Fields like `user_id` are set explicitly, never cast from params.
- [ ] **Context boundaries.** No LiveView or context reaches into another context's schema for writes.
- [ ] **Comments earn their length.** Every comment in the diff is shorter than the code it explains and says something the code cannot. Delete restated-code comments rather than rewording them. Apply the Writing Style section of `AGENTS.md` to comments, commit messages, and the PR body alike.
- [ ] **Environment configs in sync.** If the diff adds a system package, background service, or toolchain version, it makes the matching change in `.launchbox/vm.json`, `.launchbox/supervisord.conf`, or `.tool-versions`. See the Development environment section of `AGENTS.md`.

Fix any violations before committing.

### 9. Commit in semantic chunks

Group changes into commits that each tell a coherent story. Prefer multiple small commits over one giant one. Use semantic prefixes that match the repo's existing convention (look at `git log --oneline -20`).

Always include the card short code in commit messages so the GitHub webhook can link the PR back to the card automatically.

**Do not add `Co-Authored-By` or other attribution lines to commit messages.** `AGENTS.md` forbids them, and Claude Code's default commit behavior adds them — you must explicitly omit attribution footers when crafting the commit message.

### 10. Push and open a PR after the first commit

After the **first** commit lands locally:

```
git push -u origin <branch>
```

Then open a PR with `gh pr create`. Title should include the card short code. Body should have a Summary and Test plan section, and no attribution footer.

Subsequent commits just need `git push` — the PR updates automatically.

### 11. Run local review agent (if available)

After the final push, check whether `/workspaces/realtime_project_agent` exists:

```
ls /workspaces/realtime_project_agent
```

If the directory **does not exist**, skip to step 12.

If it **does exist**, run the review agent, addressing its findings between runs. The number of re-runs depends on the highest severity found:

- **High or critical**: run up to **2 times** total (fix, re-run once to verify).
- **Medium or low only**: run **once** (fix the findings, no re-run).
- **No findings**: stop immediately.

For each run:

1. Run the review command from that directory, using the open PR's URL and a numbered output file:
   ```
   cd /workspaces/realtime_project_agent && \
   mise exec -- mix review --pr <pr_url> --output /tmp/review-<card-short-code>-run-<n>.md
   ```
2. Read the output file. If it contains no actionable findings, stop the loop.
3. For each finding, address it with the same TDD red-green-refactor loop as step 7 — failing test, fix, green, `mix precommit`.
4. Commit the fixes and push.
5. If the highest severity was high/critical and this is run 1, increment `n` and repeat from step 1. Otherwise, stop.

Track a log of every run: the run number, how many findings were reported, and a one-line summary of each finding addressed (or "no findings").

After the loop ends, post a single PR comment summarising the internal review:

```
gh pr comment <pr_number> --body "<summary>"
```

Format the summary as:

```
## Local review agent runs

Ran local review agent <N> time(s) before submitting for automated review.

- **Run 1**: <n findings>. Addressed: <brief list, or "no findings">
- **Run 2**: ...
```

If every run came back clean (0 findings), note that too: "All runs returned no findings."

### 12. Sign off on the branch

There is no GitHub Actions CI. `mix signoff` runs `mix precommit` before posting the status GitHub sees. With the final commit pushed:

```
mix signoff
```

If a check is red, `mix signoff` stops without posting status. Fix it and rerun; never pass `-f` to work around uncommitted or unpushed changes.

### 13. Move the card to Automated Review after the final commit

When the work is done and the final commit is pushed, find the column tagged `automatic_code_review` on the card's board and move the card there with `move_card_to_column`.

**Don't match on column name** — a board may have both a "Review" column (human review) and an "Automated Review" column (bot review). The `automatic_code_review` tag is the only authoritative signal; the literal name "Review" is the *wrong* column.

To find it, call `get_board_overview` with the card's board_id and pick the column whose `tags` array includes `"automatic_code_review"`.

If no column on the board has that tag, **stop and warn the user** that the tag is missing. Only fall back to a column literally named "Automated Review" — never to a column named just "Review".

### 14. Print a fun success emoji

End with a one-line celebration. Examples: 🎉, 🚀, 🦄, 🍰, ✨, 🥳. Pick one. Don't overdo it.

## Hard rules

- **Never skip precommit between green tests.** That's the whole point of running it small and often.
- **Never force-push or use `--no-verify`** unless the user explicitly tells you to.
- **Never move the card to Done.** Automated Review is the terminal step for this skill.
- **Never run `mix signoff` on a red tree**, and never reach for `-f` to get past it.
- **If anything fails along the way**, stop and tell the user — don't paper over failures to keep moving.
