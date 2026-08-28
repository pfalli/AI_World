# V7.5 — Clean Visual Rebuild: Forest World + Animated Agents

The repository has been restored to the stable pre-graphics version.

The AI/simulation systems are working correctly. This milestone is a CLEAN VISUAL REBUILD.

I have added two asset packs under `assets/`:

1. **Free 16×16 Forest Sample**

   * use primarily for forest terrain/environment where appropriate

2. **Top-Down Tileset + Animated Character Pack**

   * use primarily for animated characters and any compatible complementary environment assets

IMPORTANT:

Before implementing anything, recursively inspect the actual `assets/` directories.

Determine:

* exact filenames
* texture dimensions
* tile sizes
* spritesheet layouts
* available terrain tiles
* available transitions
* water tiles
* trees
* bushes
* rocks/decorations
* character spritesheets
* character frame dimensions
* animation directions
* idle/walk frames
* any included Godot TileSet resources/scenes
* README/license/instructions included with the packs

DO NOT guess sprite regions or filenames.

If the forest pack already contains a Godot 4 TileSet/terrain configuration, reuse it where practical instead of rebuilding it incorrectly.

---

# 1. NON-NEGOTIABLE ARCHITECTURE

This is a visual layer over the existing simulation.

DO NOT modify:

* AI decisions
* FastAPI backend
* prompts
* personalities
* memories
* relationships
* needs
* inventory
* perception
* known locations
* affordances
* resource behavior
* decision triggers
* exploration logic
* action lifecycle
* movement behavior
* simulation speed/balance

Godot simulation coordinates remain authoritative.

The desired separation is:

World
├── VisualWorld
│   ├── Ground
│   ├── Terrain
│   ├── Decorations
│   └── Environment
│
├── SimulationEntities
│   ├── Trees
│   ├── BerryBushes
│   ├── WaterSources
│   └── Agents
│
└── HUD

And an agent should conceptually remain:

Agent
├── existing simulation logic
├── movement
├── perception
├── interactions
│
└── Visual
├── AnimatedSprite2D
├── NameLabel
└── SelectionIndicator

Graphics must NEVER determine simulation state.

---

# 2. BUILD A REAL TERRAIN — NOT A TILESET SHOWCASE

The previous graphics attempt incorrectly displayed many tiles from the spritesheet in rows.

Do NOT do this.

Create an intentional forest map.

The dominant terrain should be GRASS.

The map should visually contain:

* large continuous grass areas
* natural forest clusters
* clearings
* one natural-looking pond/lake
* shoreline transitions
* scattered rocks
* bushes/plants
* small decorative vegetation
* optional small dirt areas/path only if they visually fit

DO NOT include tiles merely because they exist.

For V7.5 ignore things such as:

* lava
* snow
* dungeon tiles
* castle tiles
* buildings
* indoor tiles
* unusual biome tiles
* bridges unless genuinely needed

The goal is:

**a believable small forest survival environment.**

---

# 3. TERRAIN CONSTRUCTION

Use the forest pack's terrain/autotile system if one exists and works with the current Godot version.

Prefer Godot 4 `TileMapLayer` / appropriate terrain functionality rather than manually placing hundreds of individual Sprite2D nodes.

Create logical visual layers such as:

Ground
Water/Terrain
Environment
Foreground/Decorations

Use the asset pack's actual terrain transitions.

Do NOT fake water by placing arbitrary isolated blue tiles.

A pond should have coherent:

* interior water
* shoreline
* corners
* edges

Likewise, dirt/grass transitions should use the appropriate terrain transitions if available.

---

# 4. MAP COMPOSITION

Create a simple intentional initial map approximately like:

FOREST      FOREST

🌲 🌲 🌲 🌲                 🌲 🌲
🌲                              🌲
🌲          CLEARING            🌲

```
    Alice      Bob

         🌿

                Charlie
```

🌲                    🌲 🌲

```
      ~~~~~~~~~
    ~~~~~~~~~~~~~
   ~~~~~ WATER ~~~~
    ~~~~~~~~~~~~~
      ~~~~~~~~~
```

🌲 🌲          🌿          🌲 🌲

```
      ROCKS
```

🌲 🌲 🌲                 🌲 🌲 🌲

Do not interpret this literally as tile coordinates.

The design principles are:

* open central starting area
* denser vegetation around portions of the perimeter
* navigable open spaces
* natural-looking water area
* resource locations visually understandable
* enough open terrain for us to clearly watch agents move

Avoid excessive visual clutter.

This is an AI simulation, so observing agents is more important than filling every tile.

---

# 5. VISUAL WORLD VS LOGICAL WORLD

Very important:

A visual forest may contain many decorative trees.

Not every decorative tree needs to become an AI/simulation entity.

