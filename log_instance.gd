extends VBoxContainer

#Log Instance. The node that represents a line in the console. A new one is
#created for every command typed.

#Sets the texts of the Input label and Response label
#It asks the response() command for what to put in the response label
func set_text(input: String,response):
	var InputLabel = get_node("Input")
	var ResponseLabel = get_node("Response")
	InputLabel.text = " > " + input
	if response != "":
		ResponseLabel.text = "      "+response
	else:
		ResponseLabel.text = "      Invalid inputted command or arguments."

#On creation:
func _ready() -> void:
	pass
