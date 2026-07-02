class_name Phenomenon
extends RefCounted
## Phenomenon schema [plan T7.1/T7.7, algo §11/§18]. Definitions are plain
## data (one per lever); validate() returns a list of human-readable errors
## (empty = valid). `social` may be a number or the literal "=culture"
## (resolved at runtime, T7.9). `taint` exists only on benevolent boons.
## Target kinds are the UNION of §11's list and §18's index — §18 targets
## `long_dark` at a whole region, which §11's parenthetical omitted.

const CATEGORIES := [1, 2, 3, 4, 5, 6, 7]
const VALENCES := ["benevolent", "malevolent", "neutral"]
const TAINTS := ["clean", "tainted"]
const TARGETS := ["point", "area", "settlement", "region", "region-edge", "individual"]
const EFFECT_AXES := ["material", "population", "discovery", "belief", "social"]
const CULTURE_LITERAL := "=culture"


static func validate(d: Dictionary) -> Array:
	var errors := []
	for field in ["id", "category", "valence", "target", "base_intensity", "event_drama", "tier"]:
		if not d.has(field):
			errors.append("missing field: %s" % field)
	if d.get("id", "") == "":
		errors.append("id must be a non-empty string")
	if not d.get("category", 0) in CATEGORIES:
		errors.append("category must be 1-7")
	if not d.get("valence", "") in VALENCES:
		errors.append("valence must be one of %s" % [VALENCES])
	if d.has("taint"):
		if d.get("valence", "") != "benevolent":
			errors.append("taint applies to benevolent boons only")
		elif not d["taint"] in TAINTS:
			errors.append("taint must be clean or tainted")
	if not d.get("target", "") in TARGETS:
		errors.append("target must be one of %s" % [TARGETS])
	if not d.get("tier", 0) is int or d.get("tier", 0) < 1 or d.get("tier", 0) > 6:
		errors.append("tier must be 1-6")
	errors.append_array(_validate_effects(d))
	errors.append_array(_validate_hooks(d))
	var tail: float = d.get("tail_risk", 0.0)
	if tail < 0.0 or tail > 1.0:
		errors.append("tail_risk must be a probability")
	return errors


## Count definitions per valence [plan T7.7].
static func valence_spread(defs: Array) -> Dictionary:
	var spread := {"benevolent": 0, "malevolent": 0, "neutral": 0}
	for d in defs:
		spread[d["valence"]] += 1
	return spread


## Balance rule [plan T7.7, algo §11, design §3.1]: every category stocked
## with ≥2 acts must carry both a kind and a cruel face, and the overall
## arsenal must span all three valences. Presence, not parity — the §18
## seed set is deliberately dark-tilted (4/7/4) to match the register.
static func balance_report(defs: Array) -> Array:
	var errors := []
	var by_category := {}
	for d in defs:
		if not by_category.has(d["category"]):
			by_category[d["category"]] = []
		by_category[d["category"]].append(d["valence"])
	for category in by_category:
		var valences: Array = by_category[category]
		if valences.size() < 2:
			continue
		if not "benevolent" in valences:
			errors.append("category %d offers no kind face" % category)
		if not "malevolent" in valences:
			errors.append("category %d offers no cruel face" % category)
	var overall := valence_spread(defs)
	for valence in overall:
		if overall[valence] == 0:
			errors.append("no %s act anywhere in the arsenal" % valence)
	return errors


static func _validate_effects(d: Dictionary) -> Array:
	var errors := []
	if not d.has("effects"):
		return ["missing field: effects"]
	var effects: Dictionary = d["effects"]
	for axis in EFFECT_AXES:
		if not effects.has(axis):
			errors.append("effects missing axis: %s" % axis)
			continue
		var value: Variant = effects[axis]
		if axis == "social" and value is String:
			if value != CULTURE_LITERAL:
				errors.append("social string must be the literal %s" % CULTURE_LITERAL)
			continue
		if not (value is float or value is int):
			errors.append("effect %s must be a number" % axis)
		elif value < -1.0 or value > 1.0:
			errors.append("effect %s out of the [-1,1] band" % axis)
	return errors


static func _validate_hooks(d: Dictionary) -> Array:
	var errors := []
	for hook in d.get("chain_hooks", []):
		if not (hook is Dictionary and hook.has("phenom") and hook.has("prob")):
			errors.append("chain hook needs {phenom, prob}")
			continue
		if hook["prob"] < 0.0 or hook["prob"] > 1.0:
			errors.append("chain hook prob must be a probability")
	return errors
