class_name SimRunner
extends RefCounted
## Headless sim orchestrator [plan T5.6, prototype spec]: composes the
## Phase 1–5 systems into the daily tick order (needs → decide/act → social
## side-effects → projects → aging → mortality → plasticity → decay →
## regrowth; partnerships/fertility/knowledge each season) and keeps the
## generational text log. This is glue, not policy: every rule lives in its
## system; runner-level derivations (food_factor, teacher availability,
## partner picks) are documented wiring, not spec numbers.
##
## Founder rolls [setup §5]: traits N(0.5, 0.15) via Rng, ±0.15 bias for the
## chosen temperament leanings ("hardy" maps to industrious — the trait
## catalog has no hardy; interpretive). Ages U(20, 25): young adults.

const LEANING_TO_TRAIT := {
	"hardy": "industrious",
	"curious": "curious",
	"social": "social",
	"devout": "devout",
	"ambitious": "ambitious",
}
const LEANING_BIAS := 0.15
const FOUNDER_AGE_MIN := 20.0
const FOUNDER_AGE_MAX := 25.0

var colony := Colony.new()
var time := TimeService.new()
var food: ResourceNode
var k_capacity: float
var chronicle: Array = []
var max_generation := 0

var _last_season := -1


func _init(config: WorldConfig, food_node: ResourceNode, capacity: float) -> void:
	food = food_node
	k_capacity = capacity
	_spawn_founders(config)
	EventBus.born.connect(_on_born)
	EventBus.gnome_died.connect(_on_died)


func shutdown() -> void:
	EventBus.born.disconnect(_on_born)
	EventBus.gnome_died.disconnect(_on_died)


func run_days(days: int, stop_at_generation: int = -1) -> void:
	for i in days:
		tick()
		if colony.population() == 0:
			return
		if stop_at_generation > 0 and max_generation >= stop_at_generation:
			return


func tick() -> void:
	var dt := time.advance(1.0)
	Needs.tick(colony, dt)
	var living := colony.living()
	for g in living:
		var ctx := _context_for(g, living)
		var action := Decide.choose(g, ctx)
		Act.apply(g, action, ctx)
		_side_effects(g, action, living, dt)
	Projects.tick(colony, dt)
	Aging.tick(colony, dt)
	Mortality.tick(colony, dt)
	Culture.plasticity_tick(colony, dt)
	Social.decay_tick(colony, dt)
	food.regrow(dt)
	if time.season() != _last_season:
		_last_season = time.season()
		_season_tick()


func _season_tick() -> void:
	Social.form_partnerships(colony)
	var pop := colony.population()
	# A day's meals on hand per gnome, capped at 1 (runner wiring).
	var food_factor := clampf(food.current / maxf(1.0, pop), 0.0, 1.0)
	var crowding := clampf(pop / k_capacity, 0.0, 1.0)
	Birth.season_tick(colony, food_factor, crowding)
	Knowledge.sync(colony)
	Knowledge.snapshot_records(colony)
	Knowledge.check_extinction(colony)


func _context_for(g: GnomeData, living: Array) -> Dictionary:
	var teacher := false
	for other in living:
		if other.id != g.id and not other.knowledge.is_empty():
			teacher = true
			break
	var caregiver := false
	for other in living:
		if other.stage in [Enums.LifeStage.ADULT, Enums.LifeStage.ELDER]:
			caregiver = true
			break
	return {
		"food_available": food.current > 0.0,
		"food_node": food,
		"teacher_available": teacher,
		"caregiver_available": caregiver,
	}


