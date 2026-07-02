# Gnome Colony — Game Setup, Options & Menus

*Companion to the design doc, the evolution-algorithm spec, and the prototype spec. This document turns the algorithm's ⚙️ tuning knobs into **player-facing New Game options with defaults**, and defines the **main menus** (New Game wizard, Load Game, Settings).*

> **Two kinds of configuration, kept strictly separate:**
> - **Per-game options** (this doc, §1–§5) — balance, world, and founding. Chosen at **New Game**, **baked into the save and the seed**, mostly **locked once a run begins**. They change *what world you get*.
> - **Global settings** (§7) — graphics, audio, controls, accessibility. Device/preference level, persist across all games, changeable anytime. They change *how the game looks and feels to operate*, **never the simulation outcome** (presentation is separate from sim, so these can't affect determinism).

---

## 1. Presets — the easy front door

Most players pick a preset; each is a curated bundle of every §3 slider plus world/founding defaults. "Custom" opens everything.

| Preset | Feel | Pace | Mortality | Discovery | Divinity | Chaos | Scale | World |
|---|---|---|---|---|---|---|---|---|
| **Gentle Garden** | mild & forgiving — the quiet uncanny | Slow | Gentle | Normal | Humble | Calm | Kingdom | Lush / Calm |
| **Balanced Saga** *(default)* | the intended experience | Normal | Normal | Normal | Normal | Normal | Kingdom | Normal |
| **Harsh Frontier** | brutal — famine, dread, real loss | Normal | Brutal | Slow | Normal | Capricious | Kingdom | Sparse / Volatile |
| **Epic Civilization** | the full epochal arc | Brisk | Normal | Fast | Ascendant | Normal | Civilization | Large / Normal |
| **Custom** | full control | — all sliders exposed — | | | | | | |

⚙️ = high-leverage. Presets are just starting positions; any slider can be nudged before starting.

---

## 2. The New Game wizard (flow)

A short, skippable wizard. Pages:

1. **Choose a Preset** — the §1 cards, plus **Custom**. "Balanced Saga" preselected. (A newcomer can stop here and hit Start.)
2. **The People** (Founding, §5) — band size, temperament leanings, optional culture flavor.
3. **The World** (§4) — seed, region size, resources, hazards, biomes, fog.
4. **The Rules** (Tuning, §3) — the grouped sliders (pre-filled from the preset). Collapsed by default; "Advanced" expands the raw values.
5. **Summary & Start** — recaps choices, **shows the seed** (copy/share), names the colony. Start.

Skip-ahead: "Quick Start" button on page 1 launches Balanced Saga + random world immediately.

---

## 3. The Tuning Sheet — gameplay sliders (the ⚙️ knobs, player-facing)

Each slider has player-facing levels, a **default**, and the underlying algorithm parameters it scales (traceable to the evolution-algorithm spec). Levels shown low→high; **bold = default**.

### 3.1 Generation Pace — *how fast lives and generations move*
Levels: Languid · **Balanced** · Brisk
Maps to: lifespan target (`N(90,12)` ±), 1× ticks/sec.
Effect: a life ≈ **Languid 30 min / Balanced 20 min / Brisk 10 min** at 1×. Faster = more generations per sitting, evolution more visible; slower = deeper bonds with individuals.

### 3.2 Mortality & Loss — *how harsh death and forgetting are*
Levels: Gentle · **Normal** · Harsh · Brutal
Maps to: `age_curve a,b`; `hardship` multiplier; `accident` baseline; **extinction sensitivity** (`min_holders` for knowledge survival); tail-risk lethality.
Effect: scales death rates and how easily crafts/tech are lost to dark ages. The default sits at **Normal**; Brutal makes every generation a fight and knowledge precious. *(Harshness varies; the register — eerie, ambiguous, unflinching — is locked and never a slider: design §1.8b.)*

### 3.3 Discovery Pace — *how fast tech & magic emerge*
Levels: Slow · **Normal** · Fast
Maps to: research `base_rate` (~0.01), `surplus_factor` weight, `magic_understanding` accrual rate.
Effect: speed of the material/magical climb; Fast brings the god-vs-mages endgame within reach sooner.

### 3.4 Divinity / Power Ramp — *how fast you become a god, and how hard you hit*
Levels: Humble · **Normal** · Ascendant
Maps to: devotion growth, **toolbox tier thresholds (on *per-capita* devotion `d̄`, ratcheting)**, social-mass scaling `k` (magnitude curve), and the malevolent/benevolent potency gap `δ`.
Effect: Humble = slow unlocks, gentle effects, a subtle hand; Ascendant = rapid godhood, dramatic (and dramatically risky) acts.

### 3.5 Chaos / Unpredictability — *how wild the misfires and prophets are*
Levels: Calm · **Normal** · Capricious
Maps to: universal `tail_risk` prob (~0.03), `chain_hook` probabilities, prophet `corruption_roll` (~0.10) & ripeness.
Effect: how often acts cascade or backfire, and how volatile prophets are. Capricious = frequent dominoes, mad prophets, emergent mayhem.

### 3.6 Civilization Scale — *how large it can grow* ⚙️ (also a performance choice — see §7.1)
Levels: Intimate (hundreds) · **Kingdom** (thousands) · Civilization (tens of thousands)
Maps to: population/settlement caps, `individual_budget`, and **whether the civilization tier (multi-city trade/schism/war) is enabled**.
Effect: Intimate keeps it personal and light on hardware; Civilization unlocks the full epochal, multi-city, war-capable experience (heavier compute). Default **Kingdom** balances ambition and accessibility.

### 3.7 Faith & Enlightenment *(advanced)* — *do science and faith conflict*
Levels: Coexist · **Mild drift** · Secularizing
Maps to: secularization rate (devotion drift vs `science_level`); magic-resistance ceiling.
Effect: the locked design default is **Mild drift** (devout heretics possible); exposed here for players who want a sharper science-vs-faith tension.

> **Tuning invariants enforced regardless of sliders:** early game stays recoverable, no loop runs away unbounded in a session, extinction stays "rare enough to hurt, common enough to matter." Extreme slider combos are allowed but warned.

---

## 4. World options

| Option | Levels / input | Default | Maps to |
|---|---|---|---|
| **Seed** | random or typed (shareable) | random | world-gen RNG (determinism) |
| **Region Size** | Small (3 basins) · Medium (6) · Large (12) | Medium | number of basins / expandability |
| **Resource Abundance** | Sparse · Normal · Lush | Normal | resource node capacity/regrowth/richness |
| **Hazard Frequency** | Calm · Normal · Volatile | Normal | affordance density (slopes, faults, floodplains) |
| **Biome Variety** | Uniform · Varied | Varied | range of biomes → subculture divergence |
| **Exploration Fog** | On · Off | On | gradual map discovery vs fully revealed |

---

## 5. Founding options

| Option | Levels / input | Default | Notes |
|---|---|---|---|
| **Band Size** | 3 – 5 (Advanced up to 8) | 4 | starting gnomes |
| **Temperament Leanings** | pick 1–2: Hardy · Curious · Social · Devout · Ambitious | Curious | biases founder trait means (±0.15) |
| **Culture Flavor** *(optional)* | None · a light starting custom (e.g. "elders honored") | None | seeds an initial belief-object |
| **Colony Name** | text | generated | shown in saves & UI |

Founders' exact traits are still **rolled** (from the seed) around the chosen leanings — you author tendencies, not individuals.

---

## 6. Main menu

Top-level entries:

- **Continue** — resume the most recent save (hidden if none).
- **New Game** — the §2 wizard.
- **Load Game** — §6.1.
- **Settings** — §7.
- **Codex** — the faint, in-world almanac of observed phenomena (design §3.8); browsable between runs.
- **Chronicles** — the histories of ended runs (design §1.9): each a generated record of generations, faiths, prophets, wars, and how it ended; browsable, exportable.
- **Credits**, **Quit**.

### 6.1 Load Game
A list of saves, each card showing: colony name, **current generation**, population, **era/tech level**, dominant faith, playtime, **seed**, timestamp, and a thumbnail of the civilization map. Actions: Load, Duplicate, Delete, Export (share the save/seed). Separate tabs for **Manual saves** and **Autosaves** (rolling, §7.4).

---

## 7. Settings (global, persistent, presentation-only)

### 7.1 Graphics / Display
Resolution · Window mode (Fullscreen/Borderless/Windowed) · Quality preset (Low→Ultra) · VSync · Frame-rate cap · Shadow quality · View distance · **Render Crowd Density** ⚙️ (how many puppets to *draw* in a dense scene) · UI scale. These are **pure presentation** and never touch the simulation. *Note:* how many gnomes the **Eye of God can quicken** into full simulation is a **gameplay** value (the quicken budget in `WorldConfig`, set by scale/preset — same on every machine for fairness), **not** a graphics slider — because under the Eye of God (design §2.4) that *does* change the sim, so it can't live in device-level Settings.

### 7.2 Audio
Master · Music · SFX · Ambient · UI. Mute-on-focus-loss toggle.

### 7.3 Controls
Camera scheme (orbit / RTS-pan) · Edge-scroll on/off · Pan/zoom/rotate sensitivity · Key & mouse **rebinding** · Controller support & layout · Invert options.

### 7.4 Gameplay (global, non-balance)
Default game speed on load · **Autosave frequency** (Off / every season / every year) & autosave slot count · Pause on focus loss · Tooltips & hint level · Tutorial on/off · Confirmations for irreversible acts · Language/locale · Measurement of time display (years/seasons).

### 7.5 Accessibility
Colorblind modes (the belief/mood heatmaps must stay readable) · Text size · UI scale · Reduce motion / screen-shake · High-contrast UI · Hold-vs-toggle inputs · Optional dyslexia-friendly font · Narration/screen-reader labels for key panels.

---

## 8. Persistence & architecture notes

- **Per-game options (§1–§5)** serialize into the **save** as the world-creation parameters, alongside the **seed**. The seed + options reproduce the **world's starting state and statistical substrate** (the basis of shareable *worlds*); the **lived history** then diverges with your play and your gaze (the Eye of God makes attention an input — design §2.4), so a *full run* replays only from seed + options + recorded acts + recorded attention. Most options are **locked after start**; a few are runtime-adjustable from the pause menu: **game speed**, **autosave frequency**, **tooltips/hints**, accessibility.
- **Global settings (§7)** live in a separate **user-config file**, not the save. Rendering/audio/controls are pure presentation and **cannot alter the simulation** — including **Render Crowd Density**, which only changes how many agents are *drawn*. (The sim-affecting *quicken budget* is deliberately **not** here — it's a gameplay value in `WorldConfig` so it stays fair and replay-consistent.)
- **Difficulty mid-run:** to preserve determinism and fairness, balance sliders don't change mid-run; players wanting a different feel start a new seed (or duplicate a save and branch — optional future feature).
- **Where this connects to code:** the New Game wizard writes a `WorldConfig` resource (all §3–§5 values + seed + quicken budget) consumed by world-gen and the sim at startup; global settings load from `user://settings.cfg` at boot and bind to the renderer/input/audio — the sim's *only* presentation-side input is the focused-region **attention** (dwell-derived — design §2.4), routed as a defined sim input.

---

*Build note: none of this is needed for prototype Milestones 1–2 (headless). It arrives with the first playable build — a minimal Main Menu → Quick Start → run is enough at first, with the full wizard and Settings filled in as the game grows.*
