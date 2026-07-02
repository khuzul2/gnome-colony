extends Node
## Seeded RNG singleton — the sim's ONLY source of randomness [algo §0].
## Autoloaded as `Rng` (plan T0.4). Extends Node only because Godot requires
## autoload scripts to be Nodes; it carries no scene, render, or input state.

var _rng := RandomNumberGenerator.new()


func seed_with(seed_value: int) -> void:
	_rng.seed = seed_value


func randf() -> float:
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func gauss(mu: float, sd: float) -> float:
	return _rng.randfn(mu, sd)


func chance(p: float) -> bool:
	if p >= 1.0:
		return true
	if p <= 0.0:
		return false
	return _rng.randf() < p
