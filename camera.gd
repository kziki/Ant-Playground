extends Camera2D

var can_move = true
var pp = true

var camera_tween
var camera_tween_pos

var default_validzooms = [0.03125,0.0625,0.125,0.25,0.5,1]
var validzooms = [0.03125,0.0625,0.125,0.25,0.5,1]
var zoomindex:int = 1
var des_zoom = zoom

var des_pos = position

func _ready():
	zoom = Vector2.ONE * validzooms[zoomindex]
	#global.camera = self

func _input(event):
	if can_move:
		if event is InputEventMouseButton:
			if event.is_pressed():
				if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					if zoomindex > 0:
						if !get_node("../canvas/hsplit/colour_state_edit_main").get_global_rect().grow(8*g.pppp).has_point(event.position):
							zoomindex -= 1
							des_zoom = Vector2.ONE * validzooms[zoomindex]
							zoom_tween(des_zoom,des_pos)
							#get_rect()
							#get_parent().cam_chunk()
				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					if zoomindex < validzooms.size()-1:
						if !get_node("../canvas/hsplit/colour_state_edit_main").get_global_rect().grow(8*g.pppp).has_point(event.position):
							zoomindex += 1
							des_zoom = Vector2.ONE * validzooms[zoomindex]
							zoom_tween(des_zoom,des_pos)
							#get_rect()
							#get_parent().cam_chunk()
		if event is InputEventMouseMotion:
			if event.button_mask == MOUSE_BUTTON_MASK_MIDDLE:
				if !get_node("../canvas/hsplit/colour_state_edit_main").get_global_rect().grow(8*g.pppp).has_point(event.position):
					position -= event.relative / zoom
					#get_rect()
				#get_parent().cam_chunk()
				#get_parent().get_node("field/sq_chunk").position = g.camera_rect.position

func get_rect(): #stored in global as camera_rect
	var camera_size = get_viewport_rect().size / des_zoom
	g.camera_rect = Rect2(get_screen_center_position() - camera_size / 2, camera_size)

func get_valid_zones():
	var x = 0
	validzooms = []
	for i in default_validzooms:
		validzooms.append(default_validzooms[x] * g.intscaling)
		x += 1

func set_zoom_to_index(index):
	zoomindex = index
	des_zoom = Vector2.ONE * validzooms[index]
	zoom_tween(des_zoom,des_pos)

func zoom_tween(x,y):
	if camera_tween:
		camera_tween.kill()
	if camera_tween_pos:
		camera_tween_pos.kill()
	camera_tween = get_tree().create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
	#camera_tween_pos = get_tree().create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	
	camera_tween.tween_property(self,"zoom",x,0.025)
	#camera_tween_pos.tween_property(self,"offset",y,0.2)
	
