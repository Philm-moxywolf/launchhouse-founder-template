# Improvement notes

Every improvement Launchhouse ships to founders is one small file here, at
`.claude/updates/<release>/<id>.md`, `<release>` a date like `2026-09-23`
and `<id>` a short slug matching the file name (`ghl-install-link`, not
`ghl-install-link.md` and not `GHL-Install-Link`). One file per
improvement. This file is the schema; `.claude/scripts/updates-lint.sh`
enforces the parts of it a script can check.

## Why a note, not a diff

A founder's own copy of a touched file has usually drifted from stock —
they renamed a step, added a line, reworded a sentence. A diff against the
old stock file stops applying the moment that happens. A note instead
states the *purpose* an improvement exists to serve, so Claude (through
the `update-adapter` agent) can bring that purpose into whatever the
founder's file has become, keeping everything they added that the purpose
doesn't touch. The note is also what a check script and the
`update-reviewer` agent judge the *result* against, regardless of how it
got there.

## Frontmatter

Between two `---` lines, one key per line, plain `key: value`. A list
value is the key on its own line, then each item as an indented `  - item`
line straight underneath; an empty list is `key: []` on one line.
`purpose` is always a single line (no folded YAML block), so `awk` can
read it without a YAML parser.

- **id** -- stable slug, identical to the file name minus `.md`. Never
  reused for a different purpose, even in a later release.
- **title** -- a few words, shown to the founder.
- **purpose** -- one plain sentence: the reason this improvement exists.
  This is what an adapting worker reads to bring the improvement into a
  founder's changed file, and what a check or reviewer judges the result
  against -- never a diff, never the adapting worker's own say-so.
- **touches** -- every repo-relative path this improvement changes.
- **adds** -- new hooks, commands, skills, connections, or permissions
  this improvement introduces, named in plain words. `[]` if none.
- **requires** -- other improvement `id`s that must already be applied
  first. `[]` if none.
- **safety** -- `true` or `false`. See Safety below.
- **done-when** -- plain sentences that must hold in the founder's folder
  once this improvement is applied, whatever their file looked like
  before.
- **check** -- the check script's file name (sitting beside this note, in
  the same release folder), or the literal `none`.
- **founder-data** -- `true` if this improvement changes the shape of
  files under `growth-engine/`. If `true`, the note needs its own
  `## Migration` section, run after the update lands, with its own yes
  from the founder -- never bundled into the update's own approval.

## Body

After the frontmatter: `## What changed and why` (a short account for a
maintainer), `## What a stock file looks like after` (the touched files'
post-improvement form, for an adapting worker to read against), and, only
when `founder-data: true`, `## Migration`.

## Safety

`safety: true` means declining this improvement, or a founder's own
customization quietly defeating it, leaves a real hole -- a connector call
that should be blocked or asked about goes through unchecked, a
credential ends up somewhere it can be read from chat, or one of
CLAUDE.md's six rules stops being enforced. A safety note cannot be
declined, and **every one of its `done-when` statements must be
executable** -- checked by its `check` script, never judged only by an
agent's prose reading. `check: none` is refused for a safety note; the
linter fails it. A non-safety note may still ship a check (a plain wiring
check to prove the improvement actually landed), or use `check: none` and
leave its `done-when` for the `update-reviewer` agent to judge in prose.

## The check file

A check file sits beside its note, at
`.claude/updates/<release>/<id>.check.sh`. It runs as `sh <file>`, never
relying on the executable bit (Windows NTFS carries none), with the repo
root as its current directory and also exported as `REPO_ROOT`. POSIX
`sh` plus `awk` only -- no `jq`, no `node`, no `python`, same rule
`lib.sh` line 1 sets for every hook in this repo. Exit 0 means the
purpose holds; any other exit means it does not. It may print its own
`PASS`/`FAIL` lines; on failure its **last** line must be
`hint=<one plain sentence a founder can act on>`, so it survives being
read from the tail of a long test run.

A check that needs to judge a touched `.json` file's actual content --
never its line shape, which a founder's own editor or a Windows checkout
can reformat without changing what the file means -- can lean on
`sh .claude/scripts/json-valid.sh <file>` (exit 0 = valid JSON, exit 1
with a last line `reason=<plain>` otherwise) rather than writing its own
parser. It is a genuine parser, not a brace count, and is itself POSIX
`sh` plus `awk` only.

`.claude/tests/updates-checks.sh` is what actually runs every note's
check, in order, across every release folder. A safety note's check
always has to pass, in a founder's own copy and in the template repo
alike -- a missing check, `check: none`, or a non-zero exit is a FAIL
every time. A non-safety note's check is different once there is a
founder's own copy to be advisory about: there, a failing check prints
`WARN` and leaves the run green, because the note is a nice-to-have the
founder may have knowingly changed away from, not a hole in the six
rules. In the template repo the same failure is still a FAIL, because
there the check is the only proof Launchhouse's own shipped note actually
works.

## The linter

`sh .claude/scripts/updates-lint.sh [repo-root]` checks every note under
`.claude/updates/*/*.md` except `README.md` (repo-root defaults to two
directories up from the script itself). It checks: every required
frontmatter key is present and, for the scalar keys (`id`, `title`,
`purpose`, `safety`, `check`, `founder-data`), non-empty; `touches` and
`done-when` each carry at least one item (the only two list keys with no
`[]` escape hatch); `safety` and `founder-data` are each exactly `true`
or `false`; `id` matches the file name; a `safety: true` note names an
existing check file and has at least one `done-when` statement; every
`touches` path exists in the repo; and no `touches` path is under
`growth-engine/` -- an improvement note never touches a founder's own
work. It prints `FAIL <note>: <reason>` per problem and exits 1, or
`notes=<n> ok` and exits 0.
