extends Node

#AUTOLOADED ON START as "Network"

signal server_created(username)
signal player_joined(id,username)
signal remove_client(id)
signal client_planet_selection(planetname,usern,desel)

signal log_update(text)

signal start_game_org()

var client: Node


## VAR: packets
# => Lists of packets that main_loop sends out at regular intervals
# => Packets are in the form of: "PKGTYPE-data"
# ====> PKGTYPE: STAT-ID-statname-newvalue-int/float/string
# ====> PKGTYPE: B/LERASE-shipID
# ====> PKGTYPE: MOVE_SHIP-start-destination-shipid
# ====> PKGTYPE: START_BATTLE-solar
# ====> PKGTYPE: JOIN_BATTLE-solar-shipID
# ====> PKGTYPE: QQ-proddex-activeID-amount
# ====> PKGTYPE: Q-ACTIVEID-shiptype-amount-spawnsolar
# ====> PKGTYPE: DEQ-activeID-active_index-index
# ====> PKGTYPE: BQ-playerid-systemid-solarid-planetname-buildingtype
var packets = []

var loop = 0
func _process(delta: float) -> void:
	if loop == 10:
		if packets.size() > 0:
			print("PACKET SEND")
			print(packets)
			var pkg = packets[0]
			packets.pop_front()
			print(packets)
			client.send_match_state({"SENDER_ID": Database.LOCAL_ID,"HASH": pkg},11)
		loop = 0
	loop += 1

func parse_packet(pkg):
	print(typeof(pkg))
	if typeof(pkg) == TYPE_ARRAY:
		var s
		for sys in Database.GALACTIC_DATA.keys():
			for solar in Database.GALACTIC_DATA[sys].keys():
				for obj in Database.GALACTIC_DATA[sys][solar].keys():
					if obj == pkg[1]:
						s = solar
		if pkg[0] == "LB/S":
			start_land_battle(s,pkg[1],pkg[2])
		elif pkg[0] == "LB/J":
			join_land_battle(s,pkg[1],pkg[2])
	elif typeof(pkg) == TYPE_STRING:
		var tags = pkg.split("-")
		if tags[0] == "STAT":
			if tags[4] == "float": tags[3] = float(tags[3])
			elif tags[4] == "int": tags[3] = int(tags[3])
			elif tags[4] == "str": tags[3] = str(tags[3])
			for sys in Database.GALACTIC_DATA.keys():
				for solar in Database.GALACTIC_DATA[sys].keys():
					for obj in Database.GALACTIC_DATA[sys][solar].keys():
						if obj == tags[1]:
							Database.GALACTIC_DATA[sys][solar][obj][tags[2]] = tags[3]
							return
		elif "/" in tags[0]:
			if tags[0].split("/")[1] == "ERASE":
				if tags[0].split("/")[0] == "B":
					for b in Database.BATTLE_QUEUE.keys():
						for solar in Database.BATTLE_QUEUE[b].keys():
							for side in Database.BATTLE_QUEUE[b][solar].keys():
								for ship in Database.BATTLE_QUEUE[b][solar].keys():
									if ship == tags[1]:
										Database.BATTLE_QUEUE[b][solar][side].erase(ship)
										return
				elif tags[0].split("/")[0] == "L":
					for p in Database.LAND_QUEUE.keys():
						if tags[1] in Database.LAND_QUEUE[p][0]:
							Database.LAND_QUEUE[p][0].erase(tags[1])
							return
		elif tags[0] == "MOVE_SHIP":
			tags[3] = tags[3].replace("/","-")
			InventoryManager.move_ship(int(tags[1]),int(tags[2]),tags[3],true)
			return
		elif tags[0] == "JOIN_BATTLE":
			Network.join_battle(int(tags[1]),tags[2])
			return
		elif tags[0] == "START_BATTLE":
			Network.start_battle(int(tags[1]))
			return
		elif tags[0] == "QQ":
			Database.PRODUCTION_QUEUE[int(tags[2])]["production"][int(tags[1])][1] = Database.PRODUCTION_QUEUE[int(tags[2])]["production"][int(tags[1])][1]+int(tags[3])
			return
		elif tags[0] == "Q":
			Database.PRODUCTION_QUEUE[int(tags[1])]["production"].append([tags[2],int(tags[3]),tags[4]])
			return
		elif tags[0] == "DEQ":
			Database.PRODUCTION_QUEUE[int(tags[1])]["production"].remove(int(tags[3]))
			Database.PRODUCTION_QUEUE[int(tags[1])]["active_production"].remove(int(tags[2]))
			return
		elif tags[0] == "BQ":
			add_build_queue(int(tags[1]),int(tags[2]),int(tags[3]),tags[4],tags[5])
			return
	print("ERR: INVALID PKG")



signal start_loaded_game
var main_scene = preload("res://Main.tscn")

## (start_loading_game): Adds the main scene and gets the client variable.
# @param - none
# => USER: host/client
# => RESULT: Calls start_game_org() on both
func start_loading_game():
	get_tree().get_root().add_child(main_scene.instance())
	client = get_tree().get_root().get_child(3).get_child(1)
	emit_signal("start_game_org")


