---
name: brakeman-scan
description: Runs Brakeman against this Rails app, triages the security warnings, and proposes concrete code fixes for each one. Reports as a single JSON object. Read-only — it scans and suggests, it never edits files. Use when asked to run Brakeman, do a security scan, check for vulnerabilities, or review changed code for security issues before a PR.
---

# Brakeman Scan

Runs Brakeman (7.1.1, a `:development, :test` gem) over this Rails 7.1 app, explains
each warning in terms of this codebase, and **suggests** the change that fixes it.

**Scan and suggest — do not edit.** Present the proposed fix as a diff or a described
change and stop. Applying it is a separate, explicit request from the user. The one
exception is when the user has already asked for the fixes in the same breath
("run brakeman and fix what it finds") — then implement them one warning at a time.

For Brakeman's own docs and API, see the `brakeman` skill and
https://brakemanscanner.org/docs/.

## Environment

The default shell Ruby is 3.3.0; this repo pins **3.1.3** (`.ruby-version` names the
RVM gemset `ruby-3.1.3@caffeine_monster`). Set the shell up first, and always go
through Bundler:

```bash
source "$HOME/.rvm/scripts/rvm"
rvm use ruby-3.1.3@caffeine_monster
```

Brakeman exits non-zero when it finds warnings (`--exit-on-warn` is the default), so a
non-zero status is a normal result, not a crash. A RubyGems backtrace instead of a
report *is* a crash — say so plainly rather than reporting a clean scan. **An empty
result from a failed command is not a pass.**

There is no `config/brakeman.yml` and no `config/brakeman.ignore` in this repo, and no
Brakeman step in CI (`.github/workflows/rubocop.yml` runs RuboCop only). Nothing is
being suppressed — every warning you see is live.

## Running the scan

Brakeman needs the whole app loaded to trace data flow, so it always parses the full
tree; scoping only narrows what gets *reported*.

| Situation | Command |
| --- | --- |
| Default / whole app | `bundle exec brakeman -q -f json 2>/dev/null` |
| Only files you changed | `bundle exec brakeman -q -f json --only-files app/controllers/foo_controller.rb 2>/dev/null` |
| Branch work, pre-PR | `bundle exec brakeman -q -f json --only-files $(git diff --name-only --diff-filter=d origin/main...HEAD -- '*.rb' | paste -sd, -) 2>/dev/null` |
| High-confidence only | add `-w2` (or `-w3` for High alone) |

Always scan with `-f json` — this skill reports JSON, and the JSON output carries the
`fingerprint` and `cwe_id` fields the plain text report omits. `-q` keeps the banner
off stdout; the `2>/dev/null` is defensive so a warning on stderr cannot corrupt the
parse. Drop `--no-pager`: it is meaningless with `-f json`.

The response shape is `{scan_info, warnings, ignored_warnings, errors, obsolete}`.
Each warning carries `warning_type`, `check_name`, `fingerprint`, `confidence`,
`file`, `line`, `message`, `code`, `location`, `user_input`, `cwe_id`, `link`.
**Check `errors` before reporting** — a non-empty `errors` array means Brakeman failed
to parse part of the app and the scan is incomplete, however clean `warnings` looks.

Run from the repo root. The scan takes well under a second on this app — there is no
reason to skip the full pass when the user asks for one.

`--only-files` takes a comma-separated list; directories must be app-relative and end
in `/`. If the changed-file list is empty, report "no Ruby files changed" and stop —
do not silently widen the scope.

### Comparing against a baseline

To show only what a branch *introduced*:

```bash
git stash && bundle exec brakeman -q -f json -o "$TMPDIR/brakeman-base.json"; git stash pop
bundle exec brakeman -q -f json --compare "$TMPDIR/brakeman-base.json" 2>/dev/null
```

Prefer this when the user asks "did my change add anything?" — it separates new
warnings from pre-existing ones instead of dumping the whole backlog on them.

`--compare` returns a different shape: `{new, fixed, existing}` rather than
`{warnings, ...}`. Map `new` → `"status": "new"` and `existing` → `"status":
"baseline"`, and surface anything under `fixed` in `scope.description` — a warning the
branch *removed* is worth saying out loud, not dropping silently.

`git stash` touches the user's working tree. Only run this flow when the user asked to
compare against a baseline, confirm the stash pop succeeded before reporting, and
never leave a stash behind.