func _side_effects(g: GnomeData, action: String, living: Array, dt: float) -> void:
	match action:
		"socialize":
			var other := _pick_company(g, living)
			if other != null:
				var type := "friend"
				if _mate_eligible(g) and _mate_eligible(other) and g.sex != other.sex:
					type = "mate"
				Social.interact(g, other, type, 1.0)
		"work":
			Skills.practice(g, "foraging", dt)
		"teach":
			var learner := _random_learner(g, living)
			if learner != null and not g.knowledge.is_empty():
				Skills.teach(g, learner, g.knowledge[0], dt)
		"learn":
			var teacher := _random_teacher(g, living)
			if teacher != null:
				Skills.teach(teacher, g, teacher.knowledge[0], dt)


func _mate_eligible(g: GnomeData) -> bool:
	return g.stage == Enums.LifeStage.ADULT and g.partner_id == -1


## Company is not uniform-random: half the time a courting adult seeks its
## most COMPATIBLE eligible candidate (assortative mating [algo §8/§17] —
## like pairs with like) and bonded gnomes revisit their strongest tie
## (bonds form from proximity + repeated experience, design §1.6). The
## other half is seeded chance encounters. Uniform picks dilute with
## population and no pair ever reaches the 0.6 mate line.
func _pick_company(g: GnomeData, living: Array) -> GnomeData:
	if _mate_eligible(g) and Rng.chance(0.5):
		var candidate := _best_mate_candidate(g, living)
		if candidate != null:
			return candidate
	if Rng.chance(0.5):
		var tie := _strongest_tie(g, living)
		if tie != null:
			return tie
	return _random_other(g, living)


func _best_mate_candidate(g: GnomeData, living: Array) -> GnomeData:
	var best: GnomeData = null
	var best_compat := -1.0
	for other in living:
		if other.id == g.id or other.sex == g.sex or not _mate_eligible(other):
			continue
		var c := Social.compat(g, other)
		if c > best_compat:
			best_compat = c
			best = other
	return best


func _strongest_tie(g: GnomeData, living: Array) -> GnomeData:
	var best: GnomeData = null
	var best_weight := 0.0
	for other in living:
		if other.id == g.id:
			continue
		var w: float = g.relationships.get(other.id, {}).get("weight", 0.0)
		if w > best_weight:
			best_weight = w
			best = other
	return best


func _random_other(g: GnomeData, living: Array) -> GnomeData:
	if living.size() < 2:
		return null
	var pick: GnomeData = living[Rng.randi_range(0, living.size() - 1)]
	return null if pick.id == g.id else pick


func _random_learner(g: GnomeData, living: Array) -> GnomeData:
	var pick := _random_other(g, living)
	if pick == null or pick.stage == Enums.LifeStage.INFANT:
		return null
	return pick


func _random_teacher(g: GnomeData, living: Array) -> GnomeData:
	var pick := _random_other(g, living)
	if pick == null or pick.knowledge.is_empty():
		return null
	return pick


func _spawn_founders(config: WorldConfig) -> void:
	var bias := {}
	for leaning in config.temperament_leanings:
		if LEANING_TO_TRAIT.has(leaning):
			bias[LEANING_TO_TRAIT[leaning]] = LEANING_BIAS
	for i in config.band_size:
		var g := colony.spawn()
		g.sex = i % 2
		g.age = Rng.randf_range(FOUNDER_AGE_MIN, FOUNDER_AGE_MAX)
		g.stage = Aging.stage_for_age(g.age)
		for key in Enums.TRAIT_KEYS:
			g.set_trait(key, Rng.gauss(0.5 + bias.get(key, 0.0), 0.15))
	chronicle.append("Year 0 · a band of %d steps out of the treeline" % config.band_size)


func _on_born(payload: Dictionary) -> void:
	var g: GnomeData = colony.gnomes.get(payload["id"])
	if g == null:
		return
	max_generation = maxi(max_generation, g.generation)
	chronicle.append("Year %d · born #%d (gen %d)" % [time.year(), g.id, g.generation])


func _on_died(payload: Dictionary) -> void:
	chronicle.append(
		(
			"Year %d · #%d died (%s, age %.0f)"
			% [time.year(), payload["id"], payload["cause"], payload["age"]]
		)
	)
