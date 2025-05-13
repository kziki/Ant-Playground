extends Control

func set_mousepos_text(pos:Vector2) -> void:
	$MousePos/MousePos.text = str(Vector2i(pos))
	var k = Vector2i((pos/32).floor())
	$MousePos/MouseChunk.text = str( k )
	