## Known baseline

A full scan on `main` as of 2026-08-21 reported **3 High-confidence warnings**:

| Warning | Location | Fingerprint (first 12) | Nature |
| --- | --- | --- | --- |
| `PermitAttributes` — dangerous key in mass assignment | `app/controllers/account_users_controller.rb:69` | `679d0b97d59f` | `permit(:user_id, :account_id)` — real, worth fixing |
| `EOLRails` — Rails 7.1.2 support ended 2025-10-01 | `Gemfile.lock:218` | `d84924377155` | Environment, not code |
| `EOLRuby` — Ruby 3.1.3 support ended 2025-03-31 | `.ruby-version:1` | `edf687f759ec` | Environment, not code |

Fingerprints are how you set `status` correctly. A warning whose fingerprint is in
this table is `"baseline"`; anything else is `"new"`. Fingerprints are stable across
line moves, so prefer them over file:line for the comparison.

Treat these as the floor. If a scan returns exactly these, say so — the change under
review introduced nothing. Anything beyond them is new and deserves the full triage
below. Re-verify the baseline rather than trusting this table if the repo has moved on.

## Triage before suggesting

For each warning, read the cited line in the actual file before writing a single word
about it. Then place it:

- **Confidence: High** — Brakeman traced user input to a sink. Assume it is real.
- **Confidence: Medium/Weak** — often a false positive on this codebase's patterns.
  Say why it is or is not reachable; do not pad the report with noise.
- **Unmaintained Dependency (`EOLRuby`, `EOLRails`)** — infrastructure. Report it,
  note the upgrade, and **never bump `.ruby-version`, the `Gemfile`, or `Gemfile.lock`
  as part of a security fix.** That is a project decision with its own PR.

A warning you cannot connect to a concrete attacker-controlled input is a *maybe* —
label it as such. Never invent an exploit path to make a finding sound serious.

## Suggesting the fix

Ground every suggestion in this app's conventions (see `CLAUDE.md`): business logic in
`app/services/` inheriting `BaseService`, thin controllers, dual session/JWT auth via
the `Authorize` concern.

| Check | The fix to propose |
| --- | --- |
| `PermitAttributes` / `MassAssignment` | Drop the ownership key from `permit` and derive it server-side — `current_user.id`, the scoped parent record, or the JWT subject — instead of trusting the client. Never widen to `permit!`. |
| `SQL` | Replace interpolation with a bound placeholder: `where('name = ?', name)`, `sanitize_sql_like` for `LIKE`, `Arel` for identifiers. |
| `Redirect` | Never `redirect_to params[:x]`. Redirect to a named route, or allowlist paths and pass `allow_other_host: false`. |
| `CrossSiteScripting`, `ContentTag`, `LinkToHref` | Escape at the sink. **Do not "fix" XSS with `html_safe` or `raw`** — that is the vulnerability, not the remedy. Use `sanitize` with an explicit tag allowlist when markup must survive. |
| `UnsafeReflection`, `Send`, `Evaluation` | Map user input through an explicit allowlist of permitted method or class names; never `send`/`constantize` a raw param. |
| `Execute`, `FileAccess` | Use the array form of the command, or `File.basename` plus a fixed root directory, so path or shell metacharacters cannot escape. |
| `SessionSettings`, `ForgerySetting`, `SSLVerify`, `DetailedExceptions` | Config-level. Point at the initializer or `config/environments/*.rb` line and state the secure setting. |
| `Deserialize`, `YAMLParsing`, `JSONParsing` | Move to `JSON.parse` on untrusted input; `safe_load` with an explicit permitted-classes list if YAML is unavoidable. |
| Auth-adjacent (`SkipBeforeFilter`, `FilterSkipping`) | Check the `skip_before_action :authorize_request` list — a public action added by mistake is a real hole in this app. |

Show the change as a small before/after on the real code, name the file and line, and
say what an attacker gets today. One paragraph per warning is plenty.

### Rules

- **Never add or edit `config/brakeman.ignore`, and never run `-I`
  (`--interactive-ignore`).** Silencing a warning is a team decision, not a fix. If a
  finding is genuinely a false positive, say so in the report and let the user decide.
- **Never pass `-x`/`--except` or `-w3` to make a warning disappear** from a scan you
  are reporting as complete. Narrowing confidence is fine when the user asked for it —
  state the flag you used either way.
