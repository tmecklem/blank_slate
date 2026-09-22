---
name: dotherework
description: Companion to /dothework. Takes a Launchbox card short code and addresses PR review feedback. Checks out the card's branch, moves the card to Development, fetches the open PR's review comments, addresses each one with the same TDD/precommit discipline as /dothework, pushes the fixes, marks each thread resolved, replies on anything not addressed, and moves the card back to Automated Review. Invoke when the user runs `/dotherework <short-code>`.
---

# Do The Re-Work

This skill closes the loop on review feedback. You receive a Launchbox card short code that's already been through `/dothework` and has an open PR with review comments. Your job: address every comment (or explain why not), mark threads resolved, push the fix, and put the card back in front of automated review.

The skill takes one argument: a Launchbox card short code (e.g. `abc-12`). If invoked without an argument, ask which card.

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

If `git status` shows uncommitted changes after the checkout, run `git stash push -u -m "dotherework auto-stash"` to keep the workspace clean. Tell the user you stashed their changes so they can restore them later with `git stash pop`. Do not delete or discard work without permission.

### 2. Look up the card and check out its branch

Call `search_cards` with the short code to find the card. Capture:
- card id
- title
- `suggested_branch_name`
- the board_placement (board id + current column id)

Check out the branch and fast-forward it:

```
git checkout <suggested_branch_name>
git pull --ff-only
```

If the branch doesn't exist locally, fetch and check it out from origin. If `git pull --ff-only` fails, stop and ask the user how to proceed — do not force-push or rebase without permission.

Then rebase onto main to pick up any commits that landed since the branch diverged:

```
git rebase origin/main
```

If there are conflicts, resolve them and run `mix precommit` before continuing. This prevents regressions where the branch overwrites work that already landed on main.

### 3. Move the card back to Development and assign yourself

Find the Development column on the card's board with `get_board_overview`, then call `move_card_to_column` to move the card there. Skip if it's already in Development.

Then assign the developer running the skill to the card. The original `/dothework` author may have been someone else, so this captures whoever is actually doing the re-work:

1. Read the developer's email from git: `git config user.email`.
2. Call `get_users` to list active members of the current organization and find the one whose `email` matches.
3. Call `assign_user` with `card_id` and the matched `user_id`.

`assign_user` is additive — a card can have multiple assignees, so it's safe whether the original author is still listed or not. If the same user is already assigned, the tool returns the error `"User is already assigned to this card"` — treat that string as success and continue, don't fail the workflow.

