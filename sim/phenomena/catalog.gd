class_name Catalog
extends RefCounted
## The 15 seed phenomena [plan T7.8, algo §18] — "the uncanny register",
## loaded as data. Every act carries a mundane reading (in `mundane`) so
## belief stays contested [design §1.8b]. Valence spread: 4 benevolent
## (2 clean / 2 tainted) · 7 malevolent · 4 neutral — the documented dark
## tilt. Chain targets that are not catalog entries are consequence
## markers (CONSEQUENCES) consumed by later systems/the aftermath UI.
## Encoding notes (interpretive, all disclosed here):
##  · ground_remembers' §18 material effect reads "+0.2 / −0.1" (reveal or
##    bury) — encoded as the reveal (+0.2); the bury branch is DROPPED for
##    now, not modelled (future task).
##  · day_twice's "elevated tail-risk" → 2× the universal 0.03; its §18
##    affordance "Tier VI, rare" → "any" (no rarity tag exists yet); the
##    "touched-births echo next generation" chain has no spec probability
##    and waits for Phase 9.
##  · birds_silent's §18 chain "raises local |awe−fear| (seeds prophets)"
##    is a belief-lever effect, NOT a probability chain — it has no hook
##    here and is implemented by §12's prophet-seeding (T9.1).

const CONSEQUENCES := [
	"unease",
	"flood",
	"dam_flood",
	"famine",
	"migration",
	"quake",
	"cursed_place",
	"soil_exhaustion",
	"scapegoat_schism",
	"medicine",
	"predator_follows",
	"hunt_heroism",
	"rite_crystallizes",
	"schism_seed",
	"mass_conversion",
	"heresy_schism",
]

const UNIVERSAL_TAIL := 0.03


static func handlers() -> Dictionary:
	return Landslide.handlers()


static func defs() -> Dictionary:
	var out := {}
	for d in _entries():
		out[d["id"]] = d
	return out


static func _entry(
	id: String,
	category: int,
	valence: String,
	target: String,
	intensity: float,
	drama: float,
	tier: int,
	effects: Dictionary,
	affordance: String,
	hooks: Array,
	mundane: String,
	taint: String = "",
	tail: float = UNIVERSAL_TAIL,
) -> Dictionary:
	var d := {
		"id": id,
		"category": category,
		"valence": valence,
		"target": target,
		"base_intensity": intensity,
		"event_drama": drama,
		"tier": tier,
		"effects": effects,
		"affordance_req": affordance,
		"chain_hooks": hooks,
		"tail_risk": tail,
		"mundane": mundane,
	}
	if taint != "":
		d["taint"] = taint
	return d


