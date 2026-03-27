## MissionDebriefUI
## Post-run summary screen shown after ExtractionZone signals a run end.
## Pauses the game tree while visible; unpauses and frees itself on Continue.
## process_mode = ALWAYS so it continues to run while the tree is paused.

class_name MissionDebriefUI
extends CanvasLayer

# ── Signals ───────────────────────────────────────────────────────────────────

## Fired when the player dismisses the debrief. Main listens to return to menu.
signal debrief_dismissed

# ── Tuning knobs ─────────────────────────────────────────────────────────────

## Duration of the XP count-up animation in seconds.
const XP_COUNT_DURATION := 2.0

const _OUTCOME_COLORS := {
	"SUCCEEDED":       Color(0.0,  0.784, 0.0),   # #00C800 green
	"PARTIAL_SUCCESS": Color(1.0,  0.843, 0.0),   # #FFD700 gold
	"FAILED":          Color(1.0,  0.267, 0.267),  # #FF4444 red
}

const _OUTCOME_FLAVOR := {
	"SUCCEEDED":       "Well done, agent.",
	"PARTIAL_SUCCESS": "Partial extraction. Some objectives remain.",
	"FAILED":          "Mission failed. Regroup and try again.",
}

# ── Node references ───────────────────────────────────────────────────────────

@onready var _outcome_banner:   ColorRect     = $Panel/VBox/OutcomeBanner
@onready var _outcome_label:    Label         = $Panel/VBox/OutcomeBanner/BannerVBox/OutcomeLabel
@onready var _flavor_label:     Label         = $Panel/VBox/OutcomeBanner/BannerVBox/FlavorLabel
@onready var _objective_list:   VBoxContainer = $Panel/VBox/ObjectiveList
@onready var _xp_label:         Label         = $Panel/VBox/XPLabel
@onready var _loot_label:       Label         = $Panel/VBox/LootLabel
@onready var _continue_button:  Button        = $Panel/VBox/ContinueButton

# ── State ─────────────────────────────────────────────────────────────────────

var _xp_target:  int   = 0
var _xp_elapsed: float = 0.0
var _anim_done:  bool  = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)

# ── Public API ────────────────────────────────────────────────────────────────

## Display the debrief screen. Call once after adding to the scene tree.
## outcome:    "SUCCEEDED", "PARTIAL_SUCCESS", or "FAILED"
## objectives: Array of Dictionaries — {"name": String, "is_complete": bool}
## xp_earned:  Total XP for this run (clamped to >= 0 internally)
func show_debrief(outcome: String, objectives: Array, xp_earned: int) -> void:
	_xp_target   = max(xp_earned, 0)
	_xp_elapsed  = 0.0
	_anim_done   = false
	_continue_button.disabled = true

	_apply_outcome_banner(outcome)
	_populate_objectives(objectives)
	_xp_label.text   = "0"
	_loot_label.text = "No items collected"

	get_tree().paused = true

# ── Process — XP count-up animation ──────────────────────────────────────────

func _process(delta: float) -> void:
	if _anim_done:
		return

	_xp_elapsed = minf(_xp_elapsed + delta, XP_COUNT_DURATION)

	var t := _xp_elapsed / XP_COUNT_DURATION if XP_COUNT_DURATION > 0.0 else 1.0
	_xp_label.text = str(int(_xp_target * t))

	if _xp_elapsed >= XP_COUNT_DURATION:
		_xp_label.text = str(_xp_target)
		_anim_done = true
		_continue_button.disabled = false

# ── Private ───────────────────────────────────────────────────────────────────

func _apply_outcome_banner(outcome: String) -> void:
	_outcome_banner.color = _OUTCOME_COLORS.get(outcome, Color(0.5, 0.5, 0.5))
	_outcome_label.text   = outcome.replace("_", " ")
	_flavor_label.text    = _OUTCOME_FLAVOR.get(outcome, "")

func _populate_objectives(objectives: Array) -> void:
	for child in _objective_list.get_children():
		child.queue_free()

	if objectives.is_empty():
		var empty := Label.new()
		empty.text = "No objectives defined"
		_objective_list.add_child(empty)
		return

	for obj in objectives:
		var is_complete: bool = obj.get("is_complete", false)
		var label := Label.new()
		label.text          = "%s  %s" % ["✓" if is_complete else "✗", obj.get("name", "Unknown")]
		label.modulate      = Color(0.0, 0.784, 0.0) if is_complete else Color(1.0, 0.267, 0.267)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_objective_list.add_child(label)

func _on_continue_pressed() -> void:
	get_tree().paused = false
	debrief_dismissed.emit()
	queue_free()
