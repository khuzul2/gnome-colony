class_name AttentionInput
extends Node
## The Eye of God [plan T13.5, design §2.4, algo §14/§17]: turns the
## camera's gaze into the sim's attention input. Dwell ≥ 2 s (⚙️)
## promotes the watched region; a promoted region releases only after
## ~10 s (⚙️) of the gaze resting elsewhere; civilization zoom never
## promotes and counts as absence. Release lags while dwell leads, so an
## old and a new region can be attended AT ONCE — deliberate (§14's
## promote/demote hysteresis). Every promotion opens a sparse segment
## {t_start, t_end, region, radius} so the whole attention stream
## replays bit-identically (attention is a DECLARED sim input — the
## recorder here is what T12.2's harness scripts stand in for). Time is
## fed in as wall-clock dt; the presentation drives update() per frame.
## Radius-by-zoom values are presentation numbers.

const DWELL_SECONDS := 2.0  # §17 ⚙️
const RELEASE_SECONDS := 10.0  # §17 ⚙️
## Gaze radius per zoom (km, presentation): the tighter the lens, the
## tighter the circle. Civilization zoom never gazes.
const RADIUS_BY_ZOOM := {CameraRig.Zoom.SETTLEMENT: 6.0, CameraRig.Zoom.INDIVIDUAL: 2.0}

## region → seconds of absence remaining before release (insertion order
## = promotion order, which attended() preserves).
var _active := {}
var _candidate := ""
var _dwell := 0.0
var _t := 0.0
var _segments: Array = []
var _open := {}


## Advance the Eye by dt seconds of the gaze resting on `region` at
## `zoom`. Coarse dt is fine (tests); the game calls this per frame.
func update(dt_seconds: float, region: String, zoom: int) -> void:
	_t += dt_seconds
	var gazing := zoom != CameraRig.Zoom.CIVILIZATION
	for active_region in _active.keys():
		if gazing and active_region == region:
			_active[active_region] = RELEASE_SECONDS
		else:
			_active[active_region] -= dt_seconds
			if _active[active_region] <= 0.0:
				_release(active_region)
	if not gazing or _active.has(region):
		_candidate = ""
		_dwell = 0.0
		return
	if region == _candidate:
		_dwell += dt_seconds
	else:
		_candidate = region
		_dwell = dt_seconds
	if _dwell >= DWELL_SECONDS:
		_promote(region, zoom)
		_candidate = ""
		_dwell = 0.0


## The sim's attention input right now (promotion order).
func attended() -> Array:
	return _active.keys()


func radius_for(zoom: int) -> float:
	return RADIUS_BY_ZOOM.get(zoom, 0.0)


## The sparse recorded stream — closed and still-open segments.
func recording() -> Array:
	var out := _segments.duplicate(true)
	for region in _open:
		var open_copy: Dictionary = _open[region].duplicate()
		open_copy["t_end"] = INF
		out.append(open_copy)
	return out


## Replay: the attended set at time t per the recorded segments —
## start-inclusive, end-exclusive, in promotion (t_start) order. Static
## and pure, so a saved stream reproduces the run's gaze exactly.
static func attended_at(segments: Array, t: float) -> Array:
	var hits := []
	for segment in segments:
		if t >= segment["t_start"] and t < segment["t_end"]:
			hits.append(segment)
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["t_start"] < b["t_start"])
	var out := []
	for segment in hits:
		out.append(segment["region"])
	return out


func _promote(region: String, zoom: int) -> void:
	_active[region] = RELEASE_SECONDS
	_open[region] = {"t_start": _t, "region": region, "radius": radius_for(zoom)}


func _release(region: String) -> void:
	_active.erase(region)
	var segment: Dictionary = _open[region]
	segment["t_end"] = _t
	_segments.append(segment)
	_open.erase(region)
