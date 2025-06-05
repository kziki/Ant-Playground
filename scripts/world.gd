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
var ticks:int = 0
var wrap_around:bool = true
var ant_states:int = 1
var time_state:int = -2 #-2:clear, -1:reverse(unused for now?), 0:paused, 1:forward 2: previewing
var prev_state:int = 1
var clear:bool = true
var tps_goal:int = 100
var tps_act:int = 0
var previous_screen_size: Vector2i
var previous_delta:float
var smoothed:bool = false
var do_chunk_limit:bool = true
var chunk_limit:int = 20000
var preview_grid:bool = true
var loading:bool = true


# MAIN
@onready var field = $Canvas/HSplit/OnScreen/Sim/SimViewport/Field
@onready var sim_chunk_parent = $Canvas/HSplit/OnScreen/Sim/SimViewport/Field/SimChunks
@onready var field_ants = $Canvas/HSplit/OnScreen/Sim/AntViewport/Ants
@onready var shader_node = $Canvas/HSplit/OnScreen/Sim/SimViewport/Layer/Shader
var queue:float = 0
var pq = 0 #previous queue
var ant_thread:Thread = Thread.new() #thread for ant ticks
var preview_thread:Thread = Thread.new() #thread for preview ant ticks
var screenshot_thread:Thread = Thread.new() #thread for saving a screenshot (unused for now)
var mutex:Mutex = Mutex.new()
var chunks:Dictionary[Vector2i,Array] = {} # [Sprite2d, Image, imagedata(packedbytearray)
var preview_chunks:Dictionary[Vector2i,Array] = {} # ^^
var updatequeue:Dictionary[Vector2i,bool] = {}
var update_frequency:int = 1
var request_update:bool = false

# RULES
var colour_state_rules:Array = [] #[ant][col][state][rule (to_colour = 0, to_state = 1, rotation = 2)]
var ants:Array = [] #2d array[ant][ant position, ant direction, ant state, colour on grid, start position, start direction, name]


func _ready():
	print(ants)
	RenderingServer.set_default_clear_color(g.user_pallete.get_pixel(0,0))
	
	g.ant_camera = $Canvas/HSplit/OnScreen/Sim/AntViewport/Camera
	g.world = self
	set_physics_process(false)
	#set_process(false)
	
	Engine.physics_ticks_per_second = 1
	Engine.max_physics_steps_per_frame = 100
	
	get_window().size = Vector2i(1000,640)
	get_window().position = Vector2(2000,200)
	
	get_tree().get_root().size_changed.connect(resize)
	
	update_field()
	
	new_ant()
	
	_on_h_split_dragged($Canvas/HSplit.split_offset)
	
	$Canvas/HSplit/OnScreen/Sim/AntViewport/Ants.position = Vector2(0.5,0.5)
	
	$Canvas/HSplit/OnScreen/Sim/SimViewport/Layer/Shader.material.set_shader_parameter("user_pallete",ImageTexture.create_from_image(g.user_pallete))
	$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Chunks/VBox/Limit/Label.modulate = Color.WHITE
	$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Chunks/VBox/Limit/ChunkLimit.value = 20000
	
	$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Colours/VBox/Colours/Colours.max_value = g.max_colours
	$Canvas/HSplit/Sidebar/TabCont/Ants/Ants/VBox/Rules/VBox/States/Num.max_value = g.max_states
	
	$Canvas/HSplit/OnScreen/Sim/SimViewport/Field/SimChunks.position = Vector2.ONE * g.sq_chunksize / 2
	
	
	$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Colours/VBox/Grid/GridContainer.set_deferred("columns",2)
	
	$Canvas/HSplit.set_deferred("split_offset",-200)
	
	$CsNode.Start()
	
	set_deferred("loading",false)
	print(ants)
	show_preview.call_deferred()
	print(ants)


func resize():
	g.calc_pppp()
	resize_UI($Canvas/HSplit.split_offset)