#### GAME STATES ####
signal win_screen(winnerid)
func check_for_losers(possible_loser_ID,possible_loser_username):
	var wiped_out = true
	for system in Database.GALACTIC_DATA.keys():
		for solar in Database.GALACTIC_DATA[system].keys():
			for object in Database.GALACTIC_DATA[system][solar].keys():
				var object_tags = object.split("-")
				if not "-" in object: #object is a planet
					if Database.GALACTIC_DATA[system][solar][object]["Owner"] == possible_loser_username:
						wiped_out = false
						break
	if wiped_out:
		var winnerID = 0
		if possible_loser_ID == active_id:
			emit_signal("log_update","You no longer control any more territory, and have lost.")
			if active_id == 0: # 1 was the winner
				emit_signal("log_update",Database.PLAYERS[1][0]+" has conquered all other empires!")
			else:
				emit_signal("log_update",Database.PLAYERS[0][0]+" has conquered all other empires!")
			if active_id == 0: winnerID = 1
			if active_id == 1: winnerID = 0
		else: #the winner is currently active
			emit_signal("log_update","You conquered all other empires!")
			if active_id == 0: # 0 was the winner
				emit_signal("log_update",Database.PLAYERS[0][0]+" has conquered all other empires!")
			else:
				emit_signal("log_update",Database.PLAYERS[1][0]+" has conquered all other empires!")
			winnerID = active_id
		emit_signal("win_screen",winnerID)
		get_tree().get_root().get_child(5).deactivate_console()
### UPDATING FUNCTIONS ###
#Manages resources amount, connected to ResourcesPanel script
signal update_stats(id,amount,type)
remotesync func update_inv(id,amount,type):
	emit_signal("update_stats",id,amount,type)
#Manages resources display gui, connected to ResourcesPanel script
signal update_cells(amount,type)
remotesync func update_cells(amount,type):
	emit_signal("update_cells",amount,type)

#### INVENTORY FUNCTIONS ####
#Adds a building, connected to InventoryManager script.
signal add_client_building(playerid,type,planetname)
remotesync func add_client_building(playerid,type,planetname):
	emit_signal("add_client_building",playerid,type,planetname)
#Adds a ship, connected to InventoryManager script.
signal add_new_ship(quadrant,system,planet,type,id)
remotesync func add_new_ship(quadrant,system,planet,type,id):
	emit_signal("add_new_ship",quadrant,system,planet,type,id)
signal add_new_supplier(playerid,type,supplyhub_id)
remotesync func add_new_supplier(playerid,type,supplyhub_id):
	emit_signal("add_new_supplier",playerid,type,supplyhub_id)
remotesync func change_planet_owner(system,solar,planetname,username):
	if get_tree().is_network_server():
		InventoryManager.change_planet_owner(system,solar,planetname,username)
	
#### PLAYER QUEUE FUNCTIONS ####
func add_build_queue(playerid,systemid,solarid,planetname,building_type):
	packets.append("BQ-"+str(playerid)+"-"+str(systemid)+"-"+str(solarid)+"-"+str(planetname)+"-"+str(building_type))
	if Database.GALACTIC_DATA[systemid][solarid][planetname]["building_slots"] > 0: #open slot
		if not building_type in Database.PLAYER_QUEUE[playerid].keys():
			Database.PLAYER_QUEUE[playerid][building_type] = [Database.global_turn_counter,planetname]
			Database.GALACTIC_DATA[systemid][solarid][planetname]["building_slots"] -= 1
			return true
		else:
			var num = 0
			for q in Database.PLAYER_QUEUE[playerid].keys():
				if "&" in q:
					var tags = q.split("&")
					if tags[0] == building_type:
						num += 1
				else:
					if q == building_type:
						num += 1
			Database.GALACTIC_DATA[systemid][solarid][planetname]["building_slots"] -= 1
			Database.PLAYER_QUEUE[playerid][building_type+"&"+str(num)] = [Database.global_turn_counter,planetname]
			return true
	else:
		return false

