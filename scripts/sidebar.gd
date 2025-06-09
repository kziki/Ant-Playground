extends Control

var edit_scene = preload("res://scenes/colour_state_edit.tscn")
var colour_picker = preload("res://scenes/colour_picker.tscn")
var label_scene = preload("res://scenes/state_number.tscn")

const GRID_SPACE = Vector2(72,32)
var state_edits:Dictionary = {}
var randomizing:bool = false
var visible_x:int
var visible_y:int

@onready var main_labels = $TabCont/Ants/Ants/VBox/Rules/VBox/RuleEdit/XY/Labels
@onready var main_edits = $TabCont/Ants/Ants/VBox/Rules/VBox/RuleEdit/ScrollCont/Main/Edits
@onready var main_colours = $TabCont/Ants/Ants/VBox/Rules/VBox/RuleEdit/XY/Colours
@onready var main = $TabCont/Ants/Ants/VBox/Rules/VBox/RuleEdit/ScrollCont/Main
@onready var ant_select:OptionButton = $TabCont/Ants/Select/HBox/AntChoose

func _ready():
	g.sidebar = self
	main_labels.mouse_filter = MOUSE_FILTER_IGNORE
	main_edits.mouse_filter = MOUSE_FILTER_IGNORE
	main_colours.mouse_filter = MOUSE_FILTER_IGNORE
	init_grid.call_deferred()
	
	#$TabCont/Grid/Grid/VBox/Basic/VBox/FieldSize/HBox/X.set_deferred("step",g.sq_chunksize)
	#$TabCont/Grid/Grid/VBox/Basic/VBox/FieldSize/HBox/Y.set_deferred("step",g.sq_chunksize)
	_on_x_value_changed.call_deferred($TabCont/Grid/Grid/VBox/Basic/VBox/FieldSize/HBox/X.value)
	_on_y_value_changed.call_deferred($TabCont/Grid/Grid/VBox/Basic/VBox/FieldSize/HBox/Y.value)
	$TabCont/Grid/Grid/VBox/Basic/VBox/FieldSize/HBox/X.set_deferred("min_value",g.sq_chunksize)
	$TabCont/Grid/Grid/VBox/Basic/VBox/FieldSize/HBox/Y.set_deferred("min_value",g.sq_chunksize)
	
	$TabCont/Ants/Ants/VBox/Current.rule_edit = self
	
	select_ant.call_deferred(0)
	
	#$TabCont/Grid/Grid/VBox/Colours/VBox/Grid/GridContainer.get_child(0).text = "0"
	for c in g.max_colours:
		var new = colour_picker.instantiate()
		new.get_child(0).color = g.user_pallete.get_pixel(0,c)
		new.get_child(1).text = str(int(c))
		new.size_flags_horizontal = 3
		$TabCont/Grid/Grid/VBox/Colours/VBox/Grid/GridContainer.add_child(new)
		new.hide()
	
	$TabCont/Grid/Grid/VBox/Colours/VBox/Grid/GridContainer.get_child(0).show()
	$TabCont/Grid/Grid/VBox/Colours/VBox/Grid/GridContainer.get_child(1).show()
	


func add_ant(index,ant_name):
	$TabCont/Ants/Select/HBox/AntChoose.add_item(ant_name,index)
	$TabCont/Rand/Rand/VBox/Randomize/VBox/Which/WhichAnt.add_item(ant_name)
	


func init_grid():
	#instancing the max colours and states possible!! 
	#later you just adjust which ones are visible to avoid instancing and queueing constantly
	visible_x = 0
	visible_y = 0
	main.custom_minimum_size = Vector2((2)*GRID_SPACE.x, (1)*GRID_SPACE.y)
	
	for c in g.max_colours:
		for s in g.max_states:
			new_edit(Vector2i(c,s))
	
	for s in g.max_states:
		var new = label_scene.instantiate()
		new.position = Vector2(0,s*GRID_SPACE.y+32)
		new.text = str(s)
		main_labels.add_child(new)
	
	for c in g.max_colours:
		var new = colour_picker.instantiate()
		new.position = Vector2(c * GRID_SPACE.x + GRID_SPACE.x -30, 8)
		new.get_child(0).color = g.user_pallete.get_pixel(0,c)
		new.get_child(1).text = str(int(c))
		main_colours.add_child(new)
		new.hide()
	
	main_colours.get_child(0).show()
	main_colours.get_child(1).show()
	visible_x = 2


