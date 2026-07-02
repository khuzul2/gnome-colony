class_name BeliefObject
extends RefCounted
## Layer B belief-object schema & factory [plan T6.3, algo §9]. Objects are
## plain Dictionaries (serializer-friendly, value-comparable); this class
## owns their shape and the axis→kinds mapping, which preserves the §9
## table's OVERLAPPING triggers: taboo ← fear/reverence, rite ← awe/faith,
## place_reverence ← reverence, theology ← faith. One sustained axis can
## crystallize several objects (a revered ridge becomes both sacred ground
## and a thing one must not disturb).

const AXIS_KINDS := {
	"fear": ["taboo"],
	"awe": ["rite"],
	"reverence": ["taboo", "place_reverence"],
	"faith": ["rite", "theology"],
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


static func kinds_for_axis(axis: String) -> Array:
	return AXIS_KINDS.get(axis, [])
