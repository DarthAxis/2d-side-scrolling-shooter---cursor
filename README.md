# 2D side scrolling shooter — Cursor

Godot **4.5** project (GDScript, GL Compatibility renderer).

This is a **pointer-follow auto-shooter**. The ship tracks mouse/touch on the X axis, aims at the nearest enemy, and fires pooled bullets. In-flight bullets can pass through **multiplier gates** that raise volley size (`+N` / `xN`) and split projectiles.

## Start here

1. Open this folder in **Godot 4.5**.
2. There is **no main scene yet**. Create a level, instance the player, add at least one enemy in group `enemies`, then set that scene as the main scene (Project → Project Settings → Application → Run → Main Scene). A full walkthrough is in [`TECHNICAL_HANDOFF.md`](TECHNICAL_HANDOFF.md).
3. Use **`TECHNICAL_HANDOFF.md` as the human maintenance guide.** It is written for someone who needs to tune, swap art, and extend the game without tribal knowledge.
4. Known gaps (missing scenes, implied systems, behavioural risks) live in [`docs/ISSUE_LOG.md`](docs/ISSUE_LOG.md). That log is checked on every code review; open items get a “not addressed as of …” note until they are fixed.

## What exists today

| Piece | Path |
| --- | --- |
| Player ship | `scenes/entities/player.tscn` + `scripts/player_controller.gd` |
| Bullet pool | Built in code by the player (`scripts/bullet.gd`) |
| Multiplier gate | `scenes/entities/multiplier_gate.tscn` + `scripts/multiplier_gate.gd` |

## What does not exist yet

No levels, enemies, HUD, shop, economy, save system, autoloads, ads, or analytics. Those folders in older notes were planned, not shipped. Do not look for `GameManager` or `SaveManager`.
