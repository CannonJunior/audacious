class_name FlightController
extends Node
## Computes flight velocity each tick for FlightState.
## Implements Iron Man VR-style force aggregation:
##   thrust + drag + gravity bleed + invisible bumper assist + dive-accelerate.

const SuitInputState = preload("res://network/SuitInputState.gd")
const SuitStats = preload("res://data/SuitStats.gd")

const H_ACCEL          := 0.14   # horizontal velocity lerp rate
const V_ACCEL          := 0.20   # vertical velocity lerp rate
const HOVER_GRAVITY    := 0.6    # downward bleed while neither rising nor descending
const SPRINT_MULT      := 1.4    # boost speed multiplier when sprint held
const RISE_SPEED_RATIO := 0.60   # vertical rise as fraction of boost_speed
const SINK_SPEED_RATIO := 0.40   # vertical sink as fraction of boost_speed

# Dive-accelerate: pitching camera down past this angle adds forward speed
const DIVE_THRESHOLD_RAD := 0.25
const DIVE_SPEED_BONUS   := 0.45  # extra forward speed per radian of downward pitch

# Bumper assist
const BUMPER_LOOK_AHEAD := 2.0    # ray length multiplier (× normalised speed)
const BUMPER_MIN_DIST   := 1.2    # meters: ray always at least this long
const BUMPER_CORRECTION := 0.25   # max fraction of speed the bumper can redirect

var _suit  # SuitBody, set in _ready

func _ready() -> void:
	_suit = get_parent()

func compute_flight_velocity(
	current: Vector3,
	input: SuitInputState,
	stats: SuitStats,
	cam,  ## CameraRig
	delta: float,
) -> Vector3:
	var v               := current
	var h_basis: Basis   = cam.get_horizontal_basis()

	# ── Horizontal ─────────────────────────────────────────────────────────────
	var wish_h := Vector3.ZERO
	if input.move_direction.length_squared() > 0.01:
		wish_h = h_basis * Vector3(input.move_direction.x, 0.0, -input.move_direction.y)
		wish_h = wish_h.normalized()

	# Dive-accelerate — reward pitching toward a target with a speed burst
	var pitch: float = cam.get_pitch()  # positive = looking down
	var dive_bonus := 0.0
	if pitch > DIVE_THRESHOLD_RAD:
		dive_bonus = (pitch - DIVE_THRESHOLD_RAD) * DIVE_SPEED_BONUS * stats.boost_speed

	var target_speed := stats.boost_speed * (SPRINT_MULT if input.sprint_held else 1.0)
	var target_h     := wish_h * (target_speed + dive_bonus)

	v.x = lerpf(v.x, target_h.x, H_ACCEL)
	v.z = lerpf(v.z, target_h.z, H_ACCEL)

	# ── Vertical ───────────────────────────────────────────────────────────────
	if input.boost_held:
		v.y = lerpf(v.y,  stats.boost_speed * RISE_SPEED_RATIO,  V_ACCEL)
	elif input.boost_down_held:
		v.y = lerpf(v.y, -stats.boost_speed * SINK_SPEED_RATIO,  V_ACCEL)
	else:
		# Hover: slowly bleed downward rather than a hard stop
		v.y  = lerpf(v.y, 0.0, 0.07)
		v.y -= HOVER_GRAVITY * delta

	# ── Flight ceiling ─────────────────────────────────────────────────────────
	if not is_inf(stats.max_flight_altitude):
		var ground_y: float = _suit.global_position.y - _ground_distance_below()
		if _suit.global_position.y >= ground_y + stats.max_flight_altitude:
			v.y = minf(v.y, -0.5)  # push back down; don't hard-clamp so it feels soft

	# ── Bumper assist ──────────────────────────────────────────────────────────
	var bumper := _bumper_correction(v)
	v.x += bumper.x
	v.z += bumper.z
	# Don't let bumper affect vertical (looks wrong on wall strafes)

	return v

# ── Internal ──────────────────────────────────────────────────────────────────

func _bumper_correction(vel: Vector3) -> Vector3:
	var h_vel := Vector3(vel.x, 0.0, vel.z)
	if h_vel.length_squared() < 0.5:
		return Vector3.ZERO

	var origin: Vector3              = _suit.global_position
	var forward: Vector3             = h_vel.normalized()
	var look_dist: float             = maxf(h_vel.length() * 0.06, BUMPER_MIN_DIST)

	var space: PhysicsDirectSpaceState3D = _suit.get_world_3d().direct_space_state
	var query  := PhysicsRayQueryParameters3D.create(
		origin,
		origin + forward * look_dist,
		0xFFFFFFFF,
		[_suit.get_rid()],
	)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return Vector3.ZERO

	var wall_normal: Vector3 = hit["normal"]
	var dot := forward.dot(wall_normal)
	if dot >= 0.0:
		return Vector3.ZERO  # not heading into this surface

	# Slide the velocity along the wall's tangent plane
	var into_wall := wall_normal * dot
	var correction := -into_wall * BUMPER_CORRECTION
	correction.y = 0.0
	return correction

func _ground_distance_below() -> float:
	var space: PhysicsDirectSpaceState3D = _suit.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		_suit.global_position,
		_suit.global_position + Vector3.DOWN * 2000.0,
		0xFFFFFFFF,
		[_suit.get_rid()],
	)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return 0.0
	return _suit.global_position.y - (hit["position"] as Vector3).y
