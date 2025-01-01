extends Node2D

enum sq_dir {UP,RIGHT,BACK,LEFT}
enum hx_dir {UP,RIGHT2,RIGHT1,BACK,LEFT1,LEFT2}
enum tr_dir {LEFT,RIGHT,BACK}

@onready var field = $field

var sq_move:Array = [
	Vector2i(0,-1),
	Vector2i(1,0),
	Vector2i(0,1),
	Vector2i(-1,0)
	]

var play:bool = true
var turns:int = 0
var wrap_around:bool = true
var ant_states:int = 1
var time_state:int = 0
var prev_state:int = 1
var clear:bool = true
var tps:int = 100

var sq_chunk = preload("res://sq_chunk.tscn")

var defaultant = null
var z = null
var p = null
var queue = 0
var pq = 0

var test:int = 0

var ant_thread = Thread.new()

var colours:Dictionary = {
	0: Color.BLACK,
	1: Color.WHITE}

var colour_state_rules:Dictionary = {
	0: { #Vector2i(colour,ant_state): [to_colour, to_state, rotation]
	Vector2i(0,0): [1,1,1],
	Vector2i(1,0): [0,1,3],
	Vector2i(0,1): [1,0,0],
	Vector2i(1,1): [0,0,0]}}

var ants = {
	0: [Vector2i(500,500),sq_dir.LEFT,0]} #[ant position, ant direction, ant state]

var states:Dictionary = {}
var chunks:Dictionary = {}
var pos_to_chunk:Dictionary = {}
var default_multimesh

func _ready():
	print ("ant dir: " + str(ants[0][1]))
	#b = Time.get_ticks_msec()
	#for i in 1000000:
		#change_state(ants[0])
	#print(Time.get_ticks_msec() - b)
	
	g.world = self
	set_physics_process(false)
	set_process(false)
	
	for c in colours.keys().size():
		for s in ant_states:
			#colour_state_rules[Vector2(c,s)] = [0,0,0] # colour, state, rotation
			pass
	
	Engine.physics_ticks_per_second = 1 #100000
	Engine.max_physics_steps_per_frame = 100 #1000
	
	get_tree().get_root().size_changed.connect(resize)
	
	get_default_multimesh()
	#empty_chunk = new_sq
	#$field.add_child(new_sq)
	
	get_window().size = Vector2i(1000,640)
	get_window().position = Vector2(2000,200)
	
	for r in int(g.x / g.sq_chunksize): 
		for c in int(g.y / g.sq_chunksize): 
			var i = 0
			#var new = new_sq.duplicate()
			var new = sq_chunk.instantiate()
			new.multimesh = default_multimesh.duplicate()
			new.position = Vector2(c,r) * g.sq_chunksize * 16
			chunks[Vector2i(c,r)] = new
			for x in g.sq_chunksize:
				for y in g.sq_chunksize:
					pos_to_chunk[Vector2i(y,x) + (Vector2i(c,r)*g.sq_chunksize)] = [new,i]
					i+=1
			field.add_child(new)
	#print(pos_to_chunk.keys())
			
			#print("a")
	
	for r in g.y:
		for c in g.x:
			states[Vector2i(r,c)] = 0
	
	$camera.position = (Vector2(g.x,g.y)*16)/2
	ants[0][0] = Vector2i(g.x,g.y)/2
	
	#set_physics_process(true)
	print($canvas/hsplit/colour_state_edit_main.get_colours())

func get_default_multimesh(colour = Color.BLACK):
	var temp = sq_chunk.instantiate()
	temp.init_multimesh(colour)
	default_multimesh = temp.multimesh
	temp.queue_free()

func resize():
	g.calc_pppp()
	#$canvas/ui/state_control.size.x = 256 * g.pppp
	#print($canvas/ui/state_control.get_viewport_rect())

