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
var tps_goal:int = 100
var tps_act:int = 0
var previous_screen_size: Vector2i
var previous_delta:float


# MAIN
@onready var field = $Canvas/HSplit/OnScreen/Sim/SimViewport/Field
@onready var chunk_parent = $Canvas/HSplit/OnScreen/Sim/SimViewport/Field/Chunks
@onready var field_ants = $Canvas/HSplit/OnScreen/Sim/AntViewport/Ants
@onready var shader_node = $Canvas/HSplit/OnScreen/Sim/SimViewport/Layer/Shader
var queue = 0
var pq = 0 #previous queue
var ant_thread:Thread = Thread.new()
var field_thread:Thread = Thread.new()
var screenshot_thread:Thread = Thread.new()
var mutex:Mutex = Mutex.new()
var chunks:Dictionary[Vector2i,Array] = {} # [Sprite2d, Image, imagedata(packedbytearray)
var updatequeue:Dictionary[Vector2i,bool] = {}
var update_frequency:int = 1
var request_update:bool = false

# RULES
var l8_colours:PackedColorArray = []
var colour_state_rules:Array = [] #[ant][col][state][rule (to_colour = 0, to_state = 1, rotation = 2)]
var ants:Array = [] #2d array[ant][ant position, ant direction, ant state, colour on grid, start position, start direction, name]

func _ready():
	l8_colours.resize(64)
	for i in 64:
		var c = i*4
		l8_colours[i] = Color.from_rgba8(c,c,c)
	
	RenderingServer.set_default_clear_color(g.user_pallete.get_pixel(0,0))
	
	g.ant_camera = $Canvas/HSplit/OnScreen/Sim/AntViewport/Camera
	g.world = self
	set_physics_process(false)
	set_process(false)
	
	Engine.physics_ticks_per_second = 1
	Engine.max_physics_steps_per_frame = 100
	
	get_window().size = Vector2i(1000,640)
	get_window().position = Vector2(2000,200)
	
	get_tree().get_root().size_changed.connect(resize)
	
	for r in int(g.field_x / g.sq_chunksize): 
		for c in int(g.field_y / g.sq_chunksize): 
			new_chunk(Vector2i(c,r))
	
	new_ant()
	
	_on_h_split_dragged($Canvas/HSplit.split_offset)
	
	$Canvas/HSplit/OnScreen/Sim/AntViewport/Ants.position = Vector2(0.5,0.5)
	
	#shader.set("user_pallete", g.user_pallete)
	
	$Canvas/HSplit/OnScreen/Sim/SimViewport/Layer/Shader.material.set_shader_parameter("user_pallete",ImageTexture.create_from_image(g.user_pallete))
	
	$CsNode.Start()


func resize():
	g.calc_pppp()
	resize_UI($Canvas/HSplit.split_offset)


func _process(delta):
	if time_state > 0:
		queue += delta * tps_goal
	else:
		queue = 0
	$Canvas/HSplit/OnScreen/Turns.text = str(turns) + " turns"
	
	mutex.lock()
	update_frequency = max(delta * tps_act,1)
	previous_delta = delta
	if $Canvas/HSplit/Sidebar/TabCont.get_current_tab_control().name == "Ants":
		$Canvas/HSplit/Sidebar/TabCont/Ants/Ants/VBox/Current.update()
	for a in ants.size():
		set_ant_preview_pos(a,ants[a][0]) #+ Vector2(0.5,0.5))
	for i in updatequeue.keys():
		var data = chunks[i]
		data[1].set_data(64,64,false,Image.FORMAT_L8,data[2])
		data[0].texture.update(data[1])
	updatequeue.clear()
	mutex.unlock()


func _physics_process(_delta):
	pass
	

