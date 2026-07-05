# Gnome Colony — Ravenna Redesign Spec (numeric source of truth)

*READ-ONLY once authored (like `evolution-algorithm.md`). This is the single source of every
**new** number the Ravenna redesign introduces — the mosaic render constants and the settlement-
development mechanics. It **extends** `evolution-algorithm.md` §14/§17; where a value here expresses
an existing algo term it **modulates** that term (never a parallel duplicate). Cite it as
`[rav §X]`. If it is silent, write `STUCK.md` — do not invent. The plan that consumes this doc is
`docs/redesign-plan-ravenna.md`.*

**Setting & mood.** An alternate late-antique / early-medieval Earth of gnomes, orcs, goblins and
other creatures. This game is about the **gnomes** — late-antique gnomes with a **Christian-like**
faith. Keep gnomes and the name "Gnome Colony" (no rename); render and flavor them in the **Ravenna
Christian mosaic register**, reframed as the gnomes' *own* religion of the unseen will — not literal
Christianity. The other creatures are world context, out of redesign scope. The game's existing
emergent theology, prophets, schisms and heresies map onto this register (Ravenna was split Arian
vs. Orthodox), so this is a visual + light-copy reskin, not a mechanics change.

---

## §R-art — Render constants (Ravenna mosaic; presentation-only)

**Palette — 16 tesserae colors** (Galla Placidia range). *Starting values, tuned at Playtest Gate A.*

| # | name | hex | use |
|---|------|-----|-----|
| 0 | night-lapis | `#0d1b3e` | vault ground / deepest shadow |
| 1 | deep-lapis | `#14285a` | sky / water body |
| 2 | mid-blue | `#245a8c` | water highlight / mid ground |
| 3 | verdigris | `#2f6d5f` | foliage shadow / border scroll |
| 4 | sage-green | `#5a8f6b` | grass / field |
| 5 | pale-green | `#9dc08b` | lit grass / young crop |
| 6 | gold-deep | `#a97b18` | gold-leaf shadow |
| 7 | gold | `#d6a53a` | gold tesserae / halo / roof |
| 8 | gold-lit | `#f2d488` | gold highlight / shine |
| 9 | ochre | `#b07636` | earth / warm stone |
| 10 | terracotta | `#a2432c` | roof-tile / cursed border |
| 11 | oxblood | `#5e1f1c` | deep red accent / blood-omen |
| 12 | cream | `#e8ddc4` | robe / marble base |
| 13 | bone-white | `#f5efe0` | highlight / star |
| 14 | slate-grey | `#3a4152` | grout mid / cool stone |
| 15 | near-black | `#080a12` | grout / outline |

**Stage / shader.** Internal render resolution `384×216`, integer-multiple upscale, nearest-neighbor
filter. Tessera grout: `grout_px = 4` (lattice pitch), `grout_color = #080a12` (index 15), grout
alpha `0.35`, per-cell value jitter `±0.06` (hashed by cell). Palette-map with `4×4` ordered dither
toward the 2 nearest entries, dither strength `0.5`. Gold-leaf accent: luminance lift `+0.25` on the
blessed / high-devotion mask.