func _process(delta):
	if time_state > 0:
		queue += delta * tps_goal
	else:
		queue = 0
	$Canvas/HSplit/OnScreen/TickInfo/TotalTicks.text = " " + str(ticks) + " ticks "
	
	mutex.lock()
	if $Canvas/HSplit/Sidebar/TabCont.get_current_tab_control().name == "Ants":
		$Canvas/HSplit/Sidebar/TabCont/Ants/Ants/VBox/Current.update()
	for a in ants.size():
		set_ant_preview_pos(a,ants[a][0]) #+ Vector2(0.5,0.5))
	for i in updatequeue.keys():
		var data = chunks[i]
		data[1].set_data(g.sq_chunksize,g.sq_chunksize,false,Image.FORMAT_L8,data[2])
		data[0].texture.update(data[1])
	updatequeue.clear()
	mutex.unlock()


func _on_second_timer_timeout():
	#print($Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Colours/VBox/Grid/GridContainer.columns)
	#print($Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Colours/VBox/Grid.size.x)
	tps_act = int(ticks - pq)
	$Canvas/HSplit/OnScreen/TickInfo/TPS.text = " " + str(tps_act) + " tps   "
	pq = ticks
	if previous_screen_size != get_viewport().size: 
		previous_screen_size = get_viewport().size
		resize_UI($Canvas/HSplit.split_offset)
	if queue > tps_goal: queue = tps_goal
	
	mutex.lock()
	if $Canvas/HSplit/Sidebar/TabCont.get_current_tab_control().name == "Grid":
		$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Chunks/VBox/Info/Label.text = "Current chunk count: " + str(chunks.keys().size()) + "\nMemory usage: " + str(OS.get_static_memory_usage() / 1000000) + "mb"
	mutex.unlock()
	#print(OS.get_static_memory_usage() / 1000000)


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
	colour_state_rules[id].resize(g.max_colours)
	for c in g.max_colours:
		colour_state_rules[id][c] = []
		colour_state_rules[id][c].resize(g.max_states)
		for s in g.max_states:
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
	
	set_ant_colour(id,Color(1,0,0,0.75))
	ants[id][0] = ants[id][4]
	ants[id][1] = ants[id][5]
	
	g.state_amt[id] = 1
	
	$Canvas/HSplit/Sidebar.add_ant(id, name_check)
	
	mutex.unlock()
	return id


func ant_ticks():
	print("ticking!!")
	var cs:int = g.sq_chunksize
	var csf:float = g.sq_chunksize
	var field_x:int = g.field_x
	var field_y:int = g.field_y
	var rules:PackedByteArray
	var chunk:Vector2i
	var ant:Array
	var which1d:int
	var pos:Vector2i
	var chunk_data:PackedByteArray
	var chunkslocal = chunks
	while time_state > 0:
		while queue > 1.0:
			for a in ants.size():
				ant = ants[a]
				pos = ant[0]
				chunk = Vector2(pos/csf).floor()
				# check if ant is out of bounds
				if !chunkslocal.has(chunk):
					if wrap_around:
						if ant[0].x >= field_x: ant[0].x = 0
						elif ant[0].y >= field_y: ant[0].y = 0
						elif ant[0].x < 0: ant[0].x = field_x -1
						elif ant[0].y < 0: ant[0].y = field_y -1
						pos = ant[0]
						chunk = pos/cs
					else:
						if chunk.x < g.leftmost_chunk.x: g.leftmost_chunk = chunk
						elif chunk.x > g.rightmost_chunk.x: g.rightmost_chunk = chunk
						elif chunk.y < g.upmost_chunk.y: g.upmost_chunk = chunk
						elif chunk.y > g.downmost_chunk.y: g.downmost_chunk = chunk
						new_chunk(chunk)
						mutex.lock()
						if do_chunk_limit and chunkslocal.keys().size() == chunk_limit:
							_on_stop_pressed.call_deferred()
						mutex.unlock()
				#get rules from grid state and ant state
				which1d = (pos.x - chunk.x * cs) + (pos.y - chunk.y * cs) * cs
				chunk_data = chunkslocal[chunk][2]
				rules = colour_state_rules[a][chunk_data[which1d]][ant[2]]
				# set tile colour
				mutex.lock()
				updatequeue[chunk] = true
				chunk_data[which1d] = rules[0]
				mutex.unlock()
				
				# update ant position / rotation / state
				ant[2] = rules[1]
				ant[1] = ant[1] + rules[2] & 0x3
				ant[0] = pos + sq_move[ant[1]]
				
				ticks = ticks + 1
			queue = queue - 1


