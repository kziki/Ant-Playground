extends Camera2D

var camera_tween
var camera_tween_pos
var ant_camera_tween
var ant_camera_tween_pos

@onready var parent = get_parent().get_parent().get_parent()

var can_move = true
var default_validzooms = [0.03125,0.0625,0.125,0.25,0.5,1]
var validzooms = [0.25,0.5,1,2,4,8,16]
var zoomindex:int = 2
var des_zoom = zoom
var des_pos = position
var camera_rect:Rect2

func _ready():
	zoom = Vector2.ONE * validzooms[zoomindex]


func _input(event):
	if can_move:
		# scroll
		if event is InputEventMouseButton:
			if event.is_pressed() and event.position.x > 8:
				if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and zoomindex > 0:
					zoomindex -= 1
				if event.button_index == MOUSE_BUTTON_WHEEL_UP and zoomindex < validzooms.size()-1:
					zoomindex += 1
				des_zoom = Vector2.ONE * validzooms[zoomindex]
				zoom_tween(des_zoom,des_pos)
		# pan
		if event is InputEventMouseMotion:
			parent.set_mousepos_text(get_local_mouse_position() + position)
			
			if event.button_mask == MOUSE_BUTTON_MASK_MIDDLE and event.position.x > 8:
				position -= event.relative / zoom
				
				camera_rect = Rect2(Vector2(position), Vector2(get_viewport().size) / zoom)
				var bot_right_point:Vector2 = ((camera_rect.position + camera_rect.size / 2) + Vector2.ONE * g.sq_chunksize)
				var top_left_point:Vector2 = ((camera_rect.position - camera_rect.size / 2) )
				
				#print( (g.leftmost_chunk.x * 2 ))
				
				if bot_right_point.x < g.leftmost_chunk.x * g.sq_chunksize: position.x = ((g.rightmost_chunk.x+1) * g.sq_chunksize) + camera_rect.size.x / 2 
				elif bot_right_point.y < g.upmost_chunk.y * g.sq_chunksize: position.y = ((g.downmost_chunk.y+1) * g.sq_chunksize) + camera_rect.size.y / 2 
				elif top_left_point.x > ((g.rightmost_chunk.x + 1) * g.sq_chunksize): position.x = (g.leftmost_chunk.x * g.sq_chunksize) - camera_rect.size.x / 2 
				elif top_left_point.y > ((g.downmost_chunk.y + 1) * g.sq_chunksize): position.y = (g.upmost_chunk.y * g.sq_chunksize) - camera_rect.size.y / 2 
				
				g.ant_camera.position = position

func get_valid_zooms():
	var x = 0
	validzooms = []
	for i in default_validzooms:
		validzooms.append(default_validzooms[x] * g.intscaling)
		x += 1

func set_zoom_to_index(index):
	zoomindex = index
	des_zoom = Vector2.ONE * validzooms[index]
	zoom_tween(des_zoom,des_pos)

func zoom_tween(to_zoom,_to_pos):
	if camera_tween:
		camera_tween.kill()
		ant_camera_tween.kill()
	if camera_tween_pos:
		camera_tween_pos.kill()
		ant_camera_tween_pos.kill()
	camera_tween = get_tree().create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
	ant_camera_tween = get_tree().create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
	
	camera_tween.tween_property(self,"zoom",to_zoom,0.05)
	ant_camera_tween.tween_property(g.ant_camera,"zoom",to_zoom,0.05)
	
	# TODO, zoom to mouse position!! tween the position !!!!!!
