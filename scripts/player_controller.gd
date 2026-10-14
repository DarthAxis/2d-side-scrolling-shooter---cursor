## @file_description: 2D player ship controller. Follows pointer X, auto-aims
##                    at the nearest enemy, and fires pooled Area2D bullets.
## @architecture_role: Player entity (CharacterBody2D). Runs every physics frame
##                     during gameplay to move, acquire targets, and shoot.
## @dependencies: Nodes in group "enemies"; Bullet class (scripts/bullet.gd);
##                optional child Marker2D named "Muzzle" for spawn offset;
##                MultiplierGate (scripts/multiplier_gate.gd) via bullets_per_shot.

## Pointer-follow player that auto-aims at group "enemies" and fires pooled bullets.
class_name PlayerController
extends CharacterBody2D

## Seconds between shots. Lower values increase fire rate. Default 0.15s.
@export var fire_rate: float = 0.15

## Damage copied onto each pooled bullet when it is fired.
@export var damage: float = 10.0

## Bullet travel speed in pixels per second.
@export var bullet_speed: float = 900.0

## How many projectiles leave the muzzle each volley. Modified by Multiplier Gates.
@export var bullets_per_shot: int = 1

## Hard cap so ADD/MULTIPLY gates cannot exhaust the bullet pool or flood the screen.
@export var max_bullets_per_shot: int = 64

## Total fan width in degrees when [member bullets_per_shot] is greater than 1.
@export var shot_spread_degrees: float = 12.0

## Inclusive left bound for pointer-follow on the X axis, in pixels.
@export var min_x: float = 100.0

## Inclusive right bound for pointer-follow on the X axis, in pixels.
@export var max_x: float = 980.0

## Number of Area2D bullets pre-allocated into the pool on ready.
## Size this at least [member max_bullets_per_shot] plus in-flight duplicates from gates.
@export var bullet_pool_size: int = 96

## Collision radius used when constructing pooled bullets in code.
@export var bullet_radius: float = 8.0

## Fill of the generated pool-bullet texture. Real bullet art is swapped in _create_pooled_bullet().
@export var bullet_color: Color = Color(1.0, 0.92, 0.35, 1.0)

var _fire_timer: float = 0.0
var _bullet_pool: Array[Bullet] = []
var _muzzle: Node2D


## Caches the muzzle marker and pre-allocates the Area2D bullet pool.
func _ready() -> void:
	add_to_group("player")
	_muzzle = get_node_or_null("Muzzle") as Node2D
	_build_bullet_pool()


## Moves with the pointer, acquires the nearest enemy, and fires on [member fire_rate].
## [param delta]: Physics frame duration in seconds.
func _physics_process(delta: float) -> void:
	_follow_pointer_x()
	_fire_timer -= delta
	var target := _find_nearest_enemy()
	if target == null:
		return
	if _fire_timer <= 0.0:
		_fire_at(target)
		_fire_timer = maxf(fire_rate, 0.01)


## Snaps the player X position to the current mouse/touch pointer, clamped
## between [member min_x] and [member max_x]. Y is left unchanged.
func _follow_pointer_x() -> void:
	var pointer_x := get_global_mouse_position().x
	global_position.x = clampf(pointer_x, min_x, max_x)


