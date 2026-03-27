# GDD: Audio System

> **Status**: Draft
> **Created**: 2026-03-27
> **System ID**: 2 (see systems-index.md)
> **Sprint**: S7
> **Priority**: Vertical Slice
> **Depends On**: Physics Tool System, Escalation System, Health & Death System,
>                 Objective System, Extraction System, InteractableTerminal
> **Required By**: Visual Effects & Juice System, Settings & Options System

---

## 1. Overview

The Audio System is the event-driven sound layer for RIFT. It owns a singleton
`AudioManager` node that subscribes to existing gameplay signals and routes them
to the correct `AudioStreamPlayer` or `AudioStreamPlayer3D` instances through a
four-bus Godot AudioServer layout (Master > Music > SFX > UI). No gameplay code
calls an AudioStreamPlayer directly. The vertical-slice scope covers: three
physics-tool SFX slots (one per tool), a four-layer adaptive music system that
mirrors the four escalation levels, and a minimal SFX set for footsteps, terminal
interaction, health feedback, mission result stings, and ambient environment. The
system is designed so asset slots can be filled with placeholder audio immediately
and swapped for final assets at any point without code changes.

---

## 2. Player Fantasy

Sound is the nervous system of a heist. When the facility is quiet the player
should feel like an intruder who has not yet been seen — soft industrial hum, the
creak of distant structure, footsteps that feel too loud. When escalation rises,
the music should tighten its grip before the player consciously notices. At HOSTILE
the score should feel like it is chasing them. At CRITICAL, every audio layer is
live, the alarm cuts through everything, and the only thought is exit.

The three physics tools each need a sonic identity that confirms the fantasy: Gravity
Flip should feel like the world losing its footing; Time Slow should feel dense and
submerged; Force Push should feel like a shockwave leaving the player's hand. Players
should be able to close their eyes and identify which tool is active from sound alone.

Audio also carries mechanical information. The low-health warning tone tells the
player they are in danger without requiring them to look at the HUD. The success
sting and the failure sting are the emotional punctuation at the end of a run.

---

## 3. Detailed Rules

### 3.1 AudioManager Architecture

`AudioManager` is a scene-tree singleton (`autoload`) with the following
responsibilities:

- Subscribe to all gameplay signals on `_ready()` via explicit `connect()` calls.
- Route each signal to a named handler method.
- Instantiate or pool `AudioStreamPlayer` (2D/non-positional) and
  `AudioStreamPlayer3D` (positional, world-space) nodes.
- Never expose `AudioStreamPlayer` nodes to other systems. All audio requests go
  through `AudioManager`'s public methods or signal callbacks.

No gameplay script may call `AudioStreamPlayer.play()` directly. If a system needs
to request audio outside the defined signal contracts, it must call a public method
on `AudioManager` (e.g., `AudioManager.play_sfx(asset_path, position)`). This rule
is enforced by code review.

```
Autoloads
└── AudioManager    (script: audio_manager.gd)
    ├── MusicPlayer           AudioStreamPlayer      (bus: Music)
    ├── AmbiencePlayer        AudioStreamPlayer      (bus: SFX)
    ├── StingerPlayer         AudioStreamPlayer      (bus: Music)
    ├── UIPlayer              AudioStreamPlayer      (bus: UI)
    └── SfxPool[]             AudioStreamPlayer3D[]  (bus: SFX, pooled × 8)
```

`SfxPool` is a pool of eight reusable `AudioStreamPlayer3D` nodes. When a 3D SFX
event fires, `AudioManager` picks the first idle pool node, moves it to the world
position of the event source, and plays the stream. Pool nodes are parented to
`AudioManager` (which lives in the autoload tree, not the scene tree), so they
survive scene changes.

### 3.2 Bus Layout

The Godot AudioServer bus layout MUST be configured in Project Settings exactly
as follows. No other buses are created without an architecture decision record.

```
Master  (index 0)
├── Music   (index 1)  — MusicPlayer, StingerPlayer
├── SFX     (index 2)  — SfxPool nodes, AmbiencePlayer
└── UI      (index 3)  — UIPlayer
```

