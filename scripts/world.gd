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
@onready var chunk_parent = $Field/Chunks
var sq_chunk = preload("res://scenes/sq_chunk.tscn")
var queue = 0
var pq = 0
var ant_thread:Thread = Thread.new()
var field_thread:Thread = Thread.new()
var mutex:Mutex = Mutex.new()
var states:Dictionary = {} #chunk = [0,0,0,1,0,1...]
var chunks:Dictionary = {}
var images:Dictionary[Vector2i,Image] = {}
var updatequeue:Dictionary[Vector2i,bool] = {}
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
	
	print (250 >> 0x1F)
	print (250 / 32)

func resize():
	g.calc_pppp()
	resize_UI($Canvas/HSplit.split_offset)


func _process(delta):
	if time_state > 0:
		queue += (delta * tps)
	else:
		queue = 0
	$Canvas/HSplit/OnScreen/Turns.text = str(turns)
	
	mutex.lock()
	for a in ants:
		set_ant_preview_pos(a,ants[a][0]) #+ Vector2(0.5,0.5))
	for i in chunks.keys():
		chunks[i].texture.update(images[i])
	mutex.unlock()


func _physics_process(_delta):
	# calculate / display ticks per second + queue
	$Canvas/HSplit/OnScreen/Info.text = str(int(turns - pq))# + "\n" + str(int(queue))
	pq = turns
	if queue > (turns - pq): queue = turns - pq


func new_ant() -> int:
	var x = Sprite2D.new()
	x.texture = load("res://resources/sq/pixel.png")
	$Field/Ants.add_child(x)
	
	var id = 0
	while ants.has(id):
		id += 1
	print(id)
	x.name = str(id)
	
	ants[id] = [Vector2i(g.field_x/2,g.field_y/2),sq_dir.UP,0,Color.BLUE, Vector2i(g.field_x/2,g.field_y/2),sq_dir.UP,"ant"+str(id)]
	
	var rules = {}
	
	if g.colour_amt == 1:
		rules[Vector2i(0,0)] = [0,0,0]
	elif g.colour_amt >= 2:
		rules[Vector2i(0,0)] = [1,0,1]
		rules[Vector2i(1,0)] = [0,0,3]
		if g.colour_amt > 2:
			for c in g.colour_amt - 2:
				rules[Vector2i(c+2,0)] = [0,0,0]
	
	colour_state_rules[id] = rules
	
	set_ant_colour(id,Color.RED)
	ants[id][0] = ants[id][4]
	ants[id][1] = ants[id][5]
	
	g.state_amt[id] = 1
	
	$Canvas/HSplit/Sidebar.add_ant(id, "ant"+str(id))
	
	return id

func remove_ant(which):
	
	ants[which].erase()
	colour_state_rules[which].erase()
	g.state_amt[which] = 0
	pass

func get_default_multimesh(colour = Color.BLACK):
	var temp = sq_chunk.instantiate()
	temp.init_multimesh(colour)
	default_multimesh = temp.multimesh
	temp.queue_free()


func ant_ticks():
	
	var cs:int = g.sq_chunksize
	var csf:float = g.sq_chunksize
	var rules:Array
	var chunk:Vector2i
	var ant:Array
	var which:Vector2i
	
	while is_processing():
		if queue > 0:
			for a in ants:
				ant = ants[a]
				chunk = Vector2(ant[0]/csf).floor()
				
				# check if ant is out of bounds
				if !states.has(chunk):
					if wrap_around:
						if ant[0].x >= g.field_x: ant[0].x = 0
						elif ant[0].y >= g.field_y: ant[0].y = 0
						elif ant[0].x < 0: ant[0].x = g.field_x -1
						elif ant[0].y < 0: ant[0].y = g.field_y -1
						chunk = Vector2(ant[0]/csf).floor()
					else:
						new_chunk(chunk)
						if chunks.keys().size() >= 2000:
							_on_stop_pressed.call_deferred()
				
				which = ant[0] - chunk*cs + chunk.sign().clampi(-1,0)
				#updatequeue[chunk] = true
				
				#get rules for current ant and its position / state
				rules = colour_state_rules[a][Vector2i(states[chunk][which.x][which.y],ant[2])]
				
				# set tile colour
				states[chunk][which.x][which.y] = rules[0]
				mutex.lock()
				images[chunk].set_pixelv(which,colours[rules[0]])
				mutex.unlock()
				
				# update ant position / rotation
				ant[2] = rules[1]
				ant[1] = (ant[1] + rules[2]) & 0x3
				ant[0] = ant[0] + sq_move[ant[1]]
				
				turns = turns + 1
			queue = queue - 1


func get_instance_from_pos(pos) -> int:
	var x = Vector2i(pos.x%g.sq_chunksize,pos.y%g.sq_chunksize)
	var y = x.y * g.sq_chunksize + x.x
	return y


func update_ant(which):
	colour_state_rules[which] = $Canvas/HSplit/Sidebar.make_ant_from_edits()
	print ("ant: "+ str(which)+" has rules: "+str(colour_state_rules[which].keys()))