Likewise a pond may contain dozens of water tiles while the simulation has one logical `WaterSource`.

Maintain separation:

VISUAL POND
many tiles

↓

LOGICAL WATER SOURCE
existing simulation entity / interaction area

Likewise:

VISUAL FOREST
many tree sprites/tiles

does not automatically mean:

hundreds of perceived AI entities.

Preserve the current logical resource system.

---

# 6. EXISTING RESOURCE ENTITIES

Existing logical entities such as:

* berry bushes
* water source
* rocks
* trees

must remain functional.

Give them appropriate visual representations from the new packs.

Example:

berry_bush_1

still has:

ID
position
berries_available
GATHER affordance

but now has a proper bush visual.

Do not create a second disconnected visual berry bush somewhere else.

Logical resource and its visible representation must correspond spatially.

For water, position the logical WaterSource interaction area appropriately on/around the visual pond.

---

# 7. CHARACTER IMPLEMENTATION

Use the character spritesheet from the **Top-Down Tileset + Animated Character Pack**.

Inspect the actual spritesheet before slicing it.

Correctly determine:

* frame width/height
* animation rows/columns
* frame count
* direction mapping
* idle animations
* walking animations

Create proper animations using `AnimatedSprite2D` / `SpriteFrames`.

At minimum support:

* idle_down
* idle_up
* idle_left
* idle_right
* walk_down
* walk_up
* walk_left
* walk_right

If the actual pack names/layout differ, adapt to what is actually provided.

Do not fabricate missing frames.

---

# 8. ANIMATION MUST FOLLOW EXISTING MOVEMENT

Animation is purely representational.

Use existing agent velocity/movement direction.

Conceptually:

velocity == Vector2.ZERO
→ idle animation

abs(velocity.x) > abs(velocity.y)
→ left/right walking animation

otherwise
→ up/down walking animation

Remember last facing direction so an agent that stops uses the corresponding idle animation.

DO NOT modify navigation/movement to accommodate animation.

---

# 9. ALICE, BOB AND CHARLIE MUST BE VISUALLY DISTINCT

They must be immediately recognizable.

First inspect whether the pack provides multiple characters/variants.

If it does, use compatible variants.

If only one character exists, create simple temporary variations using safe methods that do not destroy the original asset.

Possible temporary differences:

Alice → variant A
Bob → variant B
Charlie → variant C

Prefer actual provided variants over arbitrary color modulation.

Do NOT create ugly extreme RGB recoloring.

Their names should remain visible above them:

Alice
Bob
Charlie

Keep name labels small and readable.

Do NOT display:

"Wandering — explore"
"Hunger: ..."
"Goal: ..."

above their heads.

That belongs in the inspector.

---

# 10. CHARACTER SCALE

Do NOT assume characters must occupy exactly one 16×16 tile.

Terrain can use a 16×16 grid while characters may have larger native sprite dimensions.

Use the character pack's intended native proportions.

Apply ONE consistent integer display scale to the pixel-art world where appropriate.

For example:

16×16 terrain rendered consistently at 2×/3×/4× depending on project resolution.

Do NOT individually scale:

tree = 4.2x
rock = 2.7x
character = 1.4x

just to make things fit.

Preserve coherent pixel density.

---

# 11. PIXEL PERFECT RENDERING

Configure Godot for crisp pixel art.

Use nearest-neighbor texture filtering.

Avoid fractional sprite scaling where possible.

Avoid blurry movement/rendering.

Keep camera zoom at sensible integer-friendly values where practical.

Do not modify simulation coordinates simply to force pixel snapping if doing so changes behavior.

---

# 12. TREES AND Y-SORTING

Top-down depth must work correctly.

When an agent walks north/behind a tree:

the tree canopy should appear in front of the agent.

When the agent walks south/in front:

the agent should render in front.

Use appropriate Godot Y-sorting/layering.

Tree collision/interaction position should correspond primarily to its base/trunk, not the full canopy.

Do not let a large canopy become an enormous collision rectangle unless the existing simulation intentionally requires it.

---

# 13. DECORATION

Use environmental decoration carefully:

* flowers
* grass tufts
* small plants
* stones
* bushes

These should primarily be VISUAL.

Do not automatically expose every decorative object to agent perception.

Avoid excessive decoration.

Agents and important resources must remain visually identifiable.

---

# 14. CAMERA

Create/improve a proper observer camera.

The simulation is something I WATCH from above.

Support:

* WASD and/or arrow-key panning
* mouse wheel zoom
* sensible zoom limits
* smooth movement if appropriate
* ability to see a large portion of the world

Do not permanently follow one agent.

Optional:

Click an agent and press a key/button to temporarily follow it.

But keep this simple.

---

# 15. AGENT SELECTION

Allow clicking Alice, Bob or Charlie.