func update_ant(which):
	mutex.lock()
	
	print("ant updated")
	var updated = $Canvas/HSplit/Sidebar.make_ant_from_edits()
	for c in updated.size():
		for s in updated[c].size():
			for r in 3:
				colour_state_rules[which][c][s][r] = updated[c][s][r]
	
	print("update ant")
	if time_state != 0 and time_state != 1: show_preview()
	
	mutex.unlock()


func show_preview():
	print("okay ill preview")
	if $Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Preview/VBox/ShowPreview/ShowPreviewCheck.button_pressed:
		$PreviewCooldown.start()
		mutex.lock()
		ticks = 0
		update_field()
		sim_chunk_parent.modulate = Color(1,1,1,1)
		time_state = 2
		queue = $Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Preview/VBox/PreviewTicks/PreciewTicksAmt.value
		mutex.unlock()
		if !preview_thread.is_started(): preview_thread.start(ant_ticks)
		await get_tree().create_timer(0.1).timeout
		queue = 0
		_on_stop_pressed(true)
		time_state= -2
		await get_tree().create_timer(0.01).timeout
		
		for i in updatequeue.keys():
			var data = chunks[i]
			data[1].set_data(g.sq_chunksize,g.sq_chunksize,false,Image.FORMAT_L8,data[2])
			data[0].texture.update(data[1])
		for ant in ants.size():
			reset_ant(ant)


func update_colour_amt(old_amt:int):
	mutex.lock()
	#adding or removing rules from colour_state_rules when colour amount changes
	var difference = g.colour_amt - old_amt
	#if difference < 0:
	for a in ants.size():
		for c in -difference:
			for s in g.state_amt[a]:
				colour_state_rules[a][old_amt-c-1][s] = [0,0,0]
		for c in g.colour_amt:
			for s in g.state_amt[a]:
				if colour_state_rules[a][c][s][0] > g.colour_amt-1: colour_state_rules[a][c][s][0] = g.colour_amt-1
	#colour_state_rules[g.selected_ant] = $Canvas/HSplit/Sidebar.make_ant_from_edits()
	mutex.unlock()


func update_state_amt(which:int, amt:int):
	mutex.lock()
	g.state_amt[which] = amt
	
	
	var old_amt:int = g.state_amt[which]
	var difference:int = amt - old_amt
	for c in g.colour_amt:
		for s in g.state_amt[g.selected_ant]:
			if colour_state_rules[which][c][s][1] > amt-1: 
				colour_state_rules[which][c][s][1] = amt-1
	if ants[which][2] > g.state_amt[which]-1: 
		ants[which][2] = g.state_amt[which]-1
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
	#print("index = " + str(index) + ", col = " + str(colour))
	var texture = ImageTexture.create_from_image(g.user_pallete)
	shader_node.material.set_shader_parameter("user_pallete",texture)


func reverse_rules() -> void:
	pass
	#TODO
	# idk if its possible, but it shuold be possible to reverse time by reversing the ant rules somehow?


