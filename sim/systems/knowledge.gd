class_name Knowledge
extends RefCounted
## Per-settlement knowledge & extinction [plan T4.4, algo §7]: a settlement
## loses an id when no living local gnome holds it at prof ≥ 0.2 (i.e. has
## the teachable id) — a REGIONAL dark age; other settlements may keep the
## craft and later re-spread it. Durable records (writing, T4.5) exempt ids
## from loss. State lives on Colony (settlement_knowledge / durable_records).


## Register every id currently held by living gnomes to their settlements.
## Call after teaching/practice phases so newly-earned ids are on record.
static func sync(colony: Colony) -> void:
	for g in colony.living():
		var sid: int = g.home_settlement
		if not colony.settlement_knowledge.has(sid):
			colony.settlement_knowledge[sid] = {}
		for id in g.knowledge:
			colony.settlement_knowledge[sid][id] = true


## Writing durability [plan T4.5, algo §7]: in every settlement where
## `writing` is currently known, snapshot ALL known ids into durable
## records — they become extinction-proof and studyable from the record.
static func snapshot_records(colony: Colony) -> void:
	for sid in colony.settlement_knowledge:
		if not colony.settlement_knowledge[sid].has("writing"):
			continue
		if not colony.durable_records.has(sid):
			colony.durable_records[sid] = {}
		for id in colony.settlement_knowledge[sid]:
			colony.durable_records[sid][id] = true


## Remove ids with no living local holder (unless durable) and emit
## knowledge_lost per loss. `folded_sids` names settlements that live in
## AGGREGATE form (T11.2) — they hold knowledge without gnome objects by
## design, so the holder-count sweep must skip them or it would misread
## every fold as a dark age (reviewer catch); aggregate-tier loss is
## event-driven at the civilization tier (T11.4). A settlement emptied
## by DEATH is not folded — it still loses its crafts (T4.4).
static func check_extinction(colony: Colony, folded_sids: Array = []) -> void:
	var holders := {}
	for g in colony.living():
		for id in g.knowledge:
			if not holders.has(g.home_settlement):
				holders[g.home_settlement] = {}
			holders[g.home_settlement][id] = true
	for sid in colony.settlement_knowledge:
		if sid in folded_sids:
			continue
		for id in colony.settlement_knowledge[sid].keys():
			if holders.get(sid, {}).has(id):
				continue
			if colony.durable_records.get(sid, {}).has(id):
				continue
			colony.settlement_knowledge[sid].erase(id)
			EventBus.knowledge_lost.emit({"id": id, "settlement": sid})
