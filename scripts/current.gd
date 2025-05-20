extends Control
var rule_edit
var antpos

func update():
	if !g.world.ants.is_empty(): 
		antpos = g.world.ants[g.selected_ant]
		$VBox/Position/HBox/X.set_value_no_signal.call_deferred(antpos[0].x)
		$VBox/Position/HBox/Y.set_value_no_signal.call_deferred(antpos[0].y)
		$VBox/Direction/Option.select.call_deferred(antpos[1])
		$VBox/State/Num.set_value_no_signal.call_deferred(antpos[2])