func update_field(edited:bool = false):
	mutex.lock()
	for a in ants:
		a[4].x = min(g.field_x-1, a[4].x)
		a[4].y = min(g.field_y-1, a[4].y)
	
	chunks.clear()
	
	for c in sim_chunk_parent.get_children():
		c.free()
	
	g.upmost_chunk = Vector2i(0,0)
	g.downmost_chunk = Vector2i(0,g.field_y/g.sq_chunksize-1)
	g.rightmost_chunk = Vector2i(g.field_x/g.sq_chunksize-1,0)
	g.leftmost_chunk = Vector2i(0,0)
	
	for r in int(g.field_y / g.sq_chunksize): 
		for c in int(g.field_x / g.sq_chunksize): 
			new_chunk(Vector2i(c,r))
	$Canvas/HSplit/OnScreen/Sim/SimViewport/Camera.position = (Vector2(g.field_x,g.field_y))/2
	$Canvas/HSplit/OnScreen/Sim/AntViewport/Camera.position = $Canvas/HSplit/OnScreen/Sim/SimViewport/Camera.position
	
	for a in ants.size():
		ants[a][0] = ants[a][4]
		ants[a][1] = ants[a][5]
	mutex.unlock()
	if edited and !loading: show_preview.call_deferred()


func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if !event.is_echo():
			if !$KeyPressCooldown.time_left > 0:
				# pressing two keys at the same time (clear and forward) the game would crash!! so theres a timer now
				match event.keycode:
					KEY_J: _on_clear_pressed()
					KEY_K: _on_stop_pressed()
					KEY_L: _on_forward_pressed()
					KEY_R: _on_randomize_button_pressed()
					KEY_EQUAL: $Canvas/HSplit/Sidebar._on_new_ant_pressed()
					KEY_MINUS: $Canvas/HSplit/Sidebar._on_delete_ant_pressed()
				
				$KeyPressCooldown.start.call_deferred()
		if Input.is_action_just_pressed("center_on_grid"):
			var middle = Vector2( (g.rightmost_chunk.x + g.leftmost_chunk.x + 1)/2 * g.sq_chunksize, (g.upmost_chunk.y + g.downmost_chunk.y) * g.sq_chunksize)
			#middle += Vector2.ONE * g.sq_chunksize
			print(middle)
			print(g.leftmost_chunk)
			print(g.rightmost_chunk)
			$Canvas/HSplit/OnScreen/Sim/AntViewport/Camera.position = middle
			$Canvas/HSplit/OnScreen/Sim/SimViewport/Camera.position = middle
		elif event.keycode == KEY_SPACE:
			$Canvas/HSplit/OnScreen/Sim/AntViewport/Camera.position = ants[g.selected_ant][0]
			$Canvas/HSplit/OnScreen/Sim/SimViewport/Camera.position = ants[g.selected_ant][0]
		


func get_screenshot_rect() -> Rect2i:
	var bounds = [0,0,0,0] #-x +x -y +y
	
	for i in chunks:
		if i.x < bounds[0]: bounds[0] = i.x
		if i.x > bounds[1]: bounds[1] = i.x 
		if i.y < bounds[2]: bounds[2] = i.y
		if i.y > bounds[3]: bounds[3] = i.y
	
	return Rect2i(bounds[0],bounds[2],bounds[1]-bounds[0]+1,bounds[3]-bounds[2]+1)


func new_chunk(pos:Vector2i):
	mutex.lock()
	
	var sprite = Sprite2D.new()
	var img = Image.create_empty(g.sq_chunksize,g.sq_chunksize,false,Image.FORMAT_L8)
	var texture = ImageTexture.create_from_image(img)
	
	sprite.texture = texture
	sprite.use_parent_material = true
	sprite.position = pos * g.sq_chunksize
	
	var data: PackedByteArray = img.get_data()
	
	chunks[pos] = [sprite,img,data]
	sim_chunk_parent.add_child.call_deferred(sprite)
	
	sprite.texture_filter = int(smoothed) + 1
	
	mutex.unlock()


func delete_ant(id:int):
	mutex.lock()
	ants.remove_at(id)
	colour_state_rules.remove_at(id)
	$Canvas/HSplit/OnScreen/Sim/AntViewport/Ants.remove_child($Canvas/HSplit/OnScreen/Sim/AntViewport/Ants.get_children(false)[id])
	mutex.unlock()
	print("delete")
	if time_state != 0 and time_state != 1: show_preview()


func set_ant_visibility(index:int, visibility:bool):
	field_ants.get_child(index).visible = visibility


func set_ant_preview_pos(index:int, pos:Vector2):
	field_ants.get_child(index).position = pos


#region UI stuff

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