## Returns the nearest Node2D in group "enemies", or null if none exist.
func _find_nearest_enemy() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	var enemies: Array[Node] = tree.get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist_sq := INF
	var origin := _get_muzzle_position()
	for node in enemies:
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy is CanvasItem and not (enemy as CanvasItem).is_visible_in_tree():
			continue
		var dist_sq := origin.distance_squared_to(enemy.global_position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = enemy
	return nearest


## Fires [member bullets_per_shot] pooled bullets toward [param target] in a fan.
func _fire_at(target: Node2D) -> void:
	var spawn := _get_muzzle_position()
	var travel := target.global_position - spawn
	if travel.length_squared() < 0.0001:
		travel = Vector2.UP
	var count := maxi(1, bullets_per_shot)
	var spread := deg_to_rad(shot_spread_degrees)
	var playfield := _get_playfield_rect()
	for i in count:
		var bullet := _acquire_bullet()
		if bullet == null:
			return
		var t := 0.0 if count == 1 else (float(i) / float(count - 1) - 0.5)
		var dir := travel.rotated(t * spread)
		bullet.playfield_rect = playfield
		bullet.activate(spawn, dir, bullet_speed, damage)


## Adds [param amount] to [member bullets_per_shot], clamped to [member max_bullets_per_shot].
func apply_gate_add(amount: int) -> void:
	bullets_per_shot = clampi(bullets_per_shot + amount, 1, max_bullets_per_shot)


## Multiplies [member bullets_per_shot] by [param amount], clamped to [member max_bullets_per_shot].
func apply_gate_multiply(amount: int) -> void:
	bullets_per_shot = clampi(bullets_per_shot * maxi(amount, 1), 1, max_bullets_per_shot)


## Spawns [param extra_count] extra pooled copies of [param source], fanned around its heading.
## Used by MultiplierGate when a live bullet passes through. Clones ignore that same gate.
## [param source]: The in-flight bullet to copy.
## [param extra_count]: How many additional projectiles to activate from the pool.
## [param gate_id]: Instance id of the gate, written to [member Bullet.last_gate_id].
func duplicate_bullet_from_gate(source: Bullet, extra_count: int, gate_id: int) -> void:
	if source == null or extra_count <= 0:
		return
	source.last_gate_id = gate_id
	var playfield := _get_playfield_rect()
	var spread := deg_to_rad(maxi(6, extra_count) * 4.0)
	for i in extra_count:
		var clone := _acquire_bullet()
		if clone == null:
			return
		var t := 0.0 if extra_count == 1 else (float(i + 1) / float(extra_count + 1) - 0.5)
		var dir := source.direction.rotated(t * spread)
		var spawn := source.global_position + dir * 12.0
		clone.playfield_rect = playfield
		clone.last_gate_id = gate_id
		clone.activate(spawn, dir, source.speed, source.damage)


## Returns the first inactive bullet in the pool, or null if all are in flight.
func _acquire_bullet() -> Bullet:
	for bullet in _bullet_pool:
		if bullet != null and not bullet.is_active:
			return bullet
	return null


## World-space spawn point for bullets (Muzzle child if present).
func _get_muzzle_position() -> Vector2:
	if _muzzle != null:
		return _muzzle.global_position
	return global_position + Vector2(0.0, -24.0)


## Viewport-based recycle bounds with a small margin so bullets leave the screen
## before they are deactivated.
func _get_playfield_rect() -> Rect2:
	var viewport := get_viewport_rect()
	var margin := 64.0
	return Rect2(
		viewport.position.x - margin,
		viewport.position.y - margin,
		viewport.size.x + margin * 2.0,
		viewport.size.y + margin * 2.0
	)


## Pre-allocates [member bullet_pool_size] Area2D bullets as children so firing
## never instantiates nodes at runtime.
func _build_bullet_pool() -> void:
	_bullet_pool.clear()
	for i in bullet_pool_size:
		var bullet := _create_pooled_bullet()
		bullet.name = "PooledBullet_%d" % i
		add_child(bullet)
		bullet.deactivate()
		_bullet_pool.append(bullet)


## Constructs a self-contained Area2D bullet (collision + placeholder sprite).
## Replace the Sprite2D texture in a dedicated bullet scene if you swap art.
func _create_pooled_bullet() -> Bullet:
	var bullet := Bullet.new()
	bullet.top_level = true
	bullet.collision_layer = 2
	bullet.collision_mask = 0xFFFFFFFF

	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = bullet_radius
	collision.shape = circle
	bullet.add_child(collision)

	var sprite := Sprite2D.new()
	sprite.texture = _make_bullet_texture()
	bullet.add_child(sprite)
	return bullet


## Builds a circular placeholder texture for pooled bullets.
func _make_bullet_texture() -> Texture2D:
	var size := int(maxi(8, int(bullet_radius * 2.0)))
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := size * 0.5 - 0.5
	for y in size:
		for x in size:
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= radius:
				image.set_pixel(x, y, bullet_color)
	return ImageTexture.create_from_image(image)
