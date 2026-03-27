## ToolSelectionUI
## Displays the player's three physics tools at the bottom-center of the screen.
## Subscribes to BaseTool signals (tool_activated, tool_deactivated, tool_failed)
## and provides: active highlight, TimeSlowTool draining bar, and timed failure messages.
## All layout and timing values are @export so designers can tune in the Inspector.
## See design/gdd/tool-selection-ui.md for full specification.

class_name ToolSelectionUI
extends CanvasLayer

# ── Tuning Knobs (GDD §7) ─────────────────────────────────────────────────────

@export var slot_width: int = 64
@export var slot_height: int = 64
@export var slot_spacing: int = 8
@export var label_font_size: int = 14
@export var label_color: Color = Color.WHITE
@export var inactive_alpha: float = 0.4
@export var active_alpha: float = 1.0
@export var draining_bar_height: int = 8
@export var max_display_duration: float = 5.0
@export var failure_message_display_duration: float = 2.0
@export var failure_message_fade_duration: float = 0.5

# ── Constants ─────────────────────────────────────────────────────────────────

const _INACTIVE_COLOR := Color(0.15, 0.15, 0.20)
const _ACTIVE_COLOR   := Color(0.0,  0.55, 1.0)
const _BAR_GREEN      := Color(0.0,  1.0,  0.39)  # #00FF64 — safe / full
const _BAR_RED        := Color(1.0,  0.20, 0.20)  # #FF3232 — warning / at limit

# Tool node names must match the node names in Player.tscn > ToolManager.
const _TOOL_NAMES  : Array[String] = ["GravityFlipTool", "TimeSlowTool", "ForcePushTool"]
const _TOOL_LABELS : Array[String] = ["Gravity Flip",    "Time Slow",    "Force Push"]
const _TIME_SLOW_SLOT : int = 1  # index of TimeSlowTool in the arrays above

# ── Internal node references (built in _build_ui) ─────────────────────────────

var _slot_panels : Array[PanelContainer] = []
var _slot_styles : Array[StyleBoxFlat]   = []
var _draining_bar       : ProgressBar = null
var _draining_bar_style : StyleBoxFlat = null
var _failure_label      : Label = null

# ── Runtime state ─────────────────────────────────────────────────────────────

var _active_slot     : int   = -1     # -1 = no tool active
var _time_slow_held  : float = 0.0
var _time_slow_active: bool  = false
var _failure_elapsed : float = -1.0   # < 0 means no message is showing

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 105
	_build_ui()

func _process(delta: float) -> void:
	_update_draining_bar(delta)
	_update_failure_message(delta)

# ── Public API — connect these to BaseTool signals in main.gd ─────────────────

## Highlights the active slot. Clears any active failure message.
## Signature matches BaseTool.tool_activated(tool_name: String, target: Node).
func on_tool_activated(tool_name: String, _target: Node) -> void:
	var idx := _TOOL_NAMES.find(tool_name)
	if idx < 0:
		return

	# Clear previous highlight (rapid swap — no ghost highlights remain, GDD §5.1)
	if _active_slot >= 0 and _active_slot != idx:
		_set_slot_active(_active_slot, false)

	_active_slot = idx
	_set_slot_active(idx, true)

	if idx == _TIME_SLOW_SLOT:
		_time_slow_held = 0.0
		_time_slow_active = true
		if _draining_bar != null:
			_draining_bar.value = 0.0
			_draining_bar.visible = true

	# Clear failure message on successful activation (GDD §3.5)
	if _failure_label != null:
		_failure_label.visible = false
		_failure_elapsed = -1.0

## Restores slot to inactive state; hides draining bar for TimeSlowTool.
## Signature matches BaseTool.tool_deactivated(tool_name: String).
func on_tool_deactivated(tool_name: String) -> void:
	var idx := _TOOL_NAMES.find(tool_name)
	if idx < 0:
		return

	if _active_slot == idx:
		_set_slot_active(idx, false)
		_active_slot = -1

	if idx == _TIME_SLOW_SLOT:
		_time_slow_active = false
		_time_slow_held = 0.0
		if _draining_bar != null:
			_draining_bar.visible = false
			_draining_bar.value = 0.0
			if _draining_bar_style != null:
				_draining_bar_style.bg_color = _BAR_GREEN

