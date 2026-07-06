# Gaea — vendored addon provenance

**Addon:** Gaea — procedural generation framework for Godot 4 (pure GDScript, no compiled binary).

- **Upstream (canonical):** https://github.com/gaea-godot/gaea
  (Note: `github.com/BenjaTK/Gaea` redirects to `BenjaTK/gaea-fork`, a personal fork; the authoritative
  repo is the `gaea-godot/gaea` org repo. Vendored from the canonical repo.)
- **Version:** `v2.0.0-beta6` (prerelease)
- **Pinned commit:** `00f1d167f66e0945457bf5003aba084e9ec4d1b8` (tag `v2.0.0-beta6`)
- **Retrieved:** 2026-07-06 (archive tarball of the tag; only the `addons/gaea/**` subtree, no demo/docs)
- **License:** MIT — Copyright (c) 2023 BenjaTK. Full text in `addons/gaea/LICENSE.txt`
  (fetched from the upstream `2.0` branch; the tag archive did not include it).

## Why this version

- **Godot 4.7 compatibility.** The stable line is `v1.4.x`, but it predates Godot 4.7; the recent
  `v2.0.0-beta6` (2026-03) is the maintained line (upstream default branch is `2.0`) and the best bet
  for this bleeding-edge engine. Compatibility was **verified empirically**, not assumed:
  `godot --headless --import` parses/registers all Gaea `class_name`s with **exit 0, zero errors**, and
  `test/test_gaea_available.gd` (4/4) instantiates the runtime noise node + `GaeaGenerator` and computes
  a deterministic value **headless** (no editor/display/GPU).
- **Beta risk is bounded.** It is a prerelease, but all project use goes through
  `presentation/terrain/TerrainField` (G1), which wraps Gaea — so any beta API churn has a small blast
  radius. Re-pin this file if the vendored version changes.

## Integration notes

- Enabled in `project.godot` `[editor_plugins]` (alongside GUT) so the Gaea graph editor is available
  to a human; the runtime generation classes work **without** the plugin enabled (the test proves it).
- `addons/` is excluded from `./lint.sh` (`.gdlintrc` excludes the whole tree; `gdformat` only targets
  `sim/ test/ presentation/`), so the vendored code is not linted — same treatment as `addons/gut/`.
- `class_name`s register during `godot --headless --import` (the documented first-run step; the
  `.godot/` cache is gitignored), which is why terrain code and tests can reference `GaeaGenerator`
  etc. by name.
