# Heist Planner & Suit Workshop — Design Recommendations
*Audacious | Interface Design Document*
*Status: Pre-implementation, iterative design phase | Date: 2026-08-09*
*Derived from: Subtraction Extraction spacecraft builder interface concepts*

---

## Conceptual Translation

This document extends the Workshop and Mission Planner patterns developed for *Subtraction Extraction* into the heist-and-suit context of *Audacious*. The core structures carry over; the dynamics change substantially.

| Subtraction Extraction | Audacious Equivalent | Key Difference |
|---|---|---|
| Spacecraft Workshop | Suit Workshop | Suit is reconfigured per mission, not built once |
| Asteroid field Mission Planner | Heist Planner | Opposition is active and adaptive, not passive hazards |
| Launch window calendar | Mission window (guard rotation, event schedule) | Time pressure is mission-internal, not calendrical |
| Delta-v budget | Speed-mass-power budget | The rocket equation becomes the suit performance equation |
| Voyage consumables | Suit power duration | Same constraint logic, much shorter timescale |
| Spacecraft Manifest | Object Manifest | Final object is built across many heists, not one voyage |
| Wreck intelligence cards | Target dossiers | Intelligence gathered via recon, contacts, hacks |

The strategic loop is fundamentally tighter: heists happen frequently, feedback is fast, and each mission informs the next. The asteroid game asked "can I make a single dangerous voyage?" Audacious asks "can I run the right series of jobs in the right order to build the thing?"

---

## The Central Strategic Loop

```
OBJECT MANIFEST
  identifies what components are needed to complete the object
            │
            ▼
HEIST PLANNER
  selects target, gathers intelligence, designs approach
  surfaces: "to access this target, you need capability X"
            │
            ▼
SUIT WORKSHOP
  configures the right loadout for the specific job
  surfaces: "this loadout limits you to approach Y"
            │
            ▼
EXECUTION
  results feed back as:
  • New components extracted (may include suit upgrades)
  • New intelligence on future targets
  • Heat — increases security posture of related targets
            │
            └──────────────────────────────► repeat
```

This loop is the game. Every system serves it.

---

## The Object Manifest

Before designing either interface, the Object Manifest anchors everything. The player is building something — a device, weapon, piece of technology, or artifact — that requires components extracted across multiple heists. The manifest defines the win condition.

```
OBJECT: [THE THING — name TBD with objective design]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Assembly Progress:  ███████░░░░░░░░░   44%

CORE COMPONENTS         STATUS         SOURCE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Quantum Core          ✗ Not acquired   → Nexus Corp R&D (Level 4)
Resonance Array       ✓ Acquired       Heist 3 — Aldermach Labs
Signal Modulator      ✓ Acquired       Heist 1 — Port Authority
Power Coupling ×3     ✓ ✓ ✗  (2/3)    Last: Vantage Data Center
Crystalline Lattice   ⚠ Damaged        Need repair or replacement
Neural Interface      ✗ Not acquired   → Location unknown

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RECOMMENDED NEXT TARGET:
  Nexus Corp R&D — Quantum Core
  Security level: HIGH  |  Your heat there: LOW  |  Known approach: None
  [OPEN HEIST PLANNER → NEXUS CORP]
```

The manifest drives the Heist Planner's target selection the same way the spacecraft manifest drove wreck prioritization — but now "heat" (how alerted an organization is to the player's activities) adds a strategic layer that wrecks didn't have. High heat on a target means higher security, more guards, shorter windows.

---

## Interface 1: The Suit Workshop

### Philosophy

The suit is a fast-moving exoskeleton designed for infiltration and extraction. It amplifies and extends human movement rather than replacing it — an exoskeleton, not a tank. **Speed is the primary design axis.** Every component choice is evaluated against its speed cost.

The workshop should feel like an engineer's garage: a suit stand in the center, components on modular racks along the walls, a workbench for repair and modification. The aesthetic is functional, improvised, smart.

Unlike the spacecraft (built once, launched once), the suit is **reconfigured before each job**. The workshop ritual of "review the plan → configure the right loadout → execute" is intentional. It creates a meaningful pre-mission moment and makes configuration feel like preparation, not just menu navigation.

### The Four Suit Stats (Always Visible)

Four stats summarize the suit's current configuration. They update in real-time as components are swapped:

```
SUIT PERFORMANCE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SPEED       ████████████░░░░   76%   [base 45 m/s sprint]
STEALTH     ████████░░░░░░░░   52%   [noise/thermal signature]
POWER       ████████████████  100%   [4.2 kWh usable]
ENDURANCE   █████████░░░░░░░   58%   [94 min at full draw]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total mass: 34.2 kg   (optimal: <38 kg for max locomotion)
```

Speed and Stealth are usually in tension — fast movement generates noise and thermal signature. This is the core suit design trade-off.

### Component Categories

**LOCOMOTION SYSTEMS** *(the heart of a fast suit)*

| Component | Speed Effect | Stealth Effect | Power Draw |
|---|---|---|---|
| Hydraulic leg actuators | +++ | -- (mechanical noise) | Low |
| Pneumatic actuators | ++ | - (air hiss) | Low |
| Electromagnetic actuators | ++ | +++ (near-silent) | High |
| Inertia dampeners | + (safe high-speed landing) | + (quiet impact) | Passive |
| Grav-boots | Moderate (wall traversal) | Neutral | Moderate |
| Magnetic foot pads | Slow (ceiling traversal) | ++ (no footstep impact) | Low |

Inertia dampeners are specifically important: without them, the fast suit's high-speed movement creates loud impacts on landing. A fast suit without dampeners is loud. This is a deliberate design constraint — speed costs stealth unless the player invests in dampeners.

**PROPULSION / TRAVERSAL**

| Component | Capability | Mass Cost | Speed Effect |
|---|---|---|---|
| Burst thrusters | Short-range directional flight (3-5s) | Heavy | +++ burst |
| Micro-thrusters | Fine maneuvering, hover | Light | + precision |
| Grapple system | Rapid vertical traversal | Moderate | +++ vertically |
| Glide membranes | Controlled long descent | Light | + horizontal |
| Sprint boost (stored kinetic) | Single-use 200% speed surge | Light | +++ momentary |

Burst thrusters are the heavy investment — mass cost is significant, reducing base sprint speed, but enabling capabilities no other component provides. A player who sacrifices base speed for burst thrusters has a suit that is *situationally* faster than everything else.

**POWER SYSTEMS**

| Component | Benefit | Trade-off |
|---|---|---|
| High-capacity battery | Long endurance | Heavy, reduces speed |
| High-discharge cells | Burst power for speed/systems peaks | Limited cycles, light |
| Kinetic recovery coils | Recharges while sprinting | Slight drag, adds mass |
| Micro-fission cell | Long-duration high power | Regulatory/story flag; rare |

Power management becomes a tactical constraint inside a mission. High-speed sprints burn power faster. Running on fumes at the end of a job — systems flickering out — should be a designed tension state.

**PROTECTION**

Armor is explicitly a speed trade-off. Heavy armor is anti-philosophy for this suit. Options:

| Component | Protection | Mass Penalty | Speed Cost |
|---|---|---|---|
| Ballistic panels (full) | High | Heavy | Significant |
| Reactive panels (spot) | Moderate, one-hit | Moderate | Small |
| Ablative coating | Low physical, disperses energy | Light | Minimal |
| Stealth coating | Near-zero ballistic, masks signatures | Very light | None |

The "right" choice for a fast suit is reactive panels + stealth coating. Full ballistic is only valid for specific high-threat approaches where the player accepts the speed cost.

**SENSOR / INTELLIGENCE SYSTEMS**

| Component | Capability |
|---|---|
| Tactical overlay HUD | Displays guard positions, patrol paths (requires uplink) |
| Thermal imaging | See through walls (heat signatures) |
| Audio amplification | Hear through walls, detect footsteps |
| Electronic warfare suite (EWS) | Remotely hack cameras, loop footage, open mag-locks |
| Biometric bypass | Spoof fingerprint/retina scanners |

The EWS is the "hacker" loadout's core component. It's heavy (power draw), but eliminates entire categories of obstacles without physical contact. This creates a stealth/speed/tech triangle.

**UTILITY TOOLS**

| Tool | Use | Mass | Noise |
|---|---|---|---|
| Plasma cutter | Breach walls, doors, safes | Moderate | High |
| Monofilament cutter | Precise cuts, silent | Light | None |
| EMP burst | Disable all electronics in radius | Light | Moderate |
| Decoy emitter | Distract guards with sound/hologram | Light | By design |
| Scout drone | Remote scouting of next room | Moderate | Low |
| Extraction beacon | Signal exfil vehicle | Very light | None |

