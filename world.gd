extends Node2D

# DIRECTIONS
enum sq_dir { UP, RIGHT, DOWN, LEFT }
enum hx_dir { UP, RIGHT2, RIGHT1, BACK, LEFT1, LEFT2 }
enum tr_dir { LEFT, RIGHT, BACK }
var sq_move:Array = [
	Vector2i(0,-1),
	Vector2i(1,0),
	Vector2i(0,1),
	Vector2i(-1,0)
	]

# UI
var play:bool = true
var turns:int = 0
var wrap_around:bool = true
var ant_states:int = 1
var time_state:int = -2 #-2:clear, -1:reverse(unused for now?), 0:paused, 1:forward
var prev_state:int = 1
var clear:bool = true
var tps:int = 100

# MAIN
@onready var field = $Field
var sq_chunk = preload("res://sq_chunk.tscn")
var queue = 0
var pq = 0
var ant_thread:Thread = Thread.new()
var field_thread:Thread = Thread.new()
var states:Dictionary = {} #chunk = [0,0,0,1,0,1...]
var chunks:Dictionary = {}
var default_multimesh

# RULES
var colours:Dictionary = {
	0: Color.BLACK,
	1: Color.WHITE 
	}
var colour_state_rules:Dictionary = {} #Vector2i(colour,ant_state): [to_colour, to_state, rotation]
var ants:Dictionary = {} #[ant position, ant direction, ant state, colour on grid, start position, start direction, name]


func _ready():
	RenderingServer.set_default_clear_color(colours[0])
	
	g.world = self
	set_physics_process(false)
	set_process(false)
	
	Engine.physics_ticks_per_second = 1
	Engine.max_physics_steps_per_frame = 100
	
	get_window().size = Vector2i(1000,640)
	get_window().position = Vector2(2000,200)
	
	get_tree().get_root().size_changed.connect(resize)
	
	get_default_multimesh()
	
	for r in int(g.field_x / g.sq_chunksize): 
		for c in int(g.field_y / g.sq_chunksize): 
			new_chunk(Vector2i(c,r))
	
	new_ant()
	
	_on_h_split_dragged($Canvas/HSplit.split_offset)
	print(ants)


func resize():
	g.calc_pppp()
	resize_UI($Canvas/HSplit.split_offset)


func _process(delta):
	queue += (delta * tps)
	$Canvas/HSplit/OnScreen/Turns.text = str(turns)
	
	for a in ants:
		set_ant_preview_pos.call_deferred(a,ants[a][0]*16 + Vector2i(8,8))


func _physics_process(_delta):
	# calculate / display ticks per second + queue
	$Canvas/HSplit/OnScreen/Info.text = str(int(turns - pq))# + "\n" + str(int(queue))
	pq = turns
	if queue > (turns - pq): queue = turns - pq


func new_ant() -> int:
	var x = Sprite2D.new()
	x.texture = load("res://sq/square.png")
	$Field/Ants.add_child(x)
	
	var id = 0
	while ants.has(id):
		id += 1
	print(id)
	x.name = str(id)
	
	ants[id] = [Vector2i(g.field_x/2,g.field_y/2),sq_dir.UP,0,Color.BLUE, Vector2i(g.field_x/2,g.field_y/2),sq_dir.UP,"ant"+str(id)]
	colour_state_rules[id] = { 
		Vector2i(0,0): [1,0,1],
		Vector2i(1,0): [0,0,3]}
	
	set_ant_colour(id,Color.RED)
	ants[id][0] = ants[id][4]
	ants[id][1] = ants[id][5]
	
	g.state_amt.insert(id,1)
	
	$Canvas/HSplit/RuleEdit.add_ant(id, "ant"+str(id))
	
	return id


func get_default_multimesh(colour = Color.BLACK):
	var temp = sq_chunk.instantiate()
	temp.init_multimesh(colour)
	default_multimesh = temp.multimesh
	temp.queue_free()


