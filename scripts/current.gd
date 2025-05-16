extends Control
var rule_edit
var antpos

func update():
	if rule_edit.get_selected_ant_id() != -1: 
		antpos = g.world.ants[rule_edit.get_selected_ant_id()]
		$VBox/Position/HBox/X.set_value_no_signal.call_deferred(antpos[0].x)
		$VBox/Position/HBox/Y.set_value_no_signal.call_deferred(antpos[0].y)
		$VBox/Direction/Option.select.call_deferred(antpos[1])
		$VBox/State/Num.set_value_no_signal.call_deferred(antpos[2])