### Saved Loadouts

Players save and name configurations for different job types. The interface shows four slots with names the player sets:

```
SAVED LOADOUTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[GHOST]    Stealth coating + EM actuators + EWS
           Speed: 61%  Stealth: 94%  Endurance: 82%

[RUNNER]   Hydraulic actuators + burst thrusters + grapple
           Speed: 94%  Stealth: 31%  Endurance: 67%

[BREACHER] Pneumatic actuators + plasma cutter + reactive panels
           Speed: 58%  Stealth: 44%  Endurance: 79%

[GHOST-FAST] EM actuators + dampeners + EWS + kinetic coils
             Speed: 78%  Stealth: 88%  Endurance: 71%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[+ NEW LOADOUT]
```

Loadout selection should feel like choosing a character build per mission, but within the constraint of what components the player has actually acquired/built.

### Component Acquisition

Suit components are found or built, not purchased outright. Sources:
- **Heist extraction** — specific targets contain suit components (sometimes the job is specifically for a component, not the final object)
- **Underground fabrication** — using materials gained from heists to manufacture components at the base
- **Scavenging** — low-quality salvaged components at reduced performance
- **Inside contacts** — specialized components via NPC relationships

Condition ratings apply, same as spacecraft parts:
- Pristine (100%) — fabricated or stolen cleanly
- Functional (70-99%) — used, minor wear
- Damaged (30-69%) — works with penalties (reduced performance, possible failure mid-mission)
- Critical (<30%) — high failure chance; acceptable only as temp solution

### The Upgrade Board

A dedicated panel in the workshop showing the full known upgrade tree, organized by suit system. Not every slot is visible from the start — upgrades are discovered through play, and the board reflects what the player currently knows.

Each upgrade slot has one of four states:

```
UPGRADE BOARD  ─  LOCOMOTION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[✓] EM Actuators v1              INSTALLED      Fabricated
[ ] EM Actuators v2 (Ghost-Step) OPPORTUNITY → Miraxen Lab (sidequest)
[?] Actuator tier 3              LOCKED         Source unknown
[░] ──────────────               UNDISCOVERED   ??

[✓] Inertia Dampeners (std)      INSTALLED      Scavenged
[ ] High-Rebound Dampeners       OPPORTUNITY → Arashi Defense (sidequest)
[░] ──────────────               UNDISCOVERED   ??

PROPULSION
[✓] Grapple System (std)         INSTALLED      Scavenged
[ ] Extended-Reach Grapple       FABRICATABLE   Need: 2× high-tension cable
[ ] Grav-Anchor Grapple          OPPORTUNITY → Voss Transit Corp (sidequest)
[░] ──────────────               UNDISCOVERED   ??
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[OPPORTUNITY] = sidequest discovered, heist not yet planned
[LOCKED]      = upgrade exists but source unknown
[UNDISCOVERED] = slot exists; player has not learned this upgrade is possible
```

The `UNDISCOVERED` slots are the Metroid hook: the player can see an empty slot, know something could go there, and be motivated to find out what. Discovering that an upgrade exists — and where to get it — is itself a reward.

Clicking any `OPPORTUNITY` row opens a pre-filled heist planner targeting that upgrade's location, with known intelligence already populated. The upgrade board is the junction between the workshop and the sidequest system.

---

## Interface 2: The Heist Planner

### Philosophy

A heist has five phases. The planner supports each one:

```
PHASE 1: INTELLIGENCE    What is the target? What's inside? Who guards it?
PHASE 2: APPROACH DESIGN Entry point, route through the facility, exit route
PHASE 3: PREPARATION     Suit loadout, tools, timing, abort conditions
PHASE 4: EXECUTION       The mission itself (transitions to gameplay)
PHASE 5: DEBRIEF         What was acquired, what intelligence was gained, heat update
```

The interface is used for phases 1-3. Phase 5 results feed back into phase 1 of the next job.

### Target Dossier (Intelligence Layer)

Equivalent to the wreck intelligence card, the target dossier holds everything the player knows about a location. Like the `[!]` / `[?]` system for wrecks, intelligence has confidence levels:

- `[CONFIRMED]` — physically verified or data-confirmed
- `[PROBABLE]` — logical inference from available data
- `[RUMORED]` — one source, unverified
- `[UNKNOWN]` — no intelligence

```
TARGET: NEXUS CORP R&D FACILITY — Sub-level 3
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Security Level:    HIGH (4/5)
Your Heat Here:    LOW — no prior contact
Active Personnel:  [PROBABLE] 12-18 security staff
Guard Rotation:    [UNKNOWN] — requires recon
Camera Coverage:   [CONFIRMED] lobby + corridors, [UNKNOWN] sub-levels
Alarm Type:        [PROBABLE] central monitoring + immediate armed response
Key Lock Type:     [CONFIRMED] biometric (retinal) on lab access

OBJECTIVE ITEM: Quantum Core
  Location:     [PROBABLE] Cold storage, Sub-level 3
  Dimensions:   [CONFIRMED] 0.3m × 0.2m, 4.2 kg (fits standard extraction case)
  Containment:  [UNKNOWN] May require powered case

ENTRY POINTS KNOWN:
  [CONFIRMED] Main entrance — heavy security, cameras, armed guards
  [PROBABLE]  HVAC access — east face, roof level (standard building type)
  [UNKNOWN]   Sub-level utility tunnels
  [RUMORED]   Loading dock — late-night reduced staffing (unverified source)

INTELLIGENCE GAPS:  Guard rotation timing, sub-level layout, containment requirements
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[GATHER MORE INTEL]    [DESIGN APPROACH]
```

### Intelligence Gathering

Before planning an approach, the player builds intelligence. Sources:
- **Physical recon** — scout the location in a low-risk visit (observe guard patterns, count cameras, find entry points)
- **Electronic recon** — hack a network connected to the target (reveals floor plans, personnel records, camera feeds)
- **Inside contact** — an NPC with access provides specific intelligence (high value, limited, may have a cost)
- **Public records / open-source** — building permits, company filings; low specificity but free
- **Prior heist bleed** — intelligence gathered from related targets (sister facilities, same security vendor)

Recon itself is a light gameplay moment — a low-stakes stealth sequence inside the target location where failure means being seen and escorted out (raising heat slightly) rather than losing the job entirely.

### The Approach Designer

Once enough intelligence is gathered, the approach designer becomes the central planning tool.

**Visual layout:** A 2D floor plan (or isometric view) of the target facility. Unknown areas shown as fog/gray. Confirmed areas rendered with detail. Probable areas shown with lower opacity.

**Planning layers the player configures:**

```
APPROACH DESIGN  ─  NEXUS CORP R&D
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ENTRY POINT:   HVAC shaft (east roof)     [medium risk — unconfirmed inside]
               alt: Loading dock (late)   [low risk — very low intelligence]

PRIMARY ROUTE: HVAC → Sub-level 3 utility corridor → Cold storage
               Camera risk: 2 known cameras on route
               Guard encounter probability: [UNKNOWN — rotation not confirmed]

EXTRACTION:    Reverse route (primary)
               alt: Emergency stairwell → east fire exit (high noise alert)

TIMING WINDOW: [UNKNOWN — requires guard rotation data]
               [!] This approach is not viable until rotation is confirmed

SUIT REQUIREMENT:
  → HVAC access requires: Grapple (vertical shaft) + body profile <30 kg loaded
  → Biometric lock on lab requires: Biometric bypass module  
  → Cold storage: May require powered containment case (see loadout)

RECOMMENDED LOADOUT:  GHOST-FAST  (meets mass + biometric requirements)
  [VIEW IN SUIT WORKSHOP]

ABORT CONDITION: If alarm triggers before acquisition, abort via extraction route.
                 If alarm triggers after acquisition, sprint extraction.
```

The crucial connection: **approach requirements feed directly into suit workshop**. The system tells the player "this route needs X capability." The player then configures a loadout that meets those requirements — or chooses a different approach that fits their current loadout better. This bidirectional constraint is the strategic puzzle.

### The Mission Window System

Replacing the calendar-based launch window, heist missions have **timing windows** — windows of opportunity defined by guard rotations, shift changes, event schedules, and security state.