func _on_stop_pressed(preview:bool = false):
	mutex.lock()
	if (time_state != -2 and time_state != 0 and !$PreviewCooldown.time_left > 0) or preview == true:
		time_state = 0
		queue = 0.0
		set_physics_process(false)
		stop2.call_deferred()
	mutex.unlock()


func _on_forward_pressed():
	mutex.lock()
	print($PreviewCooldown.time_left)
	if !$PreviewCooldown.time_left > 0:
		if time_state == 2 or time_state == -2: 
			update_field()
			sim_chunk_parent.modulate = Color(1,1,1,1)
			ticks = 0
		time_state = 1
		
		set_physics_process(true)
		set_process(true)
		
		clear = false
		$Canvas/HSplit/Sidebar.disable_elements()
		
		if !ant_thread.is_started(): 
			ant_thread.start(ant_ticks)
		
		if !wrap_around and !$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Basic/VBox/WrapAround/CheckButton.disabled: $Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Basic/VBox/WrapAround/CheckButton.disabled = true
		$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Colours/VBox/Colours/Colours.min_value = $Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Colours/VBox/Colours/Colours.value
		
		$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Chunks/VBox/Size/ChunkSize.editable = false
	mutex.unlock()


func _on_h_slider_value_changed(value):
	update_frequency = max(previous_delta * value,1)
	tps_act = value
	tps_goal = value
	$Canvas/HSplit/OnScreen/Tools/HBox/TPS.text = str(int(value))
	mutex.lock()
	queue = 0
	mutex.unlock()


func _on_clear_pressed():
	if !$PreviewCooldown.time_left > 0:
		mutex.lock()
		time_state = -2
		
		queue = 0.0
		set_physics_process(false)
		
		clear2.call_deferred()
		mutex.unlock()


func _on_screenshot_pressed():
	var rect = get_screenshot_rect()
	var image = Image.create_empty(rect.size.x*g.sq_chunksize,rect.size.y*g.sq_chunksize,false,Image.FORMAT_RGBA8)
	var pos
	var offset = rect.position
	
	for c in chunks.keys():
		for x in g.sq_chunksize:
			for y in g.sq_chunksize:
				pos = Vector2i(x,y)
				image.set_pixelv((c-offset)*g.sq_chunksize + pos,g.user_pallete.get_pixel(0,chunks[c][1].get_pixelv(pos).r8))
	var rand = str(randi())
	#images[chunk].get_pixelv(which).r8 >> 2,ant[2]
	
	image.save_png("user://"+rand+".png")
	OS.shell_show_in_file_manager.call_deferred(ProjectSettings.globalize_path("user://"+rand+".png"))


func resize_UI(offset):
	$Canvas/HSplit/Sidebar/TabCont/Ants/Ants.size.x = int(($Canvas/HSplit.size.x / 2) + offset) - 10
	$Canvas/HSplit/Sidebar/TabCont/Ants/Ants.size.y = $Canvas/HSplit.size.y-68
	$Canvas/HSplit/Sidebar/TabCont/Ants/Select/HBox.size.x = int(($Canvas/HSplit.size.x / 2) + offset) - 14 + 4
	
	$Canvas/HSplit/Sidebar/TabCont/Grid/Grid.size.x = int(($Canvas/HSplit.size.x / 2) + offset) - 10
	$Canvas/HSplit/Sidebar/TabCont/Grid/Grid.size.y = $Canvas/HSplit.size.y - 40
	
	$Canvas/HSplit/Sidebar/TabCont/Rand/Rand.size.x = int(($Canvas/HSplit.size.x / 2) + offset) - 10
	$Canvas/HSplit/Sidebar/TabCont/Rand/Rand.size.y = $Canvas/HSplit.size.y - 40
	
	$Canvas/HSplit/Sidebar/TabCont/Misc/Misc.size.x = int(($Canvas/HSplit.size.x / 2) + offset) - 10
	$Canvas/HSplit/Sidebar/TabCont/Misc/Misc.size.y = $Canvas/HSplit.size.y - 40
	
	$Canvas/HSplit/OnScreen/Sim/SimViewport.size_2d_override = $Canvas/HSplit/OnScreen/Sim.size
	
	$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Colours/VBox/Grid/GridContainer.columns = max(1, max($Canvas/HSplit/Sidebar.size.x / 48, 224 / 40))
	
	var min_size = 20 * int(g.colour_amt / $Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Colours/VBox/Grid/GridContainer.columns)
	if int(g.colour_amt) % $Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Colours/VBox/Grid/GridContainer.columns > 0: min_size += 16
	else: min_size -= 4
	
	$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Colours/VBox/Grid/GridContainer.custom_minimum_size.y = min_size
	$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Colours/VBox/Grid.custom_minimum_size.y = min_size
	$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Colours.custom_minimum_size.y = 88 + min_size + 8
	
	$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox.custom_minimum_size.y = $Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Chunks.position.y + $Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Chunks.size.y + 4