| Bus | Purpose | Default Volume | Ducking Target |
|-----|---------|---------------|----------------|
| Master | Final output, global mute, limiter | 0 dB | — |
| Music | Adaptive music layers, stingers | -6 dB | Ducked by SFX priority events |
| SFX | All in-world positional and non-positional SFX | -3 dB | — |
| UI | UI click sounds, result stings | -2 dB | Ducks Music by 6 dB during stingers |

Bus effects (Godot AudioEffect nodes):

| Bus | Effect | Parameters |
|-----|--------|------------|
| Master | AudioEffectLimiter | threshold = -1 dB, ceiling = 0 dB |
| Music | AudioEffectReverb | room_size = 0.3, wet = 0.15 (light space) |
| SFX | AudioEffectCompressor | threshold = -12 dB, ratio = 4, release = 0.3 s |
| UI | (none) | — |

### 3.3 Adaptive Music System

The music system maintains four audio layers, one per escalation level. Layers are
pre-loaded `AudioStream` resources looped at identical BPM. They are crossfaded, not
hard-switched.

| Music Layer | Escalation Level | Character | File Slot |
|-------------|-----------------|-----------|-----------|
| `layer_0_ambient` | CALM (0) | Sparse industrial ambient — low drones, occasional metallic texture | `mus_explore_facility_calm_loop.ogg` |
| `layer_1_alert` | ALERT (1) | Rhythmic pulse added — tension building, higher frequency activity | `mus_explore_facility_alert_loop.ogg` |
| `layer_2_hostile` | HOSTILE (2) | Full percussive bed — driving, aggressive, facility under siege feel | `mus_explore_facility_hostile_loop.ogg` |
| `layer_3_critical` | CRITICAL (3) | Maximum density — distorted, chaotic, extraction-or-die urgency | `mus_explore_facility_critical_loop.ogg` |

**Layer transition rules:**

- On escalation level change, the outgoing layer fades out over `MUSIC_CROSSFADE_DURATION`
  seconds while the incoming layer fades in over the same duration.
- Layers are time-synced: the incoming layer starts at `fmod(outgoing_playback_position,
  loop_length)` so downbeats remain aligned across transitions.
- Only one crossfade may be in progress at a time. If a second level change fires
  during an active crossfade, the crossfade target updates immediately to the new
  level; the outgoing side continues fading from its current volume.
- When `critical_entered` fires, a one-shot stinger (`sfx_event_critical_stinger_01.ogg`)
  plays on `StingerPlayer` (Music bus) simultaneously with the layer crossfade.

### 3.4 Audio Event Table

All audio events, their trigger signals, target bus, spatialization mode, and
scheduling priority are listed below. Priority 1 = highest (preempts lower-priority
sounds in the pool under load shedding).

