class_name SuitStats
extends RefCounted
## Computed performance values for the current suit configuration.
## Read-only output of SuitConfiguration.get_stats(). Do not set fields directly.

# ── Design constants — tune these to feel right in Phase 0 ───────────────────

const MAX_BOOST_SPEED: float   = 200.0  # m/s at load_ratio 0.0
const MIN_BOOST_SPEED: float   =  60.0  # m/s at load_ratio 1.0
const MAX_GROUND_SPEED: float  = 200.0  # m/s at load_ratio 0.0
const MIN_GROUND_SPEED: float  =  60.0  # m/s at load_ratio 1.0
const MAX_JUMP_HEIGHT: float   = 25.0   # meters at load_ratio 0.0
const MIN_JUMP_HEIGHT: float   = 5.0    # meters at load_ratio 1.0
const MAX_HOVER_DURATION: float = INF   # seconds hover at load_ratio 0.0

# ── Computed fields ───────────────────────────────────────────────────────────

var load_ratio: float = 0.0            # 0.0 = empty frame, 1.0 = fully loaded
var is_overloaded: bool = false        # load_ratio > 1.0

var flight_available: bool = true      # false when load_ratio prevents flight
var max_flight_altitude: float = INF   # meters above ground; INF = unlimited
var boost_speed: float = MAX_BOOST_SPEED
var hover_duration: float = MAX_HOVER_DURATION
var ground_sprint_speed: float = MAX_GROUND_SPEED
var jump_height: float = MAX_JUMP_HEIGHT

var armor_points: float = 0.0
var damage_bonus: float = 0.0

var thermal_output: float = 0.0       # compared against structure thermal_tolerance on landing
