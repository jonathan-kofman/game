# Prototype Report: Physics Tools

## Hypothesis

Three physics tools — gravity flip, time slow, force push — will each feel
satisfying in isolation AND create interesting emergent combos when combined.
The 30-second loop (aim → activate → watch physics react) will be intrinsically
fun without any progression, story, or reward structure.

## Approach

Built a first-person test room in Godot 4.6 with Jolt Physics. Player can move,
aim with a raycast, and trigger three tools on keyboard keys G/T/F. 10–15
RigidBody3D objects scattered around the room. No UI, no networking, no
progression. Total prototype scope: 3 GDScript files + manual Godot scene setup.

Shortcuts taken:
- Hardcoded tuning values in physics_tools.gd (FORCE_PUSH_IMPULSE etc.)
- No audio feedback
- Primitive mesh assets (colored boxes and spheres only)
- Time slow implemented via direct velocity scaling (not Engine.time_scale)
- No undo/reset for tool states

## Result

- Gravity Flip feel: Pretty cool I like it
- Time Slow feel: Not really sure how it worked
- Force Push feel: quite strong
- Combo (all three): Cool
- Biggest surprise: Unsure
- Biggest problem: Couldnt easily look around because of the small play window and my mouse movement

## Metrics

- Frame time during time slow with 10 objects: [X ms]
- Force push impulse sweet spot: [X N — started at 18.0] allow for fluctuation
- Time slow factor sweet spot: [X — started at 0.15] Go higher
- How many times did you replay the same combo voluntarily: 10
- Did you want to keep playing after 5 minutes: Y but it needs more

## Recommendation: PROCEED

Gravity flip and force push both produced positive feel responses, and the combo
loop was replayed 10 times voluntarily with no progression or reward structure —
the core 30-second loop is intrinsically fun. Time slow could not be properly
evaluated because Jolt Physics sleeps resting objects, so velocity scaling had
no visible effect; this needs a retest with objects in motion (ramps, dropped
objects) before the tool is written off. Force push at 18N is too strong and
needs tuning down. The "wants to keep playing but needs more" response confirms
the loop has a foundation worth building on. Proceed to production implementation
with the architecture changes listed below, and retest time slow with moving
objects before committing to its production design.

---

## If Proceeding

Production implementation requirements (to revisit after recommendation):

**Architecture:**
- Physics Tool System needs a proper interface (BaseTool class) — one script per
  tool, not all tools in one file
- Time Slow needs rearchitecting — velocity scaling is hacky; consider a proper
  physics time dilation system or per-body simulation rate
- All tools need audio feedback — the silence makes interactions feel weightless
- Gravity Flip needs a visual indicator on affected objects (particle trail, color tint)
- Force Push needs a visual effect (shockwave ring, screen shake)

**Networking:**
- All tool activations must be server-authoritative
- Gravity flip state must be synced (which objects are flipped)
- Time slow area must be server-calculated (can't trust client positions)
- Use MultiplayerSynchronizer for RigidBody3D state + custom RPCs for tool activations

**Performance:**
- PhysicsShapeQueryParameters3D in _begin_time_slow() is fine for prototype;
  needs caching or event-based detection in production
- Target: time slow affecting 20+ objects at 60fps on mid-range hardware

**Scope adjustments:**
- Consider limiting gravity flip to one object at a time (reduce complexity)
- Consider adding a "charge" mechanic to force push (hold = bigger push)
- Consider making time slow a limited resource (cooldown or energy bar)

## Lessons Learned

- **Jolt Physics sleeps resting RigidBody3D objects** — velocity scaling (time slow)
  has no visible effect on bodies that aren't already moving. Production time slow
  needs to either wake all bodies in range before slowing them, or use a different
  mechanism (e.g. per-body gravity + drag scaling rather than velocity snapshot).
- **Time slow needs moving targets to be testable** — the test room should include
  objects on ramps or dropped from height so at least some are in motion at any
  given moment.
- **Force push at 18N is too strong for a 1kg box** — sweet spot is likely 8–12N.
  The "allow for fluctuation" note suggests a variable-strength push (hold-to-charge)
  may be worth prototyping.
- **Playtest environment matters** — mouse capture in the Godot editor preview window
  degraded the feel test; future playtests should run the exported build or use
  Project > Run in a maximized window.
