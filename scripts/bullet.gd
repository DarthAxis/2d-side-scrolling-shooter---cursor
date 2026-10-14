## @file_description: Pooled projectile used by the player controller. Moves in a
##                    given direction, applies damage on enemy overlap, then
##                    deactivates and returns itself to the pool.
## @architecture_role: Entity / pooled projectile (Area2D). Instantiated once at
##                     load time by PlayerController and reused every shot.
## @dependencies: Requires colliding bodies/areas to be in group "enemies" and
##                to implement take_damage(amount) or expose a health property.

## Pooled Area2D projectile. Activate to fire; deactivate to return to the pool.
class_name Bullet
extends Area2D

## World-space travel speed in pixels per second. Copied from the player on fire.
var speed: float = 800.0

## Damage applied to the first valid enemy this bullet overlaps.
var damage: float = 10.0

## Normalized travel direction set when the bullet is taken from the pool.
var direction: Vector2 = Vector2.UP

## True while this instance is in flight. Inactive bullets skip physics.
var is_active: bool = false

## World-space bounds used to recycle the bullet when it leaves the playfield.
var playfield_rect: Rect2 = Rect2(0.0, 0.0, 1080.0, 1920.0)

## Instance id of the last MultiplierGate this bullet (or its clone) passed through.
## Prevents re-entry and clone ping-pong inside the same Area2D.
var last_gate_id: int = 0


## Starts inactive and connects overlap signals used for hit detection.
func _ready() -> void:
	monitoring = false
	monitorable = false
	visible = false
	set_physics_process(false)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


## Advances the bullet along [member direction] and recycles it off-playfield.
## [param delta]: Physics frame duration in seconds.
func _physics_process(delta: float) -> void:
	if not is_active:
		return
	global_position += direction * speed * delta
	if not playfield_rect.has_point(global_position):
		deactivate()


## Activates this pooled instance at [param spawn_position], travelling toward
## [param travel_direction] at [param new_speed] and dealing [param new_damage].
func activate(
	spawn_position: Vector2,
	travel_direction: Vector2,
	new_speed: float,
	new_damage: float
) -> void:
	global_position = spawn_position
	direction = travel_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	speed = new_speed
	damage = new_damage
	rotation = direction.angle() + PI / 2.0
	is_active = true
	visible = true
	monitoring = true
	monitorable = true
	add_to_group("bullets")
	set_physics_process(true)


## Returns this bullet to the inactive pool state without freeing the node.
func deactivate() -> void:
	is_active = false
	visible = false
	monitoring = false
	monitorable = false
	last_gate_id = 0
	if is_in_group("bullets"):
		remove_from_group("bullets")
	set_physics_process(false)


## Handles Area2D overlaps. [param area]: The other area that entered this bullet.
func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


## Handles PhysicsBody2D overlaps. [param body]: The body that entered this bullet.
func _on_body_entered(body: Node2D) -> void:
	_try_hit(body)


## Applies damage to [param target] if it belongs to group "enemies", then
## recycles this bullet.
func _try_hit(target: Node) -> void:
	if not is_active:
		return
	if not target.is_in_group("enemies"):
		return
	if target.has_method("take_damage"):
		target.take_damage(damage)
	elif "health" in target:
		target.health -= damage
	deactivate()