signal calc_ship_movement(input,shipID,arrived_sector)	
signal immovable_ship(input,shipID)
signal refresh_map
func move_ship_along_path(start,solar_range,destination_solar,shipID,input):
	var arrived_with_no_complications = true
	var moveable = true
	for sys in Database.GALACTIC_DATA.keys():
		if start in Database.GALACTIC_DATA[sys].keys():
			if Database.GALACTIC_DATA[sys][start][shipID]["MOVEABLE"]:
				moveable = true
			else:
				moveable = false
	if moveable:
		#Check if the moved ship is in a battle
		var ship_tags = shipID.split("-")
		var battling_ships = {}
		var retreated: bool = false
		for battle in Database.BATTLE_QUEUE.keys():
			for side in Database.BATTLE_QUEUE[battle].keys():
				for ship in Database.BATTLE_QUEUE[battle][side].keys():
					battling_ships[ship] = [Database.BATTLE_QUEUE[battle][side][ship]["HEALTH"],Database.BATTLE_QUEUE[battle][side][ship]["MAX_HEALTH"]]
		if shipID in battling_ships.keys(): #the selected ship was battling
			var ship_health_percentage = float(battling_ships[shipID][0]/battling_ships[shipID][1])
			#Inflict "Damaged" penalty in galactic_data
			emit_signal("log_update",ship_tags[1]+" was ordered to retreat from battle and were damaged. Repairs are needed.")
			Database.GALACTIC_DATA[int(str(start)[0])][start][shipID]["MAX_HEALTH"] = Database.GALACTIC_DATA[int(str(start)[0])][start][shipID]["MAX_HEALTH"]*ship_health_percentage
			Database.GALACTIC_DATA[int(str(start)[0])][start][shipID]["HEALTH"] = Database.GALACTIC_DATA[int(str(start)[0])][start][shipID]["HEALTH"]*ship_health_percentage
			packets.append(str(shipID)+"-MAX_HEALTH-"+str(Database.GALACTIC_DATA[int(str(start)[0])][start][shipID]["MAX_HEALTH"]*ship_health_percentage)+"-float")
			packets.append(str(shipID)+"-HEALTH-"+str(Database.GALACTIC_DATA[int(str(start)[0])][start][shipID]["HEALTH"]*ship_health_percentage)+"-float")
			#erase from battles
			for battle in Database.BATTLE_QUEUE.keys():
				for side in Database.BATTLE_QUEUE[battle].keys():
					for ship in Database.BATTLE_QUEUE[battle][side].keys():
						if ship == shipID:
							Database.BATTLE_QUEUE[battle][side].erase(ship)
							packets.append("B/ERASE-"+str(ship))
							for landbattle in Database.LAND_QUEUE.keys():
								if ship in Database.LAND_QUEUE[landbattle][0]:
									Database.LAND_QUEUE[landbattle][0].erase(ship)
									packets.append("L/ERASE-"+str(ship))
			retreated = true
		for pathpoint in solar_range:
			for system in Database.GALACTIC_DATA.keys():
				for solar in Database.GALACTIC_DATA[system].keys():
					if solar == pathpoint:
						for object in Database.GALACTIC_DATA[system][solar].keys():
							var object_tags = object.split("-")
							if object_tags[0] == "SHIP": #this is another ship
								if Database.GALACTIC_DATA[system][solar][object]["OWNER"] != active_id:
									#we don't own this other ship in here
									arrived_with_no_complications = false
									emit_signal("calc_ship_movement",input,shipID,solar)
									InventoryManager.move_ship(start,solar,shipID,false)
									if solar in Database.BATTLE_QUEUE: #there's already a battle happening here
										join_battle(solar,shipID)
										emit_signal("log_update","Joining ongoing battle detected in Sector "+str(solar)+".")
										client.send_match_state({"SENDER_ID": Database.LOCAL_ID,"MESSAGE":"An enemy ship joins the battle in Sector "+str(solar)+"!"},7)
										return
									else:
										start_battle(solar)
										emit_signal("refresh_map")
										emit_signal("log_update","!! ENEMY ENCOUNTERED IN SECTOR "+str(solar)+" !!")
										client.send_match_state({"SENDER_ID": Database.LOCAL_ID,"MESSAGE":"!! ENEMY ENCOUNTERED IN SECTOR "+str(solar)+" !!"},7)
										return
		if arrived_with_no_complications:
			InventoryManager.move_ship(start,destination_solar,shipID,false)
			emit_signal("calc_ship_movement",input,shipID,destination_solar)
			return
	else:
		emit_signal("immovable_ship",input,shipID)
		return


#### TURN SYSTEM ####
signal refresh_ui(aID)
func buildLimit():
	turnLimits[0] -= 1

var turnLimits = [1,0] #1 build per turn, ships production limit, 
signal clear_history

## (next_turn) Mass updates the entire game state, proceeding to the next turn.
# @param - active_id: the active player ID
# @param - active_username: the active player username
# => USER: host
# => RESULT: Updates match state and turn limits
func next_turn(active_id,active_username): #executed when a player ends their turn
	emit_signal("clear_history")
	emit_signal("refresh_ui",active_id)
	turnLimits = [1,0] #reset
	#### FIND NUMBER OF MILITARY STATIONS ####
	for system in Database.GALACTIC_DATA.keys():
			for solar in Database.GALACTIC_DATA[system].keys():
				for object in Database.GALACTIC_DATA[system][solar].keys():
					if not "-" in object: #if its a planet
						for building in Database.GALACTIC_DATA[system][solar][object].keys():
							if building != "Owner" and building != "building_slots":
								#if building
								var building_tags = building.split("-")
								
								if building_tags[1] == "MILITARY_STATION" and Database.GALACTIC_DATA[system][solar][object][building]["OWNER"]==active_id:
									turnLimits[1] += 1
	Database.PRODUCTION_QUEUE[active_id]["slots"] = turnLimits[1]
	if active_id == 0: #new round of turns
		Database.global_turn_counter += 1
	var turncounter = Database.global_turn_counter
	var msg = "Turn "+str(turncounter)+": "+"<< "+Database.USERNAMES[active_id]+"'s turn! >>"
	emit_signal("log_update",msg)
	client.send_match_state({"SENDER_ID": Database.LOCAL_ID,"MESSAGE":msg},7)
	resolve_supply_system() #updates supply_system, using galactic data
	resolve_battles(active_id) #updates battle_Queue, land_queue, uses supply system, galactic data
	resolve_player_queue(active_id)  #updates player queue, production queue, galactic data using battle queue
	resolve_resources(active_id)  #updates players, using galactic data, battle queue, supply system
	resolve_repairs_and_moves() #updates galactic data, using galactic data, battle queue, players
	emit_signal("refresh_ui",active_id)
	client.send_match_state({},10)

func deterministicTurnUpdate():
	if active_id == 0:
		Database.global_turn_counter += 1
	resolve_supply_system() #updates supply_system, using galactic data
	resolve_battles(active_id) #updates battle_Queue, land_queue, uses supply system, galactic data
	resolve_player_queue(active_id)  #updates player queue, production queue, galactic data using battle queue
	resolve_resources(active_id)  #updates players, using galactic data, battle queue, supply system
	resolve_repairs_and_moves() #updates galactic data, using galactic data, battle queue, players
	emit_signal("refresh_ui",active_id)

signal activate_console
signal deactivate_console 
var active_id

