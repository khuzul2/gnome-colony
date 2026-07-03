class_name SaveStore
extends RefCounted
## Save discovery & storage [plan T15.3, setup §6.1]: one JSON file per
## slot — {"meta": card, "save": envelope} — under a base dir the
## caller names. The card carries what §6.1's list shows (colony name,
## current generation, population, seed, playtime, timestamp, kind);
## sim facts are DERIVED from the envelope at save time, while playtime
## and timestamp are metadata fed by the caller (the shell clock never
## enters sim logic, and tests stay deterministic). Manual and
## autosaves are the same files with a different `kind` — the tabs
## filter. Load hands back the exact envelope; restoring it is
## Serializer.save_from_dict's job. The map thumbnail is a rendering
## concern deferred to the shell (documented omission).

var _dir: String


func _init(base_dir: String = "user://saves") -> void:
	_dir = base_dir
	DirAccess.make_dir_recursive_absolute(_dir)


## Write a slot: caller meta (kind/playtime/timestamp) + derived sim
## facts, alongside the untouched envelope.
func save_game(slot: String, envelope: Dictionary, meta: Dictionary = {}) -> void:
	var card := meta.duplicate(true)
	card.merge(derive_meta(envelope), true)
	var file := FileAccess.open(_path(slot), FileAccess.WRITE)
	file.store_string(JSON.stringify({"meta": card, "save": envelope}, "", true))
	file.close()


## The §6.1 card facts, read off the envelope itself so they can never
## disagree with the save.
static func derive_meta(envelope: Dictionary) -> Dictionary:
	var gnomes: Dictionary = envelope.get("colony", {}).get("gnomes", {})
	var population := 0
	var generation := 0
	for id in gnomes:
		if gnomes[id].get("stage", -1) != Enums.LifeStage.DEAD:
			population += 1
		generation = maxi(generation, int(gnomes[id].get("generation", 0)))
	# Era/tech level = distinct known ids across settlements; dominant
	# faith = the §10 flavor read (sign of mean awe−fear toward YOU)
	# over the living, "unknown" when no one feels anything.
	var known := {}
	var knowledge: Dictionary = envelope.get("colony", {}).get("settlement_knowledge", {})
	for sid in knowledge:
		for id in knowledge[sid]:
			known[id] = true
	var balance := 0.0
	for id in gnomes:
		if gnomes[id].get("stage", -1) == Enums.LifeStage.DEAD:
			continue
		var toward_you: Dictionary = gnomes[id].get("feelings", {}).get(Devotion.YOU, {})
		balance += float(toward_you.get("awe", 0.0)) - float(toward_you.get("fear", 0.0))
	var faith := "unknown"
	if balance > 0.0:
		faith = "loved"
	elif balance < 0.0:
		faith = "feared"
	var cfg: Dictionary = envelope.get("config", {})
	return {
		"colony_name": cfg.get("colony_name", ""),
		"seed": int(cfg.get("seed", 0)),
		"population": population,
		"generation": generation,
		"day": int(envelope.get("time", {}).get("total_days", 0.0)),
		"techs": known.size(),
		"faith": faith,
	}


## Cards newest-first (timestamp string order — callers feed ISO-style
## stamps); `kind` filters the Manual/Autosave tabs.
func list_saves(kind: String = "") -> Array:
	var out := []
	for file_name in DirAccess.get_files_at(_dir):
		if not file_name.ends_with(".json"):
			continue
		var slot := file_name.trim_suffix(".json")
		var meta := _read(slot).get("meta", {}) as Dictionary
		if kind != "" and meta.get("kind", "") != kind:
			continue
		# JSON reads numbers back as doubles; the card contract is typed.
		for key in ["population", "generation", "seed", "day", "techs"]:
			if meta.has(key):
				meta[key] = int(meta[key])
		out.append({"slot": slot, "meta": meta})
	out.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a["meta"].get("timestamp", "")) > str(b["meta"].get("timestamp", ""))
	)
	return out


func load_game(slot: String) -> Dictionary:
	return _read(slot).get("save", {})


func has_save(slot: String) -> bool:
	return FileAccess.file_exists(_path(slot))


## The main menu's Continue feed.
func has_saves() -> bool:
	return not list_saves().is_empty()


func delete_save(slot: String) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(_path(slot))


func duplicate_save(slot: String, copy_slot: String) -> void:
	if has_save(slot):
		DirAccess.copy_absolute(_path(slot), _path(copy_slot))


## §6.1 Export: the raw shareable JSON (save + seed inside).
func export_save(slot: String) -> String:
	if not has_save(slot):
		return ""
	return FileAccess.get_file_as_string(_path(slot))


## Test hygiene: remove every slot in this store's dir.
func wipe() -> void:
	for file_name in DirAccess.get_files_at(_dir):
		if file_name.ends_with(".json"):
			DirAccess.remove_absolute(_dir.path_join(file_name))


func _path(slot: String) -> String:
	return _dir.path_join("%s.json" % slot)


func _read(slot: String) -> Dictionary:
	if not has_save(slot):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path(slot)))
	return parsed if parsed is Dictionary else {}
