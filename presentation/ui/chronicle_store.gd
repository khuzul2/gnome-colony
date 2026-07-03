class_name ChronicleStore
extends RefCounted
## The main menu's Chronicles shelf [plan T15.5, setup §6]: one JSON
## per ended run. keep/list/export/wipe — the same shape as SaveStore,
## but records only; a chronicle is history, never loadable state.

var _dir: String


func _init(base_dir: String = "user://chronicles") -> void:
	# Same user://-territory containment as SaveStore (reviewer).
	_dir = base_dir if base_dir.begins_with("user://") else "user://chronicles"
	DirAccess.make_dir_recursive_absolute(_dir)


func keep(slot: String, record: Dictionary) -> void:
	var file := FileAccess.open(_path(slot), FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "", true))
	file.close()


func list_chronicles() -> Array:
	var out := []
	for file_name in DirAccess.get_files_at(_dir):
		if not file_name.ends_with(".json"):
			continue
		var slot := file_name.trim_suffix(".json")
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path(slot)))
		if parsed is Dictionary:
			out.append({"slot": slot, "record": parsed})
	return out


## §1.9: exportable — the raw shareable JSON.
func export_chronicle(slot: String) -> String:
	if not FileAccess.file_exists(_path(slot)):
		return ""
	return FileAccess.get_file_as_string(_path(slot))


func wipe() -> void:
	for file_name in DirAccess.get_files_at(_dir):
		if file_name.ends_with(".json"):
			DirAccess.remove_absolute(_dir.path_join(file_name))


func _path(slot: String) -> String:
	return _dir.path_join("%s.json" % SaveStore.sanitize(slot))