## (next_player) Starts the next turn cycle
# @param - ender_id: ID of the player ending their turn
# => USER: host
# => RESULT: Calls next_turn function and changes active_id on client side
func next_player(ender_id):
	if active_id == 0: active_id = 1
	else: active_id = 0
	client.send_match_state({"ACTIVE_ID":active_id},8)
	next_turn(active_id,Database.PLAYERS[active_id][0])

func resolve_supply_system():
	var p1_quota = 0
	var p2_quota = 0
	var p1_score = 0
	var p2_score = 0
	var p1_supplyloss = 0.0
	var p2_supplyloss = 0.0
	var supplyloss = true
	#for number of battles, increase base supply loss
	if Database.BATTLE_QUEUE.keys().size() > 0 and Database.BATTLE_QUEUE.keys().size() <= 2:
		p1_supplyloss += 0.05
		p2_supplyloss += 0.05
	elif Database.BATTLE_QUEUE.keys().size() > 2 and Database.BATTLE_QUEUE.keys().size() <= 5:
		p1_supplyloss += 0.1
		p2_supplyloss += 0.1
	elif Database.BATTLE_QUEUE.keys().size() > 5:
		p1_supplyloss += 0.3
		p2_supplyloss += 0.3
	else: #no battles
		supplyloss = false
	for system in Database.GALACTIC_DATA.keys():
		for solar in Database.GALACTIC_DATA[system].keys():
			for object in Database.GALACTIC_DATA[system][solar].keys():
				var object_tags = object.split("-")
				#set supplier score
				if object_tags[0] == "SHIP":
					if Database.GALACTIC_DATA[system][solar][object]["OWNER"] == 0:
						p1_quota += Database.GALACTIC_DATA[system][solar][object]["FUEL_USAGE"]+Database.GALACTIC_DATA[system][solar][object]["ENERGY_USAGE"]+Database.GALACTIC_DATA[system][solar][object]["REPAIR_METAL_USAGE"]
					else:
						p2_quota += Database.GALACTIC_DATA[system][solar][object]["FUEL_USAGE"]+Database.GALACTIC_DATA[system][solar][object]["ENERGY_USAGE"]+Database.GALACTIC_DATA[system][solar][object]["REPAIR_METAL_USAGE"]
				#account for supply loss negation
				if object_tags[0] == "SUPPLIER":
					if Database.GALACTIC_DATA[system][solar][object]["DEFENDER"]:
						if Database.GALACTIC_DATA[system][solar][object]["OWNER"] == 0:
							p1_supplyloss -= Database.GALACTIC_DATA[system][solar][object]["SUPPLY_LOSS_NEGATION"]
						else:
							p2_supplyloss -= Database.GALACTIC_DATA[system][solar][object]["SUPPLY_LOSS_NEGATION"]
				#find supplier score
					if not Database.GALACTIC_DATA[system][solar][object]["DEFENDER"]:
						if Database.GALACTIC_DATA[system][solar][object]["OWNER"] == 0:
							p1_score += Database.GALACTIC_DATA[system][solar][object]["SUPPLIER_SCORE"]
						else:
							p2_score += Database.GALACTIC_DATA[system][solar][object]["SUPPLIER_SCORE"]
	Database.SUPPLY_SYSTEM[0]["QUOTA"] = p1_quota
	Database.SUPPLY_SYSTEM[1]["QUOTA"] = p2_quota
	Database.SUPPLY_SYSTEM[0]["SUPPLIER_SCORE"] = p1_score
	Database.SUPPLY_SYSTEM[1]["SUPPLIER_SCORE"] = p2_score
	Database.SUPPLY_SYSTEM[0]["SUPPLY_LOSS"] = p1_supplyloss
	Database.SUPPLY_SYSTEM[1]["SUPPLY_LOSS"] = p2_supplyloss
	