#func cam_chunk():
	#var chunk_dim = 16*g.sq_chunksize
	#var xx = int(g.camera_rect.position.x / chunk_dim) - int(g.camera_rect.position.x < 0)
	#var xy = int(g.camera_rect.position.y / chunk_dim) - int(g.camera_rect.position.y < 0)
	#
	#var yx = int((g.camera_rect.position.x + g.camera_rect.size.x) / chunk_dim) - int((g.camera_rect.position.x + g.camera_rect.size.x) < 0) + 1
	#var yy = int((g.camera_rect.position.y + g.camera_rect.size.y) / chunk_dim) - int((g.camera_rect.position.y + g.camera_rect.size.y) < 0) + 1
	#var chunk_rect = Rect2i(Vector2i(xx,xy),Vector2i(yx-xx,yy-xy))
	##print(Vector2(xx,xy))
	##print(Vector2(yx-xx,yy-xy))
	##print("---")
	#
	#for r in chunk_rect.size.y:
		#for c in chunk_rect.size.x: 
			#if !affected_chunks.has(Vector2i(c,r) + chunk_rect.position):
				#if !visible_chunks:
					#pass
			##print(Vector2i(c,r) + chunk_rect.position)
			#pass
	#$ColorRect.position = Vector2(xx,xy) * chunk_dim
	#$ColorRect.size = Vector2(yx-xx,yy-xy) * chunk_dim

#func _physics_process(_delta):
	#pass

func _process(delta):
	queue += (delta * tps)
	#print(queue)
	$canvas/hsplit/on_screen/turns.text = "\n" + str(turns)
	#$canvas/hsplit/on_screen/fps.text = str(int(Engine.get_frames_per_second()))
	for a in ants:
		var ant = ants[a]
		$ant.position = ant[0]*16 + Vector2i(8,8)

func _physics_process(delta):
	$canvas/hsplit/on_screen/fps.text = str(int(turns - pq)) + "\n" + str(int(queue))
	pq = turns
	if queue > (turns - pq):
		queue = turns - pq

func ant_ticks():
	while is_physics_processing():
		if int(queue) > 0:
			for a in ants:
				var z = Vector2i(states[ants[a][0]],ants[a][2])
				var ant = ants[a]
				
				states[ant[0]] = colour_state_rules[0][z][0]
				ant[2] = colour_state_rules[0][z][1]
				ant[1] = ant[1] + colour_state_rules[0][z][2]
				ant[1] = ant[1] % 4
				#print(pos_to_chunk[ant[0]][0])
				pos_to_chunk[ant[0]][0].multimesh.set_instance_color(pos_to_chunk[ant[0]][1],colours[states[ant[0]]])
				#chunks[pos_to_chunk(ant[0])].multimesh.set_instance_color(get_instance_from_pos(ant[0]),colours[states[ant[0]]])
				#
				ant[0] = ant[0] + sq_move[ant[1]]
				#
				
				if !states.has(ant[0]):
					
					var x:Vector2i = ant[0]
					if x.x<0: x.x = -((abs(x.x)-1) / 50) - 1
					else: x.x = x.x/50
					if x.y<0: x.y = -((abs(x.y)-1) / 50) - 1
					else: x.y = x.y/50
					#print(str(ant[0]) + " - " + str(x))
					
					var i = 0
					var new = sq_chunk.instantiate()
					new.multimesh = default_multimesh.duplicate()
					new.position = x * g.sq_chunksize * 16
					chunks[x] = new
					var printx = []
					
					for xx in g.sq_chunksize:
						for xy in g.sq_chunksize:
							var temp = Vector2i(xy,xx) + (x*g.sq_chunksize)
							pos_to_chunk[temp] = [new,i]
							states[temp] = 0
							i+=1
							if (xx == 0 and xy == 0) or (xx == g.sq_chunksize-1 and xy == g.sq_chunksize-1):
								printx.append(temp)
					print("new chunks at: " + str(x) + " with range: " + str(printx) + "while ant was at: " + str(ant[0]) + str(states.has(ant[0]))+ " at turn: " + str(turns))
					field.add_child.call_deferred(new)
					#await get_tree().create_timer(0.1).timeout
					
					#ant[0] = Vector2i(g.x,g.y)/2
				
				
				#if ant[1] == sq_dir.UP :ant[0].y = ant[0].y-1
				#elif ant[1] == sq_dir.LEFT: ant[0].x = ant[0].x + 1
				#elif ant[1] == sq_dir.BACK: ant[0].y = ant[0].y + 1
				#elif ant[1] == sq_dir.RIGHT: ant[0].x = ant[0].x - 1
				#if ant[0].x >= g.x: ant[0].x = 0
				#elif  ant[0].y >= g.y: ant[0].y = 0
				#elif  ant[0].x < 0: ant[0].x = g.x -1
				#elif ant[0].y < 0: ant[0].y = g.y -1
				
				turns += 1
			queue -= 1
			#print(ants[ant])