func new_ant() -> int:
	mutex.lock()
	ants.resize(ants.size()+1)
	colour_state_rules.resize(ants.size())
	var x = Sprite2D.new()
	x.texture = load("res://resources/sq/pixel.png")
	field_ants.add_child(x)
	
	var id = ants.size()-1
	
	var name_check = "Ant "+str(id)
	var name_used = true
	var i:int = 2
	if ants.size() > 1:
		while name_used:
			name_used = false
			for a in ants.size()-1:
				if ants[a][6] == name_check:
					name_used = true
					name_check = "Ant "+str(id) + " ("+str(i)+")"
					i += 1
	
	#default ant data
	ants[id] = [Vector2i(g.field_x/2,g.field_y/2),sq_dir.UP,0,Color.BLUE, Vector2i(g.field_x/2,g.field_y/2),sq_dir.UP,name_check]
	x.position = ants[id][0]
	
	colour_state_rules[id] = []
	colour_state_rules[id].resize(64)
	for c in 64:
		colour_state_rules[id][c] = []
		colour_state_rules[id][c].resize(64)
		for s in 64:
			var z: PackedByteArray = [0,0,0]
			colour_state_rules[id][c][s] = z
	
	if g.colour_amt == 1:
		colour_state_rules[id][0][0] = [0,0,0]
	elif g.colour_amt >= 2:
		colour_state_rules[id][0][0] = [1,0,1]
		colour_state_rules[id][1][0] = [0,0,3]
		if g.colour_amt > 2:
			for c in g.colour_amt - 2:
				colour_state_rules[id][c][0] = [0,0,0]
	
	set_ant_colour(id,Color.RED)
	ants[id][0] = ants[id][4]
	ants[id][1] = ants[id][5]
	
	g.state_amt[id] = 1
	
	$Canvas/HSplit/Sidebar.add_ant(id, name_check)
	
	mutex.unlock()
	return id


func remove_ant(which):
	ants[which].erase()
	colour_state_rules[which].erase()
	g.state_amt[which] = 0


func ant_ticks():
	var cs:int = g.sq_chunksize
	var csf:float = g.sq_chunksize
	var field_x:int = g.field_x
	var field_y:int = g.field_y
	var rules:PackedByteArray
	var chunk:Vector2i
	var ant:Array
	var which1d:int
	var pos:Vector2i
	var localupdate:Dictionary = {}
	var chunk_data:PackedByteArray
	
	while is_processing():
		while queue > 1.0:
			for a in ants.size():
				ant = ants[a]
				pos = ant[0]
				chunk = Vector2(pos/csf).floor()
				# check if ant is out of bounds
				if !chunks.has(chunk):
					if wrap_around:
						if ant[0].x >= field_x: ant[0].x = 0
						elif ant[0].y >= field_y: ant[0].y = 0
						elif ant[0].x < 0: ant[0].x = field_x -1
						elif ant[0].y < 0: ant[0].y = field_y -1
						pos = ant[0]
						chunk = pos/cs
						
					else:
						chunk = Vector2(pos/csf).floor()
						pos = ant[0]
						new_chunk(chunk)
						if chunks.keys().size() == 2000:
							_on_stop_pressed.call_deferred()
				
				#get rules from grid state and ant state
				which1d = (pos.x - chunk.x * cs) + (pos.y - chunk.y * cs) * cs
				chunk_data = chunks[chunk][2]
				rules = colour_state_rules[a][chunk_data[which1d] >> 2][ant[2]]
				
				# set tile colour
				localupdate[chunk] = true
				chunk_data[which1d] = rules[0] << 2
				
				# update ant position / rotation / state
				ant[2] = rules[1]
				ant[1] = (ant[1] + rules[2]) & 0x3
				ant[0] = pos + sq_move[ant[1]]
				
				turns = turns + 1
				
				mutex.lock()
				if turns % update_frequency == 0:
					for i in localupdate.keys():
						updatequeue[i] = true
					localupdate.clear()
				mutex.unlock()
			queue = queue - 1.0

func update_ant(which):
	mutex.lock()
	colour_state_rules[which] = $Canvas/HSplit/Sidebar.make_ant_from_edits()
	mutex.unlock()