| Event ID | Trigger Signal | Handler Method | Asset Slot | Bus | 3D / 2D | Priority |
|----------|---------------|----------------|------------|-----|---------|----------|
| `AE-01` | `BaseTool.tool_activated("gravity_flip", target)` | `_on_tool_activated` | `sfx_tool_gravity_flip_activate_01.ogg` | SFX | 3D (player position) | 1 |
| `AE-02` | `BaseTool.tool_deactivated("gravity_flip")` | `_on_tool_deactivated` | `sfx_tool_gravity_flip_release_01.ogg` | SFX | 3D (player position) | 2 |
| `AE-03` | `BaseTool.tool_activated("time_slow", target)` | `_on_tool_activated` | `sfx_tool_time_slow_activate_01.ogg` | SFX | 3D (player position) | 1 |
| `AE-04` | `BaseTool.tool_deactivated("time_slow")` | `_on_tool_deactivated` | `sfx_tool_time_slow_release_01.ogg` | SFX | 3D (player position) | 2 |
| `AE-05` | `BaseTool.tool_activated("force_push", target)` | `_on_tool_activated` | `sfx_tool_force_push_activate_01.ogg` | SFX | 3D (player position) | 1 |
| `AE-06` | `BaseTool.tool_deactivated("force_push")` | `_on_tool_deactivated` | `sfx_tool_force_push_release_01.ogg` | SFX | 3D (player position) | 2 |
| `AE-07` | `EscalationManager.escalation_level_changed(level, name)` | `_on_escalation_changed` | (crossfade between layer slots) | Music | 2D | 1 |
| `AE-08` | `EscalationManager.critical_entered` | `_on_critical_entered` | `sfx_event_critical_stinger_01.ogg` | Music | 2D | 1 |
| `AE-09` | `HealthComponent.health_changed(hp, max)` — hp/max < LOW_HP_THRESHOLD | `_on_health_changed` | `sfx_player_lowhealth_warning_01.ogg` | UI | 2D | 2 |
| `AE-10` | `HealthComponent.health_changed(hp, max)` — damage taken (hp decreased) | `_on_health_changed` | `sfx_player_damage_grunt_01.ogg` | SFX | 2D | 2 |
| `AE-11` | `HealthComponent.died` | `_on_player_died` | `sfx_player_death_01.ogg` | SFX | 2D | 1 |
| `AE-12` | `ObjectiveManager.primary_objective_complete` | `_on_objective_complete` | `sfx_event_objective_success_01.ogg` | UI | 2D | 1 |
| `AE-13` | `ExtractionZone.run_succeeded` | `_on_run_succeeded` | `sfx_event_run_success_01.ogg` | UI | 2D | 1 |
| `AE-14` | `ExtractionZone.run_failed` | `_on_run_failed` | `sfx_event_run_fail_01.ogg` | UI | 2D | 1 |
| `AE-15` | `InteractableTerminal.interacted` | `_on_terminal_interacted` | `sfx_interact_terminal_01.ogg` | SFX | 3D (terminal position) | 2 |
| `AE-16` | `CharacterController.landed` (footstep) | `_on_footstep` | `sfx_player_footstep_concrete_01.ogg` | SFX | 3D (player position) | 3 |
| `AE-17` | `CharacterController.jumped` | `_on_jump` | `sfx_player_jump_01.ogg` | SFX | 3D (player position) | 3 |
| `AE-18` | Scene ready / run start | `_on_run_started` | `amb_env_facility_idle_loop.ogg` | SFX | 2D | 3 |

### 3.5 Footstep System Detail

Footsteps use the `CharacterController.landed` signal as a one-shot trigger rather
than a polling loop. This avoids requiring AudioManager to query character position
every frame.

For the vertical slice, a single concrete footstep variant is used for all surfaces.
The surface-material system (for future variants: metal, grating, carpet) is
architecturally reserved via an enum in `AudioManager` but not implemented until
Alpha scope requires it.

Footstep events are priority 3 (lowest). Under SFX pool pressure they are the
first to be dropped.

### 3.6 Low-Health Warning Detail

The low-health warning (AE-09) is a periodic pulsing tone, not a one-shot. When
`_on_health_changed` fires with `hp / max < LOW_HP_THRESHOLD`:

- If the warning is not already playing, start it on a dedicated 2D `AudioStreamPlayer`
  on the UI bus with a looping asset.
- If health recovers above `LOW_HP_THRESHOLD`, stop the warning immediately.
- The warning uses a separate dedicated player node (not the SFX pool) so it cannot
  be preempted by pool load shedding.

### 3.7 Result Sting Ducking

When AE-12, AE-13, or AE-14 fires (mission result stings), the Music bus is ducked
by `RESULT_STING_DUCK_DB` dB over `RESULT_STING_DUCK_ATTACK` seconds via
`AudioServer.set_bus_volume_db()`. After the sting finishes playing, the Music bus
volume returns to nominal over `RESULT_STING_DUCK_RELEASE` seconds.

### 3.8 Asset Naming Convention

All audio assets follow the project convention:
`[category]_[context]_[name]_[variant].[ext]`

| Category Prefix | Meaning |
|-----------------|---------|
| `sfx_` | Sound effect (tool, player, interact, event) |
| `mus_` | Music loop or layer |
| `amb_` | Ambient environment loop |

All assets are `.ogg` (Vorbis). The asset file naming table in Section 3.4 lists
the exact slot filenames. Placeholder files may use any audio content but MUST use
the exact filenames specified — AudioManager loads by path constant.

Asset paths are defined as constants in `audio_manager.gd` at the top of the file,
so all path strings are in one location and never scattered through handler methods.

