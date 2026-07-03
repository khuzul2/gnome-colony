class_name AftermathPanel
extends PanelContainer
## Feedback/hindsight [plan T14.2, design §2.7]: outcomes are indirect
## and mysterious by design, so cause→effect must be traceable AFTER the
## fact. The panel subscribes to the EventBus — `phenomenon` beats build
## the cascade timeline (root first; consequence markers indented) and
## the affected-area highlight; `belief_formed` fills "what they now
## believe". who_they_think_you_are() reads the colony's image of you:
## depth (d̄, §10), the earned tier (the sim's ratchet — never re-derived
## here), flavor from the SIGN of flavor_balance (§10: love- vs
## terror-devotion; exactly zero = no image yet), and the crystallized
## theology creeds that name you (§3.7). begin(act) opens a fresh page —
## one aftermath per cast. Read-only glue: the panel mutates no sim
## state; the affected-place list is what the map layer highlights.

## The open aftermath's act (title); "" until the first begin().
var act_id := ""
## Cascade beats in arrival order (copies of the EventBus payloads).
var timeline: Array = []
## Crystallized-belief payloads since begin().
var new_beliefs: Array = []

var timeline_box: VBoxContainer
var beliefs_box: VBoxContainer

var _title: Label
var _places: Array = []


func _ready() -> void:
	var root := VBoxContainer.new()
	add_child(root)
	_title = Label.new()
	root.add_child(_title)
	timeline_box = VBoxContainer.new()
	root.add_child(timeline_box)
	beliefs_box = VBoxContainer.new()
	root.add_child(beliefs_box)
	EventBus.phenomenon.connect(_on_phenomenon)
	EventBus.belief_formed.connect(_on_belief_formed)


## A new act opens a blank page — hindsight is per-cast [design §2.7].
func begin(id: String) -> void:
	act_id = id
	timeline.clear()
	new_beliefs.clear()
	_places.clear()
	for box in [timeline_box, beliefs_box]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	_title.text = "the aftermath of %s" % id.replace("_", " ")


## The places this cast touched, in first-touch order — the map layer's
## highlight list.
func affected_places() -> Array:
	return _places.duplicate()


## "Who they think you are" [design §2.7, algo §10]: depth is d̄, tier is
## the colony's ratchet, flavor is the sign of mean(awe−fear) toward you
## (zero — an empty or untouched colony — reads "unknown": they have no
## image of you yet), creeds are the theology objects naming you.
func who_they_think_you_are(colony: Colony) -> Dictionary:
	var balance := Devotion.flavor_balance(colony)
	var flavor := "unknown"
	if balance > 0.0:
		flavor = "loved"
	elif balance < 0.0:
		flavor = "feared"
	var creeds := []
	for belief_obj in colony.beliefs:
		if belief_obj["kind"] == "theology" and belief_obj["subject"] == Devotion.YOU:
			creeds.append(belief_obj.get("flavor", "nameless"))
	return {
		"depth": Devotion.per_capita(colony),
		"tier": colony.unlocked_tier,
		"flavor": flavor,
		"creeds": creeds,
	}


func _on_phenomenon(payload: Dictionary) -> void:
	timeline.append(payload.duplicate(true))
	var place: String = payload.get("place", "")
	if place != "" and not place in _places:
		_places.append(place)
	var row := Label.new()
	var lead := "↳ " if payload.get("consequence", false) else ""
	row.text = (
		"%s%s at %s (%.2f)"
		% [
			lead,
			str(payload.get("type", "?")).replace("_", " "),
			place,
			payload.get("intensity", 0.0)
		]
	)
	timeline_box.add_child(row)


func _on_belief_formed(payload: Dictionary) -> void:
	new_beliefs.append(payload.duplicate(true))
	var row := Label.new()
	row.text = (
		"they now hold a %s about %s"
		% [payload.get("kind", "?"), str(payload.get("subject", "?")).replace("_", " ")]
	)
	beliefs_box.add_child(row)