Selected agent should receive a subtle selection indicator such as:

* small ring
* marker
* outline

Do not cover the sprite.

Selection must not affect AI behavior.

---

# 16. PROPER HUD

Use `CanvasLayer` for screen-space UI.

The HUD must NOT move with the world/camera.

Create a clean layout.

For example:

TOP LEFT:

AI World
Speed: 1x / 4x / 16x
Simulation time

RIGHT SIDE when agent selected:

ALICE

Goal: Find food
Action: Explore

Hunger: 57
Thirst: 41
Energy: 76

Inventory:
Berry ×2

Relationships:
Bob ...
Charlie ...

Recent memory:
...

BOTTOM:

collapsible simulation log

Do not allow panels to float randomly over Alice/Bob/Charlie as the camera moves.

---

# 17. DEBUG MODE

Keep the simulation's technical observability.

Use F3 or the existing debug toggle.

DEBUG OFF:

show the clean world.

DEBUG ON may show:

* agent position
* perception radius
* interaction radius
* current destination
* exploration waypoint
* entity IDs
* action state
* movement diagnostics

Debug graphics must be overlays, not part of the normal visual presentation.

---

# 18. SIMULATION LOG

Keep the simulation log, but make it collapsible.

Normal view should prioritize the world.

For example:

[Show Log]

and when expanded:

a bottom panel appears.

Do not permanently consume 25–30% of the screen with logs.

---

# 19. REMOVE OLD PLACEHOLDER VISUALS

Remove/disable old debug visuals that are no longer needed in normal mode:

* colored circles
* placeholder rectangles
* giant status text
* old floating world labels

BUT preserve useful debug overlays behind DEBUG mode.

Do not delete simulation logic associated with those entities.

---

# 20. DO NOT PROCEDURALLY GENERATE THE WORLD YET

For V7.5 create ONE good deterministic forest map.

We can introduce procedural generation later.

Right now visual quality and correct layering are more important.

The same map must load consistently so AI behavior remains easy to debug.

---

# 21. DO NOT MODIFY THE SIMULATION

After implementation, run regression tests.

Verify Alice, Bob and Charlie can still:

EXPLORE
→ move through the new visuals

DISCOVER
→ perceive logical resources

GATHER
→ approach berry bush
→ gather

EAT

DRINK
→ approach the pond/water source
→ drink

and move simultaneously.

The terrain graphics must NOT accidentally block existing navigation everywhere.

If visual collisions are added, be conservative.

Do not introduce complicated navigation/pathfinding changes during this milestone.

---

# 22. ASSET LICENSING

Inspect the license/README files distributed with both packs.

Preserve them.

Update the project README with an `Assets / Credits` section listing:

* asset pack name
* creator
* source
* license

Do not incorrectly claim that all assets use the same license.

Do not delete original license files.

---

# SUCCESS CRITERIA

V7.5 is successful when:

1. The screen immediately looks like a forest game rather than a debug application.
2. Grass forms coherent continuous terrain.
3. Water forms a natural pond with correct transitions.
4. Trees form intentional forest clusters.
5. Resources visually belong to the environment.
6. Alice, Bob and Charlie use correctly sliced animated character sprites.
7. Walking direction animations correspond to actual movement.
8. Idle direction is preserved.
9. All three people are visually distinguishable.
10. Pixel art is crisp and consistently scaled.
11. Y-sorting works around trees.
12. Camera pan/zoom works.
13. Agent selection works.
14. Inspector is screen-space UI.
15. Simulation log is collapsible.
16. Debug overlays can be toggled.
17. No tileset showcase/grid exists.
18. No random inappropriate biome tiles are displayed.
19. Existing V7.3 simulation behavior remains intact.
20. All three agents still move independently.

---

# BEFORE FINISHING

Actually run the Godot project and visually inspect the result.

Do not consider the task complete merely because the project compiles.

Specifically verify:

* no missing textures
* no incorrectly sliced sprites
* no wrong animation rows
* no giant/small inconsistent sprites
* no tile catalog/grid
* no floating debug panels in world coordinates
* pond edges look coherent
* terrain has no obvious broken transitions
* all three agents visibly animate while walking

Fix obvious visual integration problems before stopping.

---

# AFTER IMPLEMENTATION

Report:

1. Which asset files were actually used.
2. Which pack is used for terrain.
3. Which pack is used for characters.
4. Tile size.
5. Character frame size.
6. Animation frame mapping.
7. Godot visual scene/node architecture.
8. Terrain implementation.
9. Y-sorting implementation.
10. Camera controls.
11. Debug controls.
12. UI controls.
13. Files changed.
14. Any limitations of the asset packs.
15. Exact manual test procedure.

STOP after V7.5.

Do NOT implement new AI or gameplay features.