```
MISSION WINDOWS  ─  NEXUS CORP (estimated from building class)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
02:00–04:00  MINIMUM STAFFING      Guard count: ~4   [PROBABLE]
             Camera monitoring: Auto-only (no operator)
             Risk: LOW if rotation confirmed

18:30–19:30  SHIFT CHANGEOVER      Transition period, gaps possible
             Risk: VARIABLE — high variance without recon data

TONIGHT (special):                  [RUMORED — one source]
  Company event at nearby venue — some security diverted
  If true: significant window. If false: normal posture.
  Reliability: 40%

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CONFIDENCE IN WINDOW DATA:  LOW — recon required to confirm
[PLAN RECON MISSION]
```

The tonight window is a gambling mechanic — act on rumored intelligence for potentially better conditions, or confirm it first (spend time, possibly miss it). This is structurally identical to the spacecraft's "launch now on the suboptimal window vs. wait and prepare better for the optimal window" tension — but at mission scale.

### Heat and Security State

After each heist, heat propagates. This is the system that makes the sequence of heists feel like a connected campaign rather than isolated events.

```
HEAT TRACKER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Nexus Corp:          ░░░░░░░░░░   NONE
Aldermach Labs:      ████░░░░░░   ELEVATED (post-Heist 3)
Port Authority:      ██████████   HOT — avoid for now
Vantage DC:          ██░░░░░░░░   LOW
City-wide alert:     ░░░░░░░░░░   NOMINAL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
HOT target effects:
  • Additional guards deployed
  • Camera coverage extended
  • Faster alarm response
  • Windows shorter or eliminated
```

Heat can be reduced by: waiting (it decays slowly), completing a "cool-down" side operation (misdirection, data scrub), or using an inside contact to suppress a report.

### Risk Assessment Summary

Before committing to execution, the player sees a risk summary:

```
MISSION RISK ASSESSMENT  ─  NEXUS CORP, 02:00 window
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Intelligence quality:    ███░░░░░░░   PARTIAL (35%)
Approach confidence:     █████░░░░░   MODERATE (50%)
Guard rotation:          UNKNOWN       ← CRITICAL GAP
Suit capability match:   ████████░░   GOOD (80%)
Timing window:           ██████░░░░   PROBABLE (60%)

OVERALL RISK:  HIGH
RECOMMENDATION: Recon guard rotation before committing.
               Cost: 1 in-game session of recon.
               Benefit: Reduces overall risk to MODERATE.

[EXECUTE ANYWAY]    [GATHER MORE INTEL]    [ABORT PLANNING]
```

The player can always execute with incomplete intelligence — the game doesn't block them. But it clearly communicates what they don't know and what the consequences of that gap are.

### The Route Planner

The route planner is the most tactically expressive part of the heist planner. Once an approach is designed (entry point, primary path, extraction), the route planner lets the player choreograph the specific sequence of movements — maneuver by maneuver — that will execute it.

**Core design philosophy: this is choreography, not combat.** A well-planned heist is a performance. The player designs the sequence; execution is the premiere. Every dramatic action — spiraling into an HVAC shaft, launching onto a moving train, threading a camera blind spot at speed — was planned, rehearsed, and committed to in advance. Good execution feels inevitable. Improvised execution feels desperate.

**Evasion and chase scenes follow the same philosophy.** If the player is discovered, the planned evasion route is a designed asymmetric advantage — the player chose geometry that their suit can handle but pursuers cannot match. Outthinking the chase is the point, not outrunning it.

#### Visual Layout

A 3D view of the relevant portion of the megacity, navigable like a director's camera. The geometry is simplified for planning — buildings as massing models, key infrastructure (rail lines, HVAC units, camera positions) rendered explicitly. The route is drawn as a luminous line through 3D space. Maneuver nodes appear as labeled markers on the route.

Time control: a scrubable timeline at the bottom shows the sequence of events over the mission duration. Guard patrol overlays animate as the timeline advances — the player can see where guards will be when each maneuver fires.

The view toggles between:
- **Overview**: Full approach visible, zoomed out
- **Node view**: Zoomed in on a specific maneuver, showing the geometry in detail
- **Timeline view**: Flattened 2D time + route representation for precise timing

#### Maneuver Nodes

A maneuver node is a discrete moment in the route where a specific physical action is required. Nodes have:

- **Entry state**: Position, velocity, direction, altitude (what the player arrives in)
- **Movement signature**: The shape and timing of the action
- **Exit state**: Where and how the player must arrive on the other end
- **Suit requirements**: Which capabilities are needed (grapple, burst thrusters, dampeners, etc.)
- **Timing constraint**: The window in which this maneuver must begin (tied to guard positions, camera rotations, etc.)
- **Tactical purpose**: A text note explaining why this path through this geometry achieves the goal
- **Ghost/Recovery flags**: Whether this maneuver is Ghost-risky, and what the recovery option is if it fails

Nodes connect via **transit segments** — simpler movement (sprinting, grappling, riding a surface) where the suit auto-manages physics. The player defines the waypoints; the system simulates the transit path.

#### Maneuver Categories

**APPROACH MANEUVERS** — Getting to the target unobserved

| Maneuver | Description | Suit Need | Ghost Risk |
|---|---|---|---|
| Spiraling descent | Corkscrew into a shaft, avoiding direct downward visual axis | Dampeners + precise thruster control | LOW — approach avoids sightlines |
| Oblique roof crossing | Cross a rooftop at angle that stays under camera arcs | Speed + timing | MEDIUM — camera timing is critical |
| Terrain-following descent | Hug a building's exterior surface down to a specific floor | Grav-boots or mag-pads | LOW — surface contact masks thermal |
| HVAC thermal shadow | Enter ventilation at the thermal blind spot of an adjacent exhaust | Entry timing only | LOW — thermal masking |
| Low-altitude urban weave | Fly at street level through vehicle traffic and alley geometry | Micro-thrusters + precision | HIGH — civilian witnesses |

**TRANSIT MANEUVERS** — Moving through the facility or city mid-mission

| Maneuver | Description | Suit Need |
|---|---|---|
| Camera blind-spot sprint | Time a dash through a known dead zone between camera sweeps | Speed + precise timing |
| Shaft traversal | Traverse a vertical shaft (up or down) without triggering acoustic sensors | Dampeners + micro-thrusters |
| Between-floor squeeze | Crawl through sub-floor or ceiling crawlspace | Low profile, no burst |
| Wall-run bridge | Cross a gap using a wall surface to generate lateral momentum | Grav-boots + sprint |

**EXTRACTION MANEUVERS** — Getting out with the target

| Maneuver | Description | Suit Need |
|---|---|---|
| Parabolic ascent intercept | Launch on a calculated arc to land on a moving surface (train top, truck, bridge) | Burst thrusters + timing calculation |
| Controlled descent in urban canyon | Navigate a building-flanked freefall to a specific landing zone | Dampeners + glide membranes |
| River drop | Drop to a waterway below for aquatic extraction | Impact management |
| AI partner vehicle intercept | Match speed with a moving vehicle the AI partner is driving to a rendezvous point | Sprint + coordination |
| Crowd absorption | Slow to civilian pace and merge into foot traffic | Stealth coating + speed discipline |

**EVASION MANEUVERS** — Asymmetric advantages when discovered

Evasion maneuvers are pre-planned gaps between the player's capabilities and what pursuers can match. The megacity's geometry is the tool.

| Maneuver | Description | Why Pursuers Can't Follow |
|---|---|---|
| Cross-canyon burst | Gap between towers that only the suit's thrust bridges | No pursuer has burst thrusters |
| Rail-riding intercept | Board an elevated train and ride a section before dropping off | Pursuers must go around; player rides through |
| Underpass thread | Sprint through a low-clearance underpass at full speed | Vehicle pursuers blocked; foot pursuers lose speed |
| Upward escape | Grapple or thrust to a height pursuers can't reach | No vertical access without the suit |
| Physics anomaly exploit | If carrying a RARE component, the localized gravity anomaly disrupts pursuer footing | Component's own effect becomes a weapon |
| Catacombs entry | Drop into below-grade tunnel access | Smart-city sensors don't cover underground network |

#### The Evasion Addendum

Every route plan contains a primary route and an **evasion addendum** — a pre-designed chase sequence triggered if discovery occurs. The addendum is a second route, branching from the primary at a "separation point" — the moment the player commits to the escape path.

The evasion addendum has its own maneuver nodes and timing windows, but its purpose is different: not stealth, but asymmetry. The player designs for advantages that a discovered state enables:

