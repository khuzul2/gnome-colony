class_name PuppetPool
extends Node
## Puppet pooling [plan T13.2]: births and promotions must not churn
## nodes at ten-thousand scale. Released puppets go invisible and wait;
## acquire() rebinds one or grows the pool. Pure presentation.

var _free: Array = []


func acquire(gnome: GnomeData) -> GnomePuppet:
	var puppet: GnomePuppet
	if _free.is_empty():
		puppet = GnomePuppet.new()
		add_child(puppet)
	else:
		puppet = _free.pop_back()
	puppet.bind(gnome)
	return puppet


func release(puppet: GnomePuppet) -> void:
	puppet.data = null
	puppet.visible = false
	_free.append(puppet)