---

## 4. Formulas

### 4.1 Linear to Decibel Conversion (Godot standard)

All volume calculations use Godot's `linear_to_db()` / `db_to_linear()` functions.
The relationship is:

```
db    = 20 * log10(linear)
linear = 10 ^ (db / 20)

Examples:
  0.0 linear = -inf dB  (silence)
  0.5 linear = -6.0 dB  (half amplitude)
  1.0 linear =  0.0 dB  (unity)
```

### 4.2 Distance Attenuation (AudioStreamPlayer3D)

Godot's `AudioStreamPlayer3D` uses a built-in attenuation model. The configured
model for all SFX pool nodes is `ATTENUATION_INVERSE_DISTANCE` (Godot default):

```
attenuation = unit_size / max(distance, unit_size)

Variables:
  distance   = distance from listener to source (metres)
  unit_size  = ATTENUATION_UNIT_SIZE (default 1.0 m; configurable per event type)

At distance = unit_size:   attenuation = 1.0  (0 dB, full volume)
At distance = 2 * unit_size: attenuation = 0.5 (-6 dB)
At distance = MAX_DISTANCE: attenuation approaches 0 (silence)

ATTENUATION_UNIT_SIZE values by event type:
  Tool SFX (AE-01 to AE-06): 2.0 m  — tools are close-range, loud
  Terminal SFX (AE-15):       1.5 m  — moderate range
  Footsteps (AE-16, AE-17):  1.0 m  — very local
  Ambient (AE-18):            N/A    — 2D, no distance model
```

### 4.3 Music Layer Crossfade

```
crossfade_duration = MUSIC_CROSSFADE_DURATION  (default 2.0 s)

At time t within crossfade (0 ≤ t ≤ crossfade_duration):
  outgoing_volume_linear = lerp(1.0, 0.0, t / crossfade_duration)
  incoming_volume_linear = lerp(0.0, 1.0, t / crossfade_duration)

Both are applied as bus send volume overrides via:
  MusicPlayer.volume_db = linear_to_db(outgoing_volume_linear)
  IncomingPlayer.volume_db = linear_to_db(incoming_volume_linear)

Note: linear lerp is used (not dB lerp) to avoid the perceptual loudness spike
that occurs when two signals at 0 dB sum during a dB-space crossfade.
```

### 4.4 Result Sting Ducking

```
duck_target_db = Music_nominal_db - RESULT_STING_DUCK_DB

Attack phase (t from 0 to RESULT_STING_DUCK_ATTACK):
  music_volume_db = lerp(Music_nominal_db, duck_target_db,
                         t / RESULT_STING_DUCK_ATTACK)

Release phase (t from 0 to RESULT_STING_DUCK_RELEASE):
  music_volume_db = lerp(duck_target_db, Music_nominal_db,
                         t / RESULT_STING_DUCK_RELEASE)

Variables:
  Music_nominal_db          = -6 dB (Music bus default)
  RESULT_STING_DUCK_DB      = 8 dB  (duck depth)
  RESULT_STING_DUCK_ATTACK  = 0.1 s (fast duck, stinger hits immediately)
  RESULT_STING_DUCK_RELEASE = 2.0 s (slow recovery, graceful)

Example: Music plays at -6 dB. Sting fires.
  Duck target = -6 - 8 = -14 dB
  Music drops to -14 dB over 0.1 s while sting plays at full volume.
  After sting ends, music recovers to -6 dB over 2.0 s.
```

### 4.5 Low-Health Threshold Check

```
LOW_HP_THRESHOLD = 0.25  (range: 0.0–1.0)

warning_active = (current_hp / max_hp) < LOW_HP_THRESHOLD

Example: max_hp = 100, current_hp = 22
  ratio = 22 / 100 = 0.22
  0.22 < 0.25 → warning_active = true
```

### 4.6 SFX Pool Load Shedding

When all eight pool nodes are active and a new SFX event arrives:

```
candidate = pool node with lowest priority currently playing

if new_event.priority < candidate.current_priority:
    # new event is higher priority (lower number = higher priority)
    stop candidate
    use candidate node for new event
else:
    # new event is equal or lower priority — discard
    return
```

