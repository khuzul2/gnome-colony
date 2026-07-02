class_name Birth
extends RefCounted
## Birth scaffold [plan T2.4]: placeholder spawn of an Infant, emitting
## `born`. Fertility gates and genetic inheritance arrive in Phase 5
## (T5.3/T5.4); until then callers pass no parents and traits stay at
## their neutral defaults.


static func spawn_infant(colony: Colony) -> GnomeData:
	var infant := colony.spawn()
	infant.stage = Enums.LifeStage.INFANT
	infant.age = 0.0
	infant.sex = Rng.randi_range(0, 1)
	EventBus.born.emit({"id": infant.id})
	return infant