func resize_grid(x=null,y=null):
	if y != null:
		for i in state_edits:
			state_edits[i].reload(x,y - visible_y)
	else:
		for i in state_edits:
			state_edits[i].reload(x,y)
	if x != null:
		visible_x = visible_x + x
		if x > 0: #add colours to grid
			for c in x:
				for s in g.state_amt[g.selected_ant]:
					#new_edit(Vector2i(g.colour_amt-x+c,s))
					var a = Vector2i(g.colour_amt-x+c,s)
					var r = g.world.colour_state_rules[g.selected_ant][a.x][a.y]
					state_edits[a].show()
					state_edits[a].set_colour(r[0])
					state_edits[a].set_state(r[1])
					state_edits[a].set_rotate(r[2])
				
				main_colours.get_child(g.colour_amt-x+c).show()
		else: #remove colours from grid
			for c in -x:
				for s in g.state_amt[g.selected_ant]:
					state_edits[Vector2i(g.colour_amt+c,s)].hide()
				main_colours.get_child(g.colour_amt-x-c-1).hide()
			#g.world.colours = get_colours()
	elif y != null:
		var dif = y - visible_y
		visible_y = y
		if dif > 0: #add states to grid
			for c in g.colour_amt:
				for s in dif:
					var a = Vector2i(c,g.state_amt[g.selected_ant]-s-1)
					var r = g.world.colour_state_rules[g.selected_ant][c][a.y]
					state_edits[a].show()
					state_edits[a].set_colour(r[0])
					state_edits[a].set_state(r[1])
					state_edits[a].set_rotate(r[2])
			for s in y:
				main_labels.get_child(g.state_amt[g.selected_ant]-s-1).show()
			
		else: #remove states from grid
			for c in g.colour_amt:
				for s in -dif:
					state_edits[Vector2i(c,(g.state_amt[g.selected_ant]+s))].hide()
			for s in -dif:
				main_labels.get_child(g.state_amt[g.selected_ant]-dif-s-1).hide()
	
	main.custom_minimum_size = Vector2((visible_x)*GRID_SPACE.x, (visible_y)*GRID_SPACE.y)


func swap_grid(index:int):
	var state_difference:int = g.state_amt[index] - visible_y
	var old_y = visible_y
	visible_y = g.state_amt[index]
	
	for i in state_edits:
		state_edits[i].reload(null,state_difference)
	
	if state_difference > 0:
		for c in g.colour_amt:
			for s in visible_y:
				var a = Vector2i(c,s)
				var x = g.world.colour_state_rules[g.selected_ant][c][s]
				state_edits[a].show()
				state_edits[a].set_colour(x[0])
				state_edits[a].set_state(x[1])
				state_edits[a].set_rotate(x[2])
		for s in visible_y:
			main_labels.get_child(s).show()
	else:
		for c in g.colour_amt:
			for s in abs(state_difference):
				var a = Vector2i(c, old_y - s - 1)
				state_edits[a].hide()
		for c in g.colour_amt:
			for s in visible_y:
				var a = Vector2i(c,s)
				var x = g.world.colour_state_rules[g.selected_ant][c][s]
				state_edits[a].set_colour(x[0])
				state_edits[a].set_state(x[1])
				state_edits[a].set_rotate(x[2])
		for s in abs(state_difference):
			main_labels.get_child(old_y - s - 1).hide()
	
	main.custom_minimum_size = Vector2((visible_x)*GRID_SPACE.x, (visible_y)*GRID_SPACE.y)


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
	var index:int = g.selected_ant
	var c:Array = []
	c.resize(g.colour_amt)
	for i in g.colour_amt:
		c[i] = []
		c[i].resize(g.state_amt[index])
		for j in g.state_amt[index]:
			var state_edit = state_edits[Vector2i(i,j)]
			var r: PackedByteArray = [state_edit.get_colour(),state_edit.get_state(),state_edit.get_rotate()]
			c[i][j] = r
			
			
	#for i in state_edits:
		#c[i.x][i.y][0] = state_edits[i].get_colour()
		#c[i.x][i.y][1] = state_edits[i].get_state()
		#c[i.x][i.y][2] = state_edits[i].get_rotate()
	return c


