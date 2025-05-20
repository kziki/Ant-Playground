extends Control

var edit_scene = preload("res://scenes/colour_state_edit.tscn")
var colour_picker = preload("res://scenes/colour_picker.tscn")
var label_scene = preload("res://scenes/state_number.tscn")

const GRID_SPACE = Vector2(72,32)
var state_edits:Dictionary = {}
var randomizing:bool = false

@onready var main_labels = $TabCont/Ants/Ants/VBox/Rules/VBox/RuleEdit/XY/Labels
@onready var main_edits = $TabCont/Ants/Ants/VBox/Rules/VBox/RuleEdit/ScrollCont/Main/Edits
@onready var main_colours = $TabCont/Ants/Ants/VBox/Rules/VBox/RuleEdit/XY/Colours
@onready var main = $TabCont/Ants/Ants/VBox/Rules/VBox/RuleEdit/ScrollCont/Main
@onready var ant_select = $TabCont/Ants/Select/HBox/AntChoose

func _ready():
	g.sidebar = self
	main_labels.mouse_filter = MOUSE_FILTER_IGNORE
	main_edits.mouse_filter = MOUSE_FILTER_IGNORE
	main_colours.mouse_filter = MOUSE_FILTER_IGNORE
	init_grid.call_deferred()
	
	$TabCont/Grid/Grid/VBox/Basic/VBox/FieldSize/HBox/X.set_deferred("step",g.sq_chunksize)
	$TabCont/Grid/Grid/VBox/Basic/VBox/FieldSize/HBox/Y.set_deferred("step",g.sq_chunksize)
	$TabCont/Grid/Grid/VBox/Basic/VBox/FieldSize/HBox/X.set_deferred("min_value",g.sq_chunksize)
	$TabCont/Grid/Grid/VBox/Basic/VBox/FieldSize/HBox/Y.set_deferred("min_value",g.sq_chunksize)
	
	$TabCont/Ants/Ants/VBox/Current.rule_edit = self
	
	select_ant.call_deferred(0)
	
	$TabCont/Grid/Grid/VBox/Colours/VBox/Colours/GridContainer/ColourPicker.get_child(0).text = "0"


func add_ant(index,ant_name):
	$TabCont/Ants/Select/HBox/AntChoose.add_item(ant_name,index)


func init_grid():
	main.custom_minimum_size = Vector2((g.colour_amt+1)*68,(g.state_amt[g.selected_ant]+1)*28) + Vector2(32,32)
	for c in g.colour_amt:
		for s in g.state_amt[g.selected_ant]:
			var edit = new_edit(Vector2i(c,s))
			var x = g.world.colour_state_rules[g.selected_ant][c][s]
			edit.set_colour(x[0])
			edit.set_state(x[1])
			edit.set_rotate(x[2])
	
	for s in g.state_amt[g.selected_ant]:
		var new = label_scene.instantiate()
		new.position = Vector2(0,s*GRID_SPACE.y+32)
		new.text = str(s)
		main_labels.add_child(new)
	
	for c in g.colour_amt:
		var new = colour_picker.instantiate()
		new.position = Vector2(c * GRID_SPACE.x + GRID_SPACE.x -12, 8)
		if c==0:new.color = Color.BLACK
		else: new.color = Color.WHITE
		new.get_child(0).text = str(int(c))
		main_colours.add_child(new)


func resize_grid(x=null,y=null):
	for i in state_edits:
		state_edits[i].reload(x,y)
	if !x == null:
		if x > 0: #add colours to grid
			for c in x:
				for s in g.state_amt[g.selected_ant]:
					new_edit(Vector2i(g.colour_amt-x+c,s))
				
				var new = colour_picker.instantiate()
				
				new.position = Vector2((g.colour_amt-x+c)*GRID_SPACE.x + GRID_SPACE.x -12,8)
				new.get_child(0).text = str(int(g.colour_amt-x+c))
				
				new.color = g.user_pallete.get_pixel(0,g.colour_amt-x+c)
				
				main_colours.add_child(new)
			
			#g.world.colours = get_colours()
		else: #remove colours from grid
			for c in -x:
				for s in g.state_amt[g.selected_ant]:
					remove_edit(Vector2i(g.colour_amt+c,s))
				main_colours.get_child(g.colour_amt-x-c-1).queue_free()
			#g.world.colours = get_colours()
	else:
		if y > 0: #add states to grid
			for c in g.colour_amt:
				for s in y:
					new_edit(Vector2i(c,g.state_amt[g.selected_ant]-s-1))
			
			for s in y:
				var new = label_scene.instantiate()
				
				new.position = Vector2(0,(g.state_amt[g.selected_ant]-y+s)*GRID_SPACE.y+32)
				new.text = str(int(g.state_amt[g.selected_ant]-y+s))
				
				main_labels.add_child(new)
			
		else: #remove states from grid
			for c in g.colour_amt:
				for s in -y:
					remove_edit(Vector2i(c,g.state_amt[g.selected_ant]+s))
			for s in -y:
				main_labels.get_child(g.state_amt[g.selected_ant]-y-s-1).queue_free()
			
	main.custom_minimum_size = Vector2((g.colour_amt)*GRID_SPACE.x,(g.state_amt[g.selected_ant])*GRID_SPACE.y)


