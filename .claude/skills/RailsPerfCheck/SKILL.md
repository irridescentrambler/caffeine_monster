---
name: rails-perf-check
description: Checks this Rails app for performance problems — N+1 queries, missing indexes, unpaginated queries, and slow Ruby idioms — using RuboCop's Performance/Rails cops plus a manual review of the query patterns cops cannot see. Reports as a single JSON object. Read-only — it reports findings and proposes fixes, it never edits files. Use when asked to check performance, find N+1 queries, review slow endpoints, or audit changed code for query problems before a PR.
---

# Rails Performance Check

Audits this Rails 7.1 / MySQL app for performance problems in two layers: the
**automated cops** (`rubocop-performance` 1.26.1 and the query cops in
`rubocop-rails` 2.34.3, both already in the Gemfile) and a **manual query review**
for the things static analysis cannot see — N+1s, missing indexes, and unbounded
result sets.

**Report and suggest — do not edit.** Present each finding with a concrete fix and
stop. Applying it is a separate, explicit request. The one exception is when the user
asked for both in the same breath ("check performance and fix it") — then implement
one finding at a time.

The cops are the cheap half and catch maybe a fifth of what matters here. **Layer 2 is
the real work — never stop after the cop run.**

## Environment

The default shell Ruby is 3.3.0; this repo pins **3.1.3** (`.ruby-version` names the
RVM gemset `ruby-3.1.3@caffeine_monster`). Set the shell up first and go through
Bundler:

```bash
source "$HOME/.rvm/scripts/rvm"
rvm use ruby-3.1.3@caffeine_monster
```

Pass `--cache false` to every RuboCop run in this skill. Sandboxed shells cannot
write `~/.cache/rubocop_cache`, and the failure surfaces as a `FileUtils#mkdir`
backtrace — *not* as a clean run. **An empty result from a crashed command is not a
pass.** If you see a RubyGems backtrace instead of an offense list, say so plainly.

RuboCop also prints a long "the following cops are not configured" preamble on every
run, because `.rubocop.yml` does not set `AllCops: NewCops`. That is noise, not a
finding — do not report it, and do not edit `.rubocop.yml` to silence it.

## Layer 1 — the automated cops

Run only the performance-relevant cops. A plain `bundle exec rubocop` is the
`rubocop-lint` skill's job and buries query findings under style offenses.

```bash
PERF_COPS='Performance,Rails/Pluck,Rails/PluckId,Rails/PluckInWhere,Rails/SelectMap,Rails/FindEach,Rails/WhereExists,Rails/WhereEquals,Rails/Presence,Rails/IndexBy,Rails/IndexWith,Rails/EagerEvaluationLogMessage,Rails/BulkChangeTable,Rails/RedundantActiveRecordAllMethod,Rails/WhereNotWithMultipleConditions'
bundle exec rubocop --cache false --only "$PERF_COPS" --format json
```

`--format json` feeds the report directly. RuboCop writes its unconfigured-cops
preamble to **stdout**, ahead of the JSON, so redirect stderr and slice from the
first `{` before parsing — or the parse fails on a run that actually succeeded:

```bash
bundle exec rubocop --cache false --only "$PERF_COPS" --format json 2>/dev/null
```

Map each RuboCop offense into the finding schema below: `cop_name` → `cop`,
`location.line` → `line`, `correctable` → `fix.autocorrectable`. Do not re-emit
RuboCop's own JSON shape — it has no field for a Layer 2 finding, which is most of
what this skill produces.

| Situation | Scope |
| --- | --- |
| Default / whole app | append nothing |
| Just edited specific files | append the paths |
| Branch work, pre-PR | append `$(git diff --name-only --diff-filter=d origin/main...HEAD -- '*.rb')` |

`--diff-filter=d` drops deleted files, which would otherwise make RuboCop error out.
If the changed-file list is empty, report "no Ruby files changed" and move to Layer 2
against the branch's `.erb` / `.jbuilder` files — do not silently widen to a full pass.

### Known cop baseline

A full run on `main` as of 2026-08-21 reported **2 offenses**, both correctable:

| Cop | Location |
| --- | --- |
| `Rails/EagerEvaluationLogMessage` | `app/models/account.rb:11` |
| `Rails/EagerEvaluationLogMessage` | `app/models/account.rb:21` |

Both are `Rails.logger.debug "Money #{amount} ..."` — the interpolation runs even in
production where the message is discarded. The fix is the block form:
`Rails.logger.debug { "Money #{amount} ..." }`.

Treat these two as the floor. If a run returns exactly them, the change under review
introduced no new cop offenses. Re-verify rather than trusting this table if the repo
has moved on.

## Layer 2 — the manual query review