If no organization member matches the git email (e.g. the developer hasn't been added to the org, or the git email is misconfigured), warn the user and skip the assignment — don't fail the workflow either.

### 4. Find the open PR for this branch

```
gh pr list --head <branch> --json number,url,title
```

If there's no open PR for the branch, stop and tell the user — there's nothing to re-work. If there's more than one, pick the one whose title contains the card short code.

Capture the PR number for later use.

### 5. Fetch all review feedback

Use the GitHub API to pull both inline review comments and review threads (so you can resolve them later).

**Inline comments** (so you can read the actual feedback bodies, paths, and line numbers):

```
gh api repos/<owner>/<repo>/pulls/<pr_number>/comments
```

**Review threads with IDs** (needed to resolve each one):

```
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            comments(first: 20) {
              nodes {
                databaseId
                body
                path
                line
              }
            }
          }
        }
      }
    }
  }' -F owner=<owner> -F repo=<repo> -F number=<pr_number>
```

Build a working list of every unresolved thread: `{thread_id, file path, line, body, addressable: bool}`. Also pull the general review summary comments via `gh pr view <number> --comments` in case the reviewer left top-level guidance.

### 6. Read context and internalize the rules that were violated

Before touching any code:

1. Re-read `AGENTS.md` at the project root — especially the Phoenix, LiveView, Ecto, and Writing Style sections and any conventions relevant to the feedback.
2. Read your memory files (`~/.claude/projects/-workspaces-blank-slate/memory/MEMORY.md` and any referenced files) for prior feedback that applies.
3. Read the files cited in the review comments around the cited lines so you understand the surrounding code.

The goal is to internalize the rule that was violated so you fix the root cause, not just the symptom. Most review feedback comes from rules already written in `AGENTS.md` — if you had re-read the relevant section before committing, you would have caught it yourself.

### 7. Address each comment with the dothework work style

For every comment:

1. Decide whether it's addressable (the reviewer asked for a concrete change) or discussion (the reviewer asked a question or suggested an opinion).
2. For addressable items, apply the same red-green-refactor loop as `/dothework` (see the `tdd` skill):
   - Write a failing test that captures the requested behavior change (when applicable)
   - Implement the minimum fix
   - Confirm the test passes
   - **Run `mix precommit`** before moving on
3. For doc-only or markdown files, skip the test step but still run `mix precommit` if any code is touched.
4. For discussion items where you decide *not* to make a change, write down the reasoning — you'll post it as a reply in step 10.

If `mix precommit` ever fails, fix it before moving on. Never accumulate broken state.

Before committing, check the diff against the Writing Style section of `AGENTS.md`: every comment shorter than the code it explains and saying something the code cannot, no stock phrases, in comments and thread replies alike. Delete a comment that restates the code rather than rewording it.

### 8. Commit the fixes in semantic chunks

Group changes by topic, not by reviewer. Use semantic prefixes that match the repo's existing convention (look at `git log --oneline -20`). The first commit's message should mention the card short code and that it addresses review feedback (e.g. `abc-12: Address PR review feedback on signup form`).

**Do not add `Co-Authored-By` or other attribution lines to commit messages.** `AGENTS.md` forbids them, and Claude Code's default commit behavior adds them — you must explicitly omit attribution footers when crafting the commit message.

### 9. Run local review agent (if available)

After pushing, check whether `/workspaces/realtime_project_agent` exists:

```
ls /workspaces/realtime_project_agent
```

If the directory **does not exist**, skip to step 10.

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

### 10. Push and reply on each thread

Push the branch:

```
git push
```

Then for **each thread** in your working list:

- **If addressed**: post a short reply explaining the fix (e.g. "Fixed in <abbreviated sha>: moved the query into the context."), then resolve the thread.
- **If not addressed**: post a reply explaining *why* (e.g. "Skipping — this is intentional because..."), then resolve the thread.

Resolve a thread via GraphQL:

```
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) {
      thread { isResolved }
    }
  }' -F threadId=<thread_id>
```

Reply to a thread by adding a comment to the first comment in the thread:

```
gh api repos/<owner>/<repo>/pulls/<pr_number>/comments \
  -F body=<reply text> \
  -F in_reply_to=<first_comment_database_id>
```

Every thread should end up resolved. If any thread can't be resolved (e.g. the GraphQL call fails), stop and tell the user.

### 11. Sign off on the branch

There is no GitHub Actions CI. `mix signoff` runs `mix precommit` before posting the status GitHub sees. With the final commit pushed:

```
mix signoff
```

If a check is red, `mix signoff` stops without posting status. Fix it and rerun; never pass `-f` to work around uncommitted or unpushed changes.

### 12. Move the card back to Automated Review

Find the column tagged `automatic_code_review` on the card's board and move the card there with `move_card_to_column`.

**Don't match on column name** — a board may have both a "Review" column (human review) and an "Automated Review" column (bot review). The `automatic_code_review` tag is the only authoritative signal; the literal name "Review" is the *wrong* column.

To find it, call `get_board_overview` with the card's board_id and pick the column whose `tags` array includes `"automatic_code_review"`.

If no column on the board has that tag, **stop and warn the user** that the tag is missing. Only fall back to a column literally named "Automated Review" — never to a column named just "Review".

### 13. Print a fun success emoji

End with a one-line celebration. Examples: 🎯, ♻️, 🔁, 🛠️, 🪄. Pick one. Don't overdo it.

## Hard rules

- **Never skip precommit between green tests.** Same as `/dothework`.
- **Never force-push or use `--no-verify`** unless the user explicitly tells you to.
- **Never resolve a thread without replying first.** The reply is the audit trail; resolution alone hides the conversation.
- **Never silently ignore a comment.** Every thread gets either a fix-and-reply or a reasoned-decline-and-reply.
- **Never move the card to Done.** Automated Review is the terminal step for this skill.
- **Never run `mix signoff` on a red tree**, and never reach for `-f` to get past it.
- **If anything fails along the way**, stop and tell the user — don't paper over failures to keep moving.