- They no longer need to be quiet (can use loud systems freely)
- Speed maximizes — Ghost risk is irrelevant
- Environmental traps can be activated (pre-placed EMP, a timed camera loop that serves as misdirection)
- The AI partner can take over remote systems to clear a path

**Separation points** are pre-selected in planning. When the alarm triggers at position X, the player is one button press from switching to the evasion route. The UI flashes the next evasion maneuver node and countdown to the timing window.

```
EVASION ADDENDUM  ─  NEXUS CORP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Separation Point:   Sub-level 3 stairwell (after acquisition)
Trigger condition:  Any alarm activation

EVASION ROUTE:
  [1] Sprint: Stairwell → east maintenance corridor
  [2] MANEUVER: Burst-break through emergency exit (noise: HIGH — acceptable)
  [3] MANEUVER: Parabolic ascent to elevated rail — AI partner on intercept
  [4] Transit: Ride rail 3 stops northeast
  [5] Drop to underground access at Kawakami Station
  [6] Merge into transit crowd — suit to Ghost mode

AI PARTNER TASK DURING EVASION:
  → Loop camera grid from exit point to rail station (40 sec window)
  → Drive extraction vehicle to Kawakami Station north exit
  → Manage external comms (activate cover story if surveillance queries)

Pursuit-break maneuver at step 3:
  The elevated rail ascent requires burst thrusters — foot pursuers
  cannot follow. Vehicle pursuit must find an alternate crossing 
  (estimated delay: 4–6 minutes). This is the separation gap.

GHOST IMPACT: Detection confirmed. Recovery depends on camera loop success.
RECOVERY RISK: LOW if AI partner camera task succeeds.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[PRACTICE EVASION ROUTE]
```

#### RARE Component Transport Constraints

When the extraction target is a RARE component, the route planner activates component-specific constraint overlays:

- **Gravity anomaly field (3m radius)**: The component destabilizes local gravity during transit. Shown as a sphere around the player on the 3D route view. Maneuver nodes within buildings must account for this — narrow shafts may be impassable, or the anomaly may actually help (float through a section rather than grapple).
- **Sensor shimmer**: Certain components cause reflective interference visible to IR and radar. Camera-facing segments of the route are flagged; alternate angles may be needed.
- **Suit interference**: Some components interfere with specific suit systems. If a component disables burst thrusters, any maneuver node requiring burst thrusters is automatically flagged as infeasible and must be redesigned.

The AI partner checks component transport constraints against the route automatically when the extraction target is confirmed: "This component creates a 3m gravity anomaly. Your shaft descent maneuver at Node 4 has 2.1m of clearance — insufficient. Suggest redesigning entry to the adjacent utility corridor."

#### The AI Partner in Route Planning

The AI partner is the player's co-designer in route planning, not just a passive display.

**Active suggestions**: As the player places maneuver nodes, the AI partner offers real-time alternatives: "Given confirmed camera positions and the 02:17 window, a northeast approach spiraling into the HVAC has a 91% Ghost probability. Current northwest approach is 63%. Want me to model the northeast option?"

**Timing optimizer**: Given all confirmed intelligence, the AI partner can auto-optimize the timing of every node along a route — adjusting when each maneuver fires to align with camera rotations, guard positions, and window constraints. The player approves the result; the AI partner does the math.

**Stress simulation**: The AI partner runs a probabilistic simulation of the full route (10,000 runs) and returns a node-level heat map: which maneuvers are most likely to fail and why. This surfaces weak points before the player commits to practice.

```
AI PARTNER: Route stress analysis complete.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
NODE 2 (HVAC spiral entry):     ██████████  94% success
NODE 4 (Camera blind sprint):   ██████░░░░  62% success  ← WEAK
NODE 6 (Parabolic rail ascent): █████████░  88% success
NODE 8 (Crowd absorption):      ████████░░  82% success

NODE 4 ANALYSIS:
  Failure mode: Sprint requires 3.2s. Camera blind window is 3.4s.
  Margin is 0.2s — too thin. Any delay at Node 3 cascades here.
  
  SUGGESTION A: Slow the sprint (reduce noise, widen margin to 0.8s).
                Cost: +2s transit time. Ripple effect on Node 6 timing.
  SUGGESTION B: Extend blind window by having me loop this camera 
                for 4 seconds. Costs one AI task slot.
  SUGGESTION C: Redesign Node 3 exit to arrive 1.2s earlier.
```

---

## Practice Mode

Before executing a heist, the player can practice any individual maneuver node, any route segment, or the full route sequence. Practice Mode is the bridge between planning and execution — and it is itself a gameplay layer, not a tutorial screen.

### Philosophy

A practiced maneuver feels different to execute than an improvised one. The game should reward the investment of practice with a felt sense of mastery — the spiral descent that felt terrifying the first time becomes a signature move by the third. This is the "good chase scene" quality: the player isn't reacting in panic, they're performing something they designed and know.

Practice also serves as the final suit validation. When a maneuver feels right in practice, the player knows their loadout is correct for this job.

### Practice Mode Types

**MANEUVER DRILL**

Isolated practice of a single node. The game loads a simplified reconstruction of just the relevant geometry — the HVAC shaft, the rooftop gap, the rail line — stripped of all other context. Guards, alarms, and consequences removed.

The player attempts the maneuver. The system scores three axes:

```
MANEUVER DRILL: Parabolic rail ascent (Node 6)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Attempt 3 of unlimited

POSITION ACCURACY:    ████████░░   81%   (landed 0.4m from target)
TIMING ACCURACY:      ██████░░░░   61%   (arrived 1.8s late)
NOISE GENERATED:      ████████░░   80%   (impact within threshold)

OVERALL: MARGINAL — timing needs improvement

AI PARTNER: The late arrival is likely due to launching 0.3s after 
            optimal window. The train speed is 22 m/s — 0.3s late 
            means 6.6m of extra lead required. Try initiating the 
            burst as soon as the rail clears the overpass, not after.

[RETRY]  [MODIFY NODE PARAMETERS]  [BACK TO ROUTE]
```

The AI partner gives specific, physics-grounded feedback. Not "you were too slow" — "0.3s late at 22 m/s means 6.6m of extra arc." This teaches the player the underlying mechanics while staying in voice.

**SEGMENT RUN**

Practice 2–5 consecutive nodes as a linked sequence. Segments share timing — a late exit from Node 4 propagates into Node 5's timing window, just as it would in the real mission. This is where cascade effects become visible and where the player learns to chain maneuvers fluidly.

Scoring shows per-node results and highlights cascade failures: "Node 5 failure originated in Node 4 — 1.1s late exit."

**FULL ROUTE RUN**

A complete dry run of the entire heist route — primary route plus evasion addendum. No guards, no real objectives (the extraction target is simulated), but full geometry, full timing constraints, full suit power consumption.

The full route run exists to reveal systemic problems invisible in isolation: power drain from early maneuvers leaving the suit depleted for late ones, timing cascades across the full mission, discovery of a transit segment that doesn't actually connect to the next node's entry state.

```
FULL ROUTE RUN: Nexus Corp R&D
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Time: 47:23  (planned: 44:00)  ← 3:23 over
Power at extraction: 12%       (planned: 22%)  ← concerning

RESULTS BY NODE:
  Node 1 — HVAC approach:          ✓ Ghost
  Node 2 — HVAC spiral entry:      ✓ Ghost
  Node 3 — Sub-level transit:      ⚠ SLOW (4.2s over window)
  Node 4 — Camera blind sprint:    ✗ FAILED (cascade from Node 3)
  [simulation aborted — detection event]

AI PARTNER: Route has a structural timing problem at Node 3. The 
            sub-level utility corridor route is longer than the 
            floor plan suggests — actual path is 34m, not 28m.
            Recommend rerouting via the east service shaft.
            I'll update the floor plan intelligence. Re-run?
```

**EVASION DRILL**

Separate from the primary route, the player can drill the evasion addendum specifically. Evasion drills add an active element: the AI partner simulates pursuers — not gameplay AI enemies, but abstract "pursuer pressure" represented as a countdown timer. The player must reach each evasion checkpoint before the countdown expires.

This teaches the evasion route's rhythm: which moments are tight, which have slack, where the separation gap creates breathing room.

### Practice History

The system records practice attempts per node and displays a mastery indicator:

