---
description: Review a GitHub PR with the code-review-agent orchestrator
argument-hint: <pr-number> [no-post]
---

$ARGUMENTS

Review the GitHub pull request named in `$ARGUMENTS`.

**Delegate the whole job** — invoke `Agent(subagent_type: "code-review-agent")` with the
PR number. Do not resolve the diff, check out the PR, or run RuboCop, Brakeman or the
report agents yourself. The orchestrator owns all of that, and duplicating its Step 1
just produces a second, subtly different scope.

## Parsing `$ARGUMENTS`

- **First token — the PR number.** Accept `62`, `#62`, or a
  `github.com/<owner>/<repo>/pull/62` URL; pass the bare number down.
- **Default — the agent posts its review as a comment on that PR.** This command exists
  to review *and* publish; say nothing special and the agent does both.
- **`no-post` / `dry-run` in the arguments** — tell the agent explicitly not to post,
  just render the report.
- **No PR number at all** — do not guess one, and do not fall back to reviewing the
  current branch. Ask which PR, and mention that `/review-pr <number>` is the form.

## Passing it on

Give the agent the PR number, whether the user opted out of posting, and nothing else —
its own definition carries the scoping, fan-out, posting and reporting rules.

## Reporting back

Relay the agent's merged report to the user **in full** — its scope line, summary table,
"Must fix before merge" table and per-dimension sections. A subagent's report is not
shown to the user automatically, so a summary of a summary is where the file:line
detail gets lost.

Then state whether the comment was posted — **with its URL** — or why it was not.

## Examples

```
/review-pr 62           # review PR #62 and post the report as a comment
/review-pr 62 no-post   # review PR #62, print the report, post nothing
/review-pr #62          # same as 62
```

Requires the `gh` CLI, installed and authenticated (`brew install gh && gh auth login`).
If it is missing, the agent will say so and stop — that is correct. Do not work around
it by reviewing a local branch instead.
