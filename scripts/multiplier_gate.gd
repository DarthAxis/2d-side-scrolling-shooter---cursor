## @file_description: Hyper-casual multiplier gate. When a bullet enters this
##                    Area2D it either adds to or multiplies the player's
##                    bullets_per_shot, duplicates the projectile, pops floating
##                    text (+X / xX), and plays a one-shot sound.
## @architecture_role: Level pickup / combat modifier (Area2D). Placed in stages
##                    so in-flight bullets from group "bullets" upgrade the ship.
## @dependencies: PlayerController in group "player" (apply_gate_add /
##                apply_gate_multiply / duplicate_bullet_from_gate);
##                Bullet nodes in group "bullets"; optional AudioStream on
##                trigger_sfx; optional Label child named "GateLabel".

## Area2D gate that upgrades volley size and splits bullets that pass through it.
class_name MultiplierGate
extends Area2D

## ADD raises bullets_per_shot by [member value]. MULTIPLY scales it by [member value].
enum GateType { ADD, MULTIPLY }

## Operator applied to the player's bullets_per_shot and to the popup prefix.
@export var gate_type: GateType = GateType.ADD

## Integer shown on the gate and applied to ADD (+value) or MULTIPLY (x value).
@export var value: int = 2

## If true, the player modifier is applied only on the first valid bullet.
@export var apply_modifier_once: bool = true

## If true, monitoring stops after the first valid bullet (one-time pickup).
@export var consume_on_trigger: bool = false

## Seconds between popup/SFX bursts so a volley does not stack audio.
@export var feedback_cooldown: float = 0.12

## Fill copied onto the child ColorRect in _ready(). Replace ColorRect with a sprite to change art.
@export var gate_color: Color = Color(0.25, 0.85, 0.55, 0.85)

## Font size of the floating +X / xX popup.
@export var popup_font_size: int = 42

## How far (pixels) the popup rises while fading out.
@export var popup_rise_pixels: float = 64.0

## Duration of the popup tween in seconds.
@export var popup_duration: float = 0.55

## Sound played on trigger. Assign a WAV/OGG in the Inspector; silent if empty.
@export var trigger_sfx: AudioStream

var _modifier_applied: bool = false
var _feedback_timer: float = 0.0
var _sfx_player: AudioStreamPlayer2D
var _gate_label: Label


## Wires overlap signals, caches optional label, and ensures an AudioStreamPlayer2D exists.
func _ready() -> void:
	monitoring = true
	monitorable = true
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_sfx_player = get_node_or_null("Sfx") as AudioStreamPlayer2D
	if _sfx_player == null:
		_sfx_player = AudioStreamPlayer2D.new()
		_sfx_player.name = "Sfx"
		add_child(_sfx_player)
	_gate_label = get_node_or_null("GateLabel") as Label
	var body := get_node_or_null("ColorRect") as ColorRect
	if body != null:
		body.color = gate_color
	_refresh_gate_label()


## Ticks the popup/SFX cooldown.
## [param delta]: Frame duration in seconds.
func _process(delta: float) -> void:
	if _feedback_timer > 0.0:
		_feedback_timer -= delta


## Refreshes the on-gate label when the scene is saved or visibility changes.
func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE or what == NOTIFICATION_VISIBILITY_CHANGED:
		_refresh_gate_label()


## Handles Area2D bullets. [param area]: The overlapping area.
func _on_area_entered(area: Area2D) -> void:
	_try_apply(area)


## Handles PhysicsBody2D projectiles. [param body]: The overlapping body.
func _on_body_entered(body: Node2D) -> void:
	_try_apply(body)


## Applies ADD/MULTIPLY to the player, duplicates the bullet, then shows popup + SFX.
## [param node]: Candidate collider; ignored unless it is in group "bullets".
func _try_apply(node: Node) -> void:
	if not monitoring:
		return
	if node == null or not is_instance_valid(node):
		return
	if not node.is_in_group("bullets"):
		return
	var bullet := node as Bullet
	if bullet != null:
		if not bullet.is_active:
			return
		if bullet.last_gate_id == get_instance_id():
			return
		bullet.last_gate_id = get_instance_id()
	var player := _find_player()
	_apply_player_modifier(player)
	_duplicate_incoming(bullet, player)
	_play_feedback()
	if consume_on_trigger:
		monitoring = false
		monitorable = false


## ADD: bullets_per_shot += value. MULTIPLY: bullets_per_shot *= value.
## [param player]: The PlayerController that owns the volley modifier.
func _apply_player_modifier(player: PlayerController) -> void:
	if player == null:
		return
	if apply_modifier_once and _modifier_applied:
		return
	_modifier_applied = true
	match gate_type:
		GateType.ADD:
			player.apply_gate_add(value)
		GateType.MULTIPLY:
			player.apply_gate_multiply(value)


## ADD duplicates [member value] extra copies. MULTIPLY splits into [member value] total.
## [param bullet]: The in-flight projectile that entered the gate.
## [param player]: Pool owner used to activate clones without new instantiations.
func _duplicate_incoming(bullet: Bullet, player: PlayerController) -> void:
	if bullet == null or player == null:
		return
	var extra := 0
	match gate_type:
		GateType.ADD:
			extra = maxi(value, 0)
		GateType.MULTIPLY:
			extra = maxi(value - 1, 0)
	if extra <= 0:
		return
	player.duplicate_bullet_from_gate(bullet, extra, get_instance_id())


## Spawns +X / xX floating text and plays [member trigger_sfx] if the cooldown elapsed.
func _play_feedback() -> void:
	if _feedback_timer > 0.0:
		return
	_feedback_timer = maxf(feedback_cooldown, 0.0)
	_spawn_floating_text()
	_play_sound()


## Returns the first PlayerController in group "player", or null.
func _find_player() -> PlayerController:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("player") as PlayerController


## Builds a world-space Label that rises and fades, then frees itself.
func _spawn_floating_text() -> void:
	var popup := Label.new()
	popup.text = _format_gate_text()
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", popup_font_size)
	popup.add_theme_color_override("font_color", Color.WHITE)
	popup.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	popup.add_theme_constant_override("outline_size", 8)
	popup.z_index = 100
	popup.top_level = true
	popup.position = global_position + Vector2(-48.0, -24.0)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parent := get_tree().current_scene if get_tree() != null else self
	if parent == null:
		parent = self
	parent.add_child(popup)
	var tween := popup.create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - popup_rise_pixels, popup_duration)
	tween.tween_property(popup, "modulate:a", 0.0, popup_duration)
	tween.chain().tween_callback(popup.queue_free)


## Plays [member trigger_sfx] through the local AudioStreamPlayer2D.
func _play_sound() -> void:
	if trigger_sfx == null or _sfx_player == null:
		return
	_sfx_player.stream = trigger_sfx
	_sfx_player.play()


## Writes +value or xvalue onto the optional GateLabel child.
func _refresh_gate_label() -> void:
	if _gate_label == null:
		_gate_label = get_node_or_null("GateLabel") as Label
	if _gate_label == null:
		return
	_gate_label.text = _format_gate_text()


## Returns the display string used by the gate body and the floating popup.
func _format_gate_text() -> String:
	match gate_type:
		GateType.ADD:
			return "+%d" % value
		GateType.MULTIPLY:
			return "x%d" % value
	return str(value)
