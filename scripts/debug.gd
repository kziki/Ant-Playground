extends Node2D
var chunks:Dictionary = {}
var images:Dictionary = {}
var multimesh = preload("res://scenes/sq_chunk.tscn")
var case = 0

func _ready():
	var time_before = Time.get_ticks_msec()
	
		
	match case:
		0:
			
			for c in 40:
				for r in 40:
					var chunk = Image.create_empty(32,32,false,Image.FORMAT_L8)
					chunk.fill(Color.BLACK)
					var sprite = Sprite2D.new()
					var texture:ImageTexture = ImageTexture.create_from_image(chunk)
					sprite.texture = texture
					chunks[Vector2i(c,r)] = texture
					images[Vector2i(c,r)] = chunk
					sprite.position = Vector2i(c,r) * 32
					$chunks.add_child(sprite)
					
		1:
			var defc = multimesh.instantiate()
			var defm = defc.init_multimesh()
			for c in 40:
				for r in 40:
					var chunk = multimesh.instantiate()
					chunk.multimesh = defm.duplicate()
					chunks[Vector2i(c,r)] = chunk
					chunk.position = Vector2i(c,r) * 50
					$chunks.add_child(chunk)
		2:
			$MultiMeshInstance2D.multimesh.instance_count = 2000*2000
	
	var total_time = (Time.get_ticks_msec() - time_before)
	print("debug: " + str(total_time))

func _physics_process(delta):
	#print(Engine.get_frames_per_second())
	var time_before = Time.get_ticks_msec()
	if case == 0:
		var rand:Vector2i 
		for i in 100000:
			rand = Vector2i(0,0)
			images[rand].set_pixel(0,0,Color.WHITE)
		
		chunks[Vector2i(0,0)].update(images[Vector2i(0,0)])
	else:
		for i in 100000:
			chunks[Vector2i(0,0)].multimesh.set_instance_color(0,Color.WHITE)
	var total_time = (Time.get_ticks_msec() - time_before)
	print(total_time)