func update_colour_amt(old_amt:int):
	mutex.lock()
	#adding or removing rules from colour_state_rules when colour amount changes
	var difference = g.colour_amt - old_amt
	if difference > 0:
		pass
		#for a in ants.size():
			#for c in difference:
				#for s in g.state_amt[a]:
					#colour_state_rules[a][old_amt+c][s] = [0,0,0]
	else:
		for a in ants.size():
			for c in -difference:
				for s in g.state_amt[a]:
					colour_state_rules[a][old_amt-c-1][s] = [0,0,0]
			for c in g.colour_amt:
				for s in g.state_amt[a]:
					if colour_state_rules[a][c][s][0] > g.colour_amt-1: colour_state_rules[a][c][s][0] = g.colour_amt-1
	colour_state_rules[g.selected_ant] = $Canvas/HSplit/Sidebar.make_ant_from_edits()
	mutex.unlock()


func update_state_amt(old_amt:int):
	mutex.lock()
	var new_amt:int = g.state_amt[g.selected_ant]
	var difference:int = new_amt - old_amt
	if difference < 0:
		for c in g.colour_amt:
			for s in g.state_amt[g.selected_ant]:
				if colour_state_rules[g.selected_ant][c][s][1] > new_amt-1: 
					colour_state_rules[g.selected_ant][c][s][1] = new_amt-1
	colour_state_rules[g.selected_ant] = $Canvas/HSplit/Sidebar.make_ant_from_edits()
	if ants[g.selected_ant][2] > g.state_amt[g.selected_ant]-1: 
		ants[g.selected_ant][2] = g.state_amt[g.selected_ant]-1
	mutex.unlock()


func reset_ant(which:int):
	ants[which][0] = ants[which][4]
	ants[which][1] = ants[which][5]
	ants[which][2] = 0


func set_ant_colour(which:int, colour:Color):
	ants[which][3] = colour
	field_ants.get_child(which).modulate = colour


func update_colours(index,colour):
	g.user_pallete.set_pixel(0,index,colour)
	print("index = " + str(index) + ", col = " + str(colour))
	var texture = ImageTexture.create_from_image(g.user_pallete)
	shader_node.material.set_shader_parameter("user_pallete",texture)


func _on_stop_pressed():
	mutex.lock()
	set_process(false)
	time_state = 0
	queue = 0.0
	set_physics_process(false)
	mutex.unlock()
	
	stop2.call_deferred()


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
	update_frequency = max(previous_delta * value,1)
	tps_act = value
	tps_goal = value
	$Canvas/HSplit/OnScreen/Tools/HBox/TPS.text = str(int(value))
	mutex.lock()
	queue = 0
	mutex.unlock()


func _on_clear_pressed():
	mutex.lock()
	set_process(false)
	time_state = -2
	queue = 0.0
	set_physics_process(false)
	mutex.unlock()
	
	clear2.call_deferred()

func update_field():
	chunks.clear()
	
	for c in field.get_node("Chunks").get_children():
		c.free()
	
	g.downmost_chunk = Vector2i(0,g.field_y/g.sq_chunksize-1)
	g.rightmost_chunk = Vector2i(g.field_x/g.sq_chunksize-1,0)
	
	for r in int(g.field_y / g.sq_chunksize): 
		for c in int(g.field_x / g.sq_chunksize): 
			new_chunk(Vector2i(c,r))
	print($Canvas/HSplit/OnScreen/Sim/SimViewport/Camera.position)
	print($Canvas/HSplit/OnScreen/Sim/AntViewport/Camera.position)
	$Canvas/HSplit/OnScreen/Sim/SimViewport/Camera.position = (Vector2(g.field_x,g.field_y))/2
	$Canvas/HSplit/OnScreen/Sim/AntViewport/Camera.position = $Canvas/HSplit/OnScreen/Sim/SimViewport/Camera.position
	
	
	ants[0][0] = Vector2i(g.field_x,g.field_y)/2


