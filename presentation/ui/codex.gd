class_name FaintCodex
extends RefCounted
## The faint codex [plan T14.3, design §3.8 — locked: discover by
## trying]: the player is a natural philosopher of their own powers, so
## the codex keeps only faint, QUALITATIVE impressions of witnessed
## casts — "landslide — once uncovered what was hidden" — never counts,
## odds, or effect numbers. Each observation files the stimulus under
## its dominant effect axis (sign included) and repetition only firms
## the frequency WORD (once → sometimes → often). All phrasing and the
## frequency buckets are presentation language, not sim numbers; the
## sim is never read back, so the codex can't become a precise almanac
## even by accumulation. Consequence markers are remembered as things
## that FOLLOWED, keeping cascades traceable as hunches (§2.7).

## Observation-count buckets for the frequency word (presentation
## language: 1 sighting = "once", a few = "sometimes", many = "often").
const SOMETIMES_AT := 2
const OFTEN_AT := 5

## Dominant-axis phrasing, by axis and sign of the effect.
const PHRASES := {
	"material+": "raised what was not there before",
	"material-": "unmade what was built",
	"population+": "swelled their numbers",
	"population-": "took gnomes",
	"discovery+": "uncovered what was hidden",
	"discovery-": "buried what was known",
	"belief+": "left them changed inside",
	"belief-": "dulled their wonder",
	"social+": "drew them together",
	"social-": "set them against each other",
}
const FOLLOWED_PHRASE := "followed in the wake of another thing"
const FACELESS_PHRASE := "passed without a trace anyone could name"

## act type → lesson key → observation count (internal only; never
## surfaced as a number).
var _seen := {}


## File a witnessed stimulus (root, chained consequence, or tail) as a
## faint impression. Reads only the payload it is handed.
func observe(stimulus: Dictionary) -> void:
	var type: String = stimulus.get("type", "?")
	if not _seen.has(type):
		_seen[type] = {}
	var lesson := _lesson(stimulus)
	_seen[type][lesson] = _seen[type].get(lesson, 0) + 1


## The faint impressions about one act — [] when never witnessed: no
## almanac, no prediction.
func about(type: String) -> Array:
	if not _seen.has(type):
		return []
	var out := []
	for lesson in _seen[type]:
		var count: int = _seen[type][lesson]
		out.append("%s — %s %s" % [type.replace("_", " "), _frequency(count), lesson])
	return out


## Every impression in the book, act by act.
func impressions() -> Array:
	var out := []
	for type in _seen:
		out.append_array(about(type))
	return out


func _frequency(count: int) -> String:
	if count >= OFTEN_AT:
		return "often"
	if count >= SOMETIMES_AT:
		return "sometimes"
	return "once"


## The lesson is the stimulus' loudest effect axis, by |weight|;
## consequence markers teach that the thing FOLLOWED, and an act with
## no declared effects stays faceless.
func _lesson(stimulus: Dictionary) -> String:
	if stimulus.get("consequence", false):
		return FOLLOWED_PHRASE
	var effects: Dictionary = stimulus.get("effects", {})
	var best_axis := ""
	var best_value := 0.0
	for axis in effects:
		var value: Variant = effects[axis]
		if not (value is float or value is int):
			continue
		if absf(value) > absf(best_value):
			best_axis = axis
			best_value = value
	if best_axis == "":
		return FACELESS_PHRASE
	return PHRASES["%s%s" % [best_axis, "+" if best_value >= 0.0 else "-"]]
