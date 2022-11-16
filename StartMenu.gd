extends Control

onready var client = get_tree().get_root().get_child(3).get_child(1)

func _on_UsernameEntry_text_changed(new_text: String) -> void:
	Database.LOCAL_USERNAME = new_text

func _on_UsernameEntryJoin_text_changed(new_text):
	Database.LOCAL_USERNAME = new_text

var join_matchID
func _on_MatchIDEntry_text_changed(new_text):
	join_matchID = new_text

var bruh2
func _ready() -> void:
	client.connect("changed_match_presence",$LobbyMenu/LobbyMenu,"changed_match_presence")
	client.connect("received_p2_username",$LobbyMenu/LobbyMenu,"received_p2_username")
	client.connect("received_usernames_from_host",$LobbyMenu/LobbyMenu,"received_usernames_from_host")
	client.connect("client_planet_selection",$LobbyMenu/LobbyMenu,"client_planet_selection")
	client.connect("update_planetslist",$LobbyMenu/LobbyMenu,"update_planetslist")
	Database.reset()
	$AnimationPlayer.play("FadeIn")
	second_anim = "Start"

func _on_Button_pressed() -> void:
	$AnimationPlayer.play("ToServerMenu")


func _on_NewGame_pressed() -> void:
	$AnimationPlayer.play("ToLobbyMenu")
	yield(client.create_match(),"completed")
	Database.LOCAL_ID = 0
	$LobbyMenu/LobbyMenu.readyup("create")
	
func _on_JoinGame_pressed():
	$AnimationPlayer.play("ToLobbyMenu")
	yield(client.join_match(join_matchID),"completed")
	Database.LOCAL_ID = 1
	$LobbyMenu/LobbyMenu.readyup("join")

var second_anim = ""
func _on_AnimationPlayer_animation_finished(anim_name: String) -> void:
	if second_anim != "":
		$AnimationPlayer.play(second_anim)
	second_anim = ""


func _on_Music_finished() -> void:
	$Music.playing = true


func _on_LoadGameButton_pressed() -> void:
	$StartMenu/LoadGameMenu.visible = true
	$StartMenu/NewGameMenu.visible = false
	var found = false
	var ix = 0
	var last_save_index = 0
	while not found:
		var save_game = File.new()
		if not save_game.file_exists("user://savegame"+str(ix)+".save"):
			found = true
			last_save_index = ix-1
		save_game.close()
		ix += 1
	print(ix)
	if last_save_index == -1: return #no saves
	else:
		for i in range(last_save_index+1):
			var loadedgame = load("res://Instances/LoadGameButtonInstance.tscn").instance()
			loadedgame.get_node("Button").text = "Save "+str(i)
			loadedgame.savenum = i
			get_node("StartMenu/LoadGameMenu/ScrollContainer/VBoxContainer").add_child(loadedgame)
	


func _on_CreateGameButton_pressed():
	$ServerMenu/JoinGameMenu.visible = false
	$ServerMenu/CreateGameMenu.visible = true
	$AnimationPlayer.play("NewGame")

func _on_CopyID_pressed():
	OS.set_clipboard(client.matchID)


func _on_JoinGameButton_pressed():
	$ServerMenu/JoinGameMenu.visible = true
	$ServerMenu/CreateGameMenu.visible = false
	$AnimationPlayer.play("JoinGame")