func ant_ticks():
	var cs:int = g.sq_chunksize
	var csf:float = g.sq_chunksize
	var z:Vector2i
	var chunk:Vector2i
	var chunkf:Vector2
	var ant:Array
	var which:int
	
	while is_physics_processing():
		if queue > 0:
			for a in ants:
				ant = ants[a]
				chunk = ant[0]
				chunkf = ant[0]
				chunk.x = floori(chunkf.x/csf)
				chunk.y = floori(chunkf.y/csf)
				which = ant[0].x % cs + ant[0].y % cs * cs
				z = Vector2i(states[chunk][which],ant[2])
				
				# set tile colour
				states[chunk][which] = colour_state_rules[a][z][0]
				chunks[chunk].multimesh.set_instance_color(which,colours[states[chunk][which]])
				
				# update ant position / rotation
				ant[2] = colour_state_rules[a][z][1]
				ant[1] = (ant[1] + colour_state_rules[a][z][2]) % 4
				ant[0] = ant[0] + sq_move[ant[1]% 4]
				
				# check if ant is out of bounds
				chunk = ant[0]
				chunk.x = floori(chunk.x/csf)
				chunk.y = floori(chunk.y/csf)
				if !states.has(chunk):
					if wrap_around:
						if ant[0].x >= g.field_x: ant[0].x = 0
						elif ant[0].y >= g.field_y: ant[0].y = 0
						elif ant[0].x < 0: ant[0].x = g.field_x -1
						elif ant[0].y < 0: ant[0].y = g.field_y -1
					else:
						new_chunk(chunk)
						if chunks.keys().size() >= 2000:
							_on_stop_pressed.call_deferred()
				
				turns = turns + 1
			queue = queue - 1


func move_ant(ant):
	match ant[1]:
		0:ant[0].y -= 1
		1:ant[0].x += 1
		2:ant[0].y += 1
		3:ant[0].x -= 1
	if ant[0].x >= g.field_x: ant[0].x = 0
	elif  ant[0].y >= g.field_y: ant[0].y = 0
	elif  ant[0].x < 0: ant[0].x = g.field_x -1
	elif ant[0].y < 0: ant[0].y = g.field_y -1


func get_instance_from_pos(pos) -> int:
	var x = Vector2i(pos.x%g.sq_chunksize,pos.y%g.sq_chunksize)
	var y = x.y * g.sq_chunksize + x.x
	return y


func update_ant(which):
	colour_state_rules[which] = $Canvas/HSplit/RuleEdit.make_ant_from_edits()


func reset_ant(which):
	ants[which][0] = ants[which][4]
	ants[which][1] = ants[which][5]


func set_ant_colour(which:int, colour:Color):
	ants[which][3] = colour
	$Field/Ants.get_node(str(which)).modulate = colour


func update_colours(index,colour):
	colours[index] = colour
	if index == 0:
		RenderingServer.set_default_clear_color(colour)
		get_default_multimesh(colour)
		for chunk in chunks:
			chunks[chunk].multimesh = default_multimesh.duplicate()


func _on_stop_pressed():
	time_state = 0
	set_physics_process(false)
	set_process(false)
	ant_thread.wait_to_finish()


func _on_forward_pressed():
	time_state = 1
	
	set_physics_process(true)
	set_process(true)
	
	clear = false
	$Canvas/HSplit/RuleEdit.disable_elements()
	
	if !ant_thread.is_started(): 
		ant_thread.start(ant_ticks)


func _on_reverse_pressed():
	time_state = -1
	
	set_physics_process(true)
	set_process(true)
	
	if prev_state == 1: reverse_rules()
	prev_state = -1
	clear = false
	$Canvas/HSplit/RuleEdit.disable_elements()
	if !ant_thread.is_started(): 
		ant_thread.start(ant_ticks)


func reverse_rules() -> void:
	pass
	#TODO
	# idk if its possible, but it shuold be possible to reverse time by reversing the ant rules somehow?


func _on_h_slider_value_changed(value):
	tps = value
	$Canvas/HSplit/OnScreen/HBox/TPS.text = str(int(value))


