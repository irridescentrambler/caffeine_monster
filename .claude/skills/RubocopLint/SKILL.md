---
name: rubocop-lint
description: Runs RuboCop linting checks on Ruby files in this repo and reports the offenses. Reports as a single JSON object. Read-only — it never edits files or autocorrects. Use when asked to lint, run RuboCop, or check style — and after writing or editing any .rb file.
---

# RuboCop Lint

Runs RuboCop against this repo's `.rubocop.yml` (rubocop-rails, rubocop-capybara,
rubocop-performance plugins; `Metrics/MethodLength` max 20; `Metrics/BlockLength`
disabled) and reports what it finds.

**This skill is read-only. It runs the checker and shows the offenses — it does not
autocorrect, and it does not edit Ruby files.** Fixing is a separate, explicit
request from the user.

For *how to write* Ruby that passes, see the `rdoc` skill and
https://docs.rubocop.org/rubocop/latest/cops_style.html.

## Choosing a scope

Lint the narrowest scope that covers the work — never the whole repo when a few
files changed.

| Situation | Command |
| --- | --- |
| Just edited specific files | `bundle exec rubocop --cache false -f json path/to/file.rb` |
| Branch work / pre-PR (mirrors CI) | see "CI parity" below |
| Uncommitted work | `bundle exec rubocop --cache false -f json $(git diff --name-only --diff-filter=d HEAD -- '*.rb')` |
| Explicitly asked for a full pass | `bundle exec rubocop --cache false -f json` |

Always run from the repo root so `.rubocop.yml` is picked up.

Always scan with `-f json` — this skill reports JSON, and the JSON output carries the
`correctable` flag per offense, which is the single most useful field here. Redirect
stderr (`2>/dev/null`) so a warning cannot corrupt the parse.

The response shape is `{metadata, files, summary}`. Each entry in `files[].offenses[]`
carries `cop_name`, `severity`, `message`, `correctable`, and
`location{line, column, start_line, last_line}`. `summary` carries `offense_count`,
`target_file_count`, `inspected_file_count`.

### CI parity

`.github/workflows/rubocop.yml` lints only the `.rb` files changed against the PR
base. Reproduce it before pushing:

```bash
CHANGED_FILES=$(git diff --name-only --diff-filter=d origin/main...HEAD -- '*.rb')
if [ -n "$CHANGED_FILES" ]; then
  bundle exec rubocop --cache false -f json $CHANGED_FILES 2>/dev/null
else
  echo "No Ruby files changed."
fi
```

`--diff-filter=d` drops deleted files, which would otherwise make RuboCop error out.
If the file list is empty, report "no Ruby files changed" and stop — do not silently
widen to a full-repo run.

## Showing the offenses

1. Run the scoped command and parse the JSON.
2. Emit **every** offense into `findings`. Do not summarize offenses away or cap the
   array — the user wants to see them all.
3. Derive the `by_cop` tally from the parsed offenses. Do not make a second
   `--format offenses` run just to count; you already have the data.
4. Carry each offense's `correctable` flag through verbatim, and build the
   `autocorrect.command` from the affected file paths. Suggest it; do not run it.

### Rules

- **Never run `--autocorrect` / `-a` or `--autocorrect-all` / `-A`.** Both rewrite
  files. This skill only ever runs RuboCop in its default, read-only reporting mode.
- **Never hand-edit Ruby files to clear an offense under this skill.** Report it and
  stop. Fixing is a separate request — wait for the user to ask.
- **Never add `.rubocop_todo.yml`, `# rubocop:disable`, or config exclusions** to make
  an offense disappear, and **do not edit `.rubocop.yml`** — that changes the standard
  for the whole team.
- If the user asks for fixes after seeing the report, that's a normal request: fix the
  code directly, prefer hand edits over blanket `-A`, and keep any autocorrect scoped
  to the files in question so unrelated files don't land in the diff.

## Environment

RuboCop is a `:development, :test` group gem, so it must run through Bundler
(`bundle exec`) — a bare `rubocop` may resolve to a different global version.

