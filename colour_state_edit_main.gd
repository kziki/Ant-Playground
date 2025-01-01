extends Control

const GRID_SPACE = Vector2(64,24)

var edit_scene = preload("res://colour_state_edit.tscn")
var colour_picker = preload("res://colour_picker.tscn")
var label_scene = preload("res://state_number.tscn")

var state_edits:Dictionary = {}

var randomizing:bool = false

func _ready():
	g.edit_main = self
	$scroll/vbox/edit_dict/scroll_cont/main/labels.mouse_filter = MOUSE_FILTER_IGNORE
	$scroll/vbox/edit_dict/scroll_cont/main/edits.mouse_filter = MOUSE_FILTER_IGNORE
	$scroll/vbox/edit_dict/scroll_cont/main/colours.mouse_filter = MOUSE_FILTER_IGNORE
	init_grid()

func clear_grid():
	for c in $scroll/vbox/edit_dict/scroll_cont/main.get_children():
		c.queue_free()
	state_edits.clear()

func init_grid():
	$scroll/vbox/edit_dict/scroll_cont/main.custom_minimum_size = Vector2((g.colour_amt+1)*68,(g.state_amt+1)*28) + Vector2(32,32)
	for c in g.colour_amt:
		for s in g.state_amt:
			new_edit(Vector2i(c,s))
	
	for s in g.state_amt:
		var new = label_scene.instantiate()
		new.position = Vector2(0,s*GRID_SPACE.y+32)
		new.text = str(s)
		$scroll/vbox/edit_dict/scroll_cont/main/labels.add_child(new)
	
	for c in g.colour_amt:
		var new = colour_picker.instantiate()
		new.position = Vector2(c*GRID_SPACE.x+(GRID_SPACE.x/1.1),8)
		if c==0:new.color = Color.BLACK
		else: new.color = Color.WHITE
		new.get_child(0).text = str(int(c))
		$scroll/vbox/edit_dict/scroll_cont/main/colours.add_child(new)

func update_grid(x=null,y=null):
	for i in state_edits:
		state_edits[i].reload(x,y)
	if !x == null:
		if x > 0: #add colours to grid
			for c in x:
				for s in g.state_amt:
					new_edit(Vector2i(g.colour_amt-x+c,s))
				var new = colour_picker.instantiate()
				new.position = Vector2((g.colour_amt-x+c)*GRID_SPACE.x+(GRID_SPACE.x/1.1),8)
				new.get_child(0).text = str(int(g.colour_amt-x+c))
				if g.colour_amt-x+c == 0: new.color = Color.BLACK
				else: new.color = Color.WHITE
				$scroll/vbox/edit_dict/scroll_cont/main/colours.add_child(new)
			g.world.colours = get_colours()
		else: #remove colours from grid
			for c in -x:
				for s in g.state_amt:
					#print(Vector2i(g.colour_amt+c,s))
					remove_edit(Vector2i(g.colour_amt+c,s))
				#print(g.colour_amt-x-c-1)
				$scroll/vbox/edit_dict/scroll_cont/main/colours.get_child(g.colour_amt-x-c-1).queue_free()
			g.world.colours = get_colours()
	else:
		if y > 0: #add states to grid
			for c in g.colour_amt:
				for s in y:
					#new_edit(Vector2i(g.colour_amt-c-1,s))
					new_edit(Vector2i(c,g.state_amt-s-1))
			
			for s in y:
				var new = label_scene.instantiate()
				new.position = Vector2(0,(g.state_amt-y+s)*GRID_SPACE.y+32)
				new.text = str(int(g.state_amt-y+s))
				$scroll/vbox/edit_dict/scroll_cont/main/labels.add_child(new)
		else: #remove states from grid
			for c in g.colour_amt:
				for s in -y:
					remove_edit(Vector2i(c,g.state_amt+s))
			
			for s in -y:
				$scroll/vbox/edit_dict/scroll_cont/main/labels.get_child(g.state_amt-y-s-1).queue_free()
			
	$scroll/vbox/edit_dict/scroll_cont/main.custom_minimum_size = Vector2((g.colour_amt)*GRID_SPACE.x,(g.state_amt+1)*GRID_SPACE.y) + GRID_SPACE
	#print (get_colours())
	#print (make_ant_from_edits())

func new_edit(pos:Vector2i):
	var new = edit_scene.instantiate()
	new.position = (Vector2(pos.x,pos.y)*GRID_SPACE) + Vector2(32,32)
	$scroll/vbox/edit_dict/scroll_cont/main/edits.add_child(new)
	state_edits[pos] = new 

func remove_edit(pos):
	state_edits[pos].queue_free()
	state_edits.erase(pos)

func make_ant_from_edits() -> Dictionary:
	var x:Dictionary = {}
	for i in state_edits:
		x[i] = [state_edits[i].get_colour(),state_edits[i].get_state(),state_edits[i].get_rotate()]
	return x

func randomize_edits():
	g.randomizing = true
	
	randomize_to_states()
	randomize_to_colours()
	randomize_rotate()
	
	
	g.world.update_ant()

func randomize_to_states():
	g.randomizing = true
	
	for i in state_edits:
		state_edits[i].get_child(1).select(randi()%g.state_amt)
	
	g.randomizing = false
	g.world.update_ant()

func randomize_to_colours():
	g.randomizing = true
	
	for i in state_edits:
		state_edits[i].get_child(0).select(randi()%g.colour_amt)
	
	g.randomizing = false
	g.world.update_ant()

func randomize_rotate():
	g.randomizing = true
	
	for i in state_edits:
		state_edits[i].get_child(2).select(randi()%4)
	
	g.randomizing = false
	g.world.update_ant()

func randomize_colours():
	pass

func _on_x_value_changed(value):
	g.x = value
	g.world.update_field()

func _on_y_value_changed(value):
	g.y = value
	g.world.update_field()

func _on_amt_s_value_changed(value):
	var x = g.state_amt
	g.state_amt = value
	update_grid(null,value-x)
	#clear_grid()
	#init_grid()

func _on_amt_c_value_changed(value):
	var x = g.colour_amt
	g.colour_amt = value
	update_grid(value-x)
	#clear_grid()
	#init_grid()

func get_colours():
	var x:Dictionary = {}
	for i in g.colour_amt:
		x[int(i)] = $scroll/vbox/edit_dict/scroll_cont/main/colours.get_child(i).color
	return x

func disable_elements():
	$scroll/vbox/field_size/hbox/x.editable = false
	$scroll/vbox/field_size/hbox/y.editable = false
	$scroll/vbox/colours/hbox/amt_c.editable = false
	$scroll/vbox/ant_states/hbox/amt_s.editable = false

func enable_elements():
	$scroll/vbox/field_size/hbox/x.editable = true
	$scroll/vbox/field_size/hbox/y.editable = true
	$scroll/vbox/colours/hbox/amt_c.editable = true
	$scroll/vbox/ant_states/hbox/amt_s.editable = true


func _on_to_all_pressed():
	randomize_edits()

func _on_to_states_pressed():
	randomize_to_states()

func _on_to_colour_pressed():
	randomize_to_colours()

func _on_rotation_pressed():
	randomize_rotate()