Read the actual code. For each controller action, service, or view in scope, walk the
checklist below and cite real file:line for anything you flag.

### N+1 queries

The highest-value check and completely invisible to RuboCop.

1. Find every collection assigned in a controller action (`@teams`, `@users`, …).
2. Open the view *and its partials*, both `.html.erb` and `.json.jbuilder`.
3. Inside any `.each` / `json.array!`, look for a call that crosses an association —
   `team.members`, `user.account`, `membership.member.name`. Each one is one query per
   row.
4. The fix is `includes(...)` on the controller query — or `preload`/`eager_load` when
   you need the join for a `where`.

This app's index views currently render **foreign key integers** (`membership.member_id`,
`account_user.user_id`) rather than the associated record's name, so they do not N+1
today. That makes them the most likely place for one to appear: the moment a view
swaps `membership.member_id` for `membership.member.name`, `MembershipsController#index`
starts issuing one `SELECT` per row. Check this specifically on any diff that touches
an index partial.

Watch the `Authorize` concern too — `check_user_and_redirect` runs
`User.find_by(id: session[:user_id])` on **every HTML request**. Anything downstream
that touches `current_user.account` costs two more queries (`account_users`, then
`accounts`), because `has_one :account, through: :account_user` is not preloaded.

### Missing indexes

Read `db/schema.rb` and check every column used in a `where`, a `find_by`, a join, or
a uniqueness validation. MySQL does **not** create an index for a `belongs_to` unless
a migration asked for one, and this app's migrations mostly did not.

Standing gaps in the current schema:

| Table | Unindexed column | Cost |
| --- | --- | --- |
| `account_users` | `user_id`, `account_id` | full scan on every `user.account` / `account.users` |
| `memberships` | `member_id`, `team_id` | full scan on every `team.members` / `user.teams` |
| `categories` | `parent_id`, `name` | full scan on each `Category` uniqueness validation |
| `users` | — | `index_users_on_id` duplicates the primary key; it is dead weight on every write |

Propose these as a migration (`add_index`), but **never write or run the migration
under this skill** — schema changes are the user's call and belong in their own PR.

Note the ordering point when you raise `categories`: the uniqueness validation on
`name` scoped to `parent_id` is both a full table scan *and* a race condition. A
`unique: true` composite index fixes both, but only if the data is already clean.

### Unbounded queries

`ApplicationRecord` sets `paginates_per 15`, and most index actions use it — but not
all:

- `AccountUsersController#index` — `AccountUser.all`
- `MembershipsController#index` — `Membership.all`

Both load every row into memory and render every one. `TeamsController`,
`UsersController`, and `AccountsController` already call `.page(params[:page])`; these
two should match. Flag any new `.all` in an index action the same way.

For anything iterating a large set outside a request — a rake task, a backfill — the
check is `find_each` / `in_batches` instead of `.each` on a full relation
(`Rails/FindEach` catches the obvious form of this; a `.to_a.each` slips past it).

### Query idioms

| Pattern | Why it costs | Fix |
| --- | --- | --- |
| `User.all.map(&:email)` | instantiates every AR object | `User.pluck(:email)` |
| `x.where(...).present?` / `.any?` | loads rows to answer a yes/no | `.exists?` |
| `collection.count` on a loaded relation | re-queries `COUNT(*)` per call | `.size` (query if unloaded, count if loaded) |
| `.count` inside a loop | one query per iteration | `group(...).count` once, or a counter cache |
| `order(...)` on an unindexed column | filesort | index it, or drop the ordering |
| `update`/`save` in a loop | one round trip each | `update_all` / `insert_all` when callbacks are not needed |
| Multiple `add_column`/`change_column` on one table in a migration | one `ALTER TABLE` each | `change_table ... bulk: true` (`Rails/BulkChangeTable`) |

Ruby-level `Performance/*` offenses (`Performance/StringInclude`,
`Performance/RedundantMatch`, …) are real but almost always negligible next to a
query finding. Report them last and say plainly that they are microscopic — do not
let them pad a report and crowd out an N+1.

### Caching

`config.cache_store = :redis_cache_store` is configured in all environments, and
`enable_fragment_cache_logging` is on in development. Fragment caching an expensive
index partial is a legitimate suggestion — but only *after* the N+1 and the missing
index are fixed. **Never propose caching as the fix for a query problem.** It hides
the cost on a warm cache and leaves it fully exposed on a cold one.

## Measuring, when it matters

This repo has no `bullet` and no `rack-mini-profiler` (the latter is commented out in
the Gemfile). Do not add either — suggest it if the user wants continuous N+1
detection, and let them decide.

To *prove* a finding rather than assert it:

```bash
bin/rails server            # development has verbose_query_logs = true
```