func swap_grid(index:int, old_index:int):
	var state_difference:int = g.state_amt[index] - g.state_amt[old_index]
	resize_grid(null,state_difference)
	for c in g.colour_amt:
		for s in g.state_amt[index]:
			pass
			var x = g.world.colour_state_rules[g.selected_ant][c][s]
			state_edits[Vector2i(c,s)].set_colour(x[0])
			state_edits[Vector2i(c,s)].set_state(x[1])
			state_edits[Vector2i(c,s)].set_rotate(x[2])


func new_edit(pos:Vector2i):
	var new = edit_scene.instantiate()
	new.position = (Vector2(pos.x, pos.y) * GRID_SPACE) + Vector2(0, 0)
	main_edits.add_child(new)
	state_edits[pos] = new 
	
	return new


func remove_edit(pos):
	state_edits[pos].queue_free()
	state_edits.erase(pos)


func make_ant_from_edits() -> Array:
	var c:Array = []
	c.resize(64)
	for i in 64:
		c[i] = []
		c[i].resize(64)
		for j in 64:
			var r: PackedByteArray = [0,0,0]
			c[i][j] = r
	for i in state_edits:
		c[i.x][i.y][0] = state_edits[i].get_colour()
		c[i.x][i.y][1] = state_edits[i].get_state()
		c[i.x][i.y][2] = state_edits[i].get_rotate()
	return c


func randomize_edits():
	g.randomizing = true
	
	randomize_to_states()
	randomize_to_colours()
	randomize_rotate()
	
	
	g.world.update_ant(ant_select.get_selected_id())


func randomize_to_states():
	g.randomizing = true
	
	for i in state_edits:
		state_edits[i].get_child(2).select(randi()%g.state_amt[g.selected_ant])
	
	g.randomizing = false
	g.world.update_ant(ant_select.get_selected_id())


func randomize_to_colours():
	g.randomizing = true
	
	for i in state_edits:
		state_edits[i].get_child(1).select(randi()%g.colour_amt)
	
	g.randomizing = false
	g.world.update_ant(ant_select.get_selected_id())


func randomize_rotate():
	g.randomizing = true
	
	for i in state_edits:
		state_edits[i].get_child(3).select(randi()%4)
	
	g.randomizing = false
	g.world.update_ant(ant_select.get_selected_id())


func randomize_colours():
	pass


func _on_x_value_changed(value):
	g.field_x = value
	g.world.update_field()
	update_field()


func _on_y_value_changed(value):
	g.field_y = value
	g.world.update_field()
	update_field()


func _on_amt_s_value_changed(value):
	var x = g.state_amt[g.selected_ant]
	g.state_amt[g.selected_ant] = value
	resize_grid(null,value-x)
	g.world.update_state_amt(x)


func _on_amt_c_value_changed(value):
	$TabCont/Grid/Grid/VBox/Colours/VBox/Colours/Colours.min_value = max($TabCont/Grid/Grid/VBox/Colours/VBox/Colours/Colours.min_value, value)
	var x = g.colour_amt
	g.colour_amt = value
	resize_grid(value-x)
	g.world.update_colour_amt(x)


func get_colours():
	var x:Dictionary = {}
	for i in g.colour_amt:
		x[int(i)] = main_colours.get_child(i).color
	return x


func disable_elements():
	$TabCont/Ants/Select/HBox/DeleteAnt.disabled = true


func enable_elements():
	pass
	$TabCont/Ants/Select/HBox/DeleteAnt.disabled = false


