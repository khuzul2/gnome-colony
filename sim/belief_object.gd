class_name BeliefObject
extends RefCounted
## Layer B belief-object schema & factory [plan T6.3, algo §9]. Objects are
## plain Dictionaries (serializer-friendly, value-comparable); this class
## owns their shape and the axis→kind mapping. The §9 table's rows overlap
## (fear/reverence both list taboo); the axis-PRIMARY reading is used:
##   fear → taboo · awe → rite · reverence → place_reverence ·
##   faith → theology  (interpretive, noted in PROGRESS.md).
## Taboos curse a place-tag; place-reverence blesses one [algo §9].

const AXIS_KIND := {
	"fear": "taboo",
	"awe": "rite",
	"reverence": "place_reverence",
	"faith": "theology",
}


static func make(
	kind: String, subject: String, axis: String, strength: float, holders: Array
) -> Dictionary:
	return {
		"kind": kind,
		"subject": subject,
		"axis": axis,
		"strength": strength,
		"holders": holders,
		"variant": 0,
	}


static func kind_for_axis(axis: String) -> String:
	return AXIS_KIND.get(axis, "")
