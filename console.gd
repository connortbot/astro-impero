extends Control

const log_clip = preload("res://Instances/Log_Instance.tscn")
onready var history_node = $Background/MarginContainer/SectionsContainer/History/ScrollContainer/VBoxHistory

export (int) var max_history := 30
onready var mainui = get_parent()
var max_scroll_length := 0
onready var scroll = $Background/MarginContainer/SectionsContainer/History/ScrollContainer
onready var scrollbar = scroll.get_v_scrollbar()
 
var query_data

var cache = {}

var saving = false

func scroll_changed():
	if max_scroll_length != scrollbar.max_value:
		max_scroll_length = scrollbar.max_value
		scroll.scroll_vertical = scrollbar.max_value

var full_planet_list = []
var autocomplete_database
#When created
signal com_response(input,response)
func _ready() -> void:
	Network.connect("calc_ship_movement",self,"calculated_ship_movement")
	Network.connect("immovable_ship",self,"immovable_ship")
	Network.connect("clear_history",self,"clear_history")
	scrollbar.connect("changed", self,"scroll_changed")
	self.connect("com_response",self,"command_response")
	Network.connect("release_console_focus",self,"rcf")
	#connect("com_response",self,"command_response")
	max_scroll_length = scrollbar.max_value
	
	for system in Database.GALACTIC_DATA.keys():
		for solar in Database.GALACTIC_DATA[system].keys():
			for object in Database.GALACTIC_DATA[system][solar].keys():
				if not "-" in object: #is a planet
					full_planet_list.append(object)
	#inspect,endturn,select,deselect,dispatch,q,deq,build,invade
	autocomplete_database = {
	"endturn": {},
	"inspect": {
		"solar": ["e.g 101, 102..."],
	},
	"select": {
		"solar": ["e.g 101, 102..."],
		"object_ids": ["1","2","...","infinity"]
	},
	"deselect": {},
	"dispatch": {
		"solar": ["e.g 101, 102..."]
	},
	"invade": {
		"planetname": full_planet_list
	},
	"q": {
		"ship_type": Database.SHIPS.keys()+Database.SUPPLIERS.keys(),
		"amount": [],
		"spawn_planet": full_planet_list
	},
	"deq": {
		"index": ["0","1","2","...","infinity"]
	},
	"build": {#build <type> <solarid> <planetname>
		"type": Database.BUILDINGS.keys(),
		"solar": ["e.g 101, 102..."],
		"planetname": full_planet_list
	},
}
func rcf():
	var inp = $Background/MarginContainer/SectionsContainer/InputContainer/HBoxContainer/Input
	inp.release_focus()

#Parses the total text and divides into the base command and their arguments
func parse_commands(input):
	var command_line = input.split(' ')
	var command = command_line[0]
	var args = []
	for i in command_line.size():
		if i > 0:
			args.append(command_line[i])
	var parsed_command = {
		"Command": command,
		"Arguments": args
	}
	return parsed_command

#### COMMANDS ####
func _on_Input_text_entered(input: String) -> void:
	if input.empty():
		return
	var parsed_command = parse_commands(input)
	calculate_response(parsed_command,input)

func command_response(input,response):
	var new_log = log_clip.instance()
	history_node.add_child(new_log)
	new_log.set_text(input,response)
	trim_history()

