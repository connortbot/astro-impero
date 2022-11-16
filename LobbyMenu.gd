extends Control

var playerlist_instance = preload("res://Instances/playerlist_instance.tscn")
onready var playerlist = get_node("MarginContainer/VBoxContainer/HBoxContainer/PlayersList/PlayerList/MarginContainer/Scroll/VBoxContainer")
onready var planetlist = get_node("MarginContainer/VBoxContainer/HBoxContainer/PlanetsList/StartingPlanetList/MarginContainer/Scroll/VBoxContainer")

#Server uses this dictionary to keep track of players, with ID:Username
var players = {}

#On menu opening
func readyup(type): #create or join
	if type == "create":
		# Update USERNAMES
		Database.USERNAMES[0] = Database.LOCAL_USERNAME
		$MarginContainer/VBoxContainer/HBoxContainer/PlayersList/PlayerList/MarginContainer/Scroll/VBoxContainer/Player/MarginContainer/Label.text = Database.USERNAMES[0]
	if type == "join":
		$"../..".client.send_match_state({"LOCAL_USERNAME": Database.LOCAL_USERNAME},1)
	$VBoxContainer/GameID/MarginContainer/GameID.text = "Game ID: "+$"../..".client.matchID
	#Network.connect("update_clients_playerlist", self, "update_playerlist")
	#Network.connect("update_planets_list", self, "update_lobby_planetslist")
	#Network.connect("client_planet_selection", self, "_client_planet_selection")
#### PLAYER LIST UPDATES ####
func changed_match_presence(connected_opponents):
	if Database.LOCAL_ID == 0:
		print(connected_opponents.size())
		$PlayerCount/MarginContainer/PCountLabel.text = "Players: "+str(connected_opponents.size())+"/2"
	elif Database.LOCAL_ID == 1:
		print(connected_opponents.size())
		$PlayerCount/MarginContainer/PCountLabel.text = "Players: "+str(connected_opponents.size()+1)+"/2"
func received_p2_username():
	$MarginContainer/VBoxContainer/HBoxContainer/PlayersList/PlayerList/MarginContainer/Scroll/VBoxContainer/Player2/MarginContainer/Label.text = Database.USERNAMES[1]
	$"../..".client.send_match_state(Database.USERNAMES,2)
func received_usernames_from_host():
	$MarginContainer/VBoxContainer/HBoxContainer/PlayersList/PlayerList/MarginContainer/Scroll/VBoxContainer/Player/MarginContainer/Label.text = Database.USERNAMES[0]
	$MarginContainer/VBoxContainer/HBoxContainer/PlayersList/PlayerList/MarginContainer/Scroll/VBoxContainer/Player2/MarginContainer/Label.text = Database.USERNAMES[1]


#### BUTTONS ####
#When the Disconnect button is pressed
func _on_Button_pressed() -> void:
	players = {}
	Database.USERNAMES = ["",""]
	for planet in Database.PLANETS:
		Database.PLANETS[planet] = ""
	Database.PLAYERS = {}
	if Database.LOCAL_ID == 0:
		$"../..".client.leave_match()
		get_node("../../AnimationPlayer").play("BacktoServerMenu")
		yield(get_node("../../AnimationPlayer"),"animation_finished")
		get_node("../../AnimationPlayer").play("NewGame")
	else:
		$"../..".client.leave_match()
		get_node("../../AnimationPlayer").play("BacktoServerMenu")
		yield(get_node("../../AnimationPlayer"),"animation_finished")
		get_node("../../AnimationPlayer").play("JoinGame")
	

signal start_game_org()

## (_on_StartButton_pressed) Starts the game from a button press.
# @param - none
# => USER: host
# => RESULT: calls start_loading_game if both players have selected.
func _on_StartButton_pressed() -> void:
	if Database.LOCAL_ID == 0:
		for planet in Database.PLANETS:
			if Database.PLANETS[planet] == "": #selected planet
				print("A player has not selected a planet.")
				return
		Database.PLAYERS[0][0] = Database.USERNAMES[0]
		Database.PLAYERS[1][0] = Database.USERNAMES[1]
		$"../..".client.send_match_state({},5)
		Network.start_loading_game()

func _on_Anaxes_pressed() -> void:
	assign_planet("Anaxes")
func _on_Botra_pressed() -> void:
	assign_planet("Botra")

#### PLANETS LIST UPDATES ####
func update_planetslist(planet_database):
	for planet in planet_database:
		var planetname = planet
		var path = "MarginContainer/VBoxContainer/HBoxContainer/PlanetsList/StartingPlanetList/MarginContainer/Scroll/VBoxContainer/"+planetname+"/MarginContainer/"+planetname
		var button = get_node(path)
		if planet_database[planet] != "": #someone's selected it
			button.text = planetname+" "+"["+planet_database[planet]+"]"
		else:
			button.text = planetname

#### PLANET OWNERSHIP ####
#This peer selected a planet
var selecting_player = 0
func client_planet_selection(planetname,username): #Host only function
	planet_select(planetname,username)
	$"../..".client.send_match_state(Database.PLANETS,3)
func planet_select(planetname,username): #Host only function
	if Database.PLANETS[planetname] == "": Database.PLANETS[planetname] = username
	elif Database.PLANETS[planetname] == username: Database.PLANETS[planetname] = ""
	for planet in Database.PLANETS:
		if planet != planetname and Database.PLANETS[planet] == username:
			Database.PLANETS[planet] = ""
	update_planetslist(Database.PLANETS)
func assign_planet(planetname):
	if Database.LOCAL_ID == 0:
		planet_select(planetname,Database.LOCAL_USERNAME)
		$"../..".client.send_match_state(Database.PLANETS,3)
	elif Database.LOCAL_ID == 1:
		$"../..".client.send_match_state({"PLANET":planetname,"USERNAME":Database.LOCAL_USERNAME},4)
