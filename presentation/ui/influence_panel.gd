class_name InfluencePanel
extends PanelContainer
## Phenomenon controls [plan T14.1, design §3.1/§3.1b, algo §10/§11]: a
## button per act under its category roof. Gating is the SIM's — refresh()
## reads colony.unlocked_tier (Devotion's ratcheting d̄_peak ladder) and
## the panel never re-derives thresholds. A category APPEARS only once its
## first act unlocks (the toolbox widens as the myth grows — §3.1; hidden,
## not greyed, per §3.8's discover-by-trying); acts above the earned tier
## inside a visible category show a locked face. Casting is arm → paint →
## release: arm() takes an unlocked act, paint() demands the selection
## kind the act's `target` field declares and routes {act, target,
## selection} to the runner via cast_requested, then disarms — no
## preview, no undo (§3.8). The panel is presentation glue: it holds no
## sim state and mutates nothing; the runner it signals does the casting.

signal cast_requested(act_id: String, target: String, selection: Dictionary)

## Display names per design §3.1's locked seven.
const CATEGORY_NAMES := {
	1: "The Elements",
	2: "Earth & Stone",
	3: "Life & Growth",
	4: "Beasts & Creatures",
	5: "Omens & Signs",
	6: "Visions & Dreams",
	7: "Wonders & the Uncanny",
}
## The key a paint gesture must deliver per target kind [algo §11]; the
## routed target string is the painted place except where noted below.
const SELECTION_KEY := {
	"point": "place",
	"area": "place",
	"settlement": "place",
	"region": "region",
	"region-edge": "edge",
	"individual": "gnome",
}

## act id → Button; category int → its container. Public for the tests
## and for the input layer to decorate.
var buttons := {}
var category_boxes := {}

var _defs := {}
var _tier := 1
var _armed := ""


## Raise the seven roofs and a button per act from the catalog dicts.
func build(defs: Dictionary) -> void:
	var root := VBoxContainer.new()
	add_child(root)
	for category in Phenomenon.CATEGORIES:
		var box := VBoxContainer.new()
		box.name = "category_%d" % category
		var header := Label.new()
		header.text = CATEGORY_NAMES[category]
		box.add_child(header)
		root.add_child(box)
		category_boxes[category] = box
	for id in defs:
		var def: Dictionary = defs[id]
		_defs[id] = def
		var button := Button.new()
		button.name = id
		button.text = id.replace("_", " ")
		button.pressed.connect(arm.bind(id))
		category_boxes[def["category"]].add_child(button)
		buttons[id] = button
	_apply_gate()


## Re-read the sim's earned tier (never re-derive the ladder here).
func refresh(colony: Colony) -> void:
	_tier = colony.unlocked_tier
	_apply_gate()


func unlocked(act_id: String) -> bool:
	return _defs[act_id]["tier"] <= _tier


## Arm an act for targeting; a locked act refuses.
func arm(act_id: String) -> bool:
	if not _defs.has(act_id) or not unlocked(act_id):
		return false
	_armed = act_id
	return true


func armed() -> String:
	return _armed


## The paint the armed act wants, so the input layer collects the right
## gesture ("" when nothing is armed).
func armed_target_kind() -> String:
	return _defs[_armed]["target"] if _armed != "" else ""


func disarm() -> void:
	_armed = ""


## Release: validate the selection against the armed act's target kind,
## route it to the runner, disarm. Returns false (and keeps the act
## armed) when the paint is the wrong kind — a refused gesture is not a
## spent act.
func paint(selection: Dictionary) -> bool:
	if _armed == "":
		return false
	var kind: String = _defs[_armed]["target"]
	if not selection.has(SELECTION_KEY[kind]):
		return false
	var act := _armed
	_armed = ""
	cast_requested.emit(act, _target_from(kind, selection), selection)
	return true


## The place string the sim runner casts at [algo §11]: regions and
## edges are their own names; a Vision lands where its chosen gnome
## stands (the input layer supplies that place alongside the gnome id).
func _target_from(kind: String, selection: Dictionary) -> String:
	match kind:
		"region":
			return selection["region"]
		"region-edge":
			return selection["edge"]
		_:
			return selection.get("place", "")


func _apply_gate() -> void:
	for id in buttons:
		buttons[id].disabled = not unlocked(id)
	for category in category_boxes:
		var any_open := false
		for id in _defs:
			if _defs[id]["category"] == category and unlocked(id):
				any_open = true
				break
		category_boxes[category].visible = any_open
