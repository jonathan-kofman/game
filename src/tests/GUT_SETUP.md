# GUT Test Setup

GUT (Godot Unit Testing) is required to run the test suite.

## Install GUT

1. Open the Godot project (`src/`)
2. Go to **AssetLib** tab → search "GUT"
3. Install **Gut - Godot Unit Testing** by bitwes
4. Re-open the project when prompted

Alternatively, clone directly:
```
cd src/addons
git clone https://github.com/bitwes/Gut.git gut
```

## Run Tests

From the Godot editor, open `res://addons/gut/gut_cmdln.gd` as a scene and run,
or use the GUT panel at the bottom of the editor.

To run a specific suite from the command line:
```
godot --headless -s res://addons/gut/gut_cmdln.gd -- -gtest=res://tests/unit/core/test_health_component.gd
```

## Test Files

| File | System | Notes |
|------|--------|-------|
| `tests/unit/core/test_health_component.gd` | HealthComponent | 20 tests — pure logic, no physics |
| `tests/unit/tools/test_gravity_flip_tool.gd` | GravityFlipTool | 10 tests — state + toggle logic |
| `tests/unit/tools/test_force_push_tool.gd` | ForcePushTool | 8 tests — signal + direction |
| `tests/unit/tools/test_time_slow_tool.gd` | TimeSlowTool | 10 tests — deactivate path + defaults |

## Manual Tests (require Godot running)

| Scene | What to test |
|-------|-------------|
| `scenes/gameplay/RampTestRoom.tscn` | Time Slow (T) on rolling objects — resolves R-07 |
| `scenes/main/Main.tscn` | Full run loop: terminal → escalation → extraction |