## Shows a timed failure message. Replaces any currently displayed message (GDD §3.7).
## Signature matches BaseTool.tool_failed(tool_name: String, reason: String).
func on_tool_failed(_tool_name: String, reason: String) -> void:
	if _failure_label == null:
		return
	_failure_label.text = reason
	_failure_label.modulate.a = 1.0
	_failure_label.visible = true
	_failure_elapsed = 0.0

# ── Private helpers ───────────────────────────────────────────────────────────

func _update_draining_bar(delta: float) -> void:
	if not _time_slow_active or _draining_bar == null:
		return
	_time_slow_held += delta
	var fraction := clampf(_time_slow_held / max_display_duration, 0.0, 1.0)
	_draining_bar.value = fraction * 100.0
	if _draining_bar_style != null:
		_draining_bar_style.bg_color = _BAR_GREEN.lerp(_BAR_RED, fraction)

func _update_failure_message(delta: float) -> void:
	if _failure_elapsed < 0.0 or _failure_label == null:
		return
	_failure_elapsed += delta
	var fade_start := failure_message_display_duration - failure_message_fade_duration
	if _failure_elapsed >= failure_message_display_duration:
		_failure_label.visible = false
		_failure_elapsed = -1.0
	elif _failure_elapsed >= fade_start:
		var t := (_failure_elapsed - fade_start) / failure_message_fade_duration
		_failure_label.modulate.a = 1.0 - t

func _set_slot_active(idx: int, is_active: bool) -> void:
	if idx < 0 or idx >= _slot_styles.size():
		return
	var style := _slot_styles[idx]
	var color := _ACTIVE_COLOR if is_active else _INACTIVE_COLOR
	var alpha := active_alpha if is_active else inactive_alpha
	style.bg_color = Color(color.r, color.g, color.b, alpha)

# ── UI Construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Full-screen root for anchor positioning
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Bottom strip — full width, tall enough for failure label + slots
	var strip := Control.new()
	strip.anchor_left   = 0.0
	strip.anchor_right  = 1.0
	strip.anchor_top    = 1.0
	strip.anchor_bottom = 1.0
	strip.offset_top    = -(slot_height + 32.0)  # room for failure label + gap
	strip.offset_bottom = -16.0                   # 16px clearance from screen bottom
	strip.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	root.add_child(strip)

	# CenterContainer centres the VBox horizontally inside the strip
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(center)

	# VBox: failure message row + tool slots row
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	center.add_child(vbox)

	# ── Failure message label ──────────────────────────────────────────────────
	_failure_label = Label.new()
	_failure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_failure_label.add_theme_font_size_override("font_size", 12)
	_failure_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_failure_label.visible = false
	vbox.add_child(_failure_label)

	# ── Tool slots HBox ────────────────────────────────────────────────────────
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", slot_spacing)
	vbox.add_child(hbox)

	for i in _TOOL_NAMES.size():
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(slot_width, slot_height)

		# Store StyleBoxFlat per slot so we can update color without re-allocating
		var style := StyleBoxFlat.new()
		style.bg_color = Color(_INACTIVE_COLOR.r, _INACTIVE_COLOR.g, _INACTIVE_COLOR.b, inactive_alpha)
		style.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("panel", style)
		_slot_styles.append(style)

		var inner := VBoxContainer.new()
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 4)
		panel.add_child(inner)

		var lbl := Label.new()
		lbl.text = _TOOL_LABELS[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", label_font_size)
		lbl.add_theme_color_override("font_color", label_color)
		inner.add_child(lbl)

		# TimeSlowTool — draining bar only (GDD §3.4)
		if i == _TIME_SLOW_SLOT:
			var bar := ProgressBar.new()
			bar.min_value = 0.0
			bar.max_value = 100.0
			bar.value = 0.0
			bar.custom_minimum_size = Vector2(slot_width - 12, draining_bar_height)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.show_percentage = false
			bar.visible = false

			var fill_style := StyleBoxFlat.new()
			fill_style.bg_color = _BAR_GREEN
			bar.add_theme_stylebox_override("fill", fill_style)
			_draining_bar_style = fill_style

			var bg_style := StyleBoxFlat.new()
			bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
			bar.add_theme_stylebox_override("background", bg_style)

			inner.add_child(bar)
			_draining_bar = bar

		hbox.add_child(panel)
		_slot_panels.append(panel)
