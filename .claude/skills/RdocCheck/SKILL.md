---
name: rdoc-check
description: Checks RDoc documentation coverage on Ruby files in this repo and lists what is undocumented or malformed. Reports as a single JSON object. Read-only — it reports issues, it never writes docs or edits files. Use when asked to check docs, audit RDoc coverage, or find undocumented classes and methods.
---

# RDoc Check

Reports RDoc documentation gaps in this repo's Ruby code.

**This skill is read-only. It lists the issues — it does not write documentation
comments or edit Ruby files.** Writing docs is a separate, explicit request.

For *how to write* RDoc comments, see the `rdoc` skill. This skill is the checker.

## Primary tool: RDoc's coverage report

```bash
rdoc --coverage-report=0 app lib
```

`--coverage-report` (aliases `-C`, `--dcov`) parses the code and prints every
undocumented item, followed by a tally. **It generates no files** — no `doc/`
directory, nothing to clean up. Verified safe to run.

**RDoc has no JSON formatter.** The report is text, and you build the JSON in
"Reporting back" by parsing it. Two things about that text matter:

- `rdoc --coverage-report` **exits 1 whenever anything is undocumented.** That is a
  normal result, not a crash. Only a RubyGems backtrace instead of a tally is a crash.
- A long `Parsing sources...` progress list precedes the report. Slice from the
  line `The following items are not documented:` and ignore everything above it.

### The three entry shapes

```
In files:                                    <- an undocumented CLASS or MODULE
* app/helpers/teams_helper.rb                   NO LINE NUMBER, only a file path

  module TeamsHelper
  end


  class Account # is documented                <- a DOCUMENTED class whose
                                                  members are undocumented
    # in file app/models/account.rb:9
    def add_money(amount); end                 <- method: line from the comment above

    attr_reader :email # in file app/services/authenticate_user_service.rb:5
                                               <- attribute: line on the same line
    # in file lib/json_web_token.rb:5
    SECRET = nil                               <- constant: line from the comment
  ```

**Undocumented classes and modules carry no line number** — RDoc reports only the
files they appear in, and a class spanning several files lists several paths. Set
`line` to `null` for these rather than inventing one, then fill it in from RuboCop's
`Style/Documentation` output, which does report file:line. That cross-reference is
the only reliable way to get a line number for a class-level gap.

The tally at the end gives `Files`, `Classes`, `Modules`, `Constants`, `Attributes`,
`Methods`, `Total`, and a documented percentage. Parse it for the `coverage` block —
never compute those numbers yourself.

Two useful levels:

| Level | What it counts |
| --- | --- |
| `--coverage-report=0` | Classes, modules, constants, attributes, methods |
| `--coverage-report=1` | The above **plus** each method parameter |

Use level 0 by default. Reach for level 1 only when the user asks about parameter
documentation specifically — it adds a large number of findings that are not
enforced anywhere in this project.

### Scope

Match the scope to the work, same as any check:

| Situation | Command |
| --- | --- |
| Just edited specific files | `rdoc --coverage-report=0 path/to/file.rb` |
| Changed on this branch | `rdoc --coverage-report=0 $(git diff --name-only --diff-filter=d origin/main...HEAD -- '*.rb')` |
| Whole codebase audit | `rdoc --coverage-report=0 app lib` |

Skip `spec/` — test files are not documented in this project and reporting them is
noise.

## Secondary tool: the RuboCop documentation cops

Two cops overlap with RDoc, and their status in this repo matters when you report:

- **`Style/Documentation`** — requires a comment on every class and non-namespace
  module. **Enabled** here (default; `.rubocop.yml` does not disable it), so missing
  *class-level* docs already fail CI on changed files. Report these as **blocking**.
- **`Style/DocumentationMethod`** — requires comments on public methods.
  **Disabled** here (RuboCop default). Missing *method* docs are therefore a
  suggestion, not a CI failure. Report them as **advisory**.

Check them with `bundle exec rubocop --only Style/Documentation <files>`. That
distinction is the single most useful thing to convey — do not present an
undocumented method as if it will break the build.

## Malformed markup

RDoc reports coverage, not markup correctness, so read the comments for these:

- Broken inline markup — `+code+` with spaces inside, unclosed `<tt>`/`<em>`
- A `:call-seq:` block whose signature no longer matches the method
- Stale directives (`:nodoc:`, `:doc:`, `:section:`) left on the wrong item
- `link:` / `rdoc-ref:` targets that no longer exist
- Comments that restate the method name (`# Gets the user` on `#get_user`) instead
  of saying what it does — flag as low-value, not as an error

## House style in this repo

Documented classes here carry a single-line comment directly above the class stating
its purpose — see [`app/services/base_service.rb`](../../../app/services/base_service.rb)
and [`lib/json_web_token.rb`](../../../lib/json_web_token.rb). Individual methods are
mostly undocumented by convention. Judge findings against that norm: a class with no
comment is a real gap; an undocumented one-line private method usually is not.

