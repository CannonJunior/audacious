class_name SuitInputState
## Per-frame input for the player's suit.
## Produced by the local InputManager or reconstructed from SuitInputPacket (network).
## SuitBody.apply_input() consumes this — same path for human and AI agent input.

const SuitInputPacket = preload("res://network/SuitInputPacket.gd")

var move_direction: Vector2 = Vector2.ZERO   # WASD on the XZ plane, normalized
var camera_look: Vector2 = Vector2.ZERO       # mouse delta (x=yaw, y=pitch)

var boost_pressed: bool = false               # tap: jump / double-tap: boost burst
var boost_held: bool = false                  # hold: sustained thrust upward
var boost_down_held: bool = false             # descend / brake altitude
var sprint_held: bool = false                 # ground speed multiplier

var fire_primary_pressed: bool = false
var fire_primary_held: bool = false
var fire_secondary_pressed: bool = false

var lock_on_pressed: bool = false
var melee_pressed: bool = false

var ability_slot: int = 0                    # 0 = none, 1–4 = ability slots

static func from_packet(packet: SuitInputPacket) -> SuitInputState:
	var s := SuitInputState.new()
	s.move_direction = Vector2(packet.move_x, packet.move_y)
	s.camera_look = Vector2(packet.look_x, packet.look_y)
	s.boost_pressed       = packet.has_flag(SuitInputPacket.FLAG_BOOST_PRESSED)
	s.boost_held          = packet.has_flag(SuitInputPacket.FLAG_BOOST_HELD)
	s.boost_down_held     = packet.has_flag(SuitInputPacket.FLAG_BOOST_DOWN)
	s.sprint_held         = packet.has_flag(SuitInputPacket.FLAG_SPRINT)
	s.fire_primary_pressed = packet.has_flag(SuitInputPacket.FLAG_FIRE_PRIMARY_PRESSED)
	s.fire_primary_held    = packet.has_flag(SuitInputPacket.FLAG_FIRE_PRIMARY_HELD)
	s.fire_secondary_pressed = packet.has_flag(SuitInputPacket.FLAG_FIRE_SECONDARY)
	s.lock_on_pressed     = packet.has_flag(SuitInputPacket.FLAG_LOCK_ON)
	s.melee_pressed       = packet.has_flag(SuitInputPacket.FLAG_MELEE)
	s.ability_slot        = packet.ability_slot
	return s

func to_packet(tick: int, player_id: String, peer_id: int) -> SuitInputPacket:
	var p := SuitInputPacket.new()
	p.tick = tick
	p.player_id = player_id
	p.peer_id = peer_id
	p.move_x = move_direction.x
	p.move_y = move_direction.y
	p.look_x = camera_look.x
	p.look_y = camera_look.y
	p.ability_slot = ability_slot
	if boost_pressed:         p.flags |= SuitInputPacket.FLAG_BOOST_PRESSED
	if boost_held:            p.flags |= SuitInputPacket.FLAG_BOOST_HELD
	if boost_down_held:       p.flags |= SuitInputPacket.FLAG_BOOST_DOWN
	if sprint_held:           p.flags |= SuitInputPacket.FLAG_SPRINT
	if fire_primary_pressed:  p.flags |= SuitInputPacket.FLAG_FIRE_PRIMARY_PRESSED
	if fire_primary_held:     p.flags |= SuitInputPacket.FLAG_FIRE_PRIMARY_HELD
	if fire_secondary_pressed:p.flags |= SuitInputPacket.FLAG_FIRE_SECONDARY
	if lock_on_pressed:       p.flags |= SuitInputPacket.FLAG_LOCK_ON
	if melee_pressed:         p.flags |= SuitInputPacket.FLAG_MELEE
	return p