func _on_h_split_dragged(offset):
	resize_UI(offset)


func stop2():
	if ant_thread.is_started(): ant_thread.wait_to_finish()
	if preview_thread.is_started(): preview_thread.wait_to_finish()
	$Canvas/HSplit/Sidebar.enable_elements()
	print("stopped")


func clear2(): #part 2 of clearing the board. all the stuff thats call deferred
	if ant_thread.is_started(): ant_thread.wait_to_finish()
	
	chunks.clear()
	updatequeue.clear()
	update_field()
	
	if prev_state == -1:
		prev_state = 1
		reverse_rules()
	
	for ant in ants.size():
		reset_ant(ant)
	
	ticks = 0
	$Canvas/HSplit/Sidebar.enable_elements()
	clear = true
	
	for a in ants.size():
		var ant = ants[a]
		field_ants.get_child(a).position = ant[0]
	
	$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Colours/VBox/Colours/Colours.min_value = 1
	$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Basic/VBox/WrapAround/CheckButton.disabled = false
	$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Chunks/VBox/Size/ChunkSize.editable = true
	
	print("clear")
	#print(time_state)
	if time_state != 0 and time_state != 1: show_preview()


func _on_smoothed_toggled(toggled_on):
	smoothed = toggled_on
	if toggled_on:
		for i in sim_chunk_parent.get_children():
			i.texture_filter = 2
	else:
		for i in sim_chunk_parent.get_children():
			i.texture_filter = 1


func _on_chunk_limit_value_changed(value):
	mutex.lock()
	chunk_limit = int(value)
	mutex.unlock()


func _on_chunk_size_value_changed(value):
	g.sq_chunksize = value
	$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Basic/VBox/FieldSize/HBox/X.min_value = g.sq_chunksize
	$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Basic/VBox/FieldSize/HBox/Y.min_value = g.sq_chunksize
	$Canvas/HSplit/Sidebar._on_x_value_changed($Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Basic/VBox/FieldSize/HBox/X.value, false)
	$Canvas/HSplit/Sidebar._on_y_value_changed($Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Basic/VBox/FieldSize/HBox/Y.value)
	$Canvas/HSplit/OnScreen/Sim/SimViewport/Field/SimChunks.position = Vector2.ONE * value / 2


func _on_check_button_toggled(toggled_on):
	do_chunk_limit = toggled_on
	$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Chunks/VBox/Limit/ChunkLimit.editable = toggled_on
	if toggled_on: $Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Chunks/VBox/Limit/Label.modulate = Color.WHITE
	else: $Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Chunks/VBox/Limit/Label.modulate = Color.DIM_GRAY


