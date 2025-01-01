extends Control
var x:Vector2i

func _ready():
	for c in g.colour_amt:
		$colour.add_item(str(int(c)),c)
	
	for s in g.state_amt:
		$state.add_item(str(int(s)),s)

func get_colour():
	return $colour.selected

func get_state():
	return $state.selected

func get_rotate():
	return $rotation.selected

func reload(x=null,y=null):
	if x!=null:
		if x < 0:
			for c in -x:
				$colour.remove_item(g.colour_amt-x-c-1)
				#print(g.colour_amt-x-c-1)
		else:
			for c in x:
				#print(g.colour_amt-x+c)
				$colour.add_item(str(int(g.colour_amt-x+c)),g.colour_amt-x+c)
	else:
		if y < 0:
			for s in -y:
				$state.remove_item(g.state_amt-y-s-1)
		else:
			for s in y:
				$state.add_item(str(int(g.state_amt-y+s)),g.state_amt-y+s)


func _on_colour_item_selected(index):
	if !g.randomizing: g.world.update_ant()

func _on_state_item_selected(index):
	if !g.randomizing: g.world.update_ant()

func _on_rotation_item_selected(index):
	if !g.randomizing: g.world.update_ant()
