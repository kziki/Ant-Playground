extends Control

func _ready():
	for c in g.colour_amt:
		$Colour.add_item(str(int(c)),c)
	
	for s in g.state_amt:
		$State.add_item(str(int(s)),s)


func get_colour():
	return $Colour.selected


func get_state():
	return $State.selected


func get_rotate():
	return $Rotation.selected


func reload(x = null, y = null):
	if x != null:
		if x < 0:
			for c in -x:
				$Colour.remove_item(g.colour_amt-x-c-1)
		else:
			for c in x:
				$Colour.add_item(str(int(g.colour_amt-x+c)),g.colour_amt-x+c)
	else:
		if y < 0:
			for s in -y:
				$State.remove_item(g.state_amt-y-s-1)
		else:
			for s in y:
				$State.add_item(str(int(g.state_amt-y+s)),g.state_amt-y+s)


func _on_colour_item_selected(_index):
	if !g.randomizing: g.world.update_ant()

func _on_state_item_selected(_index):
	if !g.randomizing: g.world.update_ant()

func _on_rotation_item_selected(_index):
	if !g.randomizing: g.world.update_ant()