func resolve_player_queue(id):
	var current_turn = Database.global_turn_counter
	#### RESOLVE BUILDING ####
	for queue in Database.PLAYER_QUEUE[id].keys():
		var building_type = ""
		if "&" in queue:
			var tags = queue.split("&")
			building_type = tags[0]
		else: building_type = queue
		if building_type in Database.BUILDINGS.keys():
			if (current_turn-Database.PLAYER_QUEUE[id][queue][0]) == Database.BUILDINGS[building_type]["BUILD_TIME"]:
				emit_signal("log_update",building_type+" finished building on "+Database.PLAYER_QUEUE[id][queue][1]+".")
				InventoryManager.add_building(id,building_type,Database.PLAYER_QUEUE[id][queue][1])
				Database.PLAYER_QUEUE[id].erase(queue)
				if building_type == "MILITARY_STATION":
					Database.PRODUCTION_QUEUE[id]["slots"] = Database.PRODUCTION_QUEUE[id]["slots"]+1
			else:
				emit_signal("log_update",building_type+" will be finished in "+str((Database.BUILDINGS[building_type]["BUILD_TIME"])-(current_turn-Database.PLAYER_QUEUE[id][queue][0]))+" turns.")
	#### RESOLVE PRODUCTION ####
	#Checks if we have too little military stations for the production queue
	#if so, remove
	var available_production_slots = Database.PRODUCTION_QUEUE[id]["slots"]
	for product in Database.PRODUCTION_QUEUE[id]["production"]:
		if product[0] in Database.SHIPS.keys():
			available_production_slots -= Database.SHIPS[product[0]]["REQUIRED_STATIONS"]
		elif product[0] in Database.SUPPLIERS.keys():
			available_production_slots -= Database.SUPPLIERS[product[0]]["REQUIRED_STATIONS"]
	var ineligible_queues = []
	if available_production_slots < 0:
		var queue_short_enough: bool = false
		for product in Database.PRODUCTION_QUEUE[id]["production"]:
			if not queue_short_enough:
				available_production_slots = Database.PRODUCTION_QUEUE[id]["slots"]
				Database.PRODUCTION_QUEUE[id]["production"].erase(product)
				ineligible_queues.append([product[0],product[2]])
				for pr in Database.PRODUCTION_QUEUE[id]["production"]:
					available_production_slots -= Database.SHIPS[pr[0]]["REQUIRED_STATIONS"]
				if available_production_slots >= 0: #we've removed enough
					queue_short_enough = true
		emit_signal("log_update","Production queue has been edited to account for lack of capacity.")
	#Removes entry from active production in case lost military stations cancelled them
	for product in Database.PRODUCTION_QUEUE[id]["active_production"]:
		for product2 in ineligible_queues:
			if product[0] == product2[0] and product[2] == product[2]: #this entry in active prod was removed due to exceeding capacity
				Database.PRODUCTION_QUEUE[id]["active_production"].erase(product)
				emit_signal("log_update","Cancelled production of "+product[0]+".")
	#spawn ships if they're done
	for product in Database.PRODUCTION_QUEUE[id]["active_production"]:
		#[shiptype,turn started,spawn planet,amount]
		var spawn = false
		var type = 0
		if product[0] in Database.SHIPS.keys():
			if (current_turn-product[1]) == Database.SHIPS[product[0]]["REQUIRED_TURNS"]: #done ship!
				spawn = true
		elif product[0] in Database.SUPPLIERS.keys():
			if (current_turn-product[1]) == Database.SUPPLIERS[product[0]]["REQUIRED_TURNS"]: #done ship!
				spawn = true
				type = 1
		if spawn:
			for i in range(product[3]):
				#find the solar the planet resides in
				var spawn_solar = 0
				for sector in Database.GALACTIC_DATA.keys():
					for solar in Database.GALACTIC_DATA[sector].keys():
						for object in Database.GALACTIC_DATA[sector][solar].keys():
							if object == product[2]:
								spawn_solar = solar
				if type == 0:
					var enemy_in_solar = false
					var new_ship_id = "SHIP-"+product[0]+"-"+str(Database.global_id_counter)
					InventoryManager.add_ship(id,product[0],spawn_solar)
					if spawn_solar in Database.BATTLE_QUEUE.keys():
						join_battle(spawn_solar,new_ship_id)
						emit_signal("log_update","Newly built ship joining ongoing battle detected in Sector "+str(spawn_solar)+".")
					else: #no battle here yet, check if enemies in solar
						for sys in Database.GALACTIC_DATA.keys():
							for sol in Database.GALACTIC_DATA[sys].keys():
								if sol == spawn_solar:
									for obj in Database.GALACTIC_DATA[sys][sol].keys():
										var obj_tags = obj.split("-")
										if obj_tags[0] == "SHIP":
											if Database.GALACTIC_DATA[sys][sol][obj]["OWNER"] != id: #dont own ship
												enemy_in_solar = true
					if enemy_in_solar:
						start_battle(spawn_solar)
						emit_signal("refresh_map")
						emit_signal("log_update","!! ENEMY ENCOUNTERED IN SECTOR "+str(spawn_solar)+" !!")
				else:
					InventoryManager.add_supplier(id,product[0],spawn_solar)
				emit_signal("log_update","Finished production on "+str(product[3])+" "+product[0]+"(s).")
				Database.PRODUCTION_QUEUE[id]["active_production"].erase(product)
	for product in Database.PRODUCTION_QUEUE[id]["production"]:#[ship type, amount,spawnplanet]
		var active = false
		for product2 in Database.PRODUCTION_QUEUE[id]["active_production"]:
			if product[0] == product2[0] and product[2] == product[2]:
				active = true
		if not active:
			#this entry in production is not active!
			Database.PRODUCTION_QUEUE[id]["active_production"].append([product[0],current_turn,product[2],product[1]])
			emit_signal("log_update","Started production on "+str(product[1])+" "+product[0]+"(s).")