func randomize_edits():
	if ant_select.selected >= 0:
		g.randomizing = true
		
		for i in state_edits:
			state_edits[i].get_child(0).select(randi()%g.colour_amt)
			state_edits[i].get_child(1).select(randi()%g.state_amt[g.selected_ant])
			state_edits[i].get_child(2).select(randi()%4)
		
		g.randomizing = false
		g.world.update_ant(ant_select.selected)


func randomize_to_states():
	if ant_select.selected >= 0:
		g.randomizing = true
		
		for i in state_edits:
			state_edits[i].get_child(1).select(randi()%g.state_amt[g.selected_ant])
		
		g.randomizing = false
		g.world.update_ant(ant_select.selected)


func randomize_to_colours():
	if ant_select.selected >= 0:
		g.randomizing = true
		
		for i in state_edits:
			state_edits[i].get_child(0).select(randi()%g.colour_amt)
		
		g.randomizing = false
		g.world.update_ant(ant_select.selected)


func randomize_rotate():
	if ant_select.selected >= 0:
		g.randomizing = true
		
		for i in state_edits:
			state_edits[i].get_child(2).select(randi()%4)
		
		g.randomizing = false
		g.world.update_ant(ant_select.selected)


func randomize_colours():
	pass


func _on_x_value_changed(value:int, update:bool = true):
	var x = value - value % g.sq_chunksize
	$TabCont/Grid/Grid/VBox/Basic/VBox/FieldSize/HBox/X.set_value_no_signal(max(x,g.sq_chunksize))
	g.field_x = x
	if update: 
		update_field()
		g.world.update_field(true)
		#if g.world.time_state != 0 and g.world.time_state != 1 and !g.world.loading: g.world.show_preview.call_deferred()


func _on_y_value_changed(value:int, update:bool = true):
	var y = value - value % g.sq_chunksize
	$TabCont/Grid/Grid/VBox/Basic/VBox/FieldSize/HBox/Y.set_value_no_signal(max(y,g.sq_chunksize))
	g.field_y = y
	if update: 
		update_field()
		g.world.update_field(true)
		#if g.world.time_state != 0 and g.world.time_state != 1 and !g.world.loading: g.world.show_preview.call_deferred()


func _on_amt_s_value_changed(value):
	g.world.update_state_amt(g.selected_ant,value)
	resize_grid(null,value)


func _on_amt_c_value_changed(value):
	var x = g.colour_amt
	g.colour_amt = value
	resize_grid(value-x)
	g.world.update_colour_amt(x)
	
	if value - x > 0:
		for i in value - x:
			$TabCont/Grid/Grid/VBox/Colours/VBox/Grid/GridContainer.get_child(x + i).show()
	elif value - x < 0:
		for i in abs(value - x):
			$TabCont/Grid/Grid/VBox/Colours/VBox/Grid/GridContainer.get_child(x - i - 1).hide()
	
	var min_size = 20 * int(value / $TabCont/Grid/Grid/VBox/Colours/VBox/Grid/GridContainer.columns)
	if int(value) % $TabCont/Grid/Grid/VBox/Colours/VBox/Grid/GridContainer.columns > 0: min_size += 16
	else: min_size -= 4
	
	$TabCont/Grid/Grid/VBox/Colours/VBox/Grid/GridContainer.custom_minimum_size.y = min_size
	$TabCont/Grid/Grid/VBox/Colours/VBox/Grid.custom_minimum_size.y = min_size
	$TabCont/Grid/Grid/VBox/Colours.custom_minimum_size.y = 88 + min_size + 8
	
	await get_tree().create_timer(0.05).timeout
	
	$TabCont/Grid/Grid/VBox.custom_minimum_size.y = $TabCont/Grid/Grid/VBox/Chunks.position.y + $TabCont/Grid/Grid/VBox/Chunks.size.y + 4

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


