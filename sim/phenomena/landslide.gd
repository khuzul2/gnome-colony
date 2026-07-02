class_name Landslide
extends RefCounted
## The Sliding Earth [plan T7.3, algo §18, design §3.4] — the canonical
## first act. World effects at the target site:
##   · the site is buried (current scaled by 1 − intensity)
##   · hidden resources are exposed (the scar glints with ore)
##   · the "<site>_path" is blocked when one exists
##   · each gnome present rolls death at |effects.population| · intensity
##     (the population axis IS the lethality dial — interpretive; the spec
##     gives the axis weight, not a separate casualty number)
## Fear/appraisal is NOT done here — the stimulus reaches T7.4's appraisal.


static func handlers() -> Dictionary:
	return {"landslide": _handle}


static func _handle(colony: Colony, world: WorldState, stim: Dictionary) -> void:
	var place: String = stim["place"]
	var intensity: float = stim["intensity"]
	if world.sites.has(place):
		world.sites[place].current *= maxf(0.0, 1.0 - intensity)
	world.reveal_hidden(place)
	var path_id := "%s_path" % place
	if world.paths.has(path_id):
		world.paths[path_id] = false
	var lethality: float = absf(stim["effects"]["population"]) * intensity
	for g in colony.living():
		if g.location == place and Rng.chance(lethality):
			g.stage = Enums.LifeStage.DEAD
			EventBus.gnome_died.emit({"id": g.id, "cause": stim["type"], "age": g.age})