This ensures tool SFX (priority 1) and critical stingers always play. Footsteps
(priority 3) are silently dropped under load. The discarded event is not queued;
it is gone.

---

## 5. Edge Cases

| Scenario | Explicit Behaviour |
|----------|-------------------|
| `escalation_level_changed` fires twice in rapid succession (same frame) | Second crossfade call updates the crossfade target. The incoming stream switches to the new target level; the outgoing fade continues from its current volume. No double-crossfade. |
| `critical_entered` fires while a crossfade to level 3 is already in progress | Stinger plays immediately on `StingerPlayer`. Crossfade continues uninterrupted. Stinger is on a separate player node so there is no conflict. |
| `HealthComponent.health_changed` fires for a heal (hp increases) | `_on_health_changed` checks direction. If `new_hp > previous_hp`, no damage grunt plays. Low-health warning is re-evaluated: if ratio is now above threshold, warning stops. |
| `HealthComponent.health_changed` fires multiple times per frame (multi-hit) | Each call is handled independently. Damage grunt has a `GRUNT_COOLDOWN_SECONDS` debounce timer — at most one grunt per cooldown window. Low-health warning check runs each time (cheap boolean comparison). |
| `HealthComponent.died` fires while low-health warning is playing | Warning player is stopped immediately. Death sound plays on the 2D non-pool player. Pool is not used for death to guarantee it plays. |
| `run_succeeded` and `run_failed` both fire on the same frame (impossible by design, but defensive) | `_on_run_succeeded` and `_on_run_failed` each check a `_run_ended` boolean flag. Whichever fires first sets the flag and plays the sting. The second is a no-op. |
| SFX pool is fully occupied (all 8 nodes playing) and a priority-1 event arrives | Pool ejects the lowest-priority currently-playing node and reassigns it. Priority 1 is always guaranteed a slot. |
| SFX pool node's `AudioStreamPlayer3D` parent scene is changed (scene transition) | Pool nodes are parented to `AudioManager` (autoload), not the gameplay scene. Scene transitions do not free pool nodes. |
| `BaseTool.tool_activated` fires for an unknown tool name | `_on_tool_activated` logs a warning via `push_warning()` and plays a generic fallback SFX (`sfx_tool_unknown_activate_01.ogg`). No crash. |
| Audio asset file is missing at runtime | `AudioManager._ready()` validates all asset paths using `ResourceLoader.exists()`. Missing assets log a warning; the event slot plays silence (no crash). |
| Two players use the same tool simultaneously (co-op) | Each player's `BaseTool` instance is distinct. Both `tool_activated` signals fire. Both compete for SFX pool slots at priority 1. With 8 pool nodes this is fine for up to 4 simultaneous activations. |
| `InteractableTerminal.interacted` fires but terminal has no world position | If the terminal node reference is null or not in the scene tree, `AudioManager` falls back to playing the SFX at the local player's position rather than crashing. |
| Music layer assets are not yet imported (first boot) | `AudioManager._ready()` calls `ResourceLoader.exists()` on each layer path. Missing layers cause the layer to be null; crossfade to a null layer is skipped with a warning. The remaining valid layers continue to function. |

---

## 6. Dependencies

