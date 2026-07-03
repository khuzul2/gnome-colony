class_name Telemetry
extends RefCounted
## Run telemetry [plan T16.3, design §1.9]: the optional balancing
## sheet — generations, peak pop, techs, schisms, wars — accrued from
## the SAME recorded event stream the Chronicle composes from (one
## stream, two readers; nothing to drift out of sync) plus day-by-day
## population peaks. Plain data, JSON-exportable; the shell owns when
## to record and when to export.

## The recorded stream (Chronicle-compatible: {type, day, ...}).
var events: Array = []

var _peak_pop := 0


## Call once per sim day (or as often as wanted — peaks only rise).
func track_day(colony: Colony) -> void:
	_peak_pop = maxi(_peak_pop, colony.population())


## Append one run event: war, schism, discovery, settlement_founded…
func record(event: Dictionary) -> void:
	events.append(event.duplicate(true))


## Re-arm the peak after a load [T17.2 reviewer catch]: the shell
## serializes summary()'s peak into its save envelope; without this the
## counter restarts at the loaded population and end-of-run stats lie.
func restore_peak(peak: int) -> void:
	_peak_pop = maxi(_peak_pop, peak)


## The balancing summary [T16.3's named fields].
func summary(colony: Colony) -> Dictionary:
	var generations := 0
	for g in colony.gnomes.values():
		generations = maxi(generations, g.generation)
	var known := {}
	for sid in colony.settlement_knowledge:
		for id in colony.settlement_knowledge[sid]:
			known[id] = true
	var wars := 0
	var schisms := 0
	for event in events:
		match event.get("type", ""):
			"war":
				wars += 1
			"schism":
				schisms += 1
	return {
		"generations": generations,
		"peak_pop": maxi(_peak_pop, colony.population()),
		"techs": known.size(),
		"schisms": schisms,
		"wars": wars,
	}


func export_json(colony: Colony) -> String:
	return JSON.stringify(summary(colony), "", true)