static func _entries() -> Array:
	return [
		_entry(
			"still_air",
			1,
			"neutral",
			"area",
			0.3,
			0.3,
			1,
			{"material": 0.2, "population": 0.1, "discovery": 0.0, "belief": 0.3, "social": 0.1},
			"any",
			[{"phenom": "unease", "prob": 0.05}],
			"a calm spell"
		),
		_entry(
			"weeping_sky",
			1,
			"benevolent",
			"area",
			0.4,
			0.4,
			1,
			{"material": 0.4, "population": 0.3, "discovery": 0.1, "belief": 0.4, "social": 0.1},
			"drought",
			[{"phenom": "flood", "prob": 0.10}],
			"weather turned",
			"tainted"
		),
		_entry(
			"long_dark",
			1,
			"malevolent",
			"region",
			0.6,
			0.5,
			2,
			{
				"material": -0.5,
				"population": -0.4,
				"discovery": 0.3,
				"belief": 0.5,
				"social": "=culture"
			},
			"any",
			[{"phenom": "famine", "prob": 0.20}, {"phenom": "migration", "prob": 0.15}],
			"volcanic haze, a bad year"
		),
		_entry(
			"ground_remembers",
			2,
			"neutral",
			"point",
			0.4,
			0.5,
			2,
			{"material": 0.2, "population": 0.0, "discovery": 0.4, "belief": 0.4, "social": 0.0},
			"any",
			[{"phenom": "quake", "prob": 0.10}],
			"the earth settles"
		),
		_entry(
			"standing_stones",
			2,
			"benevolent",
			"point",
			0.4,
			0.5,
			2,
			{"material": 0.3, "population": 0.2, "discovery": 0.1, "belief": 0.4, "social": 0.1},
			"any",
			[],
			"we never noticed it",
			"clean"
		),
		_entry(
			"the_swallowing",
			2,
			"malevolent",
			"point",
			0.6,
			0.6,
			2,
			{
				"material": -0.5,
				"population": -0.2,
				"discovery": 0.1,
				"belief": 0.5,
				"social": "=culture"
			},
			"built_up",
			[{"phenom": "cursed_place", "prob": 0.20}],
			"the ground was soft"
		),
		_entry(
			"landslide",
			2,
			"malevolent",
			"point",
			0.6,
			0.6,
			2,
			{
				"material": -0.3,
				"population": -0.3,
				"discovery": 0.4,
				"belief": 0.5,
				"social": "=culture"
			},
			"slope",
			[{"phenom": "dam_flood", "prob": 0.15}, {"phenom": "cursed_place", "prob": 0.20}],
			"heavy rains, a loose slope"
		),
		_entry(
			"the_quickening",
			3,
			"benevolent",
			"area",
			0.5,
			0.4,
			3,
			{"material": 0.5, "population": 0.4, "discovery": 0.1, "belief": 0.4, "social": 0.1},
			"farmland",
			[{"phenom": "soil_exhaustion", "prob": 0.10}],
			"a good year",
			"tainted"
		),
		_entry(
			"the_blight",
			3,
			"malevolent",
			"area",
			0.6,
			0.5,
			3,
			{
				"material": -0.6,
				"population": -0.3,
				"discovery": 0.3,
				"belief": 0.5,
				"social": "=culture"
			},
			"farmland",
			[{"phenom": "famine", "prob": 0.20}],
			"crop disease"
		),
		_entry(
			"wrongness_blood",
			3,
			"malevolent",
			"settlement",
			0.6,
			0.6,
			3,
			{
				"material": -0.1,
				"population": -0.6,
				"discovery": 0.4,
				"belief": 0.6,
				"social": "=culture"
			},
			"crowded",
			[{"phenom": "scapegoat_schism", "prob": 0.15}, {"phenom": "medicine", "prob": 0.10}],
			"a fever passed through"
		),
		_entry(
			"coming_herd",
			4,
			"benevolent",
			"region-edge",
			0.4,
			0.4,
			3,
			{"material": 0.4, "population": 0.2, "discovery": 0.2, "belief": 0.4, "social": 0.1},
			"wilds",
			[{"phenom": "predator_follows", "prob": 0.10}],
			"migration season",
			"clean"
		),
		_entry(
			"thing_in_dark",
			4,
			"malevolent",
			"region-edge",
			0.5,
			0.6,
			3,
			{
				"material": -0.1,
				"population": -0.3,
				"discovery": 0.2,
				"belief": 0.5,
				"social": "=culture"
			},
			"wilds",
			[{"phenom": "hunt_heroism", "prob": 0.15}],
			"a wolf, a bear"
		),
		_entry(
			"birds_silent",
			5,
			"neutral",
			"settlement",
			0.3,
			0.5,
			4,
			{
				"material": 0.0,
				"population": 0.0,
				"discovery": 0.1,
				"belief": 0.6,
				"social": "=culture"
			},
			"any",
			[],
			"an ill-omened day"
		),
		_entry(
			"shared_dream",
			6,
			"neutral",
			"settlement",
			0.5,
			0.6,
			5,
			{
				"material": 0.0,
				"population": 0.0,
				"discovery": 0.2,
				"belief": 0.6,
				"social": "=culture"
			},
			"any",
			[
				{"phenom": "rite_crystallizes", "prob": 0.20},
				{"phenom": "schism_seed", "prob": 0.15}
			],
			"a strange night"
		),
		_entry(
			"day_twice",
			7,
			"malevolent",
			"settlement",
			0.9,
			1.0,
			6,
			{
				"material": 0.0,
				"population": -0.2,
				"discovery": 0.1,
				"belief": 0.9,
				"social": "=culture"
			},
			"any",
			[
				{"phenom": "mass_conversion", "prob": 0.25},
				{"phenom": "heresy_schism", "prob": 0.25}
			],
			"collapses — yields madness and denial, not proof",
			"",
			UNIVERSAL_TAIL * 2.0
		),
	]