| System | Relationship | Signal(s) Consumed |
|--------|--------------|--------------------|
| **Physics Tool System** (`BaseTool`) | AudioManager subscribes to tool signals. BaseTool is required to emit these signals on every activation and deactivation. | `tool_activated(tool_name, target)`, `tool_deactivated(tool_name)` |
| **Escalation System** (`EscalationManager`) | AudioManager subscribes to level-change signals to drive music layer transitions. EscalationManager must emit these on every level change including the transition from CALM at run start. | `escalation_level_changed(level, name)`, `critical_entered` |
| **Health & Death System** (`HealthComponent`) | AudioManager subscribes to health events for grunt and warning. Each player's `HealthComponent` must be connected individually by the signal-wiring pass at spawn time. | `health_changed(hp, max)`, `died` |
| **Objective System** (`ObjectiveManager`) | AudioManager subscribes to primary objective completion for success stinger. | `primary_objective_complete` |
| **Extraction System** (`ExtractionZone`) | AudioManager subscribes to run result signals for result stings and music stop. | `run_succeeded`, `run_failed` |
| **InteractableTerminal** | AudioManager subscribes to interaction signal for terminal SFX. Terminal must be passed as the signal emitter so AudioManager can read its world position. | `interacted` (emitter provides position) |
| **Character Controller** (`CharacterController`) | AudioManager subscribes to movement signals for footstep and jump SFX. | `landed`, `jumped` |
| **Godot AudioServer** | AudioManager configures buses and applies bus volume changes at runtime via `AudioServer.set_bus_volume_db()`. Bus layout must match Section 3.2 exactly. | — |
| **Settings & Options System** (future) | Will call `AudioManager.set_bus_volume(bus_name, linear_volume)` public method to apply user volume preferences. AudioManager must expose this method. | — |
| **Visual Effects & Juice System** (future) | Coordinates timing with AudioManager for events where audio and VFX must be frame-synchronous (e.g., force-push impact). Protocol: VFX listens to same signals independently; no direct coupling to AudioManager. | — |

**Bidirectional note**: The Physics Tool System GDD (section Required By) and the
Escalation System GDD (section Dependencies, "Audio System") already reference this
system. Those references are satisfied by this document.

---

## 7. Tuning Knobs

All constants below are exported variables on `AudioManager` (or a companion
`AudioConfig` resource) so they can be adjusted in the Godot Inspector without
code changes.

| Knob | Default | Safe Range | Affects |
|------|---------|------------|---------|
| `MASTER_VOLUME_DB` | 0 dB | -40–0 dB | Global output level |
| `MUSIC_BUS_VOLUME_DB` | -6 dB | -20–0 dB | Music loudness relative to SFX |
| `SFX_BUS_VOLUME_DB` | -3 dB | -20–0 dB | In-world SFX loudness |
| `UI_BUS_VOLUME_DB` | -2 dB | -12–0 dB | UI and stinger loudness |
| `MUSIC_CROSSFADE_DURATION` | 2.0 s | 0.5–5.0 s | How fast escalation music transitions feel |
| `RESULT_STING_DUCK_DB` | 8 dB | 0–20 dB | How much music drops under result stings |
| `RESULT_STING_DUCK_ATTACK` | 0.1 s | 0.05–0.5 s | Speed of music duck on sting hit |
| `RESULT_STING_DUCK_RELEASE` | 2.0 s | 0.5–5.0 s | Speed of music recovery after sting |
| `LOW_HP_THRESHOLD` | 0.25 | 0.1–0.5 | HP ratio below which warning tone plays |
| `GRUNT_COOLDOWN_SECONDS` | 0.4 s | 0.1–1.0 s | Min time between consecutive damage grunts |
| `ATTENUATION_UNIT_SIZE_TOOL` | 2.0 m | 0.5–5.0 m | Effective range of tool SFX |
| `ATTENUATION_UNIT_SIZE_TERMINAL` | 1.5 m | 0.5–5.0 m | Effective range of terminal SFX |
| `ATTENUATION_UNIT_SIZE_FOOTSTEP` | 1.0 m | 0.3–3.0 m | Effective range of footstep SFX |
| `SFX_MAX_DISTANCE` | 20.0 m | 5.0–50.0 m | Distance at which 3D SFX reach silence |
| `SFX_POOL_SIZE` | 8 | 4–16 | Max simultaneous positional SFX; higher = more CPU |
| `MUSIC_REVERB_WET` | 0.15 | 0.0–0.5 | Space feel of music bus reverb |

---

## 8. Acceptance Criteria

