class_name ChronicleScreen
extends Control
## Chronicle & world's end [plan T15.5, design §1.9 locked, setup §6]:
## when world_ended fires, the camera holds on the empty world for a
## breath — HOLD_SECONDS is a presentation number — then the Chronicle
## shows: an auto-generated history composed from the colony's final
## state plus the run's telemetry event list (the shell accumulates
## it; T16.3 formalizes the hooks). Records keep in a ChronicleStore
## (one JSON per run) for the main menu's Chronicles list, exportable.
## No new band arrives; what is gone is gone.

const HOLD_SECONDS := 4.0

var showing := false

var _held := 0.0
var _armed := false


func _ready() -> void:
	EventBus.world_ended.connect(_on_world_ended)


## Wall-clock beat: the shell drives this per frame after the end.
func update(dt_seconds: float) -> void:
	if not _armed or showing:
		return
	_held += dt_seconds
	if _held >= HOLD_SECONDS:
		showing = true


## The §1.9 history, from the fallen colony + telemetry:
##  · generations — the furthest generation any gnome reached
##  · settlements — founded per telemetry
##  · faiths — the theology creeds that named you (flavors)
##  · prophets — gnomes the calling ever touched
##  · wars, discoveries — from the telemetry stream
##  · structures — R3.4 [rav §R-build]: what they built, tallied by kind, so the
##    history reads as CIVIC DEVELOPMENT and not just survival
##  · peak_tier — R3.4: the height they reached (top tier crossed; a colony that
##    never crossed one stayed a "hamlet")
##  · how_it_ended — always total extinction (§14: the only world-end)
func compose(colony: Colony, telemetry: Array, run_meta: Dictionary) -> Dictionary:
	var generations := 0
	var prophets := 0
	for g in colony.gnomes.values():
		generations = maxi(generations, g.generation)
		if not g.prophet.is_empty():
			prophets += 1
	var faiths := []
	for belief_obj in colony.beliefs:
		if belief_obj["kind"] == "theology" and belief_obj["subject"] == Devotion.YOU:
			faiths.append(belief_obj.get("flavor", "nameless"))
	var wars := 0
	var settlements := 0
	var discoveries := []
	var structures := {}
	var peak_tier: int = Enums.SettlementTier.HAMLET
	for event in telemetry:
		match event.get("type", ""):
			"war":
				wars += 1
			"settlement_founded":
				settlements += 1
			"discovery":
				discoveries.append(event.get("id", "?"))
			"structure_built":
				var id: String = event.get("building", "structure")
				structures[id] = int(structures.get(id, 0)) + 1
			"settlement_tier_changed":
				peak_tier = maxi(peak_tier, int(event.get("to", Enums.SettlementTier.HAMLET)))
	return {
		"colony_name": run_meta.get("colony_name", ""),
		"seed": run_meta.get("seed", 0),
		"days": run_meta.get("days", 0),
		"generations": generations,
		"settlements": settlements,
		"faiths": faiths,
		"prophets": prophets,
		"wars": wars,
		"discoveries": discoveries,
		"structures": structures,
		"peak_tier": SettlementRoster.TIER_NAMES.get(peak_tier, "hamlet"),
		"how_it_ended": "total extinction",
	}


func store(base_dir: String = "user://chronicles") -> ChronicleStore:
	return ChronicleStore.new(base_dir)


func _on_world_ended(_payload: Dictionary) -> void:
	_armed = true
	_held = 0.0