#inspect,endturn,select,deselect,dispatch,q,deq,build,invade
func calculate_response(parsed_command,input):
	#for commands that affect ships the sector_inspect_desc function should run
	var command = parsed_command["Command"]
	var args = parsed_command["Arguments"]
	#### INSPECT COMMAND ####
	if command == "inspect": #inspect <id>
		if args.size() > 1 or args.size() == 0:
			emit_signal("com_response",input,"")
			return #Says its invalid. Inspect should only have 1 argument
		var inspect_data
		if args[0].length() == 3:
			var id = int(args[0])
			for system in Database.GALACTIC_DATA.keys():
				for solar in Database.GALACTIC_DATA[system].keys():
					if solar == id:
						inspect_data = Database.GALACTIC_DATA[system][solar]
						print(inspect_data)
			mainui.sector_inspect_desc(str(id),inspect_data)
			emit_signal("com_response",input,"Intel Retrieved.")
			return
		else:
			emit_signal("com_response",input,"")
			return #Says its invalid. Inspect should only have 1 argument
	#### END TURN COMMAND ####
	elif command == "endturn":
		get_node("Background/MarginContainer/SectionsContainer/InputContainer/HBoxContainer/Input").release_focus()
		if Database.LOCAL_ID == 0:
			Network.next_player(Database.LOCAL_ID)
		else:
			Network.client.send_match_state({"SENDER_ID":Database.LOCAL_ID},6)
		emit_signal("com_response",input,"Ended turn.")
		return
	#### SELECT COMMAND ####
	elif command == "select":
		cache = {}
		if args.size() < 2:
			emit_signal("com_response",input,"")
			return
		var selected_solar = int(args[0])
		args.remove(0)
		#if selected_solar in cache:
		for select in args: #for each select
			#Find the system the inspect was in
			for system in Database.GALACTIC_DATA.keys():
				if selected_solar in Database.GALACTIC_DATA[system].keys(): #the inspected solar is in this system
					if not "-" in select: #just number ID
						var found_item = false
						for item in Database.GALACTIC_DATA[system][selected_solar].keys():
							if "-" in item:
								var select_tags = item.split("-")
								if select == select_tags[2]:
									if Database.GALACTIC_DATA[system][selected_solar][item]["OWNER"] == Network.active_id:
										if selected_solar in cache.keys():
											cache[selected_solar][item] = Database.GALACTIC_DATA[system][selected_solar][item]
										else:
											cache[selected_solar] = {}
											cache[selected_solar][item] = Database.GALACTIC_DATA[system][selected_solar][item]
										found_item = true
						if not found_item:
							emit_signal("com_response",input,"ID does not exist in specified location.")
							return
					#if theres a full id
					elif select in Database.GALACTIC_DATA[system][selected_solar]: #we found the select in this solar
						if Database.GALACTIC_DATA[system][selected_solar][select]["OWNER"] == Network.active_id: #we own this
							if selected_solar in cache.keys():
								cache[selected_solar][select] = Database.GALACTIC_DATA[system][selected_solar][select]
							else:
								cache[selected_solar] = {}
								cache[selected_solar][select] = Database.GALACTIC_DATA[system][selected_solar][select]
							break
						else:
							emit_signal("com_response",input,"Ship is not owned and cannot be selected.")
							return
					else:
						emit_signal("com_response",input,"Invalid selected ID.")
						return
		emit_signal("com_response",input,"Selected "+str(args.size())+" object(s).")
		return
	elif command == "deselect":
		cache = {}
		emit_signal("com_response",input,"Deselected all objects.")
		return
	#### DISPATCH COMMAND #### dispatch <solar>
	elif command == "dispatch":
		if args.size() < 1:
			emit_signal("com_response",input,"")
			return ""
		var selected_solar = args[0]
		for solar in cache.keys():
			for object in cache[solar].keys():
				var object_tags = object.split("-")
				if object_tags[0] == "SHIP":
					# This section determines the distance between the solars, the path, etc.
					var ship_speed = cache[solar][object]["SPEED"]
					var destination = [] #[system,0,solar spec]
					var start = []
					for i in selected_solar:
						destination.append(int(i))
					for i in str(solar):
						start.append(int(i))
					#Simpler option. Is the destination in the same solar? If so, its easy to calculate:
					var solar_range = []
					if destination[0] == start[0]: #same system
						if abs(destination[2]-start[2]) <= ship_speed:
							if start[2] > destination[2]:
								var s = range(int(selected_solar),solar)
								var i = s.size() - 1
								while i >= 0:
									solar_range.append(int(s[i]))
									i -= 1
							if destination[2] > start[2]:
								solar_range = range(solar,int(selected_solar))
								solar_range.remove(0)
								solar_range.append(int(selected_solar))
						else:
							emit_signal("com_response",input,"Solar is out of reach for "+object+"!")
							return
					else: #not same system
						if destination[0] in Database.SYSTEM_SIBLINGS[start[0]]: #neighbouring system
							#calculates the destinations distance to the border and the starts, adds them and sees if its a short enough distance
							if (abs(destination[2]-5)+abs(start[2]-5))+1 <= ship_speed:
								for s in range(solar,int(str(start[0])+"05")):
									solar_range.append(int(s))
								solar_range.append(int(str(start[0])+"05"))
								solar_range.append(int(str(destination[0])+"05"))
								var r = range(int(selected_solar),int(str(destination[0])+"05"))
								var i = r.size() - 1
								while i >= 0:
									solar_range.append(int(r[i]))
									i -= 1
							else:
								emit_signal("com_response",input,"Solar is out of reach for "+object+"!")
								return
						else:
							emit_signal("com_response",input,"Solar is out of reach for "+object+"!")
							cache = {}
							return
					Network.move_ship_along_path(solar,solar_range,int(selected_solar),object,input)
					print(cache)
				else:
					emit_signal("com_response",input,"Some of the selected objects are not moveable and remain in their original sector.")
					cache = {}
					return
		cache = {}
		return
	#### QUEUE COMMANDS ####
	elif command == "q": #<type> <amount> <spawn_planet>
		if args.size() < 3 or args.size() > 3:
			emit_signal("com_response",input,"")
			return
		var ship_type = args[0].to_upper()
		var amount = int(args[1])
		var spawn_planet = (args[2].to_lower()).capitalize()
		
		#i have no fucking clue what this does
		var valid = false
		for sys in Database.GALACTIC_DATA.keys():
			for sol in Database.GALACTIC_DATA[sys].keys():
				for obj in Database.GALACTIC_DATA[sys][sol].keys():
					if obj == spawn_planet:
						if Database.GALACTIC_DATA[sys][sol][obj]["Owner"] == Database.PLAYERS[Network.active_id][0]:
							valid = true
		if not valid:
			emit_signal("com_response",input,"This planet is not owned by the user.")
			return
		var available_slots =  Database.PRODUCTION_QUEUE[Network.active_id]["slots"]
		for product in Database.PRODUCTION_QUEUE[Network.active_id]["production"]:
			#[ship type, amount]
			if product[0] in Database.SHIPS.keys(): available_slots -= Database.SHIPS[product[0]]["REQUIRED_STATIONS"]
			elif product[0] in Database.SUPPLIERS.keys(): available_slots -= Database.SUPPLIERS[product[0]]["REQUIRED_STATIONS"]
		if available_slots <= 0:
			emit_signal("com_response",input,"Production queue is at full capacity.")
			return
		else: #available slots
			var requested_slots = 0
			if ship_type in Database.SHIPS.keys():
				requested_slots = Database.SHIPS[ship_type]["REQUIRED_STATIONS"]*amount
			elif ship_type in Database.SUPPLIERS.keys():
				requested_slots = Database.SUPPLIERS[ship_type]["REQUIRED_STATIONS"]*amount
			else: 
				emit_signal("com_response",input,"Invalid ship type.")
				return
			if available_slots < requested_slots:
				emit_signal("com_response",input,"There is not enough space in the production queue for this request.")
				return
			else:
				for product in Database.PRODUCTION_QUEUE[Network.active_id]["production"]:
					if product[0] == ship_type and product[2] == spawn_planet: #already this ship type in queue
						var ix = Database.PRODUCTION_QUEUE[Network.active_id]["production"].find(product,0)
						Database.PRODUCTION_QUEUE[Network.active_id]["production"][ix][1] = Database.PRODUCTION_QUEUE[Network.active_id]["production"][ix][1]+amount
						Network.packets.append("QQ-"+str(ix)+"-"+str(Network.active_id)+"-"+str(amount))
						emit_signal("com_response",input,"Added "+str(amount)+" of "+ship_type+" to production queue.")
						return
				Database.PRODUCTION_QUEUE[Network.active_id]["production"].append([ship_type,amount,spawn_planet])
				Network.packets.append("Q-"+str(Network.active_id)+"-"+str(ship_type)+"-"+str(amount)+"-"+str(spawn_planet))
				emit_signal("com_response",input,"Added "+str(amount)+" of "+ship_type+" to production queue.")
				return
	elif command == "deq": #<index>
		if args.size() < 1 or args.size() > 1:
			emit_signal("com_response",input,"")
			return
		var removed_ship_type = Database.PRODUCTION_QUEUE[Network.active_id]["production"][int(args[0])][0]
		var removed_queue_amount = Database.PRODUCTION_QUEUE[Network.active_id]["production"][int(args[0])][1]
		var ix
		for q in Database.PRODUCTION_QUEUE[Network.active_id]["active_production"]:
			if removed_ship_type == q[0]:
				ix = Database.PRODUCTION_QUEUE[Network.active_id]["active_production"].find(q)
		Network.packets.append("DEQ-"+str(Network.active_id)+"-"+str(ix)+"-"+str(args[0]))
		Database.PRODUCTION_QUEUE[Network.active_id]["production"].remove(args[0])
		Database.PRODUCTION_QUEUE[Network.active_id]["active_production"].remove(ix)
		emit_signal("com_response",input,"Removed "+str(removed_queue_amount)+" of "+removed_ship_type+" from production queue.")
		return
	#### BUILD COMMAND #### build <type> <solarid> <planetname>
	elif command == "build":
		if args.size() < 3 or args.size() > 3:
			emit_signal("com_response",input,"")
			return
		var id = int(args[1])
		args[0] = args[0].to_upper()
		args[2] = (args[2].to_lower()).capitalize()
		if args[0] in Database.BUILDINGS.keys(): #valid building type
			for system in Database.GALACTIC_DATA.keys():
				if id in Database.GALACTIC_DATA[system].keys(): #valid id in system
					for object in Database.GALACTIC_DATA[system][id].keys():
						if not "-" in object: #if there is no dash, its a planet
							if object == args[2]:
								if Database.GALACTIC_DATA[system][id][object]["Owner"] == Database.PLAYERS[Network.active_id][0]:
									if Network.turnLimits[0] > 0: 
										#playerid,systemid,solarid,planetname,building_type
										var attempted_build = Network.add_build_queue(Network.active_id,system,id,object,args[0])
										if attempted_build:
											Network.turnLimits[0] -= 1
											emit_signal("com_response",input,"Started building "+args[0]+" in "+args[2]+".")
											return
										else:
											emit_signal("com_response",input,"There are not enough available building slots in "+args[2]+".")
											return
									else:
										emit_signal("com_response",input,"Another building construction is already in progress.")
										return
								else:
									emit_signal("com_response",input,"The argued planet or solar is not controlled by the user.")
									return
		else:
			emit_signal("com_response",input,"Invalid building type.")
			return
	elif command == "invade": #invade <planetname>
		if args.size() < 1 or args.size() > 1:
			emit_signal("com_response",input,"No planet specified!")
			return
		var contested_planet = (args[0].to_lower()).capitalize()
		for system in Database.GALACTIC_DATA.keys():
			for solar in Database.GALACTIC_DATA[system].keys():
				for object in Database.GALACTIC_DATA[system][solar].keys():
					if contested_planet == object: #this is the planet we're invading
						if Database.GALACTIC_DATA[system][solar][contested_planet]["Owner"] != Database.PLAYERS[Network.active_id][0]: #we own this planet already
							if solar in cache.keys(): #if there's selected ships where the planet is
								if Database.GALACTIC_DATA[system][solar][contested_planet]["Owner"] == "":
									emit_signal("com_response",input,"Colonized "+contested_planet+". Buildings can now be constructed here.")
									Network.packets.append("STAT-"+str(contested_planet)+"-Owner-"+str(Database.PLAYERS[Network.active_id][0])+"-str")
									Database.GALACTIC_DATA[system][solar][contested_planet]["Owner"] = Database.PLAYERS[Network.active_id][0]
									return
								var invading_shipsIDs = []
								for ship in cache[solar]:
									invading_shipsIDs.append(ship)
								if contested_planet in Database.LAND_QUEUE.keys(): #there's already an invasion happening
									Network.join_land_battle(solar,contested_planet,invading_shipsIDs)
									cache = {}
									emit_signal("com_response",input,"Reinforcements joining The Siege of "+contested_planet+".")
								else:
									Network.start_land_battle(solar,contested_planet,invading_shipsIDs)
									cache = {}
									emit_signal("com_response",input,"The Siege of "+contested_planet+" has begun.")
									Network.client.send_match_state({"SENDER_ID":Database.LOCAL_ID,"MESSAGE":contested_planet+" is being invaded."},7)
							else:
								emit_signal("com_response",input,"Selected ships are not in the area!")
								return
						else:
							emit_signal("com_response",input,"You already control this planet!")
							return