```
NODE MASTERY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Node 1 — HVAC approach:       ★★★★★  (5 clean runs)
Node 2 — HVAC spiral entry:   ★★★★☆  (best: 89% position)
Node 3 — Sub-level transit:   ★★☆☆☆  (timing struggles)
Node 4 — Camera blind sprint: ★★★☆☆  (3 clean, 2 cascade fails)
Node 5 — Extraction corridor: ★★★★★  (5 clean runs)
Node 6 — Rail ascent:         ★★★☆☆  (still timing)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Weakest node: 3 — [DRILL NODE 3]
Ready to execute?  [EXECUTE HEIST]  [MORE PRACTICE]
```

The "Execute Heist" button from Practice Mode carries a quiet suggestion: you've seen your weak nodes, you've drilled the hard ones. This is as ready as you're going to get. The rest is execution.

---

## Upgrade Sidequests

### Philosophy

Upgrade sidequests are optional heists — same infrastructure as main heists, same planning and practice pipeline — but the payoff is suit capability rather than RARE components. They are never listed in a menu or handed to the player. They are discovered.

This distinction matters. Main heists are the job: the player knows what they need and must go get it. Upgrade sidequests are intelligence rewards: the player finds out about an opportunity through what they do, and then decides whether to pursue it. A thorough ghost-run of a corporate server room might surface a development log describing an experimental actuator two buildings away. A rushed heist that trips alarms and exits fast finds nothing extra.

**The strategic choice upgrades create:** Every sidequest costs heat on some organization and costs time that could go toward RARE components. The upgrade must be worth the trade — and the interface should give the player enough information to decide honestly. Upgrades that directly reduce risk on a planned main heist node (quantified: "Node 4 timing margin improves by 0.6s") give the player a concrete calculation to make.

---

### The Intelligence Trail

Upgrade opportunities are discovered through five channels:

**1. Data extraction during heists**
While hacking a system during any heist — main or sidequest — the player may find documents referencing technology elsewhere. A R&D memo. A shipping manifest. A project codename in an email thread. These surface as flagged findings after the mission debrief:

```
DEBRIEF: Nexus Corp R&D (Heist 6)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OBJECTIVE: ✓ Quantum Resonance Core — ACQUIRED (Ghost)
ADDITIONAL INTELLIGENCE FOUND:

  [!] R&D memo references "Ghost-Step" actuator development
      at Miraxen Lab, District 7. Prototype reported functional.
      This matches your current actuator gap.
      → Added to Upgrade Board as OPPORTUNITY
      [VIEW OPPORTUNITY]
```

The depth of data extracted scales with how thoroughly the player used the AI partner's remote access during the heist. A minimal hack gets the objective data. A comprehensive one gets the objective data plus ambient intelligence.

**2. Physical discovery during intrusion**
Objects found during EVA-style intrusion: a business card with a lab address, a hardware prototype left on a bench, a schematic pinned to a wall. These are placed deliberately in the environment — rewards for exploring beyond the minimum path to the objective. A player who checks the adjacent office before extracting finds what a player who runs straight to the exit does not.

**3. AI partner cross-referencing**
The AI partner passively monitors the player's suit performance across missions and flags patterns: repeated timing failures at high-speed nodes, power depletion before extraction, noise threshold overruns. When a known upgrade opportunity correlates with a persistent weakness, the AI partner surfaces it:

```
AI PARTNER: Pattern noted across last 4 missions —
  Node 4-class camera blind sprints succeed 61% of the time.
  Root cause: EM actuator reaction latency at peak sprint speed.
  
  Miraxen Lab (District 7) has a Ghost-Step actuator prototype
  in development that addresses this specifically.
  
  If acquired: estimated Node 4 success rate → 89%.
  Heat cost: Miraxen Lab (currently NONE).
  [VIEW OPPORTUNITY]  [DISMISS]
```

**4. NPC contact tips**
Named contacts in the player's network occasionally surface time-sensitive opportunities — a prototype being moved tonight, a researcher who will destroy their work if funding doesn't arrive, a black market window that opens briefly. These are the most urgent sidequests and the most time-pressured.

**5. Villain operation intelligence**
Raiding or observing the villain's supply operations leaks what they're pursuing. If the villain's operatives are targeting the same upgrade, that's both a warning (time pressure) and a confirmation (the upgrade is worth having). Intercepting a villain courier to deny them a component could double as a sidequest if the component is useful to the player as well.

---

### Sidequest Target Types

Each target type has a characteristic security posture and payoff profile, creating different planning textures.

**CORPORATE R&D LABS**
- Security: Moderate. Physical security is professional but not military. Camera coverage is thorough; guard counts are low.
- Opportunity type: Prototype components in active development — higher performance than anything fabricatable, but unique and unreplaceable.
- Discovery: Almost always via data extraction from related organizations (sister labs, partner companies, shared vendors).
- Example: Miraxen Lab Ghost-Step actuators — the lab is working on noise-dampened high-speed locomotion for search-and-rescue robotics. The player's suit is a perfect fit.
- Characteristic challenge: The component is still in development. It may need a specific secondary item to function (a firmware key, a calibration module) — potentially spawning a two-step chain.

**MILITARY AND GOVERNMENT DEPOTS**
- Security: High. Armed personnel, multi-factor access control, active surveillance, rapid response. Heat consequence is severe — government heat propagates differently than corporate (city-wide alert level rises faster).
- Opportunity type: Fielded military hardware — proven performance, extremely durable, but heavy and designed for soldiers not infiltration. Often needs adaptation.
- Discovery: Via government contract documents leaked from corporate targets, or via NPC contacts with insider access.
- Example: Arashi Defense high-rebound dampeners — designed to protect soldiers from blast impacts. Overkill for the suit, but the rebound coefficient makes quiet high-speed landings trivially easy.
- Characteristic challenge: The depot has no single point of entry. The approach design phase requires more creativity than a lab.

**VILLAIN SUPPLY CHAIN**
- Security: Variable and unpredictable. The villain's operatives adapt; what worked once may not work again on a related target.
- Opportunity type: Components the villain is acquiring for their own purposes — intercepting their supply denies them capability while granting it to the player.
- Discovery: From villain-adjacent intelligence gathered during main heists, or from observing villain-linked activity in the city.
- Example: A villain courier transporting an experimental power cell. The cell is surplus to their current needs but would give the player double endurance duration. Intercept the courier in transit.
- Characteristic challenge: Moving-target heist. The courier follows a route through the city. The player designs an intercept — a specific maneuver node at a specific point in the route — rather than breaching a fixed facility.

**PRIVATE COLLECTORS AND BLACK MARKET**
- Security: Light physical, but socially complex. Entry may require social engineering rather than stealth. The collector doesn't know they have what the player needs — or does and has priced it.
- Opportunity type: Assembled one-offs, decommissioned prototypes, exotic materials. Condition is variable.
- Discovery: Via NPC contacts, or finding collector manifests in hacked databases.
- Example: A private collector has decommissioned military EWS hardware in a secured home gallery. They're not a security professional — but their building is in a high-surveillance district with smart-city integration.
- Characteristic challenge: The security is the district, not the building. The approach is about the city context, not the interior.

**UNIVERSITY AND RESEARCH INSTITUTIONS**
- Security: Light — but the target is time-pressured. Research prototypes exist briefly before being dismantled, modified beyond usefulness, or destroyed when projects end.
- Opportunity type: Cutting-edge science that hasn't been productized yet. High performance upside, but experimental — may have quirks the player discovers during first use.
- Discovery: Public research announcements cross-referenced by AI partner against suit upgrade needs.
- Example: A materials science lab has developed a new stealth coating compound with 40% better thermal masking. It's in a test batch awaiting publication. The lab will hand samples to a corporate partner in 72 hours — after that, it's gone.
- Characteristic challenge: Time pressure. Simple security. The planning time is compressed.

---

### Multi-Step Upgrade Chains

Some upgrades require more than one heist to acquire, building a mini-campaign within the sidequest structure. Each step uses the full planning pipeline.

**Example Chain: Ghost-Step Actuators (3 steps)**

