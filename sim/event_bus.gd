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
## The run closes into the Chronicle [design §1.9]; no re-founding (T11.4).
signal world_ended(payload: Dictionary)
