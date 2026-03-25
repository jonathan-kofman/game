# Game Concept: RIFT

*Created: 2026-03-25*
*Status: Draft*

---

## Elevator Pitch

> RIFT is a co-op physics-based roguelike where you and up to 3 friends breach
> abandoned corporate megastructures using gravity, time, and force tools —
> bringing back resources to build and expand your base between runs. Designed
> to be genuinely great solo, and even better with a squad.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Co-op physics roguelike + tactical extraction + sandbox base-building |
| **Platform** | PC, Console, Mobile, Web (all platforms) |
| **Target Audience** | Teens, young adults, and adults (13–35+) |
| **Player Count** | 1–4 players (solo is first-class, co-op amplifies) |
| **Session Length** | 15–20 min breach run; 1–2 hr full session |
| **Monetization** | TBD (premium or cosmetic F2P to be decided) |
| **Estimated Scope** | Large (18–24 months to full game; mini-games shippable at 3–6 months each) |
| **Comparable Titles** | Portal 2, Deep Rock Galactic, Hades |

---

## Core Fantasy

You are a physics-empowered operative breaching vast, eerie corporate
megastructures that humanity abandoned — or was forced to leave. You wield
tools that bend the laws of the environment itself: gravity fields, time
dilation, force projection. The facilities push back with traps, failing
infrastructure, and things that shouldn't still be running.

Between runs, you return to your base — a reclaimed slice of one of these
structures — and build it into something greater using what you extracted.
Every breach teaches you something new about what happened here.

You can do this alone, reading the silence. Or with friends, creating chaos
and pulling off things no solo operative ever could.

---

## Unique Hook

Like Portal 2 co-op, AND ALSO it's a roguelike with a persistent base you
build from extracted resources, set inside a dark sci-fi world that tells
its story entirely through the environments you breach.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | 3 | Physics interactions feel weighty and satisfying; audio/visual feedback on tool use |
| **Fantasy** (make-believe) | 4 | You are a capable operative in a mysterious, abandoned sci-fi world |
| **Narrative** (drama, story arc) | 5 | Environmental storytelling; the world reveals what happened run by run |
| **Challenge** (obstacle course, mastery) | 1 | High skill ceiling on physics tools; roguelike difficulty scaling |
| **Fellowship** (social connection) | 2 | Co-op coordination; shared "did you see that?" moments |
| **Discovery** (exploration, secrets) | 2 | Hidden lore, secret rooms, emergent physics interactions |
| **Expression** (self-expression) | 4 | Base building; tool loadout choices; play style |
| **Submission** (relaxation) | N/A | Not a relaxation game |

### Key Dynamics (Emergent player behaviors)

- Players will experiment with tool combinations to find unintended solutions
- Solo players will develop precise, efficient techniques; co-op squads will develop chaotic-but-effective combos
- Players will compare run stories ("we accidentally launched the whole platform into the reactor")
- Players will optimize base layouts and theorize about the lore between sessions

### Core Mechanics (Systems we build)

1. **Physics Tool System** — Each player accesses gravity manipulation, time dilation, and force projection. In co-op, multiple tools can operate simultaneously to create combinations impossible solo.
2. **Breach Mission Loop** — Procedurally generated megastructure facilities with hand-crafted room archetypes. Enter, hit objective, extract before escalation. ~15–20 min runs.
3. **Base Building System** — Persistent base built from extracted materials. Real physics simulation applies to structures. Upgrades unlock new tools, mission types, and story fragments.
4. **Environmental Narrative System** — Lore delivered entirely through the environment: logs, architectural details, anomalies. No cutscenes. Players piece together what happened.
5. **Solo/Co-op Scaling** — Mission difficulty, enemy count, and puzzle complexity scale to player count. Solo players gain mobility advantages; co-op squads gain multi-tool synergies.

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | Choose tools, base layout, mission approach, and play style | Core |
| **Competence** | High skill ceiling on physics tools; visible mastery growth over runs | Core |
| **Relatedness** | Co-op coordination creates shared stories; solo players bond with the world's mystery | Supporting |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** — Run completion, base progression, tool mastery, unlock trees
- [x] **Explorers** — Hidden lore, secret rooms, emergent physics interactions, world mystery
- [x] **Socializers** — Co-op runs, squad coordination, sharing stories
- [ ] **Killers/Competitors** — PvP undecided; not the primary focus

### Flow State Design

- **Onboarding curve**: First run is a guided breach of a simpler facility. Physics tools introduced one at a time. By end of run 1, player has used all three tools at least once.
- **Difficulty scaling**: Procedural mission difficulty scales to run count + player skill signals (completion time, resource extracted). Harder missions unlock organically.
- **Feedback clarity**: Physics interactions give immediate audiovisual feedback. Base upgrades visually reflect progression. Run debrief screen shows improvement metrics.
- **Recovery from failure**: Roguelike — death returns you to base. You keep a portion of extracted resources. Failure always teaches something about the facility or your tool usage.

---

## Core Loop