func _on_to_ant_states_pressed():
	randomize_to_states()


func _on_to_grid_states_pressed():
	randomize_to_colours()


func _on_rotation_pressed():
	randomize_rotate()


func get_selected_ant_id() -> int:
	return $TabCont/Ants/Select/HBox/AntChoose.get_selected_index()


func _on_tab_cont_tab_changed(tab):
	pass


func _on_ant_choose_item_selected(index):
	select_ant(index)


func select_ant(index):
	if index >= 0:
		var ant = g.world.ants[index]
		g.selected_ant = index
		
		$TabCont/Ants/Ants/VBox/Start/VBox/Position/HBox/X.set_value_no_signal(ant[4].x)
		$TabCont/Ants/Ants/VBox/Start/VBox/Position/HBox/Y.set_value_no_signal(ant[4].y)
		$TabCont/Ants/Ants/VBox/Start/VBox/Direction/Option.selected = ant[5]
		$TabCont/Ants/Ants/VBox/Rules/VBox/States/Num.set_value_no_signal(g.state_amt[index])
		$TabCont/Ants/Ants/VBox/Info/VBox/Colour/ColorPickerButton.color = ant[3]
		$TabCont/Ants/Ants/VBox/Info/VBox/Name/LineEdit.text = ant[6]
		$TabCont/Ants/Ants/VBox/Info/VBox/Visibility/ShowAnt.set_pressed_no_signal(g.world.field_ants.get_child(index).visible)
		
		$TabCont/Ants/Ants/VBox/Rules/VBox/RuleEdit/XY.show()
		$TabCont/Ants/Ants/VBox/Rules/VBox/RuleEdit/ScrollCont/Main/Edits.show()
		
		$TabCont/Ants/Ants/VBox/Info/VBox/Name/LineEdit.editable = true
		$TabCont/Ants/Ants/VBox/Info/VBox/Colour/ColorPickerButton.disabled = false
		$TabCont/Ants/Ants/VBox/Info/VBox/Visibility/ShowAnt.disabled = false
		
		$TabCont/Ants/Ants/VBox/Start/VBox/Direction/Option.disabled = false
		$TabCont/Ants/Ants/VBox/Start/VBox/Position/HBox/X.editable = true
		$TabCont/Ants/Ants/VBox/Start/VBox/Position/HBox/Y.editable = true
		
		$TabCont/Ants/Ants/VBox/Rules/VBox/States/Num.editable = true
		$TabCont/Ants/Ants/VBox/Rules/VBox/RandRow1/HBox/ToAll.disabled = false
		$TabCont/Ants/Ants/VBox/Rules/VBox/RandRow1/HBox/ToGStates.disabled = false
		$TabCont/Ants/Ants/VBox/Rules/VBox/RandRow2/HBox/Rotation.disabled = false
		$TabCont/Ants/Ants/VBox/Rules/VBox/RandRow2/HBox/ToAStates.disabled = false
		
		swap_grid(index)
	else:
		$TabCont/Ants/Ants/VBox/Start/VBox/Position/HBox/X.set_value_no_signal(0)
		$TabCont/Ants/Ants/VBox/Start/VBox/Position/HBox/Y.set_value_no_signal(0)
		$TabCont/Ants/Ants/VBox/Start/VBox/Direction/Option.selected = 0
		$TabCont/Ants/Ants/VBox/Rules/VBox/States/Num.set_value_no_signal(0)
		$TabCont/Ants/Ants/VBox/Info/VBox/Colour/ColorPickerButton.color = Color.TRANSPARENT
		$TabCont/Ants/Ants/VBox/Info/VBox/Name/LineEdit.text = ""
		$TabCont/Ants/Ants/VBox/Info/VBox/Visibility/ShowAnt.set_pressed_no_signal(false)
		
		$TabCont/Ants/Ants/VBox/Rules/VBox/RuleEdit/XY.hide()
		$TabCont/Ants/Ants/VBox/Rules/VBox/RuleEdit/ScrollCont/Main/Edits.hide()
		
		$TabCont/Ants/Ants/VBox/Info/VBox/Name/LineEdit.editable = false
		$TabCont/Ants/Ants/VBox/Info/VBox/Colour/ColorPickerButton.disabled = true
		$TabCont/Ants/Ants/VBox/Info/VBox/Visibility/ShowAnt.disabled = true
		
		$TabCont/Ants/Ants/VBox/Start/VBox/Direction/Option.disabled = true
		$TabCont/Ants/Ants/VBox/Start/VBox/Position/HBox/X.editable = false
		$TabCont/Ants/Ants/VBox/Start/VBox/Position/HBox/Y.editable = false
		
		$TabCont/Ants/Ants/VBox/Rules/VBox/States/Num.editable = false
		$TabCont/Ants/Ants/VBox/Rules/VBox/RandRow1/HBox/ToAll.disabled = true
		$TabCont/Ants/Ants/VBox/Rules/VBox/RandRow1/HBox/ToGStates.disabled = true
		$TabCont/Ants/Ants/VBox/Rules/VBox/RandRow2/HBox/Rotation.disabled = true
		$TabCont/Ants/Ants/VBox/Rules/VBox/RandRow2/HBox/ToAStates.disabled = true