func colour_thread():
	pass


func rotate_ant(ant,degrees):
	ant[1] += degrees
	ant[1] = ant[1] % 4

func change_state(ant):
	var x = Vector2i(states[ant[0]],ant[2])
	states[ant[0]] = colour_state_rules[0][x][0]
	ant[2] = colour_state_rules[0][x][1]
	rotate_ant(ant,colour_state_rules[0][x][2])
	#states[ant[0]] = state_rules[states[ant[0]]][1]
	#chunks[pos_to_chunk(ant[0])].multimesh.set_instance_color(get_instance_from_pos(ant[0]),colours[states[ant[0]]])
	#print (ant[0])

func move_ant(ant):
	match ant[1]:
		0:ant[0].y -= 1
		1:ant[0].x += 1
		2:ant[0].y += 1
		3:ant[0].x -= 1
	if ant[0].x >= g.x: ant[0].x = 0
	elif  ant[0].y >= g.y: ant[0].y = 0
	elif  ant[0].x < 0: ant[0].x = g.x -1
	elif ant[0].y < 0: ant[0].y = g.y -1

func get_instance_from_pos(pos) -> int:
	var x = Vector2i(pos.x%g.sq_chunksize,pos.y%g.sq_chunksize)
	var y = x.y * g.sq_chunksize + x.x
	return y

func vec_to_chunk(pos):
	var x = ((pos.x+1) / g.sq_chunksize)
	var z = ((pos.x+1.0) / g.sq_chunksize)
	x = (x + int(abs(z - x) > 0))
	
	var y = ((pos.y+1) / g.sq_chunksize)
	z = ((pos.y+1.0) / g.sq_chunksize)
	y = (y + int(abs(z - y) > 0))
	
	return Vector2i(x-1,y-1)

func reset():
	pass


func _on_forward_pressed():
	time_state = 1
	if defaultant == null: defaultant = ants[0].duplicate()
	print(defaultant)
	set_physics_process(true)
	set_process(true)
	if prev_state == -1: reverse_rules()
	prev_state = 1
	clear = false
	$canvas/hsplit/colour_state_edit_main.disable_elements()
	if !ant_thread.is_started(): ant_thread.start(ant_ticks)

func _on_stop_pressed():
	time_state = 0
	set_physics_process(false)
	set_process(false)
	ant_thread.wait_to_finish()


func _on_reverse_pressed():
	time_state = -1
	if defaultant == null: defaultant = ants[0].duplicate()
	print(defaultant)
	set_physics_process(true)
	if prev_state == 1: reverse_rules()
	prev_state = -1
	clear = false
	$canvas/hsplit/colour_state_edit_main.disable_elements()
	if !ant_thread.is_started(): ant_thread.start(ant_ticks)
	

func reverse_rules():
	
	for i in colour_state_rules:
		for j in colour_state_rules[i]:
			#print(colour_state_rules[i][j])
			if colour_state_rules[i][j][2] == 1 or colour_state_rules[i][j][2] == 3:
				print(colour_state_rules[i][j])
				#colour_state_rules[i][j][0] = g.colour_amt - colour_state_rules[i][j][0] - 1
				colour_state_rules[i][j][1] = g.state_amt - colour_state_rules[i][j][1] - 1
				colour_state_rules[i][j][2] += 2
				colour_state_rules[i][j][2] = colour_state_rules[i][j][2] % 4
				print(colour_state_rules[i][j])
			#print(colour_state_rules[i][j])
	z = ants[0]
	print("r" + str(z))
	for ant in ants:
		rotate_ant(ants[ant],2)

func _on_h_slider_drag_ended(value_changed):
	pass # Replace with function body.


func _on_h_slider_value_changed(value):
	#var x = ((value/1000000) * 4900) + 100
	tps = value
	#Engine.physics_ticks_per_second = value
	#Engine.max_physics_steps_per_frame = 9999
	$canvas/hsplit/on_screen/hbox/tps.text = str(int(value))