### Moment-to-Moment (30 seconds)
Using physics tools to interact with the environment — launching objects with
force projection, reversing gravity on a platform, slowing a collapsing
corridor with time dilation. Each interaction has satisfying physical weight.
The 30-second loop must feel good in isolation, like swinging in Spider-Man
or portal placement in Portal.

### Short-Term (5–15 minutes)
A breach run segment: navigate a procedurally assembled wing of the facility,
use tools to bypass obstacles and enemies, hit a mid-objective (data extract,
power core, survivor). Escalation timer creates urgency in the back half.

### Session-Level (30–120 minutes)
2–3 breach runs per session. Between runs: return to base, process resources,
make one meaningful upgrade or structural addition to the base. Discover one
new lore fragment. End session with a clear "next time I want to try X."

### Long-Term Progression
- Base grows from a bare foothold into a complex, personalized facility
- New tool variants unlock deeper physics interactions
- Facility types expand — each megastructure has its own architectural style, hazards, and lore thread
- The overarching mystery of what happened to these structures unfolds over weeks of play

### Retention Hooks

- **Curiosity**: What happened in this facility? What's in the locked wing? What does that anomaly mean?
- **Investment**: The base you built, the upgrades you unlocked, the lore fragments you've collected
- **Social**: Friends want to run missions together; co-op combos create stories worth sharing
- **Mastery**: Physics tool skill ceiling is high — there's always a more elegant solution

---

## Game Pillars

### Pillar 1: Physics is the Language
Every interaction — puzzles, traversal, combat, building — flows through the
physics simulation. If it bypasses physics, it doesn't belong in RIFT.

*Design test: "Does this feature use or respond to the physics simulation? If not, cut it or redesign it until it does."*

### Pillar 2: Smart Feels Better Than Fast
Clever solutions always beat brute force. Reward players who think,
coordinate, and experiment — not players who grind or out-react the game.

*Design test: "Does a player who thinks about this problem get a better outcome than one who just pushes through it? If not, rebalance."*

### Pillar 3: The World Has History
The sci-fi setting is not a backdrop. Every room, object, and anomaly tells
part of a story. Players who look closer always find something.

*Design test: "Does this room tell us something about what happened here? If it's a generic corridor with no story, it needs a detail."*

### Pillar 4: Failure is Interesting
Roguelike runs that go wrong should still feel worth having. Failure teaches,
surprises, and produces the best stories.

*Design test: "If the squad wipes here, is it still a good memory? If failure just feels bad with no insight, the encounter needs rethinking."*

### Pillar 5: Solo is First-Class
The game is designed to be genuinely fun alone. Co-op amplifies the
experience — it never completes it.

*Design test: "If someone plays this entirely solo, do they get a full, satisfying game? If a mechanic only makes sense in co-op, it needs a solo equivalent."*

### Anti-Pillars (What RIFT Is NOT)

- **NOT a grind**: No repetitive content that doesn't teach, evolve, or reveal something new
- **NOT brainrot**: No cheap dopamine loops, no pay-to-win, no shallow meme content
- **NOT co-op-dependent**: Fun is never locked behind having a squad — co-op is a multiplier, not a requirement
- **NOT fast-food design**: No feature that bypasses the physics simulation for convenience

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Portal 2 | Physics-tool puzzle satisfaction; co-op coordination; dark-funny sci-fi tone | Roguelike structure instead of linear levels; persistent world | Proves physics tools + co-op = beloved game |
| Deep Rock Galactic | Co-op mission loop; solo scaling; "failure is fun" culture | Physics-first mechanics; base building; richer narrative | Proves 1–4 co-op roguelike works commercially |
| Hades | Roguelike loop with narrative delivery through repetition; failure as story | 3D, physics-based, multiplayer | Proves story and roguelike are not opposites |
| Minecraft | Base building as long-term investment; emergent creativity | Constrained by physics simulation; sci-fi setting | Proves players invest deeply in persistent bases |
| Rainbow Six Siege | Tactical co-op; destructibility; skill expression | Roguelike, no PvP (TBD); physics tools replace operators | Proves destructible environments create engagement |