#Trims the amount of log lines in the console to the max amount
func trim_history():
	if history_node.get_child_count() > max_history:
		var rows_to_forget = history_node.get_child_count() - max_history
		for i in range(rows_to_forget):
			history_node.get_child(i).queue_free()
func clear_history():
	for i in history_node.get_children():
		i.queue_free()
func calculated_ship_movement(input,shipID,arrived_sector):
	emit_signal("com_response",input,shipID+" dispatched to Sector "+str(arrived_sector)+".")
func immovable_ship(input,shipID):
	emit_signal("com_response",input,shipID+" has already been moved this turn.")




onready var autocomplete = $Autocomplete
onready var label = load("res://Instances/AutocompleteLabel.tscn")
onready var arg_name = $Autocomplete/MarginContainer/VBoxContainer/arg_name
var possible_options = []
func add_to_autocomplete_list(text):
	var new_label = label.instance()
	new_label.text = str(text)
	possible_options.append(str(text))
	autocomplete.get_node("MarginContainer/VBoxContainer").add_child(new_label)
func remove_from_autocomplete_list(text):
	for child in autocomplete.get_node("MarginContainer/VBoxContainer").get_children():
		if child.text == text:
			child.queue_free()
func _on_Input_text_changed(new_text: String) -> void:
	autocomplete.visible = true
	for child in autocomplete.get_node("MarginContainer/VBoxContainer").get_children():
		if child.name != "arg_name":
			child.queue_free()
	var num_of_words = new_text.split(" ").size()
	var command = new_text.split(" ")[0]
	if num_of_words == 0:
		arg_name.text = "<command>"
		for cmd in autocomplete_database.keys():
			add_to_autocomplete_list(cmd)
	var current_word = new_text.split(" ")[num_of_words-1]
	if num_of_words == 1: #initial command
		arg_name.text = "<command>"
		autocomplete.rect_position.x = 60
		possible_options = []
		for cmd in autocomplete_database.keys():
			add_to_autocomplete_list(cmd)
		for word in possible_options:
			if not word.begins_with(current_word):
				remove_from_autocomplete_list(word)
	else:
		var p = 0 #length of newtext before this new currently typed out argument
		var words = new_text.split(" ")
		for num in range(num_of_words-1):
			p += words[num].length()
		autocomplete.rect_position.x = 60 + 12*p + 12*(num_of_words-1) 
		possible_options = []
		if command in autocomplete_database.keys():
			var args_list = autocomplete_database[command].keys()
			if args_list.size() >= num_of_words-1:
				arg_name.text = "<"+str(autocomplete_database[command].keys()[num_of_words-2])+">"
				for arg_option in autocomplete_database[command][args_list[num_of_words-2]]:
					add_to_autocomplete_list(arg_option)
				for word in possible_options:
					if not word.begins_with(current_word):
						remove_from_autocomplete_list(word)
			else:
				arg_name.text = "<no more arguments required>"