func _on_randomize_colours_pressed():
	match $Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Colours/VBox/Rand/Type.selected:
		0: #true rand
			for i in 23:
				var col = Color(randf(),randf(),randf())
				update_colours(i+1,col)
				$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Colours/VBox/Grid/GridContainer.get_child(i+1).get_child(0).color = col
		1: #range rand
			var range_r = [randf()*0.1+0.3,randf()]
			var range_g = [randf()*0.1+0.3,randf()]
			var range_b = [randf()*0.1+0.3,randf()]
			
			var which = randi() % 3
			if which == 0: range_r[0] += 0.3
			elif which == 0: range_g[0] += 0.3
			else: range_b[0] += 0.3
			
			for i in 23:
				var col = Color(
					min(range_r[1] + (randf() * range_r[0] - range_r[0]), 1),
					min(range_g[1] + (randf() * range_g[0] - range_g[0]), 1),
					min(range_b[1] + (randf() * range_b[0] - range_b[0]), 1)
				)
				update_colours(i+1,col)
				$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Colours/VBox/Grid/GridContainer.get_child(i+1).get_child(0).color = col
		2: #gradient
			var pointer = 0
			var points = [1]
			var colours = [Color(randf(),randf(),randf())]
			
			var c_range = g.colour_amt-1
			var point_count = int((g.colour_amt-1) / 7)
			if randi() % 2 == 0: point_count = max(0, point_count-1)
			
			if g.colour_amt > 2:
				if (int((g.colour_amt-1) / 7)) + 2 > 0:
					for i in (point_count+1):
						points.append((c_range / (point_count+1) * (i+1))+1)
						colours.append(Color(randf(),randf(),randf()))
				points[-1] = g.colour_amt-1
			
			if g.colour_amt > 2:
				for i in g.colour_amt-1:
					var lerp_value = (float((i+1) - points[pointer]) / (points[pointer+1] - points[pointer]))
					var col = colours[pointer].lerp(colours[pointer+1], lerp_value)
					update_colours(i+1, col)
					$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Colours/VBox/Grid/GridContainer.get_child(i+1).get_child(0).color = col
					if points.has(i+1):
						pointer = points.find(i+1)
			else:
				var col = colours[0]
				update_colours(1, col)
				$Canvas/HSplit/Sidebar/TabCont/Grid/Grid/VBox/Colours/VBox/Grid/GridContainer.get_child(1).get_child(0).color = col

#endregion


