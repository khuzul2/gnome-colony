extends Node
## Sim event bus [plan T2.1, algo §16] — autoloaded as `EventBus`; systems
## react independently so emergent chains are easy to wire. Payloads are
## plain Dictionaries. Extends Node only because Godot autoloads must be
## Nodes; carries no scene/render state.

signal born(payload: Dictionary)
signal gnome_died(payload: Dictionary)
signal stage_changed(payload: Dictionary)
signal knowledge_lost(payload: Dictionary)
signal belief_formed(payload: Dictionary)
signal phenomenon(payload: Dictionary)
## The colony's principal settlement changed [user feature 2026-07-03]:
## first anointment or succession after the main settlement died off.
## Payload {"sid": new main (-1 when none survive), "previous": old sid}.
signal main_settlement_changed(payload: Dictionary)
## The run closes into the Chronicle [design §1.9]; no re-founding (T11.4).
signal world_ended(payload: Dictionary)
## [T22.3] Migrants found a frontier basin [algo §14] — emitted by the
## shell where the founding enters telemetry. Payload {"sid": basin id,
## "place": its place id, "day": sim day}.
signal settlement_founded(payload: Dictionary)
## [T22.3] A §13 research season lands a discovery — one emission per
## discovered id. Payload {"id": tech id, "day": sim day}.
signal discovery_made(payload: Dictionary)
## [T22.3] Unrest crossed the §10 fracture line and a splinter walked
## out of the colony [algo §14]. Payload {"day": sim day}.
signal colony_fractured(payload: Dictionary)
## [T22.3] A §17 war resolved between aggregate settlements. Payload
## {"winner": sid, "loser": sid, "day": sim day}.
signal war_waged(payload: Dictionary)
## [T22.3] A §14 doctrinal schism split a settlement's faction into a
## free basin. Payload {"from": source sid, "to": new sid, "day": sim day}.
signal schism_split(payload: Dictionary)
## [rav §R-set] A settlement crossed a development tier. Payload
## {"sid": settlement id, "from": old tier, "to": new tier}.
signal settlement_tier_changed(payload: Dictionary)
## [rav §R-set] A settlement finished building a structure. Payload
## {"sid": settlement id, "building": id, "tier": current tier}.
signal structure_built(payload: Dictionary)