```
GHOST-STEP ACTUATOR CHAIN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 1: Acquire prototype hardware    Miraxen Lab (District 7)
        Status: OPPORTUNITY           Heat cost: Miraxen (LOW → ELEVATED)

Step 2: Acquire firmware key          Miraxen satellite office (District 2)
        Status: LOCKED (need step 1   Hardware is useless without the key.
        completed first)              Discovered after step 1 acquisition.

Step 3: Calibration run               Miraxen test facility rooftop (District 7)
        Status: LOCKED (need step 2)  The actuators must be calibrated while
                                      installed on a live suit, in motion.
                                      A unique mission type: no extraction
                                      target — just execute a calibration
                                      maneuver sequence while avoiding
                                      detection.

Completion reward: Ghost-Step EM Actuators v2
  Speed: +8%  |  Stealth: +22% at sprint speeds  |  Mass: +1.2 kg
  Node 4-class success rate: 61% → 89%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Step 3 introduces a new heist type: the **calibration run** — the extraction target is the maneuver sequence itself, not a physical object. The player must execute a specific route while installed sensors calibrate the hardware. This is the practice mode inverted: instead of practicing toward a future heist, the practice *is* the mission.

**Example Chain: Active Camouflage Module (2 steps)**

```
ACTIVE CAMOUFLAGE CHAIN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 1: Steal metamaterial sample     Osei University Materials Lab
        Status: OPPORTUNITY           Time-limited: 72 hours
        (discovered via AI partner    Simple security, complex district.
        monitoring public research)

Step 2: Acquire integration module    [VILLAIN SUPPLY CHAIN TARGET]
        Status: OPPORTUNITY           The villain is sourcing the same
        (discovered by intercepting   integration module. Race condition.
        villain courier intelligence) If villain gets there first: lost.

Completion reward: Active Camouflage (4-second burst, 90-second recharge)
  Ghost risk on any node: reduced by 35% during active window
  Power draw: HIGH during active period
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
URGENCY: Step 1 expires in 58 hours. Step 2 is contested.
[PLAN STEP 1 NOW]
```

Step 2 of the camouflage chain introduces the villain race condition explicitly: the same target, two competing actors. The player must decide whether to accelerate their timeline to beat the villain, potentially skipping intelligence gathering on step 2. Going in underinformed to win the race is exactly the risk-reward texture upgrade sidequests should generate.

**Example Chain: Neural-Link AI Partner Interface (3 steps)**

```
NEURAL-LINK UPGRADE CHAIN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 1: Acquire neural interface chip  Kessler BioTech (medical R&D)
        New target type: medical       Access requires biometric spoofing
        facility — different security  a staff member's credentials.
        posture than tech targets

Step 2: Acquire bandwidth amplifier    City telecom switching node
        Status: LOCKED (need step 1)   First infrastructure target —
                                       the target IS city infrastructure.
                                       Hacking it is the heist.
                                       No physical intrusion required.

Step 3: Installation and sync          Home base — no heist required.
        AI partner guides the process. Takes 1 in-game session.

Completion reward: AI partner capacity +2 simultaneous tasks
  AI partner can now assist with: tactical overlay (live, not pre-planned),
  real-time route deviation alerts, and remote vehicle + door control
  simultaneously during a single mission.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

The neural-link chain upgrades the AI partner's capabilities directly — the payoff isn't a suit stat but an expansion of what the AI partner can do during missions. This establishes that sidequests can improve systems beyond the suit itself. Step 2 introduces a new heist type: a **pure cyber intrusion**, where the target is a digital system and the "extraction" is a data payload rather than a physical object.

---

### Upgrade Impact Preview

Before the player commits to planning any sidequest, the upgrade board shows a preview of the upgrade's effect — concrete, quantified, tied to the player's actual current situation:

```
UPGRADE PREVIEW: Ghost-Step EM Actuators v2
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SUIT STATS (current → with upgrade)
  Speed:         76%  →  84%   (+8%)
  Stealth:       52%  →  74%   (+22% at sprint speeds)
  Mass:          34.2 kg → 35.4 kg  (+1.2 kg)

YOUR CURRENT PLANNED ROUTES
  Nexus Corp (Node 4 — camera blind sprint):
    Current success rate:   62%
    With upgrade:           89%   ← significant improvement

  Vantage DC (Node 2 — HVAC transit):
    Current success rate:   94%
    With upgrade:           96%   (marginal)

COST
  Heat: Miraxen Lab NONE → ELEVATED (3-step chain)
  Time: Estimated 3 sessions to complete chain
  Opportunity cost: Delays Nexus Corp heist by ~3 sessions

VILLAIN STATUS: No known interest in this target.

[PLAN SIDEQUEST STEP 1]  |  [ADD TO WATCHLIST]  |  [DISMISS]
```

The "opportunity cost" line is the key piece: the preview tells the player explicitly how long the sidequest detours them from main heist progress. A player who is three sessions from closing the RARE assembly and sees a sidequest that costs three sessions will likely decline. A player earlier in the campaign with a specific weak node they keep failing will likely commit. Both are correct decisions — the preview enables them.

---

### Time-Limited Sidequest Windows

Some upgrade opportunities exist only within a window. Once the window closes, the target is gone permanently.

```
⏱ TIME-SENSITIVE OPPORTUNITY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WHAT:    Metamaterial stealth coating sample (Active Camouflage Step 1)
WHERE:   Osei University Materials Lab
WINDOW:  58 hours until corporate transfer
SOURCE:  AI partner (public research cross-reference)

Why now: The batch transfers to Osei's corporate partner at end of
         week. After that it enters industrial production — available
         only through the corporate supply chain (new target, higher
         security, unknown timeline).

Proceeding now: simple security, low heat.
Waiting: harder target, unknown when available again.

[PLAN NOW — 58 HRS REMAINING]  |  [TRACK WINDOW]
```

Time-limited sidequests apply pressure without being punishing: the window closing doesn't lock the upgrade forever in most cases — it changes the source. The easier version of the heist expires. A harder version exists somewhere in the city, available whenever the player finds it. This keeps the game from feeling like failure states, while still making urgency real.

The single exception: villain-contested targets. If the villain reaches the target first, the upgrade is gone. They have it. This is the one true miss condition for a sidequest.

---

### The Sidequest Heist in the Planner

Within the heist planner, sidequests are tagged and filtered but use identical infrastructure. The target dossier includes a `SIDEQUEST` tag and the upgrade it yields. The approach designer, route planner, and practice mode work exactly the same way.