func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			set_physics_process(true)
			if !ant_thread.is_started():
				ant_thread.start(ant_ticks)
		if event.keycode == KEY_Q:
			pass

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
	var image = Image.create_empty(rect.size.x*g.sq_chunksize,rect.size.y*g.sq_chunksize,false,Image.FORMAT_RGBA8)
	var pos
	var offset = rect.position
	
	for c in chunks.keys():
		for x in g.sq_chunksize:
			for y in g.sq_chunksize:
				pos = Vector2i(x,y)
				image.set_pixelv((c-offset)*g.sq_chunksize + pos,g.user_pallete.get_pixel(0,chunks[c][1].get_pixelv(pos).r8 >> 2))
	var rand = str(randi())
	#images[chunk].get_pixelv(which).r8 >> 2,ant[2]
	
	image.save_png("user://"+rand+".png")
	OS.shell_show_in_file_manager.call_deferred(ProjectSettings.globalize_path("user://"+rand+".png"))


func new_chunk(pos:Vector2i):
	pass
	mutex.lock()
	
	var sprite = Sprite2D.new()
	var img = Image.create_empty(g.sq_chunksize,g.sq_chunksize,false,Image.FORMAT_L8)
	var texture = ImageTexture.create_from_image(img)
	
	sprite.texture = texture
	sprite.use_parent_material = true
	sprite.position = pos * g.sq_chunksize
	
	var data: PackedByteArray = img.get_data()
	
	chunks[pos] = [sprite,img,data]
	chunk_parent.add_child.call_deferred(sprite)
	
	mutex.unlock()


func resize_UI(offset):
	$Canvas/HSplit/Sidebar/TabCont/Ants/Ants.size.x = int(($Canvas/HSplit.size.x / 2) + offset) - 18
	$Canvas/HSplit/Sidebar/TabCont/Ants/Ants.size.y = $Canvas/HSplit.size.y-68-8
	$Canvas/HSplit/Sidebar/TabCont/Ants/Select/HBox.size.x = int(($Canvas/HSplit.size.x / 2) + offset) - 14
	
	$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox.size.x = int(($Canvas/HSplit.size.x / 2) + offset) - 10
	
	$Canvas/HSplit/OnScreen/Sim/SimViewport.size_2d_override = $Canvas/HSplit/OnScreen/Sim.size


func _on_h_split_dragged(offset):
	resize_UI(offset)


func set_ant_visibility(index:int, visibility:bool):
	field_ants.get_child(index).visible = visibility


func set_ant_preview_pos(index:int, pos:Vector2):
	field_ants.get_child(index).position = pos


func stop2():
	mutex.lock()
	if ant_thread.is_started(): ant_thread.wait_to_finish()
	$Canvas/HSplit/Sidebar.enable_elements()
	print("stopped")
	mutex.unlock()


func delete_ant(id:int):
	mutex.lock()
	ants.remove_at(id)
	colour_state_rules.remove_at(id)
	$Canvas/HSplit/OnScreen/Sim/AntViewport/Ants.remove_child($Canvas/HSplit/OnScreen/Sim/AntViewport/Ants.get_children(false)[id])
	mutex.unlock()


func move_ant_index(index_from:int, intex_to:int):
	pass


func _on_second_timer_timeout():
	tps_act = int(turns - pq)
	$Canvas/HSplit/OnScreen/Info.text = str(tps_act) + " tps"
	pq = turns
	if previous_screen_size != get_viewport().size: 
		previous_screen_size = get_viewport().size
		resize_UI($Canvas/HSplit.split_offset)
	if queue > tps_goal: queue = tps_goal

func clear2(): #part 2 of clearing the board. all the stuff thats call deferred
	if ant_thread.is_started(): ant_thread.wait_to_finish()
	
	mutex.lock() #i dont think i need this but just in case?
	chunks.clear()
	updatequeue.clear()
	update_field()
	
	if prev_state == -1:
		prev_state = 1
		reverse_rules()
	
	for ant in ants.size():
		reset_ant(ant)
	
	turns = 0
	$Canvas/HSplit/Sidebar.enable_elements()
	clear = true
	
	for a in ants.size():
		var ant = ants[a]
		field_ants.get_child(a).position = ant[0]
	
	$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Colours/VBox/Colours/Colours.min_value = 1
	mutex.unlock() #i dont think i need this but just in case?