func _on_to_all_pressed():
	randomize_edits()


func _on_to_states_pressed():
	randomize_to_states()


func _on_to_colour_pressed():
	randomize_to_colours()


func _on_rotation_pressed():
	randomize_rotate()


func get_selected_ant_id() -> int:
	return $TabCont/Ants/Select/HBox/AntChoose.get_selected_index()


func _on_tab_cont_tab_changed(tab):
	if tab == 0:
		$TabCont/Ants/Ants/VBox/Current.set_process(false)
	elif tab == 1:
		$TabCont/Ants/Ants/VBox/Current.set_process(true)


func _on_ant_choose_item_selected(index):
	select_ant(index)


func select_ant(index):
	var old_id = g.selected_ant
	var ant = g.world.ants[index]
	g.selected_ant = index
	
	$TabCont/Ants/Ants/VBox/Start/VBox/Position/HBox/X.set_value_no_signal(ant[4].x)
	$TabCont/Ants/Ants/VBox/Start/VBox/Position/HBox/Y.set_value_no_signal(ant[4].y)
	$TabCont/Ants/Ants/VBox/Start/VBox/Direction/Option.selected = ant[5]
	$TabCont/Ants/Ants/VBox/Rules/VBox/States/Num.set_value_no_signal(g.state_amt[index])
	$TabCont/Ants/Ants/VBox/Info/VBox/Colour/ColorPickerButton.color = ant[3]
	$TabCont/Ants/Ants/VBox/Info/VBox/Name/LineEdit.text = ant[6]
	
	swap_grid(index,old_id)
	
	#resize_grid(g.colour_amt, g.state_amt[g.selected_ant])


func update_field():
	print("updated field")
	$TabCont/Ants/Ants/VBox/Start/VBox/Position/HBox/X.max_value = g.field_x - 1
	$TabCont/Ants/Ants/VBox/Start/VBox/Position/HBox/Y.max_value = g.field_y - 1
	$TabCont/Ants/Ants/VBox/Current/VBox/Position/HBox/X.max_value = g.field_x - 1
	$TabCont/Ants/Ants/VBox/Current/VBox/Position/HBox/Y.max_value = g.field_y - 1
	
	var ant = g.world.ants[$TabCont/Ants/Select/HBox/AntChoose.get_selected_id()]
	ant[4].x = min(g.field_x-1, ant[4].x)
	ant[4].y = min(g.field_y-1, ant[4].y)


func _on_new_ant_pressed():
	var x = g.world.new_ant()
	ant_select.select(x)
	select_ant(x)
	g.world.update_ant(g.sidebar.ant_select.get_selected_id())


func _on_start_x_value_changed(value):
	g.world.ants[g.selected_ant][4].x = value
	g.world.reset_ant(g.selected_ant)


func _on_start_y_value_changed(value):
	g.world.ants[g.selected_ant][4].y = value
	g.world.reset_ant(g.selected_ant)


func _on_start_direction_changed(direction):
	g.world.ants[g.selected_ant][5] = direction
	g.world.reset_ant(g.selected_ant)


func _on_color_picker_button_color_changed(color):
	g.world.set_ant_colour(g.selected_ant, color)


func _on_line_edit_text_submitted(new_text):
	g.world.ants[g.selected_ant][6] = new_text
	$TabCont/Ants/Select/HBox/AntChoose.set_item_text(g.selected_ant,"["+str(g.selected_ant)+"] - "+new_text)


func _on_show_ant_toggled(toggled_on):
	g.world.set_ant_visibility(g.selected_ant,toggled_on)


func _on_check_button_toggled(toggled_on):
	g.world.wrap_around = toggled_on


func _on_delete_ant_pressed():
	var index:int = $TabCont/Ants/Select/HBox/AntChoose.get_item_index(g.selected_ant)
	print("asdasdasd" + str(index) + str(index))
	if index > 0: 
		$TabCont/Ants/Select/HBox/AntChoose.select(index-1)
		select_ant($TabCont/Ants/Select/HBox/AntChoose.get_item_index(index-1))
	else: 
		$TabCont/Ants/Select/HBox/AntChoose.select(index+1)
		select_ant($TabCont/Ants/Select/HBox/AntChoose.get_item_index(index+1))
	
	$TabCont/Ants/Select/HBox/AntChoose.remove_item(index)
	
	g.world.delete_ant(index)
