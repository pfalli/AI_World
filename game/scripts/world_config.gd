class_name WorldConfig
extends RefCounted

# The visual forest is a fixed 60 x 40 map of 16px tiles (960 x 640).
# Insets keep an agent's body within the terrain rather than half outside its edge.
const MAP_BOUNDS := Rect2(24, 24, 912, 592)
const PERCEPTION_RADIUS := 250.0
const INTERACTION_DISTANCE := 58.0
const HUNGER_PER_TICK := 1
const THIRST_PER_TICK := 1
const ENERGY_ACTIVE_PER_TICK := 1
const REST_ENERGY_PER_TICK := 2
const BERRY_NUTRITION := 25
const WATER_HYDRATION := 55
const GIVE_TRUST := 5
const GIVE_AFFINITY := 3
