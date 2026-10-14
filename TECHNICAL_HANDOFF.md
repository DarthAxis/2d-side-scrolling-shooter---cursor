# Technical Handoff & Maintenance Guide

This file is the source of truth for a human taking over the project. Values, groups, collision layers, and file paths below were checked against the Godot project and scripts. If code and this guide disagree, **the code wins** — then this file must be updated.

Gaps, implied-but-missing systems, and review follow-ups are **not** listed as if they were shipped. They live in [`docs/ISSUE_LOG.md`](docs/ISSUE_LOG.md). Check that log on every code review.

---

## 1. What this game is

| | |
| --- | --- |
| **Project name** | `2D side scrolling shooter - Cursor` (`project.godot`) |
| **Engine** | Godot **4.5**, GDScript |
| **Renderer** | GL Compatibility (desktop and mobile) |
| **Play pattern** | 2D auto-shooter: pointer moves the ship on **X only**; the ship auto-fires at group `enemies`; gates upgrade and split bullets |
| **Not this** | Not idle, not tower defense, not a complete mobile product. Those were earlier product notes. The shipped code is combat + gates only. |

There is **no main scene** in `project.godot`. Opening the project and pressing Play will fail until you assign one. See [§8 Build a playable level](#8-build-a-playable-level-from-scratch).

There are **no autoloads**, **no Input Map actions** (movement uses `get_global_mouse_position()`), and **no named physics layers** in Project Settings. Layers are raw bit values on nodes/scripts.

---

## 2. How to open, run, and tune without guessing

1. Install / open **Godot 4.5**.
2. Import this folder (the one that contains `project.godot`).
3. After you have a main scene (or by opening a scene and pressing F6), run it.
4. Click a node in the scene tree. Tune **Inspector** properties listed in [§5](#5-player-and-bullet-pool) and [§6](#6-multiplier-gate). You do not need to edit GDScript for fire rate, damage, gate `+2` vs `x3`, etc.
5. Change art on scene nodes (`Sprite2D`, `ColorRect`, `GateLabel`) or assign `trigger_sfx` on a gate.

Scripts use Godot `##` doc comments. In the editor, those show up as Inspector tooltips and in the Script help panel.

---

## 3. What is on disk (actual tree)

Do not expect empty folders from older drafts (`scenes/ui`, `scenes/levels`, `scripts/autoload`, `scripts/components`, `assets`). They are **not** in the repo.

```text
res://
├── project.godot
├── icon.svg                          # Project icon only
├── README.md                         # Short front door
├── TECHNICAL_HANDOFF.md              # This guide
├── docs/
│   └── ISSUE_LOG.md                  # Gaps, implied systems, review stamps
├── .cursor/rules/                    # AI coding / handoff rules
├── scenes/entities/
│   ├── player.tscn                   # Ship: body, empty Sprite2D, Muzzle
│   └── multiplier_gate.tscn          # Gate: Area2D, ColorRect, label, SFX player
└── scripts/
    ├── player_controller.gd          # class_name PlayerController
    ├── bullet.gd                     # class_name Bullet
    └── multiplier_gate.gd            # class_name MultiplierGate
```

| File | Role |
| --- | --- |
| `player_controller.gd` | Move on X, pick nearest enemy, fire pool, apply gate math, duplicate in-flight bullets |
| `bullet.gd` | Move, hit `enemies`, recycle when off-screen or after a hit |
| `multiplier_gate.gd` | On bullet overlap: change volley size, split the bullet, popup, optional SFX |

---

## 4. Groups, collision, and contracts

If these are wrong, **nothing will shoot, hit, or upgrade**. Set them in the Inspector (Node → Groups) or in script.

### 4.1 Node groups

| Group | Who joins | Why it exists |
| --- | --- | --- |
| `player` | Player, in `PlayerController._ready()` | Gates call `apply_gate_add`, `apply_gate_multiply`, `duplicate_bullet_from_gate` on the first node in this group |
| `enemies` | **You must add this.** No enemy scene ships yet | Targeting and bullet damage. Hidden `CanvasItem` enemies are skipped for aim |
| `bullets` | Active pooled bullets only (`Bullet.activate` / removed in `deactivate`) | Gates ignore anything not in this group |

### 4.2 Collision layers (Godot 1-based layer numbers)

| Actor | Layer (bit value in file) | Mask | Meaning |
| --- | --- | --- | --- |
| Player (`player.tscn`) | Layer **1** (`collision_layer = 1`) | `0` (collides with nothing) | CharacterBody2D 48×48 box. Does not physics-collide with gates or bullets |
| Pooled bullets (created in code) | Layer **2** (`collision_layer = 2`) | All layers (`0xFFFFFFFF`) | Area2D. Must stay on **layer 2** or gates will not see them |
| Gate (`multiplier_gate.tscn`) | Layer **3** (`collision_layer = 4`) | Layer **2** (`collision_mask = 2`) | Area2D 140×72. Detects player bullets |

Bullets also listen for `area_entered` / `body_entered`. They only apply damage if the other node is in group `enemies`. A gate is not an enemy, so bullets do not “kill” gates.

**Do not** put the player in group `enemies`. Bullet mask includes the player’s layer; a self-hit would immediately recycle shots at the muzzle.

### 4.3 Enemy hit contract (required when you add enemies)

Preferred:

```gdscript
func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		queue_free()
```

If `take_damage` is missing, the bullet subtracts from a `health` property when that property exists. Then the bullet deactivates (one enemy per bullet).

---

## 5. Player and bullet pool

**Scene:** `res://scenes/entities/player.tscn`  
**Scripts:** `res://scripts/player_controller.gd`, `res://scripts/bullet.gd`

Select the **Player** root in the Inspector.

### 5.1 Scene tree

| Node | Type | Notes |
| --- | --- | --- |
| `Player` | CharacterBody2D | Script + exports. Group `player` is added at runtime |
| `CollisionShape2D` | 48×48 rectangle | Hit box for the ship (nothing uses it yet except future hazards) |
| `Sprite2D` | Sprite2D | **No texture assigned.** The ship is invisible until you drop art here |
| `Muzzle` | Marker2D | Default offset `(0, -28)`. Bullets spawn here. If this node is deleted, code falls back to player position + `(0, -24)` |

### 5.2 Inspector properties

| Property | Default | What changing it does |
| --- | --- | --- |
| `fire_rate` | `0.15` | Seconds between auto-volleys. Runtime minimum `0.01` |
| `damage` | `10.0` | Copied onto each bullet when fired. Gate clones copy the **source bullet’s** damage, not a new read of this field |
| `bullet_speed` | `900.0` | Pixels per second. Clones copy the source bullet’s speed |
| `bullets_per_shot` | `1` | Projectiles per volley. Floor `1`. Gates change this |
| `max_bullets_per_shot` | `64` | Clamp after every ADD/MULTIPLY on the **player**. Does not by itself cap in-flight clones |
| `shot_spread_degrees` | `12.0` | Total fan width for a volley when count > 1. One bullet = no spread |
| `min_x` / `max_x` | `100` / `980` | Inclusive X clamp for pointer follow (meant for a ~1080-wide layout). **Y is never moved by this script** |
| `bullet_pool_size` | `96` | How many Area2D bullets are created in `_ready()`. Firing never `instantiate()`s new bullets |
| `bullet_radius` | `8.0` | Circle collision and placeholder texture size |
| `bullet_color` | `Color(1, 0.92, 0.35, 1)` | Fill of the generated circle texture |

`min_x`, `max_x`, `bullet_radius`, and `bullet_color` are script defaults (not duplicated in the `.tscn`). Changing them in the Inspector still works.

### 5.3 Combat behaviour (what the code actually does)

1. Every physics frame, `global_position.x` is set to the mouse/touch X, clamped to `min_x`–`max_x`.
2. The nearest **visible** `Node2D` in group `enemies` is chosen (distance from muzzle). If none, **the ship does not fire**.
3. When `_fire_timer` elapses, it fires `max(1, bullets_per_shot)` pooled bullets in a fan around the vector muzzle → enemy. Degenerate aim (enemy on top of muzzle) uses `Vector2.UP`.
4. Each active bullet is `top_level = true` (does not inherit ship transform), in group `bullets`.
5. Movement is `position += direction * speed * delta`. Leaving the **viewport + 64px margin** deactivates the bullet.
6. First valid enemy overlap: damage, then deactivate.

### 5.4 Object pool (read this before raising fire rate)

- Pool is an array of `Bullet` children of the player, built once.
- `_acquire_bullet()` returns the first inactive bullet, or `null`.
- If the pool is empty mid-volley or mid-gate-split, **remaining shots are skipped**. There is no overflow spawn.
- **Size rule:** `bullet_pool_size` must cover (max volley) + (bullets still flying) + (gate extras). `96` with a cap of `64` leaves 32 slots for in-flight clones; heavy gate chains can still starve the pool.

### 5.5 Gate APIs on the player

```text
apply_gate_add(amount)       → bullets_per_shot = clamp(bullets_per_shot + amount, 1, max)
apply_gate_multiply(amount)  → bullets_per_shot = clamp(bullets_per_shot * max(amount, 1), 1, max)
duplicate_bullet_from_gate(source, extra_count, gate_id)
```

Clone spread uses `deg_to_rad(max(6, extra_count) * 4)` degrees, fanned around the source heading. Each clone spawns `12` pixels along its new direction. Source and clones store `last_gate_id` so they do not retrigger the **same** gate instance.

### 5.6 Swapping player / bullet art

- **Ship:** assign a `Texture2D` on `Player/Sprite2D`. Move/scale the sprite; keep `CollisionShape2D` aligned if you care about future collisions.
- **Muzzle:** drag the `Muzzle` marker in the 2D editor.
- **Bullets:** placeholders are generated in `_create_pooled_bullet()` / `_make_bullet_texture()`. To use a real sprite, change that constructor to instance a bullet `.tscn` (keep `class_name Bullet`, layer 2, and the activate/deactivate API). Or only retint via `bullet_color` / `bullet_radius`.

---

## 6. Multiplier gate

**Scene:** `res://scenes/entities/multiplier_gate.tscn`  
**Script:** `res://scripts/multiplier_gate.gd`

Instance this scene in a level so flying bullets pass through the 140×72 area.

### 6.1 Scene tree

| Node | Type | Notes |
| --- | --- | --- |
| `MultiplierGate` | Area2D | Layer 3, mask 2. Monitoring on |
| `CollisionShape2D` | 140×72 rectangle | Detection volume |
| `ColorRect` | 140×72 | Placeholder body. `_ready()` copies `gate_color` onto it |
| `GateLabel` | Label | Shows `+value` or `xvalue`. Font size 36, white + outline |
| `Sfx` | AudioStreamPlayer2D | Created in the scene; script will create one if missing |

### 6.2 Inspector properties

| Property | Default | What changing it does |
| --- | --- | --- |
| `gate_type` | `ADD` (0) | `ADD` → popup `+N`, `player.apply_gate_add(value)`, extra clones = `value`. `MULTIPLY` → popup `xN`, `apply_gate_multiply(value)`, extra clones = `value - 1` (split into `value` total including the original) |
| `value` | `2` | Integer on the label and in the math. MULTIPLY of `1` changes nothing and adds no clones |
| `apply_modifier_once` | `true` | Player volley size changes on the **first** valid bullet only. Later bullets still split |
| `consume_on_trigger` | `false` | If true, monitoring stops after the first valid bullet (one-shot pickup) |
| `feedback_cooldown` | `0.12` | Minimum seconds between popup + SFX so one volley does not stack sound |
| `gate_color` | green `Color(0.25, 0.85, 0.55, 0.85)` | Applied to `ColorRect` in `_ready()` |
| `popup_font_size` | `42` | Floating text size (on-gate label stays 36 unless you edit `GateLabel`) |
| `popup_rise_pixels` | `64` | Popup rises this many pixels while fading |
| `popup_duration` | `0.55` | Tween length in seconds, then the popup is freed |
| `trigger_sfx` | empty | WAV/OGG/etc. Empty = silent |

### 6.3 Trigger rules

A collider counts if it is in group `bullets`. If it is a `Bullet`:

- Inactive bullets are ignored.
- If `bullet.last_gate_id ==` this gate’s instance id, it is ignored (stops ping-pong inside the Area2D and stops clones from immediately re-hitting the same gate).

Then: apply player modifier → duplicate → popup/SFX → optional consume.

### 6.4 Swapping art / sound

- **Body:** replace `ColorRect` with `Sprite2D` or `NinePatchRect`. If you remove `ColorRect`, `gate_color` no longer tints anything — tint the new sprite instead.
- **Label:** edit `GateLabel` theme overrides. Runtime still overwrites `.text` with `+N` / `xN`.
- **Sound:** assign `trigger_sfx` on the gate root. Played on child `Sfx`.
- **Keep** bullet layer 2 and gate mask 2.

---

## 7. Project settings and third-party keys

| Setting | Value |
| --- | --- |
| Application name | `2D side scrolling shooter - Cursor` |
| Features | `4.5`, `GL Compatibility` |
| Icon | `res://icon.svg` |
| Main scene | **unset** |
| Autoload | **none** |
| Ads / analytics / IAP / SDK keys | **none** |

When you add an SDK, put the setting path and a dummy-vs-live note in this section.

---

## 8. Build a playable level from scratch

Use this when taking over with only this repo.

1. In Godot: **Scene → New Scene**. Root: `Node2D`. Save as `res://scenes/levels/test_level.tscn` (create the folder).
2. Instance `scenes/entities/player.tscn`. Place it near the bottom-center (example: `(540, 1600)` if you use a 1080×1920 layout).
3. Add an enemy:
   - `CharacterBody2D` or `Area2D` named `DummyEnemy`.
   - Node → Groups → add `enemies`.
   - Give it a `CollisionShape2D` so bullets can overlap it.
   - Attach a short script with `health` and `take_damage` as in [§4.3](#43-enemy-hit-contract-required-when-you-add-enemies).
   - Put it **above** the ship so shots fly toward it.
4. Instance `scenes/entities/multiplier_gate.tscn` between ship and enemy. Set `gate_type` / `value` per instance (`ADD` `+1`, `MULTIPLY` `x2`, …).
5. **Project → Project Settings → Application → Run → Main Scene** → this level.
6. Press Play. Move the mouse left/right. You should see yellow bullets (placeholders), gates popping `+2`, and the dummy taking damage.

If nothing fires: the dummy is not in `enemies`, or it is invisible (`visible` off).  
If gates never trigger: bullets are not layer 2, or the gate mask is not layer 2, or the gate is not in the bullet path.  
If later shots vanish: raise `bullet_pool_size`.

---

## 9. Common balance recipes

| Goal | Where |
| --- | --- |
| Faster shooting | Lower Player `fire_rate` (not below `0.01`) |
| Harder hitting | Raise Player `damage` |
| Wider volley | Raise `shot_spread_degrees` |
| Stronger ADD gate | Gate `value` (e.g. `3` → `+3` and 3 extra in-flight copies) |
| Stronger MULTIPLY gate | Gate `value` (e.g. `3` → `x3` volley and 2 extra copies of that bullet) |
| Gate only upgrades the ship, doesn’t split | Not a single flag. You would need a code change (skip `_duplicate_incoming`) |
| One-time gate | `consume_on_trigger = true` |
| Gate keeps splitting every bullet but ship upgrades once | Default: `apply_modifier_once = true`, `consume_on_trigger = false` |
| Wider playfield | Raise Player `max_x`, lower `min_x` to match your viewport |

---

## 10. Not built (do not search the repo for these)

These are reasonable next systems. They are **absent** on purpose:

- Main / game-loop scene, camera, parallax, scrolling world
- Enemy types, waves, HP bars, death FX
- HUD, menus, shop, currency, idle rewards
- Save / load, settings
- Autoloads (`GameManager`, `SaveManager`, …)
- Ads, analytics, IAP
- Named input actions, mobile UI buttons
- Asset folders (art, fonts, audio) — gates can take an `AudioStream` but none is included

When you add one, document Inspector knobs, art swap, groups/layers, and any API keys in this file. Mark the matching item in [`docs/ISSUE_LOG.md`](docs/ISSUE_LOG.md) as addressed and write **how**.

---

## 11. Coding / documentation rules (for the next person or AI)

Project rule: `.cursor/rules/documentation-standards.mdc`

- Every `.gd` file keeps the header (`@file_description`, `@architecture_role`, `@dependencies`).
- Public/`@export` members use `##` doc comments so Inspector help stays useful.
- This handoff is updated whenever a core system is added or its Inspector contract changes.
- Document **what exists**, not a future folder tree. Planned work belongs in [§10](#10-not-built-do-not-search-the-repo-for-these) until it ships.
- On every review of new or changed code, open [`docs/ISSUE_LOG.md`](docs/ISSUE_LOG.md) first. Stamp open items `not addressed as of [date] / [version]`, or record how they were fixed. If `project.godot` still has no version, use `unversioned`.