- **Never edit application code under this skill unless the user asked for fixes.**
- Do not weaken a check to pass it (`permit!`, `html_safe`, `verify_mode = NONE`).
  If the only way to satisfy Brakeman is to break the feature, say that and ask.
- Report exactly what the tool printed — never a warning count you did not see.

## Reporting back

**Output a single JSON object and nothing else** — no prose before or after, no
markdown fence around it. Findings go in `findings`, ordered by exploitability:
confirmed-reachable High first, dependency and config warnings last.

This is the same envelope the `rails-perf-check` skill emits (`scope` / `summary` /
`findings`), so the two reports can be consumed by one reader. The per-finding fields
differ.

### Schema

```jsonc
{
  "scope": {
    "description": "human-readable, e.g. 'full app' or 'branch vs origin/main'",
    "command": "the exact brakeman command run",
    "brakeman_version": "7.1.1",
    "checks_performed": 78,          // scan_info.checks_performed.size
    "files_scoped": null,            // --only-files list, or null for a full scan
    "scan_errors": []                // scan_info errors[]; non-empty = INCOMPLETE scan
  },
  "summary": {
    "total": 3,
    "by_confidence": { "High": 3, "Medium": 0, "Weak": 0 },
    "by_status": { "new": 0, "baseline": 3 },
    "by_kind": { "code": 1, "dependency": 2, "config": 0 }
  },
  "findings": [
    {
      "id": "permit-attributes-account-users",   // stable kebab-case slug
      "warning_type": "Mass Assignment",         // Brakeman warning_type, verbatim
      "check": "PermitAttributes",               // Brakeman check_name, verbatim
      "fingerprint": "679d0b97d59f97fe81e9b9e0b1b46647f112de5f62a9931b0fadd8e9eeee5940",
      "confidence": "High",                      // "High" | "Medium" | "Weak"
      "status": "baseline",                      // "new" | "baseline", by fingerprint
      "kind": "code",                            // "code" | "dependency" | "config"
      "file": "app/controllers/account_users_controller.rb",
      "line": 69,
      "code": "params.require(:account_user).permit(:user_id, :account_id)",
      "user_input": ":account_id",               // Brakeman's traced input, or null
      "cwe_id": [915],
      "link": "https://brakemanscanner.org/docs/warning_types/mass_assignment/",
      "exploitable": true,                       // true | false | "unknown" -- see below
      "impact": "What an attacker gets today, in one sentence.",
      "fix": {
        "description": "The change, grounded in this app's conventions.",
        "diff": "- params.require(:account_user).permit(:user_id, :account_id)\n+ params.require(:account_user).permit()",
        "applied": false                         // false unless the user asked for fixes
      }
    }
  ]
}
```

### Rules for the JSON

- **`exploitable` is your triage verdict, not Brakeman's confidence.** Set `true` only
  when you traced attacker-controlled input to the sink *in this codebase* and can name
  it in `impact`. Set `false` for a warning you verified is unreachable, and say why in
  `impact`. Use `"unknown"` when you could not determine it — that is a legitimate
  answer and far better than a guess. **Never set `true` to make a finding sound
  serious, and never invent an exploit path for `impact`.**
- **A `false` verdict does not remove the finding from the array.** Report it with the
  reasoning; suppressing it is the user's call, not yours.
- `warning_type`, `check`, `fingerprint`, `code`, `user_input`, `cwe_id` and `link` are
  copied verbatim from Brakeman. Do not paraphrase them — `impact` and `fix` are where
  your own analysis goes.
- `kind` is `"dependency"` for `EOLRuby` / `EOLRails` and other
  `Unmaintained Dependency` warnings, `"config"` for initializer and
  `config/environments/*` findings, `"code"` otherwise. For `"dependency"`, `fix.diff`
  must be `null` — **never emit a diff bumping `.ruby-version`, `Gemfile`, or
  `Gemfile.lock`.** Say what the upgrade is in `fix.description` and leave it there.
- `fix.applied` is `false` on every finding unless the user asked for fixes in the same
  breath and you implemented that one.
- Clean scan: emit the object with `"findings": []` and a zeroed `summary`. Do **not**
  emit an empty object.
- If the scan crashed or `scan_errors` is non-empty, put the error text in
  `scope.scan_errors` and do not present the run as complete — a short `warnings` array
  from a partial parse is not a clean result.
