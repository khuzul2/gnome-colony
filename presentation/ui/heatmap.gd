class_name Heatmap
extends RefCounted
## Mood/belief heatmaps [plan T14.3, design §2.7]: pure READERS of the
## substrate at either grain — living gnomes by location (quickened) or
## folded Settlement aggregates (statistical, §14) — returning
## place → {mood, faith, awe, fear} for the map layer to paint. Mood is
## §5's 1 − mean(needs); belief axes are the feelings toward the unseen
## will. Nothing here computes sim state — a heatmap that disagreed
## with the fold would be a lie. The color ramp is a presentation
## number (red = low, green = high).

const AXES := ["faith", "awe", "fear"]


## Quickened grain: mean mood & mean feelings toward YOU per place,
## from the living only.
static func from_gnomes(colony: Colony) -> Dictionary:
	var sums := {}
	var counts := {}
	for g in colony.living():
		var place: String = g.location
		if not sums.has(place):
			sums[place] = {"mood": 0.0, "faith": 0.0, "awe": 0.0, "fear": 0.0}
			counts[place] = 0
		var need_sum := 0.0
		for key in Enums.NEED_KEYS:
			need_sum += g.needs[key]
		sums[place]["mood"] += 1.0 - need_sum / Enums.NEED_KEYS.size()
		for axis in AXES:
			sums[place][axis] += g.get_feeling(Devotion.YOU, axis)
		counts[place] += 1
	var out := {}
	for place in sums:
		out[place] = {}
		for key in sums[place]:
			out[place][key] = sums[place][key] / counts[place]
	return out


## Statistical grain: the fold IS the reading. `place_of` maps sid →
## place name (the orchestrator's wiring); an unmapped settlement gets
## a fallback key so the map never goes blind.
static func from_settlements(settlements: Dictionary, place_of: Dictionary) -> Dictionary:
	var out := {}
	for sid in settlements:
		var s: Settlement = settlements[sid]
		var place: String = place_of.get(sid, "settlement_%d" % sid)
		var reading := {"mood": s.mood}
		for axis in AXES:
			reading[axis] = s.belief[axis]
		out[place] = reading
	return out


## Cold→warm ramp (presentation number): low reads red, high reads
## green, at constant blue so the two ends stay distinguishable to
## common color-blindness axes better than pure red/green would.
static func color(value: float) -> Color:
	var v := clampf(value, 0.0, 1.0)
	return Color(1.0 - v, v, 0.25)