Hit the endpoint and count the `SELECT` lines in `log/development.log`. Each one is
annotated with the app line that caused it, which is usually enough to point straight
at the N+1.

To pin a count in a spec (RSpec only — the `test/` directory is legacy and unused):

```ruby
count = 0
ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
  count += 1 unless payload[:name] =~ /SCHEMA|TRANSACTION/
end
get teams_path
expect(count).to be <= 3
```

Prefer a measured number over an estimate. If you did not measure, say "this will
issue one query per row" — never invent a millisecond figure or a "3x faster" claim.

## Rules

- **Never edit application code, views, migrations, or `db/schema.rb`** under this
  skill unless the user asked for fixes.
- **Never run `rubocop -a` / `-A`.** Some `Performance` autocorrects are marked
  unsafe and change semantics.
- **Never add `# rubocop:disable`, a `.rubocop_todo.yml`, or a config exclusion** to
  clear an offense, and do not edit `.rubocop.yml`.
- **Never run a migration or `db:reset`.** `db:reset` drops the user's development
  database.
- **Never propose `N+1 → caching`** or any fix that trades correctness for speed
  (dropping a validation, skipping callbacks with `update_column`) without saying
  outright what is being given up.
- Report exactly what you ran and what it printed. Never a number you did not see.
- A pattern you cannot tie to a specific file and line is not a finding. Say
  "nothing found in scope" rather than filling a report with generic Rails advice.

## Reporting back

**Output a single JSON object and nothing else** — no prose before or after, no
markdown fence around it. Findings go in `findings`, sorted by real impact: query
count first, Ruby microseconds last.

### Schema

```jsonc
{
  "scope": {
    "description": "human-readable, e.g. 'branch vs origin/main' or 'full app'",
    "layer1_command": "the exact rubocop command run, or null if skipped",
    "files_inspected": 108,          // from RuboCop's summary; null if Layer 1 skipped
    "layer2_paths": ["app/controllers/teams_controller.rb"]  // what you actually read
  },
  "summary": {
    "total": 5,
    "by_severity": { "high": 2, "medium": 1, "low": 2 },
    "by_status":   { "new": 3, "baseline": 2 }
  },
  "findings": [
    {
      "id": "missing-index-memberships",   // stable kebab-case slug
      "layer": "manual",                   // "cop" | "manual"
      "category": "missing_index",         // see the enum below
      "severity": "high",                  // "high" | "medium" | "low"
      "status": "new",                     // "new" | "baseline"
      "file": "db/schema.rb",
      "line": 37,
      "cop": null,                         // cop name for layer "cop", else null
      "summary": "memberships.member_id and team_id are unindexed.",
      "cost": "Full table scan on every team.members and user.teams.",
      "measured": false,                   // true ONLY if you counted queries
      "evidence": null,                    // measured numbers, else null
      "fix": {
        "description": "Add a composite index on [team_id, member_id].",
        "diff": "add_index :memberships, %i[team_id member_id]",
        "autocorrectable": false,
        "applied": false                   // always false unless the user asked for fixes
      }
    }
  ]
}
```

`category` is one of: `n_plus_one`, `missing_index`, `redundant_index`,
`unbounded_query`, `query_idiom`, `ruby_micro`, `caching`.

`redundant_index` is a write-side cost, not a read-side one — an index MySQL
maintains on every INSERT/UPDATE that no query benefits from (a duplicate of the
primary key, or a prefix of a wider composite index). Keep it `low` unless the table
is write-heavy.

### Rules for the JSON

- **`file` and `line` are required and must be real.** A finding you cannot anchor to
  a line you actually read does not go in the array. There is no "general advice"
  field on purpose.
- **`measured` is `false` unless you counted queries** with the log or the
  `sql.active_record` subscriber above. When it is `true`, `evidence` carries the
  numbers you saw. Never set `measured: true` for an estimate, and never put a
  millisecond figure or a "3x faster" claim in `evidence` that you did not observe.
- **`fix.applied` is `false`** on every finding unless the user asked for fixes in the
  same breath and you implemented that one.
- `severity` ranks by query cost, not by cop severity. A `Performance/*` cop offense
  is `low` (`ruby_micro`) almost every time; an N+1 on a paginated index is `high`.
- Clean run: emit the object with `"findings": []` and a zeroed `summary`. Do **not**
  emit an empty object, and do not claim a clean result without having run Layer 1
  *and* read the Layer 2 code in scope. A clean cop run alone is not a clean bill of
  health.
- If Layer 1 crashed (see Environment), set `layer1_command` to what you ran,
  `files_inspected` to `null`, and add a finding with
  `"category": "ruby_micro", "severity": "low", "summary": "Layer 1 did not run: <error>"`
  rather than reporting a passing scan.