Pass `--cache false` on every run. Sandboxed shells cannot write
`~/.cache/rubocop_cache`, and the failure surfaces as a `FileUtils#mkdir` backtrace
where the JSON should be — which `JSON.parse` then reports as a syntax error, not as
a lint result.

RuboCop prints a "the following cops are not configured" preamble to **stdout**,
ahead of the JSON, because `.rubocop.yml` does not set `AllCops: NewCops`. Slice from
the first `{` before parsing. That preamble is noise, not a finding: do not put it in
`findings`, and do not edit `.rubocop.yml` to silence it.

This repo targets Ruby 3.1.3 (`.ruby-version`). If `bundle exec rubocop` fails with a
Bundler/RubyGems or "Your Ruby version is X" error rather than lint output, the shell
is on the wrong Ruby. Report that plainly instead of treating it as a clean run — an
empty result from a crashed command is not a pass. Recovery:

```bash
rvm use ruby-3.1.3@caffeine_monster   # .ruby-version names an RVM gemset
bundle install
```

## Reporting back

**Output a single JSON object and nothing else** — no prose before or after, no
markdown fence around it. This is the same `scope` / `summary` / `findings` envelope
the `brakeman-scan` and `rails-perf-check` skills emit, so one reader can consume any
of the three.

### Schema

```jsonc
{
  "scope": {
    "description": "human-readable, e.g. '3 changed files vs origin/main'",
    "command": "the exact rubocop command run",
    "files_inspected": 3,          // summary.inspected_file_count
    "ci_parity": true              // true when the scope matches what CI lints
  },
  "summary": {
    "total": 7,
    "correctable": 5,
    "by_severity": { "convention": 6, "warning": 1 },   // RuboCop's own severities
    "by_cop": { "Style/StringLiterals": 4, "Metrics/MethodLength": 1 }
  },
  "autocorrect": {
    "command": "bundle exec rubocop -a app/models/team.rb",
    "fixes": 5,
    "leaves": 2                    // total - fixes; these need real code changes
  },
  "findings": [
    {
      "id": "style-stringliterals-team-8",     // cop slug + file + line
      "cop": "Style/StringLiterals",
      "category": "style",                     // cop department, lowercased
      "severity": "convention",                // RuboCop's severity, verbatim
      "blocking": true,                        // see below
      "correctable": true,                     // RuboCop's flag, verbatim
      "file": "app/models/team.rb",
      "line": 8,
      "column": 12,
      "message": "Prefer single-quoted strings...",   // RuboCop's message, verbatim
      "fix": {
        "description": "Only for correctable:false offenses -- what a human must do. Otherwise null.",
        "applied": false
      }
    }
  ]
}
```

`category` is the cop's department lowercased: `style`, `layout`, `lint`, `metrics`,
`naming`, `security`, `rails`, `performance`, `capybara`, `gemspec`, `bundler`.

### Rules for the JSON

- **`blocking` is the field that matters.** `.github/workflows/rubocop.yml` runs the
  full cop set against changed `.rb` files on every PR, so an offense is `blocking`
  when its file is in the PR diff. An offense on a file *not* in the diff is
  `false` — CI never looks at it. When the scope is a full-repo pass with no diff
  context, set every `blocking` to `null` rather than guessing.
- **`cop`, `severity`, `message` and `correctable` are copied verbatim** from
  RuboCop. Never paraphrase a message, and never infer `correctable` — if it is not
  in the JSON you parsed, you do not know it.
- `fix.description` is `null` for anything RuboCop can autocorrect; the command in
  `autocorrect` already covers those. Fill it in only for `correctable: false`
  offenses, where a human has to decide something.
- `fix.applied` is `false` on every finding unless the user asked for fixes in the
  same breath and you implemented that one.
- `autocorrect.command` must list **only the files that actually have correctable
  offenses**, so running it cannot touch anything else. If `summary.correctable` is
  0, set the whole `autocorrect` object to `null`.
- Clean run: emit the object with `"findings": []`, a zeroed `summary`, and
  `"autocorrect": null`. Never report clean without a passing run of the exact scope
  you name in `scope.command`.
- If RuboCop crashed (see Environment), do not emit a findings array at all — report
  the failure as prose instead. A parse failure is not an empty result.