func resolve_resources(id): 
	var fuel_change = 0
	var metals_change = 0
	var energy_change = 0
	var supplyoutput = 0.0 #supply score fulfillment
	if float(Database.SUPPLY_SYSTEM[id]["QUOTA"]) != 0.0:
		supplyoutput = float(Database.SUPPLY_SYSTEM[id]["SUPPLIER_SCORE"])/float(Database.SUPPLY_SYSTEM[id]["QUOTA"])
	else:
		supplyoutput = 10.0
	if not supplyoutput < 1.0:
		supplyoutput = 1.0
	#Adds resources for every fuel mine, metals mine, etc
	#Removes resources for every running ship (even if they aren't fully supplied)
	for system in Database.GALACTIC_DATA.keys():
		for solar in Database.GALACTIC_DATA[system].keys():
			for object in Database.GALACTIC_DATA[system][solar].keys():
				var object_tags = object.split("-")
				if object_tags[0] != "SHIP":
					for building in Database.GALACTIC_DATA[system][solar][object].keys(): #for each thing on planet
						object_tags = building.split("-")
						if object_tags[0] == "BUILDING":
							if object_tags[1] == "FUEL_MINE":
								if Database.GALACTIC_DATA[system][solar][object][building]["OWNER"] == id: #if this player owns the mine
									fuel_change += 1200
							if object_tags[1] == "ENERGY_MINE":
								if Database.GALACTIC_DATA[system][solar][object][building]["OWNER"] == id:
									energy_change += 800
							if object_tags[1] == "METALS_MINE":
								if Database.GALACTIC_DATA[system][solar][object][building]["OWNER"] == id:
									metals_change += 100
				else: #is a ship
					if Database.GALACTIC_DATA[system][solar][object]["OWNER"] == id:
						energy_change -= Database.SHIPS[object_tags[1]]["ENERGY_USAGE"]*supplyoutput
						fuel_change -= Database.SHIPS[object_tags[1]]["FUEL_USAGE"]*supplyoutput
	for solar in Database.BATTLE_QUEUE.keys():
		for side in Database.BATTLE_QUEUE[solar].keys():
			for ship in Database.BATTLE_QUEUE[solar][side].keys():
				if Database.BATTLE_QUEUE[solar][side][ship]["OWNER"] == Network.active_id:
					metals_change -= Database.BATTLE_QUEUE[solar][side][ship]["REPAIR_METAL_USAGE"]*supplyoutput
	emit_signal("update_stats",id,metals_change,"metals")
	emit_signal("update_stats",id,fuel_change,"fuel")
	emit_signal("update_stats",id,energy_change,"energy")
	emit_signal("log_update","Industrial reports indicate a metals change of: "+str(metals_change)+".")
	emit_signal("log_update","Industrial reports indicate a fuel change of: "+str(fuel_change)+".")
	emit_signal("log_update","Industrial reports indicate an energy change of: "+str(energy_change)+".")