func _on_clear_pressed():
	time_state = 0
	set_physics_process(false)
	set_process(false)
	if ant_thread.is_started(): ant_thread.wait_to_finish()
	
	chunks.clear()
	pos_to_chunk.clear()
	update_field()
	
	for chunk in chunks:
		chunks[chunk].multimesh = default_multimesh.duplicate()
	
	if prev_state == -1:
		prev_state = 1
		reverse_rules()
	ants[0][1] = 1
	
	for s in states:
		states[s] = 0
	
	print(defaultant)
	ants[0] = defaultant.duplicate()
	
	
	$canvas/hsplit/colour_state_edit_main.enable_elements()
	
	clear = true

func update_ant():
	colour_state_rules[0] = $canvas/hsplit/colour_state_edit_main.make_ant_from_edits()

func update_colours(index,colour):
	colours[index] = colour
	if index == 0:
		get_default_multimesh(colour)
		for chunk in chunks:
			chunks[chunk].multimesh = default_multimesh.duplicate()

func update_field():
	chunks.clear()
	pos_to_chunk.clear()
	for c in field.get_children():
		c.queue_free()
	
	for r in int(g.x / g.sq_chunksize): 
		for c in int(g.y / g.sq_chunksize): 
			var i = 0
			#var new = new_sq.duplicate()
			var new = sq_chunk.instantiate()
			new.multimesh = default_multimesh.duplicate()
			new.position = Vector2(c,r) * g.sq_chunksize * 16
			chunks[Vector2i(c,r)] = new
			for x in g.sq_chunksize:
				for y in g.sq_chunksize:
					pos_to_chunk[Vector2i(y,x) + (Vector2i(c,r)*g.sq_chunksize)] = [new,i]
					i+=1
			field.add_child(new)
	
	for r in g.y:
		for c in g.x:
			states[Vector2i(r,c)] = 0
	
	$camera.position = (Vector2(g.x,g.y)*16)/2
	ants[0][0] = Vector2i(g.x,g.y)/2

func _input(event):
	if event is InputEventMouseButton:
		var x:Vector2i = get_global_mouse_position()/16
		if x.x<0: x.x = -((abs(x.x)-1) / 50) - 1
		else: x.x = x.x/50
		if x.y<0: x.y = -((abs(x.y)-1) / 50) - 1
		else: x.y = x.y/50
		
		var printx = []
		for xx in g.sq_chunksize:
			for xy in g.sq_chunksize:
				if (xx == 0 and xy == 0) or (xx == g.sq_chunksize-1 and xy == g.sq_chunksize-1):
					var temp = Vector2i(xy,xx) + (x*g.sq_chunksize)
					printx.append(temp)
		#print(get_global_mouse_position())
		#print("pos = "+str(Vector2i(get_global_mouse_position())/16) + " new chunk at: " + str(x) + " with range: " + str(printx))
		#await get_tree().create_timer(0.1).timeout

func get_screenshot_rect() -> Rect2i:
	var bounds = [0,0,0,0] #-x +x -y +y
	var rect:Rect2i =  Rect2i()
	
	for i in chunks:
		if i.x < bounds[0]: bounds[0] = i.x
		if i.x > bounds[1]: bounds[1] = i.x 
		if i.y < bounds[2]: bounds[2] = i.y
		if i.y > bounds[3]: bounds[3] = i.y
	
	print (bounds)
	
	return Rect2i(bounds[0],bounds[2],bounds[1]-bounds[0]+1,bounds[3]-bounds[2]+1)

func _on_screenshot_pressed():
	var rect = get_screenshot_rect()
	
	#rect = rect.grow(1)
	
	$ColorRect2.position = rect.position*g.sq_chunksize*16
	$ColorRect2.size = (rect.size)*g.sq_chunksize*16
	
	var image = Image.create_empty(rect.size.x*g.sq_chunksize,rect.size.y*g.sq_chunksize,false,Image.FORMAT_RGB8)
	#image.resize(rect.size.x*g.sq_chunksize,rect.size.y*g.sq_chunksize)
	print("image size: " +str(image.get_size()))
	
	for y in rect.size.y*g.sq_chunksize:
		for x in rect.size.x*g.sq_chunksize:
			var pos = Vector2i(x,y)
			#print(pos)
			if states.has(pos + (rect.position*g.sq_chunksize)): image.set_pixel(x,y,colours[states[pos+(rect.position*g.sq_chunksize)]])
			else:image.set_pixel(x,y,colours[0])
	
	image.save_png("user://"+str(randi())+".png")