func _on_randomize_button_pressed():
	mutex.lock()
	var whichants:Array = []
	var ants_opt = $Canvas/HSplit/Sidebar/TabCont/Rand/Rand/VBox/Randomize/VBox/Which/WhichAnt.selected
	
	var g_state_rand = $Canvas/HSplit/Sidebar/TabCont/Rand/Rand/VBox/Randomize/VBox/GStateRand/GStateRandCheck.button_pressed
	var a_state_rand = $Canvas/HSplit/Sidebar/TabCont/Rand/Rand/VBox/Randomize/VBox/AStateRand/AStateRandCheck.button_pressed
	var a_rot_rand = $Canvas/HSplit/Sidebar/TabCont/Rand/Rand/VBox/Randomize/VBox/ARotRand/ARotRandCheck.button_pressed
	
	var g_state_rang = $Canvas/HSplit/Sidebar/TabCont/Rand/Rand/VBox/Randomize/VBox/GStateRang/GStateRangCheck.button_pressed
	var a_state_amt = $Canvas/HSplit/Sidebar/TabCont/Rand/Rand/VBox/Randomize/VBox/AStateAmt/AStateAmtCheck.button_pressed
	var a_rot_rang = $Canvas/HSplit/Sidebar/TabCont/Rand/Rand/VBox/Randomize/VBox/ARotRang/ARotRandCheck.button_pressed
	
	var start_pos_rand = $Canvas/HSplit/Sidebar/TabCont/Rand/Rand/VBox/Randomize/VBox/StartPosRand/StartPosRandCheck.button_pressed
	var start_dir_rand = $Canvas/HSplit/Sidebar/TabCont/Rand/Rand/VBox/Randomize/VBox/StartDirRand/StartDirRandCheck.button_pressed
	
	match ants_opt:
		0: #all ants
			for a in ants.size():
				whichants.append(a)
		1: #one nt
			whichants.append(randi() % ants.size())
		2: #multiple ants
			var odds = 2 + ((randi() % 3) - 1) #25, 50 or 75 % odds
			for a in ants.size():
				if randi() % 5 > odds:
					whichants.append(a)
			if whichants.is_empty():
				whichants.append(randi() % ants.size())
		_: #specific ant
			whichants.append(ants_opt - 4)
	
	for a in whichants:
		if a_state_amt:
			var x = (randi()%24) + 1
			update_state_amt(a,x)
			if a == g.selected_ant: 
				update_state_amt(a,x)
				$Canvas/HSplit/Sidebar.resize_grid(null,x)
				$Canvas/HSplit/Sidebar/TabCont/Ants/Ants/VBox/Rules/VBox/States/Num.set_value_no_signal(x)
		
		var col_range = Vector2i(0,g.colour_amt-1)
		if g.colour_amt > 2 and g_state_rang:
			var crange = (randi() % (g.colour_amt - 1))+1
			var offset = randi() % ((g.colour_amt)  - crange)
			col_range = Vector2i(offset, crange + offset)
		
		var rot_range = [0,1,2,3]
		if a_rot_rang:
			for i in 2:
				if randi() % 3 == 0:
					rot_range.remove_at(randi() % rot_range.size())
		
		if start_pos_rand:
			ants[a][4] = Vector2i(randi() % g.field_x, randi() % g.field_y)
		if start_dir_rand:
			ants[a][5] = randi() % 4
		reset_ant(a)
		
		for c in col_range.y - col_range.x + 1:
			for s in g.state_amt[a]:
				var rulepointer = colour_state_rules[a][c+col_range.x][s]
				var newrules:PackedByteArray = \
				[((randi() % (col_range.y - col_range.x + 1)) + col_range.x),
				randi() % g.state_amt[a],
				rot_range[randi() % rot_range.size()]
				]
				#print(str(Vector2i(c+col_range.x,s)) + " got rule " + str(newrules))
				if g_state_rand: rulepointer[0] = newrules[0]
				if a_state_rand: rulepointer[1] = newrules[1]
				if a_rot_rand: rulepointer[2] = newrules[2]
				
				if a == g.selected_ant: 
					var state_edit = $Canvas/HSplit/Sidebar.state_edits[Vector2i(c+col_range.x,s)]
					state_edit.set_colour(rulepointer[0])
					state_edit.set_state(rulepointer[1])
					state_edit.set_rotate(rulepointer[2])
		
		if col_range.x > 0:
			for c in col_range.x:
				for s in g.state_amt[a]:
					var rulepointer = colour_state_rules[a][c+col_range.x][s]
					var newrules:PackedByteArray = [col_range.x,0,0]
					
					if g_state_rand: rulepointer[0] = newrules[0]
					if a_state_rand: rulepointer[1] = newrules[1]
					if a_rot_rand: rulepointer[2] = newrules[2]
					
					if a == g.selected_ant: 
						var state_edit = $Canvas/HSplit/Sidebar.state_edits[Vector2i(c,s)]
						state_edit.set_colour(rulepointer[0])
						state_edit.set_state(rulepointer[1])
						state_edit.set_rotate(rulepointer[2])
		
		if col_range.y < g.colour_amt - 1:
			for c in g.colour_amt - 1 - col_range.y:
				for s in g.state_amt[a]:
					var rulepointer = colour_state_rules[a][c+col_range.x][s]
					var newrules:PackedByteArray = [col_range.y,0,0]
					
					if g_state_rand: rulepointer[0] = newrules[0]
					if a_state_rand: rulepointer[1] = newrules[1]
					if a_rot_rand: rulepointer[2] = newrules[2]
					
					if a == g.selected_ant: 
						var state_edit = $Canvas/HSplit/Sidebar.state_edits[Vector2i(g.colour_amt - 1 - c,s)]
						state_edit.set_colour(rulepointer[0])
						state_edit.set_state(rulepointer[1])
						state_edit.set_rotate(rulepointer[2])
	
	mutex.unlock()
	print("randomized")
	if time_state != 0 and time_state != 1: show_preview()


func _on_preview_cooldown_timeout():
	pass # Replace with function body.


func _on_key_press_cooldown_timeout():
	pass # Replace with function body.