## (resolve_battles) Resolves battles and corresponding stats per turn
# @param - active_id: active player ID
# => USER: host/client
# => RESULT: Updates BATTLE_QUEUE, SUPPLY_SYSTEM
func resolve_battles(active_id):
	#### SUPPLY PENALTY ####
	var p1_supply_output
	var p2_supply_output
	if float(Database.SUPPLY_SYSTEM[0]["QUOTA"]) != 0.0:
		p1_supply_output = float(Database.SUPPLY_SYSTEM[0]["SUPPLIER_SCORE"])/float(Database.SUPPLY_SYSTEM[0]["QUOTA"])
	else:
		p1_supply_output = 10.0
	if float(Database.SUPPLY_SYSTEM[1]["QUOTA"]) != 0.0:
		p2_supply_output = float(Database.SUPPLY_SYSTEM[1]["SUPPLIER_SCORE"])/float(Database.SUPPLY_SYSTEM[1]["QUOTA"])
	else:
		p2_supply_output = 10.0
	var p1_supply_modifier = 1.0
	var p2_supply_modifier = 1.0
	if p1_supply_output < 1.0: #penalty
		p1_supply_modifier = (1.0-p1_supply_output)
	elif p1_supply_output > 1.0:
		p1_supply_modifier = p1_supply_output*0.1
	if p2_supply_output < 1.0: #penalty
		p2_supply_modifier = (1.0-p2_supply_output)
	elif p2_supply_output > 1.0:
		p2_supply_modifier = p2_supply_output*0.1
	#### NAVAL BATTLES ####
	for battle in Database.BATTLE_QUEUE.keys():
		var sidesID = []
		for side in Database.BATTLE_QUEUE[battle].keys():
			sidesID.append(side)
		var side1ATK = 0
		var side2ATK = 0
		#Find the total attack per side
		var SIDE
		for s in range(0,2):
			if s == 0:
				var rng = RandomNumberGenerator.new()
				rng.seed = hash("cockandballslmao")
				rng.randomize()
				SIDE = rng.randi_range(0,1)
			else:
				if SIDE == 0:
					SIDE = 1
				else:
					SIDE = 0
			for ship in Database.BATTLE_QUEUE[battle][SIDE].keys():
				if SIDE == sidesID[0]:
					var shipATK = Database.BATTLE_QUEUE[battle][SIDE][ship]["ATTACK"]*p1_supply_modifier#multiplied by modifiers
					side1ATK += shipATK
					Database.BATTLE_QUEUE[battle][SIDE][ship]["RECENT_DAMAGE_OUTPUT"] = shipATK
				if SIDE == sidesID[1]:
					var shipATK = Database.BATTLE_QUEUE[battle][SIDE][ship]["ATTACK"]*p2_supply_modifier#multiplied by modifiers
					side2ATK += shipATK
					Database.BATTLE_QUEUE[battle][SIDE][ship]["RECENT_DAMAGE_OUTPUT"] = shipATK
		#Deal damage
		var ship_index = 0
		for side in Database.BATTLE_QUEUE[battle].keys():
			for ship in Database.BATTLE_QUEUE[battle][side].keys():
				var evasion = Database.BATTLE_QUEUE[battle][side][ship]["EVASION"]
				var armor = Database.BATTLE_QUEUE[battle][side][ship]["ARMOR"]
				if side == 0:
					armor = armor*p1_supply_modifier
				elif side == 1:
					armor = armor*p2_supply_modifier
				var aps = 0
				if side == sidesID[0]:
					#attack per ship
					aps = side2ATK/Database.BATTLE_QUEUE[battle][side].keys().size()
				if side == sidesID[1]:
					aps = side1ATK/Database.BATTLE_QUEUE[battle][side].keys().size()
				var dmg = 0
				if Database.LOCAL_ID == 0:
					randomize()
					Database.evasion_rands.append(randf())
					if randf() > evasion: #gets number from 0-1, if its above evasion then we did not evade
						dmg = aps*(1.0-armor)
				else:
					if Database.evasion_rands[ship_index] > evasion:
						dmg = aps*(1.0-armor)
					ship_index += 1
				Database.BATTLE_QUEUE[battle][side][ship]["HEALTH"] -= dmg
				Database.BATTLE_QUEUE[battle][side][ship]["RECENT_TAKEN_DAMAGE"] = dmg
				if Database.BATTLE_QUEUE[battle][side][ship]["HEALTH"] <= 0:
					Database.BATTLE_QUEUE[battle][side].erase(ship)
					#!!!!ship dead message
					InventoryManager.remove_ship(ship)
					#remove from invasions
					for landbattle in Database.LAND_QUEUE.keys():
						if ship in Database.LAND_QUEUE[landbattle][0]:
							Database.LAND_QUEUE[landbattle][0].erase(ship)
			if Database.BATTLE_QUEUE[battle][side].size() == 0: #all of one sides ships are gone
				if active_id == side: #current player lost
					emit_signal("log_update","You lost the battle of Sector "+str(battle)+".")
				else: #show to other player, current player won
					emit_signal("log_update","You won the battle of Sector "+str(battle)+".")
				#Give Damaged penalty to everyone that won (10%)
				var winnerIDs = []
				var winnerID = 0
				for s in Database.BATTLE_QUEUE[battle].keys():
					if s != side: #this is NOT the side that has no ships left: the winners
						winnerID = s
						for ship in Database.BATTLE_QUEUE[battle][s].keys():
							winnerIDs.append(ship)
				for id in winnerIDs:
					for system in Database.GALACTIC_DATA.keys():
						for solar in Database.GALACTIC_DATA[system].keys():
							for object in Database.GALACTIC_DATA[system][solar].keys():
								if object == id:
									Database.GALACTIC_DATA[system][solar][object]["MAX_HEALTH"] = Database.GALACTIC_DATA[system][solar][object]["MAX_HEALTH"]*0.9
									Database.GALACTIC_DATA[system][solar][object]["HEALTH"] = Database.GALACTIC_DATA[system][solar][object]["HEALTH"]*0.9
									if active_id == winnerID:
										emit_signal("log_update","Remaining ships are damaged, and require full repairs.")
				Database.BATTLE_QUEUE.erase(battle)
				break
	client.send_match_state({"EVASION_RANDS": Database.evasion_rands},9)
	#### LAND BATTLES ####
	for battle in Database.LAND_QUEUE.keys():
		if (Database.global_turn_counter - Database.LAND_QUEUE[battle][2]) >= 4:
			#its been 4 turns since the battle started
			var side1_warscore = 0 
			var side2_warscore = 0
			var battalions = 0
			var legions = 0
			var ids = [0,0]
			for ship in Database.LAND_QUEUE[battle][0]: #for all the ships on side 1
				for system in Database.GALACTIC_DATA.keys():
					for solar in Database.GALACTIC_DATA[system].keys():
						for object in Database.GALACTIC_DATA[system][solar].keys():
							if "-" in object and object == ship: #its a ship
								battalions += Database.GALACTIC_DATA[system][solar][object]["BATTALIONS"]
								legions += Database.GALACTIC_DATA[system][solar][object]["LEGIONS"]
								ids[0] = Database.GALACTIC_DATA[system][solar][object]["OWNER"]
			side1_warscore = (100*battalions)+(500*legions)*p1_supply_modifier
			battalions = 0
			legions = 0
			for garrison in Database.LAND_QUEUE[battle][1]:
				for system in Database.GALACTIC_DATA.keys():
					for solar in Database.GALACTIC_DATA[system].keys():
						for object in Database.GALACTIC_DATA[system][solar].keys():
							if object == battle:
								for building in Database.GALACTIC_DATA[system][solar][object].keys():
									if building != "Owner" and building != "building_slots":
										var building_tags = building.split("-")
										if building_tags[1] == "GARRISON":
											battalions += Database.GALACTIC_DATA[system][solar][object][building]["BATTALIONS"]
											ids[1] = Database.GALACTIC_DATA[system][solar][object][building]["OWNER"]
			if Database.LAND_QUEUE[battle][1].size() == 0: #undefended planet
				for system in Database.GALACTIC_DATA.keys():
					for solar in Database.GALACTIC_DATA[system].keys():
						for object in Database.GALACTIC_DATA[system][solar].keys():
							if object == battle: #correct planet
								for ID in Database.PLAYERS.keys():
									if Database.GALACTIC_DATA[system][solar][object]["Owner"] == Database.PLAYERS[ID][0]:
										ids[1] = ID
			side2_warscore = (100*battalions)+(500*legions)*p2_supply_modifier
			if side1_warscore == side2_warscore:
				emit_signal("log_update","The Battle of "+battle+" is at a stalemate. The siege continues...")
				Database.LAND_QUEUE[battle][2] = Database.global_turn_counter #resets, we'll have to wait another 4 turns
				return
			if side2_warscore > side1_warscore: #DEFENDERS WIN
				#message to defenders
				if ids[1] == active_id: #current player is defender
					emit_signal("log_update","Successfully defended against the Siege of "+battle+".")
				else:
					emit_signal("log_update","The invasion of "+battle+" has failed.")
				Database.LAND_QUEUE.erase(battle)
			if side1_warscore > side2_warscore: #ATTACKERS WIN!!! WOOO??
				#message to defenders
				if ids[0] == active_id: #current player is attacker
					emit_signal("log_update","Successfully invaded and capitulated "+battle+"!")
					emit_signal("log_update","Gained control of the planet and subsequent buildings.")
				else:
					emit_signal("log_update",battle+" has capitulated to an invasion.")
				#message to attackers
				for system in Database.GALACTIC_DATA.keys():
					for solar in Database.GALACTIC_DATA[system].keys():
						for object in Database.GALACTIC_DATA[system][solar].keys():
							if not "-" in object: #is a planet
								if object == battle:
									Database.GALACTIC_DATA[system][solar][object]["Owner"] = Database.PLAYERS[ids[0]][0]
									for building in Database.GALACTIC_DATA[system][solar][object].keys():
										if building != "Owner" and building != "building_slots":
											Database.GALACTIC_DATA[system][solar][object][building]["OWNER"] == ids[0]
				Database.LAND_QUEUE.erase(battle)
				check_for_losers(ids[1],Database.PLAYERS[ids[1]][0])
		else:
			emit_signal("log_update","The Siege of "+battle+" will finish in "+str(4-(Database.global_turn_counter - Database.LAND_QUEUE[battle][2]))+" turns.")
