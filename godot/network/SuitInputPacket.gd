class_name SuitInputPacket
## Serializable per-tick input snapshot transmitted from client to server.
## 48 bytes on the wire.

var tick: int = 0
var player_id: String = ""
var peer_id: int = 0

var move_x: float = 0.0
var move_y: float = 0.0
var look_x: float = 0.0
var look_y: float = 0.0
var ability_slot: int = 0

const FLAG_BOOST_PRESSED         := 1 << 0
const FLAG_BOOST_HELD            := 1 << 1
const FLAG_BOOST_DOWN            := 1 << 2
const FLAG_SPRINT                := 1 << 3
const FLAG_FIRE_PRIMARY_PRESSED  := 1 << 4
const FLAG_FIRE_PRIMARY_HELD     := 1 << 5
const FLAG_FIRE_SECONDARY        := 1 << 6
const FLAG_LOCK_ON               := 1 << 7
const FLAG_MELEE                 := 1 << 8
var flags: int = 0

func has_flag(flag: int) -> bool:
	return (flags & flag) != 0

func serialize() -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(48)
	var o := 0
	buf.encode_s32(o, tick);         o += 4
	buf.encode_s32(o, peer_id);      o += 4
	buf.encode_float(o, move_x);     o += 4
	buf.encode_float(o, move_y);     o += 4
	buf.encode_float(o, look_x);     o += 4
	buf.encode_float(o, look_y);     o += 4
	buf.encode_s32(o, ability_slot); o += 4
	buf.encode_s32(o, flags);        o += 4
	buf.encode_s64(o, player_id.hash()); o += 8
	return buf

static func deserialize(bytes: PackedByteArray) -> SuitInputPacket:
	var p := SuitInputPacket.new()
	var o := 0
	p.tick         = bytes.decode_s32(o);   o += 4
	p.peer_id      = bytes.decode_s32(o);   o += 4
	p.move_x       = bytes.decode_float(o); o += 4
	p.move_y       = bytes.decode_float(o); o += 4
	p.look_x       = bytes.decode_float(o); o += 4
	p.look_y       = bytes.decode_float(o); o += 4
	p.ability_slot = bytes.decode_s32(o);   o += 4
	p.flags        = bytes.decode_s32(o);   o += 4
	# player_id resolved server-side by peer_id mapping
	return p