func _on_clear_pressed():
	time_state = -2
	set_physics_process(false)
	set_process(false)
	if ant_thread.is_started(): ant_thread.wait_to_finish()
	
	chunks.clear()
	update_field()
	
	for chunk in chunks:
		chunks[chunk].multimesh = default_multimesh.duplicate()
		for ci in g.sq_chunksize * g.sq_chunksize:
			states[chunk][ci] = 0
	
	if prev_state == -1:
		prev_state = 1
		reverse_rules()
	
	for ant in ants:
		reset_ant(ant)
	
	turns = 0
	$Canvas/HSplit/RuleEdit.enable_elements()
	clear = true
	
	for a in ants:
		var ant = ants[a]
		$Field/Ants.get_node(str(a)).position = ant[0]*16 + Vector2i(8,8)


func update_field():
	chunks.clear()
	states.clear()
	
	for c in field.get_node("Chunks").get_children():
		c.free()
	
	for r in int(g.field_y / g.sq_chunksize): 
		for c in int(g.field_x / g.sq_chunksize): 
			new_chunk(Vector2i(c,r))
	
	$Camera.position = (Vector2( (g.field_x*16 - (int(($Canvas/HSplit.size.x / 2) + $Canvas/HSplit.split_offset))*(16)) ,g.field_y*16))/2 
	print((int(($Canvas/HSplit.size.x / 2) + $Canvas/HSplit.split_offset)))
	
	ants[0][0] = Vector2i(g.field_x,g.field_y)/2


func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			set_physics_process(true)
			if !ant_thread.is_started():
				ant_thread.start(ant_ticks)
		if event.keycode == KEY_Q:
			print (Vector2(floor(get_global_mouse_position().x/800), floor(get_global_mouse_position().y/800) ))
			print(get_global_mouse_position()/16)
			print("aa")


func get_screenshot_rect() -> Rect2i:
	var bounds = [0,0,0,0] #-x +x -y +y
	
	for i in chunks:
		if i.x < bounds[0]: bounds[0] = i.x
		if i.x > bounds[1]: bounds[1] = i.x 
		if i.y < bounds[2]: bounds[2] = i.y
		if i.y > bounds[3]: bounds[3] = i.y
	
	return Rect2i(bounds[0],bounds[2],bounds[1]-bounds[0]+1,bounds[3]-bounds[2]+1)


func _on_screenshot_pressed():
	var rect = get_screenshot_rect()
	var image = Image.create_empty(rect.size.x*g.sq_chunksize,rect.size.y*g.sq_chunksize,false,Image.FORMAT_RGB8)
	
	for y in rect.size.y*g.sq_chunksize:
		for x in rect.size.x*g.sq_chunksize:
			var pos = Vector2i(x,y)
			if states.has(pos + (rect.position*g.sq_chunksize)): image.set_pixel(x,y,colours[states[pos+(rect.position*g.sq_chunksize)][0]])
			else:image.set_pixel(x,y,colours[0])
	
	image.save_png("user://"+str(randi())+".png")


func new_chunk(pos:Vector2i):
	var new = sq_chunk.instantiate()
	new.multimesh = default_multimesh.duplicate()
	new.position = pos * g.sq_chunksize * 16
	chunks[pos] = new
	states[pos] = PackedByteArray()
	states[pos].resize(g.sq_chunksize*g.sq_chunksize)
	field.get_node("Chunks").add_child.call_deferred(new)


func resize_UI(offset):
	$Canvas/HSplit/RuleEdit/TabCont/Ants/Ants.size.x = int(($Canvas/HSplit.size.x / 2) + offset) - 18
	$Canvas/HSplit/RuleEdit/TabCont/Ants/Ants.size.y = max($Canvas/HSplit.size.y,706)
	$Canvas/HSplit/RuleEdit/TabCont/Ants/Select/HBox.size.x = int(($Canvas/HSplit.size.x / 2) + offset) - 14
	
	$Canvas/HSplit/RuleEdit/TabCont/Field/Field/VBox.size.x = int(($Canvas/HSplit.size.x / 2) + offset) - 10
	$Canvas/HSplit/RuleEdit/TabCont/Field/Field/VBox.size.y = max($Canvas/HSplit.size.y - 76,706)


func _on_h_split_dragged(offset):
	resize_UI(offset)


func set_ant_visibility(id, is_visible):
	$Field/Ants.get_node(str(id)).visible = is_visible


func set_ant_preview_pos(id, pos):
	$Field/Ants.get_node(str(id)).position = pos
