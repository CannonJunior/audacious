## Peer abstraction: switches between offline, ENet (LAN), and Steam transports.
## All game code interacts with multiplayer through standard Godot RPC — never
## directly with ENetMultiplayerPeer or SteamMultiplayerPeer.
##
## In single-player the dormant OfflineMultiplayerPeer is active so that
## multiplayer.is_server() / authority checks work correctly without changes.
extends Node

const SuitInputPacket = preload("res://network/SuitInputPacket.gd")
const SuitInputState  = preload("res://network/SuitInputState.gd")

enum NetMode { OFFLINE, ENET_LAN, STEAM }

const ENET_PORT: int = 7777
const MAX_PEERS: int = 8

var mode: NetMode = NetMode.OFFLINE
var local_player_id: String = "player_1"

var _enet_peer: ENetMultiplayerPeer = null
var _next_player_number: int = 2          # server = player_1; clients get player_2, 3 …

## Server-side: maps multiplayer peer_id → game player_id string
var _peer_to_player: Dictionary = {}

## Server-side input buffer: peer_id → InputPacket
var _input_buffer: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	go_offline()

# ── Host / Join ───────────────────────────────────────────────────────────────

func host_enet(port: int = ENET_PORT) -> Error:
	_enet_peer = ENetMultiplayerPeer.new()
	var err := _enet_peer.create_server(port, MAX_PEERS)
	if err != OK:
		push_error("NetworkManager: ENet host failed: " + str(err))
		return err
	multiplayer.multiplayer_peer = _enet_peer
	mode = NetMode.ENET_LAN
	local_player_id = "player_1"
	_peer_to_player[1] = local_player_id
	EventBus.session_started.emit()
	return OK

func join_enet(address: String, port: int = ENET_PORT) -> Error:
	_enet_peer = ENetMultiplayerPeer.new()
	var err := _enet_peer.create_client(address, port)
	if err != OK:
		push_error("NetworkManager: ENet join failed: " + str(err))
		return err
	multiplayer.multiplayer_peer = _enet_peer
	mode = NetMode.ENET_LAN
	return OK

func go_offline() -> void:
	if _enet_peer:
		_enet_peer.close()
		_enet_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = NetMode.OFFLINE
	local_player_id = "player_1"
	_peer_to_player.clear()
	_next_player_number = 2

## Host calls this to load the game scene on all peers simultaneously.
@rpc("authority", "call_local", "reliable")
func load_game_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

func is_server() -> bool:
	return multiplayer.is_server()

# ── Peer → player mapping ─────────────────────────────────────────────────────

func get_player_id_for_peer(peer_id: int) -> String:
	return _peer_to_player.get(peer_id, "")

## Server calls this to tell a client which player_id they own.
@rpc("authority", "reliable")
func assign_local_player(player_id: String) -> void:
	local_player_id = player_id

# ── RPC: client → server ──────────────────────────────────────────────────────

@rpc("any_peer", "unreliable_ordered")
func submit_input(packet_bytes: PackedByteArray) -> void:
	if not multiplayer.is_server():
		return
	var packet := SuitInputPacket.deserialize(packet_bytes)
	var sender := multiplayer.get_remote_sender_id()
	packet.player_id = get_player_id_for_peer(sender)
	_input_buffer[sender] = packet

# ── Server tick ───────────────────────────────────────────────────────────────

## Call from the game scene's _physics_process on the server.
## game_scene must expose get_suit_node(player_id: String) -> Node.
func apply_buffered_inputs(game_scene: Node) -> void:
	for peer_id: int in _input_buffer:
		var packet = _input_buffer[peer_id]  ## SuitInputPacket
		var pid: String = packet.player_id
		if pid.is_empty():
			pid = get_player_id_for_peer(peer_id)
		var suit_node: Node = game_scene.get_suit_node(pid)
		if suit_node:
			suit_node.apply_input(SuitInputState.from_packet(packet))
	_input_buffer.clear()

# ── Connection callbacks ───────────────────────────────────────────────────────

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		var player_id := "player_%d" % _next_player_number
		_next_player_number += 1
		_peer_to_player[peer_id] = player_id
		assign_local_player.rpc_id(peer_id, player_id)
	EventBus.peer_connected.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	_peer_to_player.erase(peer_id)
	_input_buffer.erase(peer_id)
	EventBus.peer_disconnected.emit(peer_id)

func _on_connected_to_server() -> void:
	local_player_id = ""   # server will set via assign_local_player RPC

func _on_connection_failed() -> void:
	push_error("NetworkManager: connection failed")
	go_offline()

# ── Chat relay ────────────────────────────────────────────────────────────────

## Send a chat message; handles both offline and networked sessions.
func chat_say(message: String) -> void:
	if mode == NetMode.OFFLINE:
		# Bypass the RPC system entirely in single-player.
		EventBus.chat_message_received.emit(local_player_id, message)
	elif multiplayer.is_server():
		_recv_chat.rpc(local_player_id, message)
	else:
		_send_chat.rpc_id(1, message)

## Client → server: deliver my chat message for relay.
@rpc("any_peer", "reliable")
func _send_chat(message: String) -> void:
	if not multiplayer.is_server():
		return
	var peer: int = multiplayer.get_remote_sender_id()
	var sender: String = _peer_to_player.get(peer, "player_%d" % peer)
	_recv_chat.rpc(sender, message)

## Server → all: broadcast a chat message to every peer.
@rpc("authority", "call_local", "reliable")
func _recv_chat(sender_id: String, message: String) -> void:
	EventBus.chat_message_received.emit(sender_id, message)