func update_field():
	$TabCont/Ants/Ants/VBox/Start/VBox/Position/HBox/X.max_value = g.field_x - 1
	$TabCont/Ants/Ants/VBox/Start/VBox/Position/HBox/Y.max_value = g.field_y - 1
	$TabCont/Ants/Ants/VBox/Current/VBox/Position/HBox/X.max_value = g.field_x - 1
	$TabCont/Ants/Ants/VBox/Current/VBox/Position/HBox/Y.max_value = g.field_y - 1


func _on_new_ant_pressed():
	var x = g.world.new_ant()
	ant_select.select(x)
	select_ant(x)
	g.world.update_ant(x)


func _on_start_x_value_changed(value):
	g.world.ants[g.selected_ant][4].x = value
	g.world.reset_ant(g.selected_ant)


func _on_start_y_value_changed(value):
	g.world.ants[g.selected_ant][4].y = value
	g.world.reset_ant(g.selected_ant)


func _on_start_direction_changed(direction):
	g.world.ants[g.selected_ant][5] = direction
	g.world.reset_ant(g.selected_ant)
	if g.world.time_state != 0 and g.world.time_state != 1: g.world.show_preview()


func _on_color_picker_button_color_changed(color):
	g.world.set_ant_colour(g.selected_ant, color)


func _on_line_edit_text_submitted(new_text):
	g.world.ants[g.selected_ant][6] = new_text
	$TabCont/Ants/Select/HBox/AntChoose.set_item_text(g.selected_ant,new_text)
	$TabCont/Rand/Rand/VBox/Randomize/VBox/Which/WhichAnt.set_item_text(g.selected_ant+4,new_text)


func _on_show_ant_toggled(toggled_on):
	g.world.set_ant_visibility(g.selected_ant,toggled_on)


func _on_check_button_toggled(toggled_on):
	g.world.wrap_around = toggled_on
	if g.world.time_state == 1: $TabCont/Grid/Grid/VBox/Basic/VBox/WrapAround/CheckButton.disabled = true 


func _on_delete_ant_pressed():
	if g.world.ants.size() > 0:
		var index:int = g.selected_ant
		$TabCont/Ants/Select/HBox/AntChoose.remove_item(index)
		$TabCont/Rand/Rand/VBox/Randomize/VBox/Which/WhichAnt.remove_item(index+4)
		g.world.delete_ant(index)
		$TabCont/Rand/Rand/VBox/Randomize/VBox/Which/WhichAnt.selected = 0
		
		if index > 0: 
			$TabCont/Ants/Select/HBox/AntChoose.select(index-1)
			select_ant(index-1)
		else:
			if g.world.ants.size() > 0:
				$TabCont/Ants/Select/HBox/AntChoose.select(index)
				select_ant(index)
			else:
				select_ant(-1)
