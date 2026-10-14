# Issue log (gaps, implications, and follow-up checks)

Living record of things that are **missing**, **implied by names/code/docs but not present**, or **risky** in the current project. This file is documentation only. It is not a task tracker that implies fixes have been made.

**How to maintain this file**

1. Read this log **before** reviewing any code addition or update.
2. If an item is still open, append a line: `not addressed as of [date] / [version]`.
3. If it was fixed, set **Status** to `Addressed`, fill **How it was addressed**, and date the resolution. Do not delete the original finding.
4. If a new gap appears, add a new `ISS-xxx` entry with **Found**.
5. Add a row to the [Review history](#review-history) table every time this log is checked.

**Version used in notes:** `project.godot` has no `config/version`. Until one exists, use **`unversioned`** plus the check date.

**Timezone for timestamps:** America/Chicago (UTC-5 on the dates below).

---

## Review history

| Check date | Version | What was reviewed | Outcome |
| --- | --- | --- | --- |
| 2026-10-14 11:02 CDT | unversioned | Full repo vs handoff (`player.tscn`, `multiplier_gate.tscn`, `player_controller.gd`, `bullet.gd`, `multiplier_gate.gd`, `project.godot`) | Opened this log. All `ISS-001`–`ISS-018` still open. Docs drift from the prior handoff rewrite is recorded as addressed in [Resolved](#resolved). |

---

## Open issues

### ISS-001 — No main scene; Play cannot start a game

| | |
| --- | --- |
| **Found** | 2026-10-14 11:02 CDT / unversioned |
| **Status** | Open |
| **Where** | `project.godot` has no `run/main_scene` |
| **Concern** | Godot has nothing to run. The player and gate scenes exist but are not composed into a level. A maintainer pressing Play gets a missing-scene error, not a shooter. |

- 2026-10-14 11:02 CDT / unversioned — not addressed as of 2026-10-14 / unversioned

---

### ISS-002 — No enemy scenes or spawners (combat is implied, not playable)

| | |
| --- | --- |
| **Found** | 2026-10-14 11:02 CDT / unversioned |
| **Status** | Open |
| **Where** | No files under enemies; group `enemies` is only referenced in scripts |
| **Concern** | `PlayerController` only fires if a visible node is in group `enemies`. `Bullet` only damages that group. Without an enemy scene, the ship never shoots and gates never trigger. The hit API (`take_damage` / `health`) is a contract with no implementation in-repo. |

- 2026-10-14 11:02 CDT / unversioned — not addressed as of 2026-10-14 / unversioned

---

### ISS-003 — Player ship has no texture (invisible actor)

| | |
| --- | --- |
| **Found** | 2026-10-14 11:02 CDT / unversioned |
| **Status** | Open |
| **Where** | `scenes/entities/player.tscn` → `Sprite2D` has no `texture` |
| **Concern** | The ship exists as a 48×48 body and a muzzle. On screen it is blank except for pooled bullets. Art swap is documented; art is not shipped. |

- 2026-10-14 11:02 CDT / unversioned — not addressed as of 2026-10-14 / unversioned

---

### ISS-004 — Title implies side-scrolling; code does not scroll

| | |
| --- | --- |
| **Found** | 2026-10-14 11:02 CDT / unversioned |
| **Status** | Open |
| **Where** | Project name vs `player_controller.gd` `_follow_pointer_x()` |
| **Concern** | Name: “2D side scrolling shooter”. Behaviour: pointer sets **X** only; **Y** is never driven; there is no camera, world scroll, or level length. A new owner may look for a scroller and not find one. |

- 2026-10-14 11:02 CDT / unversioned — not addressed as of 2026-10-14 / unversioned

---

### ISS-005 — Earlier product pitch (idle / TD / autoloads) is still implied, not built

| | |
| --- | --- |
| **Found** | 2026-10-14 11:02 CDT / unversioned |
| **Status** | Open (code); docs now describe the gap |
| **Where** | Missing `GameManager`, `SaveManager`, shop, HUD, economy, ads; no `scripts/autoload`, `scenes/ui`, `scenes/levels`, `assets` |
| **Concern** | Those systems were described in older notes. They are still absent. Handoff §10 lists them as not built. Gameplay loop, persistence, and monetization remain implied product goals without code. |

- 2026-10-14 11:02 CDT / unversioned — not addressed as of 2026-10-14 / unversioned (no autoloads, UI, levels, or assets added)

---

### ISS-006 — No display size or stretch settings

| | |
| --- | --- |
| **Found** | 2026-10-14 11:02 CDT / unversioned |
| **Status** | Open |
| **Where** | `project.godot` has no `[display]` / window size / stretch mode |
| **Concern** | Player `min_x` / `max_x` default to `100`–`980` (1080-wide assumption). Bullet recycle uses the **actual** viewport + 64px. Default Godot window size may not match those clamps, so the ship can be locked to a strip that is not the visible playfield. |

- 2026-10-14 11:02 CDT / unversioned — not addressed as of 2026-10-14 / unversioned

---

### ISS-007 — Physics layers are unnamed numbers

| | |
| --- | --- |
| **Found** | 2026-10-14 11:02 CDT / unversioned |
| **Status** | Open |
| **Where** | Project Settings have no layer names; player layer 1, bullets layer 2, gates layer 3 |
| **Concern** | Easy to break gates (mask must stay on bullet layer 2) when adding enemies or walls. Nothing in the editor labels “player / bullets / gates”. |

- 2026-10-14 11:02 CDT / unversioned — not addressed as of 2026-10-14 / unversioned

---

### ISS-008 — Bullet mask is every layer (`0xFFFFFFFF`)

| | |
| --- | --- |
| **Found** | 2026-10-14 11:02 CDT / unversioned |
| **Status** | Open |
| **Where** | `player_controller.gd` `_create_pooled_bullet()` |
| **Concern** | Bullets overlap everything, including the player (layer 1). Damage is gated on group `enemies`, so the ship is safe **unless** someone also puts the player in `enemies`. Future world geometry on any layer will also generate overlap signals. |

- 2026-10-14 11:02 CDT / unversioned — not addressed as of 2026-10-14 / unversioned

---

### ISS-009 — Volley cap does not cap in-flight gate clones

| | |
| --- | --- |
| **Found** | 2026-10-14 11:02 CDT / unversioned |
| **Status** | Open |
| **Where** | `max_bullets_per_shot` vs `duplicate_bullet_from_gate()` |
| **Concern** | Inspector copy says the cap stops gates from exhausting the pool. It only clamps `bullets_per_shot` on the player. Each gate still requests extra pooled clones per passing bullet. A chain of gates can empty `bullet_pool_size` (96) while the volley cap is still 64. Empty pool → remaining shots silently skipped. |

- 2026-10-14 11:02 CDT / unversioned — not addressed as of 2026-10-14 / unversioned

---

### ISS-010 — Pool exhaustion has no feedback

| | |
| --- | --- |
| **Found** | 2026-10-14 11:02 CDT / unversioned |
| **Status** | Open |
| **Where** | `_acquire_bullet()` returns `null`; `_fire_at` / `duplicate_bullet_from_gate` `return` |
| **Concern** | When the pool is dry, the volley or split stops with no log, HUD, or overflow spawn. Looks like a fire-rate or gate bug. |

- 2026-10-14 11:02 CDT / unversioned — not addressed as of 2026-10-14 / unversioned

---

### ISS-011 — `consume_on_trigger` hides function, not the gate

| | |
| --- | --- |
| **Found** | 2026-10-14 11:02 CDT / unversioned |
| **Status** | Open |
| **Where** | `multiplier_gate.gd` `_try_apply()` sets `monitoring` / `monitorable` false |
| **Concern** | The ColorRect and label stay on screen. A designer may expect a one-time pickup to disappear. |

- 2026-10-14 11:02 CDT / unversioned — not addressed as of 2026-10-14 / unversioned

---

### ISS-012 — No dedicated bullet scene (art swap requires code)

| | |
| --- | --- |
| **Found** | 2026-10-14 11:02 CDT / unversioned |
| **Status** | Open |
| **Where** | `_create_pooled_bullet()` / `_make_bullet_texture()` |
| **Concern** | Handoff tells a human to instance a bullet `.tscn` inside the constructor. That scene does not exist. Changing bullet art is not Inspector-only. |

- 2026-10-14 11:02 CDT / unversioned — not addressed as of 2026-10-14 / unversioned

---

### ISS-013 — Pointer input is mouse API only; no Input Map

| | |
| --- | --- |
| **Found** | 2026-10-14 11:02 CDT / unversioned |
| **Status** | Open |
| **Where** | `get_global_mouse_position()`; empty Input Map |
| **Concern** | Touch often maps to this API in Godot, but there are no actions, no multi-touch handling, and no on-screen stick. Keyboard / gamepad cannot move the ship. Mobile controls are implied by the old “mobile app” goal, not implemented as a control scheme. |

- 2026-10-14 11:02 CDT / unversioned — not addressed as of 2026-10-14 / unversioned

---

### ISS-014 — Clone spread is hardcoded, not Inspector-tuned

| | |
| --- | --- |
| **Found** | 2026-10-14 11:02 CDT / unversioned |
| **Status** | Open |
| **Where** | `duplicate_bullet_from_gate()`: `deg_to_rad(maxi(6, extra_count) * 4.0)` and `+ dir * 12.0` spawn offset |
| **Concern** | Player volley spread is `shot_spread_degrees`. Gate splits use a different, unexported formula. Balancing split width means editing GDScript. |

- 2026-10-14 11:02 CDT / unversioned — not addressed as of 2026-10-14 / unversioned

---

### ISS-015 — Targeting skips hidden enemies; collision may not

| | |
| --- | --- |
| **Found** | 2026-10-14 11:02 CDT / unversioned |
| **Status** | Open |
| **Where** | `_find_nearest_enemy()` skips non-visible `CanvasItem`; `_try_hit()` does not |
| **Concern** | An invisible enemy in group `enemies` will not be aimed at, but a stray bullet can still damage it. Easy to misuse for spawners or off-screen placeholders. |

- 2026-10-14 11:02 CDT / unversioned — not addressed as of 2026-10-14 / unversioned

---

### ISS-016 — Gate `last_gate_id` is per instance, not per type or per pass

| | |
| --- | --- |
| **Found** | 2026-10-14 11:02 CDT / unversioned |
| **Status** | Open |
| **Where** | `Bullet.last_gate_id` |
| **Concern** | Stops re-entry on the **same** Area2D. Two overlapping gates, or a bullet leaving and hitting a **different** gate, behave as designed. There is no “already gated this frame” flag. Overlapping volumes can still stack modifiers. |

- 2026-10-14 11:02 CDT / unversioned — not addressed as of 2026-10-14 / unversioned

---

### ISS-017 — Player does not collide with the world

| | |
| --- | --- |
| **Found** | 2026-10-14 11:02 CDT / unversioned |
| **Status** | Open |
| **Where** | `player.tscn` `collision_mask = 0`; no `move_and_slide` in the controller |
| **Concern** | Position is assigned directly. Walls, hazards, and pickups cannot block or bump the ship with physics. CharacterBody2D is used as a tagged transform, not a physics character. |

- 2026-10-14 11:02 CDT / unversioned — not addressed as of 2026-10-14 / unversioned

---

### ISS-018 — No project version field for this log to cite

| | |
| --- | --- |
| **Found** | 2026-10-14 11:02 CDT / unversioned |
| **Status** | Open |
| **Where** | `project.godot` `[application]` has name, features, icon only |
| **Concern** | Issue notes cannot say “fixed in 0.2.0” until a version (or git tag policy) exists. Checks currently stamp **unversioned**. |

- 2026-10-14 11:02 CDT / unversioned — not addressed as of 2026-10-14 / unversioned

---

## Resolved

### ISS-DOC-001 — Handoff described folders and genre that were not in the repo

| | |
| --- | --- |
| **Found** | 2026-10-14 ~10:41 CDT / unversioned |
| **Status** | Addressed |
| **Resolved** | 2026-10-14 (handoff rewrite, before this log existed) |
| **How it was addressed** | Rewrote `TECHNICAL_HANDOFF.md` and added `README.md` to match shipped files only. Removed idle/tower-defense as current genre. Deleted duplicate `TECHNICAL_HANDOFF.md.txt`. Documented groups, collision bits, pool behaviour, and a “not built” list. Code was not changed to add those missing systems. |

### ISS-DOC-002 — Inspector comments mentioned the wrong visual nodes

| | |
| --- | --- |
| **Found** | 2026-10-14 ~10:41 CDT / unversioned |
| **Status** | Addressed |
| **Resolved** | 2026-10-14 |
| **How it was addressed** | `multiplier_gate.gd` `gate_color` comment now refers to `ColorRect`. `player_controller.gd` `bullet_color` comment now refers to the generated pool texture / `_create_pooled_bullet()`, not a scene sprite. |