One structural difference: **the extraction object matters**. In main heists the RARE component is treated as mass-neutral in planning (it's small, contained). Suit hardware components may be larger and heavier — the route planner applies the component's physical footprint to the cargo profile, affecting maneuver node feasibility in the same way RARE transport constraints do (though without the physics anomaly overlay).

```
HEIST PLANNER: MIRAXEN LAB — Ghost-Step Actuator
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TYPE:    UPGRADE SIDEQUEST
YIELD:   Ghost-Step EM Actuators v2 (suit upgrade — Step 1 of 3)
TARGET:  Miraxen Lab, District 7 — Prototype Lab, Floor 4

CARGO PROFILE (affects route planning):
  Actuator assembly: 4.8 kg, 0.4 m × 0.3 m × 0.2 m
  Requires: padded carry case — adds 1.1 kg, 0.6 m × 0.5 m × 0.3 m
  Total cargo:  5.9 kg, bulky — restricts HVAC shaft traversal
                                options under 0.45 m clearance

  [!] HVAC entry at Node 2 (0.4 m shaft): NOT VIABLE with cargo
      Alternate: Service elevator shaft (0.9 m clearance) — confirmed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

The cargo profile creating route constraints is deliberate: it means the player can't plan a sidequest heist identically to a RARE component heist. Physical bulk adds planning texture, and the moment of discovering "the standard HVAC entry doesn't fit" creates a small puzzle that makes each sidequest feel distinct.

---

The systems are tightly integrated. Changes propagate automatically:

```
Object Manifest update       → highlights relevant targets in Heist Planner
                             → flags RARE transport constraints in Route Planner
Heist approach design        → recommends loadout in Suit Workshop
                             → enables Route Planner for that target
Suit workshop change         → updates approach viability in Heist Planner
                             → rechecks maneuver node feasibility in Route Planner
Route planner node change    → updates timing windows in Heist Planner
                             → triggers AI partner stress re-simulation
Mission execution results    → updates Object Manifest + Heat Tracker + Target Dossier
                             → updates detection record (Ghost/Recovered/Failed)
                             → runs AI partner data extraction pass → may surface
                               new sidequest opportunities on Upgrade Board
New component acquired       → unlocks new loadout options in Suit Workshop
                             → may unlock new maneuver types in Route Planner
                             → may reveal next step in an upgrade chain
Upgrade Board opportunity    → pre-populates Heist Planner with target + intel
                             → applies cargo profile constraints to Route Planner
Sidequest completion         → installs upgrade in Suit Workshop
                             → rechecks all planned route nodes for improvement
                             → may reveal next step in upgrade chain
Time-limited window expiry   → Upgrade Board state transitions (OPPORTUNITY → harder
                               alternate source, or LOST if villain-contested)
Villain activity detected    → may add urgency flags to contested sidequest targets
Practice mode completion     → updates node mastery display in Route Planner
AI partner capacity changed  → rechecks evasion addendum feasibility
                             → unlocks new AI task types if neural-link upgraded
```

**The "What do I do next?" recommendation** interleaves main heists and sidequests ranked by strategic value — timing urgency, node impact, and opportunity cost all weighted together:

```
RECOMMENDED NEXT ACTION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Priority 1: [MAIN] Quantum Resonance Core — blocks RARE (final 44%)
  Target: Nexus Corp R&D  |  Heat: LOW  |  Route: NOT DESIGNED
  → Electronic recon recommended before approach design
  [PLAN RECON]

Priority 2: [SIDEQUEST ⏱ 58 HRS] Metamaterial coating — Active Camouflage step 1
  Target: Osei University  |  Simple security  |  Window closing
  Impact on Nexus Corp: Ghost risk on Nodes 2-4 reduced ~35% if done first
  → Doing this before Nexus Corp is tactically sound
  [PLAN SIDEQUEST]

Priority 3: [MAIN] 3rd Anchor Coupling
  Target: Vantage DC  |  Route: DESIGNED  |  Node 3 mastery: 2 stars
  [PRACTICE NODE 3]  |  [EXECUTE]

Priority 4: [SIDEQUEST] Ghost-Step Actuators — step 1 of 3
  Target: Miraxen Lab  |  No time pressure  |  No villain interest
  Impact on Nexus Corp Node 4: 62% -> 89% success (after all 3 steps)
  Timeline cost: ~3 sessions — consider after Nexus Corp
  [VIEW DETAILS]

GHOST STATUS:  4 heists Ghost  |  0 heists Detected
Ending branch: CLEAN — maintain to unlock best outcome
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

The recommendation engine never instructs — it surfaces the calculation with timing and impact quantified and lets the player decide.

---

## Godot Architecture Notes

### Data Resources

```
SuitConfiguration (Resource)
  → List of EquippedComponent (slot_id, component_id, condition)
  → computed stats: speed, stealth, power_capacity, endurance, mass

ComponentDefinition (Resource)
  → slot_category, mass, power_draw, speed_modifier, stealth_modifier
  → capability_tags: ["grapple", "biometric_bypass", "ews", "burst_thrust", ...]
  → condition_curve (performance vs. condition)

HeistTarget (Resource)
  → security_level, heat_level
  → IntelligenceEntry[] (type, confidence, content)
  → ApproachOption[] (entry, route, exit, required_capabilities[])
  → MissionWindow[] (time_start, time_end, quality, confidence)

MissionRoute (Resource)                          # NEW
  → target_id
  → ManeuverNode[] (see below)
  → TransitSegment[] (waypoints between nodes)
  → EvasionAddendum (separation_point, ManeuverNode[], ai_tasks[])
  → detection_record: enum { ghost, recovered, failed }

ManeuverNode (Resource)                          # NEW
  → node_id, position: Vector3, label: String
  → maneuver_type: enum { approach, transit, extraction, evasion }
  → entry_state: PhysicsState, exit_state: PhysicsState
  → timing_window: float (seconds)
  → required_capabilities: String[]
  → ghost_risk: float, recovery_note: String
  → rare_constraints: RAREConstraint[]           # active if carrying RARE component
  → practice_history: PracticeRecord[]

PracticeRecord (Resource)                        # NEW
  → position_accuracy: float
  → timing_accuracy: float
  → noise_generated: float
  → timestamp: int

ObjectManifest (Resource)
  → ComponentRequirement[] (name, acquired, source_target_id, rare_role: String)
  → assembly_progress: float
  → detection_record_aggregate: dict            # per-heist ghost/recovered/failed

UpgradeOpportunity (Resource)                  # NEW — sidequest entry
  → upgrade_id: String
  → target_id: String                          # HeistTarget for this sidequest
  → chain_step: int, chain_total: int          # position in multi-step chain
  → state: enum { undiscovered, locked, opportunity, active, complete, lost }
  → discovery_source: String                   # how the player found this
  → time_limit_hours: float                    # -1 if no limit
  → villain_contested: bool
  → cargo_profile: CargoProfile               # physical constraints on route planning
  → impact_preview: UpgradeImpactPreview      # stat deltas + node success rate changes

UpgradeBoard (Resource)                        # NEW — full upgrade tree state
  → UpgradeOpportunity[] opportunities
  → upgrade_slots: dict                        # slot_id → current installed component
  → undiscovered_slots: int                    # total slots player has not yet found

CargoProfile (Resource)                        # NEW — for route planner constraints
  → mass_kg: float
  → dimensions: Vector3
  → clearance_required: float                  # min shaft/gap width
  → fragility: enum { none, moderate, high }  # affects maneuver speed limits

UpgradeChain (Resource)                        # NEW — multi-step sidequest definition
  → chain_id: String
  → steps: UpgradeOpportunity[]
  → final_reward: ComponentDefinition
  → villain_race: bool                         # true if villain competes for any step
```

### Logic Layer

```
SuitStatCalculator.gd        # Pure functions: mass → speed/endurance curve, power budget
ApproachValidator.gd         # Check loadout capabilities against approach requirements
ManeuverFeasibilityChecker.gd  # Check each node against suit config + RARE + cargo constraints
HeatSystem.gd                # Heat propagation, decay, cross-target spread, city-wide level
RouteTimingOptimizer.gd      # Align node timing windows to guard/camera schedules
AIPartnerAdvisor.gd          # Route stress simulation, suggestions, capacity management,
                             # passive suit-gap monitoring → sidequest surface triggers
RecommendationEngine.gd      # Priority scoring: manifest + intel + heat + detection record
                             # + sidequest urgency + node impact quantification
MissionWindowEvaluator.gd    # Confidence-weighted window quality
PracticeScorer.gd            # Score maneuver attempts on three axes, generate feedback
UpgradeBoardManager.gd       # Track opportunity states, window expiry, chain progression,
                             # villain race resolution
IntelligenceExtractor.gd     # Post-mission pass over hacked data → surface upgrade leads
```

### UI Layer

```
OperationsCenter.gd          # Root controller — the hub the player inhabits
SuitWorkshopPanel.gd         # Suit stand + component rack + stat display + loadout manager
  └── UpgradeBoardPanel.gd   # Full upgrade tree display with slot states + opportunity links
HeistPlannerPanel.gd         # Target dossier + approach designer + risk summary
                             # (works for both main heists and sidequests; sidequest-tagged)
RoutePlannerPanel.gd         # 3D city view, maneuver node editor, evasion addendum
  ├── CitySceneViewport.gd   # SubViewport rendering the 3D city geometry
  ├── RouteLineRenderer.gd   # Draws the route arc + cargo clearance warnings
  ├── ManeuverNodeEditor.gd  # Node placement, parameter editing
  ├── TimelineBar.gd         # Scrubable mission timeline with guard overlays
  └── AIPartnerPanel.gd      # Stress sim results, suggestions, capacity display
PracticeModeController.gd    # Loads geometry, manages drill / segment / full-run / evasion
  ├── ManeuverDrillUI.gd     # Single node practice + scoring display
  ├── SegmentRunUI.gd        # Multi-node segment + cascade failure display
  └── FullRouteRunUI.gd      # Complete route run + power tracking
ObjectManifestPanel.gd       # RARE assembly progress + next-action recommendations
UpgradePreviewPopup.gd       # Stat deltas + node impact preview before sidequest commit
HeatTrackerPanel.gd          # Per-organization + city-wide heat + villain activity flags
IntelligenceOverlay.gd       # Floor plan renderer with fog-of-war
MissionDebriefPanel.gd       # Post-mission: results + intelligence found + new opportunities
```

### Key Architectural Note: Practice Geometry

Practice mode needs simplified geometry to load quickly and isolate the relevant physical space. Recommend a dedicated `PracticeGeometryLibrary` of pre-built "arena" scenes (shaft, rooftop gap, rail line, urban canyon section, crowd street) that are parameterized to match the target's specific dimensions as recorded in the route node. This avoids loading the full city scene for a drill, while still making the geometry feel authentic.

The same arena scenes are used across multiple heist targets — a shaft is a shaft. What differs are the dimensions, the obstacle placements, and the timing parameters fed in from the `ManeuverNode` resource.

---

## Visual Design Direction

The operations center aesthetic should feel like an underground command room: industrial, improvised, functional. Not a corporate UI — something the player character built themselves from available resources.

- **Primary palette**: Near-black background (#0A0A0F) with amber/orange (#FF6B00) as the accent — warmer than Subtraction Extraction's green phosphor, suggesting human urgency rather than cold engineering
- **Heat indication**: Red is semantic only — reserved for heat levels and critical risk. The base UI avoids red entirely to preserve this signal value
- **Floor plan / 2D views**: Blueprint-style white lines on dark blue (#0D1A2E) — technical, readable
- **Route Planner 3D view**: The city geometry renders as massing models in deep charcoal. The planned route glows amber. Guard patrol paths are dim cyan. Camera arcs pulse slowly in pale blue. Maneuver nodes are bright amber diamonds.
- **Practice mode**: Stripped UI — near-black, no HUD chrome, just the geometry and a minimal scoring readout. The sparse aesthetic focuses attention on the maneuver.
- **3D suit stand**: Low-poly, well-lit from above, rotating slowly in idle. Components slot in visually as they're equipped — the suit physically assembles.
- **Typography**: Monospaced, but slightly humanized — less "terminal output," more "handwritten technical notes." Mission-specific notes (the AI partner's annotations) should feel hand-marked, as if scrawled on a planning document.
- **RARE component warning overlays**: When a RARE transport constraint is active on a route, the affected segments shift from amber to a violet-white shimmer — visually distinct from all other warning colors, suggesting physics wrongness rather than security risk.

**The megacity in the route planner** should feel dense and real: overlapping rail lines at different heights, buildings of sharply varying scales (a Haussmann-style six-story block immediately adjacent to a Tokyo-scale tower), and visible infrastructure complexity (water towers, HVAC units, aerial walkways, construction cranes). This density is the playground. The city should look almost overwhelming when the player first opens the route planner — and feel mastered by the time they're designing their fourth heist.

The contrast with Subtraction Extraction is intentional: that game is cold, methodical, engineering-first. Audacious is urgent, human, and slightly illegal. One player is alone in space solving physics equations. The other is alone in a city solving human systems — but the intellectual satisfaction of a well-built plan is the same.

---

## World & Objective Context

*The following resolves the four open design questions from the initial draft.*

### 1. The Final Object: Reality-Anchor Resonance Engine (RARE)

The player is assembling a **Reality-Anchor Resonance Engine** — a device that stabilizes or destabilizes the fundamental laws of physics within a targeted zone. Two versions of this device exist in the world simultaneously:

- **The hero's RARE**: Designed to lock an evil force into a permanently mortal, vulnerable state — collapsing whatever non-human physical properties make it otherwise unkillable.
- **The villain's RARE**: Designed to lock the entire planet into permanent stasis — a physics freeze at the city-wide or planetary scale.

The villain may be assembling an identical device from the same component pool. This creates competitive pressure: some components may be raced for, some targets may already be stripped when the player arrives.

**Design implications:**
- Components are specialized physics and quantum equipment — targets skew toward research labs, government black sites, military installations, and cutting-edge corporate R&D. Not warehouses.
- Some components are dangerous to transport. A RARE sub-assembly in transit creates localized physics anomalies — gravity instability within a 3m radius, reflective shimmer visible to certain sensors, suit system interference. The route planner must account for this: component-specific constraints appear as overlay warnings on the planned route.
- Components are not interchangeable. Each has a specific function in the RARE's assembly. The manifest shows what each component does, which grounds the object's narrative weight.
- Assembly itself is a mechanic — the final sequence may require a dedicated heist of its own: a secure location, a precise assembly window, and possibly defense against the villain attempting to disrupt it.

**The split-ending structure:** Both the hero's RARE and the villain's RARE can be completed. Which one is finished first, and under what conditions, determines the ending.

### 2. Discovery, Recovery, and Multiple Outcomes

Discovery during a heist is not mission failure — it is a **branching complication** with narrative consequence.

**The discovery spectrum:**
- **Never detected (Ghost)**: No witness, no record. The operation officially never happened. Contributes to the cleanest ending branch.
- **Detected, successfully recovered**: The player was seen, an alarm triggered, or evidence was left — but they extracted successfully and covered what they could. Recovery is explained by:
  - Bribed officials or planted evidence pointing elsewhere
  - Activated cover story (AI partner manages external communications during extraction)
  - Witness neutralization (non-lethal: memory wipe tech, disorientation; this fits a physics-bending world)
  - Speed of exit and absence of physical evidence
- **Detected, unrecovered**: Mission failed. Components not retrieved, heat spikes hard, the villain may exploit the gap.

**Outcome tracking:** The game tracks a per-heist detection record. Aggregate Ghost status across all heists unlocks the purest ending. Partial detection accumulates a "trail" that shapes the final confrontation's difficulty and tone.

**Design implication for the risk system:** The risk assessment summary now explicitly labels consequences as: `GHOST RISK` (are you leaving any trace?) and `RECOVERY RISK` (if detected, can you get out?). These are tracked separately because some approaches are high Ghost risk but low recovery risk (e.g., a bold frontal approach — you'll probably be seen, but you'll also definitely get out fast).

### 3. The AI Partner

The player operates alone during heists, but is supported by a single AI partner — an intelligence with full access to the operations center systems and limited real-world reach through connected infrastructure.

**In the planning phase**, the AI partner functions as:
- **Route analyst**: Reviews planned routes and maneuver nodes, flags issues ("Your spiral approach at this angle generates more thermal signature than the threshold — try 8° shallower")
- **Intelligence synthesizer**: Cross-references acquired intel to fill in probable gaps, updates confidence ratings as new data arrives
- **Window optimizer**: Given all confirmed intelligence, suggests the optimal timing window and explains the reasoning
- **Stress-tester**: Can run a probabilistic simulation of the plan and return a heat map of where failures are most likely to occur

**During execution**, the AI partner functions as:
- **Mission control**: Monitors the player's deviation from the planned route, provides live updates ("Guard is 40 seconds early — hold position")
- **Vehicle operator**: Controls an extraction vehicle (motorcycle, car, boat, drone carrier) navigating city infrastructure to meet the player at a planned rendezvous point. The player briefs the vehicle rendezvous in the route planner; the AI partner executes it in real-time during the mission.
- **Remote access**: Maintains camera loops, manages timed door unlocks, deploys digital misdirection — actions the player configured during planning

The AI partner has **capacity limits** — it can manage a fixed number of simultaneous tasks. During planning, the player allocates which tasks the AI partner handles. Overloading the partner is itself a risk factor.

### 4. The Megacity: Setting and Environmental Design

The world is a megacity — a seamless architectural mashup of Tokyo, Paris, and Manhattan. Dense, vertical, alive at all hours.

**Environmental layers that directly enable route planning:**

| Layer | Source Inspiration | Design Opportunity |
|---|---|---|
| Elevated rail network | Tokyo (Yamanote, Shinkansen) | Moving vehicle boarding, extraction handoffs, mid-rail maneuvers |
| Rooftop continuity | Haussmann Paris + Manhattan midtown | Extended rooftop traversal, gap jumps between buildings of varying heights |
| Urban canyons | Manhattan avenues | Vertical surfaces, wind dynamics, long sightlines (double-edged for stealth) |
| Underground transit | Paris Métro, NYC subway | Below-grade approach routes, heat-sink for pursuer evasion |
| Alley networks | Tokyo back-streets | Crowd-cover at ground level, tight geometries that disadvantage pursuers |
| River/waterway | Seine analog | Aquatic extraction, bridge access, sight-line breaks |
| Smart city sensors | Near-future Tokyo | The city's infrastructure IS the security system; hacking it re-routes it |

**Heat propagation in the megacity context:** Heat doesn't just affect individual organizations — at high city-wide alert, the smart city infrastructure activates against the player. More cameras live-monitored, facial recognition widened, drone patrols added. "Cool-down" operations target the city's awareness systems, not just individual organizations.

**The villain's presence in the city:** The villain operates from somewhere in the megacity. As the game progresses, the city itself changes to reflect their growing influence — security posture escalates in certain districts, strange physics anomalies appear (reality destabilization tests), and the environment subtly shifts.

---

*Remaining open questions: exact RARE component list and per-component physics anomaly types; villain RARE race pacing and competitive overlap with player targets; AI partner personality and voice. Interface design is stable and complete for implementation planning.*
