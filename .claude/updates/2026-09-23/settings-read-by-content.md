---
id: settings-read-by-content
title: The setup check reads settings.json by content
purpose: The setup check reads the settings file by what it says, not how it is laid out, so a settings file Claude Code's own screens have reformatted is never mistaken for a broken one.
touches:
  - .claude/scripts/setup-check.sh
  - .claude/scripts/json-flat.sh
adds: []
requires: []
safety: false
done-when:
  - "json-flat.sh exists"
  - "setup-check.sh uses json-flat.sh"
check: settings-read-by-content.check.sh
founder-data: false
---

## What changed and why

`setup-check.sh` used to look for `outputStyle` and the disabled
`growth-engine` plugin switch in `.claude/settings.json` by grepping for an
exact line shape -- a specific key/value spacing, a specific quoting. But
Claude Code's own Settings screens, a founder's editor, or `jq -S` can
re-serialize the same JSON (re-indent it, drop or add a space after a
colon, reorder keys, write it as one compact line) without changing what it
means at all. A founder who opened the settings screen and toggled one
unrelated setting could come back to a setup-check false alarm telling them
Launchhouse's own checks or voice were off, when nothing about the file's
actual content had changed.

`json-flat.sh` is a shared JSON flattener: a real recursive-descent parse
(built on `json-valid.sh`, so a genuinely broken file is never
misread as flattened-but-empty) that walks any JSON file into
`path<TAB>value` lines, one per leaf, regardless of indentation, key order,
line endings, or whether it is one compact line or spread across hundreds.
`setup-check.sh` now reads `/outputStyle` and
`/enabledPlugins/growth-engine@launchhouse-v3` from that flattened output
instead of grepping the raw file, and fails open (treats the setting as
present) if the flattener is missing or the file will not parse at all --
a genuinely broken `settings.json` is a separate, already-covered case, not
this check's job to re-detect.

## What a stock file looks like after

`.claude/scripts/setup-check.sh`, in its settings.json section:

```sh
flattener="$(dirname "$0")/json-flat.sh"
if [ -f "$flattener" ]; then
  settings_flat=$(sh "$flattener" "$settings" 2>/dev/null)
  if [ -n "$settings_flat" ]; then
    printf '%s\n' "$settings_flat" | awk -F '\t' \
      '$1 == "/outputStyle" && $2 == "Launchhouse Guide" { found = 1 } END { exit !found }' \
      || ok_style=0
    printf '%s\n' "$settings_flat" | awk -F '\t' \
      '$1 == "/enabledPlugins/growth-engine@launchhouse-v3" && $2 == "false" { found = 1 } END { exit !found }' \
      || ok_plugin=0
  fi
fi
```

`.claude/scripts/json-flat.sh` exists, takes one JSON file path, validates
it with `json-valid.sh` first, and prints one `path<TAB>value` line per
leaf on success, or a `reason=` line on failure -- POSIX `sh` plus `awk`
only, no `jq`, no `node`, no `python`.