Do not report `# frozen_string_literal: true` as documentation — it is a magic
comment, and RDoc does not count it.

## Environment

The default shell Ruby is 3.3.0, but this repo pins **3.1.3** (`.ruby-version` names
the RVM gemset `ruby-3.1.3@caffeine_monster`). Running `rdoc` on the wrong Ruby exits
with a RubyGems backtrace instead of a report. Set up the shell first:

```bash
source "$HOME/.rvm/scripts/rvm"
rvm use ruby-3.1.3@caffeine_monster
```

A crashed command is not a clean bill of health — if you get a backtrace rather than
a tally, say so plainly rather than reporting zero issues.

## Reporting back

**Output a single JSON object and nothing else** — no prose before or after, no
markdown fence around it. This is the same `scope` / `summary` / `findings` envelope
the `rubocop-lint`, `brakeman-scan` and `rails-perf-check` skills emit, plus a
`coverage` block specific to this checker.

### Schema

```jsonc
{
  "scope": {
    "description": "human-readable, e.g. 'app and lib' or '3 changed files'",
    "command": "rdoc --coverage-report=0 app lib",
    "cross_referenced": true      // true if you ran Style/Documentation for line numbers
  },
  "coverage": {                   // parsed from the tally; never computed by you
    "files": 51,
    "total_items": 94,
    "undocumented": 40,
    "percent_documented": 57.45,
    "by_kind": {
      "classes":    { "total": 23, "undocumented": 7 },
      "modules":    { "total": 8,  "undocumented": 7 },
      "constants":  { "total": 2,  "undocumented": 2 },
      "attributes": { "total": 6,  "undocumented": 6 },
      "methods":    { "total": 55, "undocumented": 18 }
    }
  },
  "summary": {
    "total": 40,
    "by_severity": { "blocking": 9, "advisory": 31 }
  },
  "findings": [
    {
      "id": "docs-class-teams-helper",
      "kind": "class",              // class | module | constant | attribute | method
      "item": "TeamsHelper",        // qualified name, e.g. "Account#add_money"
      "severity": "blocking",       // see below
      "enforced_by": "Style/Documentation",   // that cop, or null if unenforced
      "file": "app/helpers/teams_helper.rb",
      "files": null,                // string[] when RDoc lists several; else null
      "line": 3,                    // null unless you cross-referenced RuboCop
      "summary": "module TeamsHelper has no documentation comment.",
      "fix": {
        "description": "Add a one-line comment above the module stating its purpose.",
        "applied": false
      }
    }
  ]
}
```

### Severity, and why the two tools disagree

- **`blocking`** — only what `Style/Documentation` actually flags. That cop is enabled
  here, and CI runs the full cop set on changed files, so these fail the build. Set
  `enforced_by` to `"Style/Documentation"`.
- **`advisory`** — everything else: methods, constants, attributes, and any class or
  module RDoc counts but the cop does not. `Style/DocumentationMethod` is **disabled**
  in this repo, so method docs will never fail CI. Set `enforced_by` to `null`.

**The two tools do not report the same set, and you must not assume they do.**
Measured on `main` as of 2026-08-21: RDoc found 14 undocumented classes + modules in
`app lib`, while `Style/Documentation` flagged 15 files — but 6 of those
(`config/application.rb` and 5 migrations) are outside RDoc's `app lib` scope, and the
cop exempts some constructs RDoc still counts. **Run both and intersect; never derive
one from the other.** If you did not run the cop, set `cross_referenced: false`, leave
every `line` as `null`, and mark severity `advisory` — you have not established that
anything is blocking.

### Rules for the JSON

- **`line` is `null` unless you got it from `Style/Documentation`.** RDoc does not
  report line numbers for classes and modules. Never invent one, and never substitute
  the line of the `In files:` entry.
- When RDoc lists a class under several paths, put them all in `files` and set `file`
  to the first. Otherwise `files` is `null`.
- `percent_documented` and every number in `coverage` comes from the tally you
  actually saw. **Never report a coverage percentage you did not read in output.**
- Skip `spec/` entirely — test files are not documented in this project, and
  reporting them is noise.
- Judge against house style before flagging: documented classes here carry a single
  line above the class; individual methods are mostly undocumented by convention. An
  undocumented one-line private method is usually not a real gap. It still belongs in
  `findings` as `advisory` if RDoc counted it — but say so in `summary` rather than
  implying it needs fixing.
- Do not report `# frozen_string_literal: true` as documentation; it is a magic
  comment and RDoc does not count it.
- Malformed-markup findings (see above) use `kind` matching the item they sit on,
  `enforced_by: null`, and a `summary` naming the specific breakage.
- `fix.applied` is `false` on every finding — this skill never writes docs. It stays
  `false` unless the user asked for docs in the same breath and you wrote that one.
- Clean run: emit the object with `"findings": []` and the real `coverage` block —
  100% coverage still has a tally worth reporting.