func resolve_repairs_and_moves():
	for system in Database.GALACTIC_DATA.keys():
		for solar in Database.GALACTIC_DATA[system].keys():
			if not solar in Database.BATTLE_QUEUE.keys():
				for object in Database.GALACTIC_DATA[system][solar].keys():
					var object_tags = object.split("-")
					var friendly_base = false
					#check if we own a planet in here and if there's no battle here
					for o in Database.GALACTIC_DATA[system][solar].keys():
						if not "-" in o: #planet
							if Database.GALACTIC_DATA[system][solar][o]["Owner"] == Database.PLAYERS[active_id][0]:
								#we own the planet
								friendly_base = true
					if object_tags[0] == "SHIP":
						Database.GALACTIC_DATA[system][solar][object]["MOVEABLE"] = true
						if Database.GALACTIC_DATA[system][solar][object]["OWNER"] == active_id:
							if Database.GALACTIC_DATA[system][solar][object]["MAX_HEALTH"] != Database.SHIPS[object_tags[1]]["MAX_HEALTH"]:
								#this ship has been damaged
								if friendly_base:
									Database.GALACTIC_DATA[system][solar][object]["MAX_HEALTH"] = Database.SHIPS[object_tags[1]]["MAX_HEALTH"]
									Database.GALACTIC_DATA[system][solar][object]["HEALTH"] = Database.SHIPS[object_tags[1]]["HEALTH"]
									emit_signal("log_update","Ship(s) in "+str(solar)+" fully underwent repairs.")
			else:
				for object in Database.GALACTIC_DATA[system][solar].keys():
					var object_tags = object.split("-")
					if object_tags[0] == "SHIP":
						Database.GALACTIC_DATA[system][solar][object]["MOVEABLE"] = true
					
func start_battle(solar_id):
	packets.append("START_BATTLE-"+str(solar_id))
	var side1ships = {}
	var side2ships = {}
	var id1 = 0
	var id2 = 1
	Database.BATTLE_QUEUE[solar_id] = {
		0: {},
		1: {}
	}
	for system in Database.GALACTIC_DATA.keys():
			for solar in Database.GALACTIC_DATA[system].keys():
				if solar == solar_id:
					for object in Database.GALACTIC_DATA[system][solar].keys():
						var object_tags = object.split("-")
						if object_tags[0] == "SHIP":
							if Database.GALACTIC_DATA[system][solar][object]["OWNER"] == 0:
								side1ships[object] = Database.GALACTIC_DATA[system][solar][object].duplicate()
							elif Database.GALACTIC_DATA[system][solar][object]["OWNER"] == 1:
								side2ships[object] = Database.GALACTIC_DATA[system][solar][object].duplicate()
	Database.BATTLE_QUEUE[solar_id] = {
		0: side1ships,
		1: side2ships
	}
func join_battle(solar,shipID):
	packets.append("JOIN_BATTLE-"+str(solar)+"-"+str(shipID))
	for side in Database.BATTLE_QUEUE[solar].keys():
		for system in Database.GALACTIC_DATA.keys():
			if solar in Database.GALACTIC_DATA[system].keys():
				if Database.GALACTIC_DATA[system][solar][shipID]["OWNER"] == side:
					#the joining ship is on this side
					Database.BATTLE_QUEUE[solar][side][shipID] = Database.GALACTIC_DATA[system][solar][shipID].duplicate()
					break
func start_land_battle(solar,contested_planet,invading_shipsIDs):
	packets.append(["LB/S",contested_planet,invading_shipsIDs])
	var turncounter = Database.global_turn_counter
	var defending_garrisons = []
	for system in Database.GALACTIC_DATA.keys():
		for solar in Database.GALACTIC_DATA[system].keys():
			for object in Database.GALACTIC_DATA[system][solar].keys():
				if not "-" in object: #its a planet
					if object == contested_planet:
						for building in Database.GALACTIC_DATA[system][solar][object].keys():
							if building != "Owner" and building != "building_slots":
								var building_tags = building.split("-")
								if building_tags[1] == "GARRISON":
									defending_garrisons.append(building)
	var battle = [invading_shipsIDs,defending_garrisons,turncounter]
	Database.LAND_QUEUE[contested_planet] = battle
func join_land_battle(solar,contested_planet,invading_shipsIDs):
	packets.append(["LB/J",contested_planet,invading_shipsIDs])
	Database.LAND_QUEUE[contested_planet][0] += invading_shipsIDs
	
signal release_console_focus