var expand = false
func _process(delta: float) -> void:
	var inp = $Background/MarginContainer/SectionsContainer/InputContainer/HBoxContainer/Input
	autocomplete.rect_size.y = autocomplete.rect_min_size.y
	autocomplete.rect_position.y = rect_size.y-130-26*(autocomplete.get_node("MarginContainer/VBoxContainer").get_children().size()-1)
	if Input.is_action_pressed("escape"):
		autocomplete.visible=false
	if Input.is_action_just_pressed("tab"):
		if autocomplete.get_node("MarginContainer/VBoxContainer").get_children().size() == 2: 
			#only one possibility
			var label
			for bruh in autocomplete.get_node("MarginContainer/VBoxContainer").get_children():
				if bruh.name != "arg_name":
					label = bruh
			#make sure we haven't already typed it out...
			var w = inp.text.split(" ")
			if not label.text == w[w.size()-1]:
				var words = inp.text.split(" ")
				words.remove((words.size()-1))
				inp.text = ""
				if words:
					for word in words:
						inp.text = word+" "
				inp.text = inp.text+label.text
			inp.grab_focus()
			inp.caret_position = inp.text.length()
	if get_focus_owner() == inp:
		if Input.is_action_just_pressed("up_arrow"):
			expand = true
		if Input.is_action_just_pressed("down_arrow"):
			expand = false
	if expand: 
		rect_size.y = lerp(rect_size.y,560,10*delta)
		rect_position.y = lerp(rect_position.y,20,10*delta)
	else:
		rect_size.y = lerp(rect_size.y,180,10*delta)
		rect_position.y = lerp(rect_position.y,500,10*delta)
	