func update_colour_amt(old_amt:int):
	#adding or removing rules from colour_state_rules when colour amount changes
	var difference = g.colour_amt - old_amt
	
	if difference > 0:
		for i in colour_state_rules.keys():
			pass
			for c in difference:
				for s in g.state_amt[i]:
					colour_state_rules[i][Vector2i(old_amt+c,s)] = [0,0,0]
	else:
		for i in colour_state_rules.keys():
			pass
			for c in -difference:
				for s in g.state_amt[i]:
					colour_state_rules[i].erase(Vector2i(old_amt-c-1,s))
			for c in g.colour_amt:
				for s in g.state_amt[i]:
					if colour_state_rules[i][Vector2i(c,s)][0] > g.colour_amt-1: colour_state_rules[i][Vector2i(c,s)][0] = g.colour_amt-1


func update_state_amt(old_amt:int):
	var new_amt:int = g.state_amt[g.selected_ant]
	var difference:int = new_amt - old_amt
	if difference < 0:
		for c in g.colour_amt:
			for s in g.state_amt[g.selected_ant]:
				if colour_state_rules[g.selected_ant][Vector2i(c,s)][1] > new_amt-1: 
					colour_state_rules[g.selected_ant][Vector2i(c,s)][1] = new_amt-1


func reset_ant(which):
	ants[which][0] = ants[which][4]
	ants[which][1] = ants[which][5]
	ants[which][2] = 0


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
	set_process(false)
	time_state = 0
	queue = 0.0
	set_physics_process(false)
	
	$StopTimer.start()


func _on_forward_pressed():
	time_state = 1
	
	set_physics_process(true)
	set_process(true)
	
	clear = false
	$Canvas/HSplit/Sidebar.disable_elements()
	
	if !ant_thread.is_started(): 
		ant_thread.start(ant_ticks)


func _on_reverse_pressed():
	time_state = -1
	
	set_physics_process(true)
	set_process(true)
	
	if prev_state == 1: reverse_rules()
	prev_state = -1
	clear = false
	$Canvas/HSplit/Sidebar.disable_elements()
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
	set_physics_process(false)
	set_process(false)
	
	$StopTimer.start()
	time_state = -2
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
	$Canvas/HSplit/Sidebar.enable_elements()
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
	
	$Camera.position = (Vector2( (g.field_x - (int(($Canvas/HSplit.size.x / 2) + $Canvas/HSplit.split_offset))) ,g.field_y))/2 
	print((int(($Canvas/HSplit.size.x / 2) + $Canvas/HSplit.split_offset)))
	
	ants[0][0] = Vector2i(g.field_x,g.field_y)/2


func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			set_physics_process(true)
			if !ant_thread.is_started():
				ant_thread.start(ant_ticks)
		if event.keycode == KEY_Q:
			print("---")
			var i = get_global_mouse_position()
			var j = Vector2i(get_global_mouse_position()) % 32
			var k = Vector2i((get_global_mouse_position()/32).floor())
			print ( Vector2i(i) - k*32  +  k.sign().clampi(-1,0))
			print ( j )
			print ( k )


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
	var rand = str(randi())
	
	image.save_png("user://"+rand+".png")
	OS.shell_show_in_file_manager.call_deferred(ProjectSettings.globalize_path("user://"+rand+".png"))


func new_chunk(pos:Vector2i):
	#var new = sq_chunk.instantiate()
	var sprite = Sprite2D.new()
	var img = Image.create_empty(g.sq_chunksize,g.sq_chunksize,false,Image.FORMAT_L8)
	img.fill(colours[0])
	
	var texture = ImageTexture.create_from_image(img)
	sprite.texture = texture
	sprite.use_parent_material = true
	
	sprite.position = pos * g.sq_chunksize
	chunks[pos] = sprite
	images[pos] = img
	
	states[pos] = []
	states[pos].resize(g.sq_chunksize)
	for i in g.sq_chunksize:
		states[pos][i] = PackedByteArray()
		states[pos][i].resize(g.sq_chunksize)
	chunk_parent.add_child.call_deferred(sprite)


func resize_UI(offset):
	$Canvas/HSplit/Sidebar/TabCont/Ants/Ants.size.x = int(($Canvas/HSplit.size.x / 2) + offset) - 18
	$Canvas/HSplit/Sidebar/TabCont/Ants/Ants.size.y = $Canvas/HSplit.size.y-68-8
	$Canvas/HSplit/Sidebar/TabCont/Ants/Select/HBox.size.x = int(($Canvas/HSplit.size.x / 2) + offset) - 14
	
	$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox.size.x = int(($Canvas/HSplit.size.x / 2) + offset) - 10
	#$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox.size.y = max($Canvas/HSplit.size.y - 76,706)


func _on_h_split_dragged(offset):
	resize_UI(offset)


func set_ant_visibility(id:int, visibility:bool):
	$Field/Ants.get_node(str(id)).visible = visibility


func set_ant_preview_pos(id:int, pos:Vector2):
	$Field/Ants.get_node(str(id)).position = pos


func _on_stop_timer_timeout():
	if ant_thread.is_started(): ant_thread.wait_to_finish()
	print("stopped")