| # | Criterion | Test Method |
|---|-----------|-------------|
| AC-01 | No gameplay script calls `AudioStreamPlayer.play()` directly | Code review: grep for `.play()` in `src/scripts/` excluding `audio_manager.gd`; zero results |
| AC-02 | AudioManager autoload is present and `_ready()` completes without errors | Unit test: boot scene; assert `AudioManager` node exists in autoload tree; no GDScript errors in output |
| AC-03 | Bus layout matches spec: Master, Music, SFX, UI at correct indices | Unit test: assert `AudioServer.get_bus_name(0) == "Master"`, `get_bus_name(1) == "Music"`, `get_bus_name(2) == "SFX"`, `get_bus_name(3) == "UI"` |
| AC-04 | `BaseTool.tool_activated("gravity_flip", target)` triggers `sfx_tool_gravity_flip_activate_01.ogg` on SFX bus | Integration test: emit signal; assert a SFX pool node begins playing the correct stream within 1 frame |
| AC-05 | `BaseTool.tool_activated("time_slow", target)` triggers `sfx_tool_time_slow_activate_01.ogg` | Integration test: same method as AC-04 for time_slow |
| AC-06 | `BaseTool.tool_activated("force_push", target)` triggers `sfx_tool_force_push_activate_01.ogg` | Integration test: same method as AC-04 for force_push |
| AC-07 | `escalation_level_changed(1, "ALERT")` begins crossfade from layer 0 to layer 1 | Integration test: assert `MusicPlayer.stream` changes to layer_1 asset within `MUSIC_CROSSFADE_DURATION` + 1 frame |
| AC-08 | Music crossfade uses linear volume lerp; midpoint of crossfade has both layers at 50% linear volume | Unit test: mock crossfade; sample volumes at t = MUSIC_CROSSFADE_DURATION / 2; assert both volumes = 0.5 linear (±0.02) |
| AC-09 | `critical_entered` plays stinger on Music bus without interrupting layer crossfade | Integration test: trigger escalation to CRITICAL; assert StingerPlayer is playing AND MusicPlayer crossfade is active simultaneously |
| AC-10 | `health_changed` with ratio below LOW_HP_THRESHOLD starts looping warning tone | Integration test: set hp=20, max=100 (ratio 0.2 < 0.25); emit signal; assert dedicated warning player is playing |
| AC-11 | `health_changed` with ratio above LOW_HP_THRESHOLD after warning is active stops warning | Integration test: start warning; emit health_changed with hp=50 max=100; assert warning player stops within 1 frame |
| AC-12 | `HealthComponent.died` stops low-health warning and plays death sound | Integration test: start warning; emit `died`; assert warning stopped AND death SFX playing |
| AC-13 | `primary_objective_complete` plays success stinger on UI bus | Integration test: emit signal; assert UIPlayer begins playing `sfx_event_objective_success_01.ogg` |
| AC-14 | `run_succeeded` ducks Music bus and plays success sting | Integration test: emit signal; assert Music bus volume decreases by RESULT_STING_DUCK_DB within RESULT_STING_DUCK_ATTACK time |
| AC-15 | `run_failed` plays failure sting and neither result sting double-fires | Integration test: emit both `run_succeeded` and `run_failed` on same frame; assert exactly one sting plays |
| AC-16 | `InteractableTerminal.interacted` plays terminal SFX at terminal's world position | Integration test: place terminal at (10, 0, 0); emit signal; assert SFX pool node position == (10, 0, 0) within 1 frame |
| AC-17 | SFX pool does not grow beyond SFX_POOL_SIZE nodes | Unit test: fire SFX_POOL_SIZE + 4 simultaneous SFX events; assert `AudioManager.get_child_count()` equals initial count (no new nodes spawned) |
| AC-18 | Priority-1 SFX preempts a priority-3 SFX when pool is full | Unit test: fill pool with 8 footstep events (priority 3); fire tool activation (priority 1); assert tool SFX plays and one footstep was stopped |
| AC-19 | Missing audio asset logs a warning and does not crash | Unit test: set one asset path constant to a non-existent file; boot; assert `push_warning()` was called; assert no exceptions |
| AC-20 | All asset path constants resolve to existing `.ogg` files before first playtest milestone | Asset pipeline check: run `ResourceLoader.exists()` against all constants; all return true |
| AC-21 | `CharacterController.landed` triggers footstep SFX within 1 frame | Integration test: emit `landed`; assert SFX pool node begins playing footstep stream |
| AC-22 | Ambient loop starts on run begin and stops on `run_succeeded` or `run_failed` | Integration test: start scene; assert AmbiencePlayer playing; emit `run_succeeded`; assert AmbiencePlayer stopped |
