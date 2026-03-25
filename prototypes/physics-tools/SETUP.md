# Physics Tools Prototype — Godot 4.6 Setup

## Prerequisites
- Godot 4.6.1 installed (https://godotengine.org/download)
- Jolt Physics enabled (it's the default in 4.6 — no action needed)

---

## Step 1: Create a New Godot Project

1. Open Godot 4.6
2. Create a new project — name it `rift-physics-tools-proto`
3. Choose **Forward+** renderer
4. Copy the `scripts/` folder from this directory into the project root

---

## Step 2: Enable Input Actions

Go to **Project > Project Settings > Input Map** and add:

| Action | Key |
|--------|-----|
| `move_forward` | W |
| `move_back` | S |
| `move_left` | A |
| `move_right` | D |
| `tool_gravity` | G |
| `tool_time_slow` | T |
| `tool_force_push` | F |

---

## Step 3: Build the Player Scene

Create `Player.tscn` with this node tree:

```
CharacterBody3D  [script: player.gd]
├── CollisionShape3D  (CapsuleShape3D, height=1.8, radius=0.4)
├── Camera3D  (position y=1.6)
│   ├── RayCast3D  (target_position=(0,0,-10), enabled=true)
│   └── CanvasLayer
│       ├── Label  [name: Crosshair]  (anchors: center, text: "+")
│       └── Label  [name: ToolLabel]  (anchors: bottom-left, text: "")
└── Node  [name: PhysicsTools, script: physics_tools.gd]
```

---

## Step 4: Build the Test Room Scene

Create `TestRoom.tscn`:

```
Node3D  [name: TestRoom]
├── WorldEnvironment  (add default sky)
├── DirectionalLight3D  (rotation x=-45)
│
├── StaticBody3D  [name: Floor]
│   ├── CollisionShape3D  (BoxShape3D, size=20x0.2x20)
│   └── MeshInstance3D  (BoxMesh, size=20x0.2x20)
│
├── StaticBody3D  [name: Walls]  (4x wall boxes around the room)
│
│  ── Physics test objects (RigidBody3D each, script: physics_object.gd) ──
├── RigidBody3D  [name: Box_01]
│   ├── CollisionShape3D  (BoxShape3D 1x1x1)
│   └── MeshInstance3D  (BoxMesh 1x1x1)
│
├── RigidBody3D  [name: Box_02]  ... (add 6-10 boxes at different positions)
├── RigidBody3D  [name: Sphere_01]
│   ├── CollisionShape3D  (SphereShape3D radius=0.5)
│   └── MeshInstance3D  (SphereMesh)
│
│  ── Stacking challenge (stack 3-4 boxes for gravity tool test) ──
├── RigidBody3D  [name: Stack_A]  position=(5, 0.5, 0)
├── RigidBody3D  [name: Stack_B]  position=(5, 1.5, 0)
├── RigidBody3D  [name: Stack_C]  position=(5, 2.5, 0)
│
│  ── Ramp (for force push testing) ──
├── StaticBody3D  [name: Ramp]  (rotated box, 30 degree angle)
│
└── Player  (instance Player.tscn, position y=1.0)
```

---

## Step 5: Run It

Press **F5** to run. Use:

| Key | Action |
|-----|--------|
| WASD | Move |
| Mouse | Look |
| Space | Jump |
| **G** | Gravity Flip (aim at object first) |
| **T** | Time Slow (area around player) |
| **F** | Force Push (aim at object first) |
| Esc | Release mouse |

---

## What to Test

### Tool 1 — Gravity Flip (G)
- [ ] Flip a single box — does it feel immediate and satisfying?
- [ ] Flip a stacked tower — does the chaos feel fun?
- [ ] Flip the same object again to restore — does restore feel intentional?
- [ ] Flip multiple objects — do they interact with each other well?

### Tool 2 — Time Slow (T)
- [ ] Slow a rolling sphere — is the visual effect clear?
- [ ] Toggle on/off rapidly — does it feel snappy?
- [ ] Combine with Force Push: slow objects, then push one through the others
- [ ] Does releasing time slow feel like a "burst" of energy returning?

### Tool 3 — Force Push (F)
- [ ] Push a single box — is the impulse satisfying?
- [ ] Push a stacked tower — domino effect?
- [ ] Push an airborne object (gravity flipped) — does it feel like zero-G?
- [ ] Tune `FORCE_PUSH_IMPULSE` in physics_tools.gd until it feels right

### Combo Test
- [ ] Gravity flip a box → time slow → force push it across the room
- [ ] Does combining tools feel like an "aha" moment?
- [ ] Would you want to do that again?

---

## Filling in the Report

After testing, fill in the **Result**, **Metrics**, and **Recommendation** sections
of `REPORT.md`. Be specific: "response felt sluggish at X" not "felt bad."