**Non-game inspirations**: Control (SCP/New Weird aesthetic — bureaucratic horror beneath a mundane surface), Annihilation (environmental mystery, something wrong that can't be explained), Half-Life (environmental storytelling, physics as gameplay foundation)

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 13–35+ (teens, young adults, adults) |
| **Gaming experience** | Mid-core to hardcore |
| **Time availability** | 30 min quickplay (1 run) or 1–2 hr sessions on weekends |
| **Platform preference** | PC primary; console and mobile secondary |
| **Current games they play** | Portal 2, Deep Rock Galactic, Minecraft, Rocket League, R6 Siege |
| **What they're looking for** | A clever, physics-driven co-op game that respects their intelligence and rewards mastery |
| **What would turn them away** | Pay-to-win, shallow mechanics, required grind, poor solo experience |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4 — best transition from Roblox/Luau (GDScript ≈ Lua), free, all-platform export, excellent physics engine |
| **Key Technical Challenges** | Physics networking (syncing simulation across players); procedural generation quality; physics performance at scale |
| **Art Style** | 3D stylized — clean, sleek corporate sci-fi with dark undertones. Think Portal's white/grey aesthetic with Control's brutalist architecture |
| **Art Pipeline Complexity** | Medium-High (custom 3D environments, modular room system) |
| **Audio Needs** | Adaptive — ambient tension that escalates during breach missions; satisfying physics SFX |
| **Networking** | Client-Server (dedicated or hosted); physics authority on server |
| **Content Volume** | MVP: 1 facility type, 3 room archetypes, 3 tools, 1 base area. Full: 5+ facility types, 20+ room archetypes, 6+ tool variants |
| **Procedural Systems** | Procedural facility assembly from hand-crafted room modules (like Dead Cells or Hades room layout) |

---

## Risks and Open Questions

### Design Risks
- Solo experience may feel lonely or mechanically limited compared to co-op — needs dedicated solo design pass
- Physics tool skill ceiling may be too high for casual players in the target audience (teens)
- Roguelike structure may conflict with players wanting a clear narrative endpoint

### Technical Risks
- **Physics networking is the #1 technical risk** — syncing Godot 4 physics across 4 clients is unsolved until prototyped
- Procedural room assembly quality — bad generation breaks immersion and pacing
- Performance on mobile — physics simulation is CPU-intensive

### Market Risks
- Co-op roguelike space is growing competitive (Risk of Rain 2, Deep Rock, Helldivers 2)
- "Physics game" as a genre label doesn't market cleanly — needs strong visual hook
- Cross-platform launch scope may delay PC release

### Scope Risks
- Three interlocking systems (tools + missions + base) is ambitious for a 3-person team
- Art pipeline for modular 3D environments requires strong asset discipline
- Networking adds significant development and testing overhead

### Open Questions
- Can Godot 4's physics networking handle 4-player real-time physics sync? → **Answer via RIFT prototype (mini-game 1)**
- What is the minimum base-building feature set that feels meaningful? → **Answer via CONSTRUCT prototype (mini-game 3)**
- Does the roguelike structure work with environmental storytelling, or do players miss persistent lore? → **Answer via BREACH prototype (mini-game 2)**
- PvP: is there a mode where squads compete in the same facility simultaneously? → **Defer to post-MVP**

---

## MVP Definition

**Core hypothesis**: Players find breaching procedurally assembled facilities
using physics tools satisfying enough to run again immediately after failure.

**Required for MVP** (RIFT mini-game — prototype #1):
1. Three physics tools: gravity flip, time slow, force push — all controllable in real time
2. One facility type with 5–8 hand-crafted rooms assembled procedurally
3. One objective type (extract the core) with escalation timer
4. 2-player co-op with physics networking validated
5. Basic run debrief screen

**Explicitly NOT in MVP**:
- Base building (CONSTRUCT prototype validates this separately)
- Full narrative/lore system
- Mobile or console builds
- More than one facility type
- Progression or unlocks beyond the run

### Scope Tiers

| Tier | Content | Features | Notes |
| ---- | ---- | ---- | ---- |
| **MVP (RIFT mini-game)** | 1 facility, 5–8 rooms, 3 tools | Physics tools + breach loop + 2-player co-op | Ship as standalone prototype |
| **Mini-game 2 (BREACH)** | Roguelike loop + escalation | Full run structure + resource extraction | Ship as standalone |
| **Mini-game 3 (CONSTRUCT)** | Base building slice | Physics-based building + upgrade system | Ship as standalone |
| **Full Game Alpha** | All 3 systems integrated | Combined loop, 3 facility types, 1–4 players | Internal playtest |
| **Full Vision** | 5+ facilities, full lore, all platforms | Polished, complete game | Shipped product |

---

## Development Strategy

RIFT uses a **mini-game pipeline** — build and ship 3 standalone prototypes
that each validate one of the three core systems, then integrate them into
the full game. Each mini-game is a shippable product in its own right.

```
Phase 1 (Months 1–3):   RIFT mini-game     — physics tools + breach loop
Phase 2 (Months 3–5):   BREACH mini-game   — roguelike run structure
Phase 3 (Months 5–7):   CONSTRUCT mini-game — base building + physics sim
Phase 4 (Months 7+):    Integration        — full game loop
```

This approach:
- Validates each system before combining them
- Produces 3 shippable games that build an audience
- De-risks the ambitious full scope
- Keeps the 3-person team focused on one system at a time

---

## Next Steps

- [ ] Run `/setup-engine godot 4` to configure Godot 4 and populate version-aware reference docs
- [ ] Run `/design-review design/gdd/game-concept.md` to validate concept completeness
- [ ] Run `/map-systems` to decompose RIFT into individual systems with dependencies
- [ ] Run `/prototype physics-tools` to begin RIFT mini-game (Phase 1)
- [ ] Run `/sprint-plan new` to plan the first sprint