**Lighting** (replaces `RunView`'s `SKY_COLOR` / `AMBIENT_COLOR` / sun): key light gold `#f2d488`,
energy `1.3`, elevation `28°`; ambient background `#0d1b3e`, ambient energy `0.35`; figure rim
`#f2d488` at `0.4`; bloom threshold `0.85` (gold only); black crush `0.04`.

**Mood & iconography (late-antique Christian-like — the gnomes' own faith).** Register is the
Ravenna Christian mosaic. Iconography set:
- **Sacred monogram** — a Chi-Rho-like mark, the gnomes' symbol of the unseen will. Appears on the
  blessed border, the basilica pediment, and the city medallion.
- **Halo / nimbus** — a gold disc (`#d6a53a`→`#f2d488`), outer radius ≈ `0.6 ×` puppet height,
  rendered behind any gnome that is a prophet **or** has `notability ≥ 0.6` (the same threshold algo
  §14 uses for promotion). Reuses data presentation already reads; no new sim channel.
- **Star-field ground** — bone-white (`#f5efe0`) stars scattered on night-lapis for sacred vaults /
  roundels.
- **Borders** — meander (Greek key), wave-scroll, rosette. **Architecture register** — basilica,
  aediculae, colonnade, gabled pediment.

Diegesis: this is the gnomes' religion (the emergent theology of the player-god), rendered
Christian-like — *not* a claim of literal Christianity; schisms/heresies read as the era's own creed
disputes (Arian vs. Orthodox is the natural analog).

---

## §R-set — Settlement development (extends algo §14; sim logic)

**Tiers.** Derived from population **and** structure/tech gates; hysteresis `±10%` of the population
threshold prevents flicker at a boundary.

| tier | gate |
|---|---|
| Hamlet | default / pop < 12 |
| Village | pop ≥ 12 **and** farm ≥ 1 |
| Town | pop ≥ 60 **and** construction_level ≥ 1 **and** granary ≥ 1 |
| City | pop ≥ 250 **and** basilica ≥ 1 **and** wall ≥ 1 |

**Build labor per season.** `labor = max(0, adults − 0.33·pop) · 0.5` — the surplus adult-days
beyond the §17 maintenance load (`≈0.33 actions/day`), half of which goes to building.

**Structure cost** (labor-seasons): dwelling `1` · farm `1.5` · well `1.5` · granary `3` ·
workshop `4` · shrine `2` · wall `5` · market `4` · basilica `8`.

**Construction step (per season).** Accumulate `build_progress += labor`; spend it on the single
top-priority **buildable** structure (tech prerequisite met **and** below its per-tier cap); when
`build_progress ≥ cost`, increment that structure's count by 1, subtract the cost, and emit
`structure_built`. At most one completion per season per settlement (progress carries over).

**Priority score** (choose the max over buildable structures):

| structure | priority |
|---|---|
| dwelling | `crowding` |
| farm | `hunger_pressure + 0.3` |
| well / cistern | `water_pressure` |
| granary | `surplus` (at Village+) — *corrected from "Town+": Town requires a granary, so gating the granary at Town+ would deadlock progression; a prosperous village stores its surplus and so becomes a town* |
| workshop | `has_ore + curiosity` |
| shrine | `faith · (1 − has_shrine)` |
| basilica (temple) | `faith · devotion_tier` (only at Village+) |
| wall | `fear + war_threat` |
| market | `surplus` (requires writing ∨ a trade route) |

**Caps** scale with tier: dwellings cap `≈ pop / 4`; farms cap `≈ pop / 15`; one shrine per
settlement below Town, promoted to basilica at Town+; wall count `≤ 4`; granary/workshop/market
`≤ 2` each.

**Decay / regression.** Each season, per structure: `count −= 0.05 · max(0, 1 − labor / upkeep)`
where `upkeep = 0.1 · count` (buildings need tending); floored at 0. Tier is re-derived each season
and may drop. A regional dark age (§7 per-settlement extinction of the enabling craft) zeroes the
workshop.

---

## §R-build — Building effects (modulate existing flows; no double-count)

Each structure **modulates** an existing algo term rather than adding a parallel one. The R2.4
isolation tests guard against double-counting.

| building | prereq | effect (into the existing sim) |
|---|---|---|
| dwelling | — | housing cap `+4 pop`; `crowding = pop / min(K, housing_cap)` |
| farm | agriculture | contributes to the effective agriculture factor in `K` / `food_factor`, `+0.15` per farm, **capped** so total ≈ the §14 `0.5·agriculture` term (modulates, not additive) — consistent with `terrain.gd` `farmland` |
| well / cistern | — | drought / water mortality `−20%` while active |
| granary | agriculture | famine (hardship) deaths `−30%` |
| workshop | smithing / stoneworking | craft research pressure `×1.2`; enables metallurgy uptake |
| shrine | — | belief-crystallization duration `−1 season` |
| basilica (temple) | construction + devotion tier ≥ III | terror-unrest growth `×0.8`; devotion mass `×1.05` at this settlement; the seat's Christian-like faith house |
| wall | construction | `war_strength ×(1 + 0.25·wall_count)`, capped at `×2` — consistent with `terrain.gd` `built_up` |
| market | writing ∨ trade route | trade mood-lift `×1.5`; knowledge-spread reach `+1 partner` |

All multipliers are starting points, tuned at the playtest gates.

---

## §R-infl — Influence → development routing (indirect only)

The construction priority (§R-set) is fed **only** by signals the player already shapes through the
world — never a build command (design §1.3). Mapping:

| player / nature signal (existing) | reads as | steers toward |
|---|---|---|
| drought phenomena / low larder → hunger & water need-pressure | scarcity | **farm, well / cistern** |
| landslide / quake / beast → fear scalar + `war_threat` | threat | **wall**, and (revealed ore) **workshop** |
| devotion depth + faith scalar | reverence | **shrine → basilica** |
| bountiful harvest / good seasons → surplus | plenty | **granary, market**, growth to the next tier |
| a wonder or a `blessed` place-tag on a site | sanctified ground | **shrine at that place** |
| famine / `cursed` tag / war depopulation | ruin | **abandonment & regression** (§R-set decay) |

The rule (design §1.3): you author the *cause* (a drought, an omen, a devotion), never the *effect*
(the farm, the wall, the basilica). Development is the gnomes' response, legible only in hindsight
(design §2.7). `natural_events` (when enabled, `WorldConfig.environmental_events`) enters the same
table as another author of causes — the construction driver reads world / need state, not "who cast
it," so it needs no special case.
