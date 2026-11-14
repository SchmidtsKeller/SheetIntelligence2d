# Game Design & Technical Overview Document

## 1. Executive Summary & High Concept

- **Game Title:** Hide in Sheep Clothing
- **Genre:** Asymmetric Social Deduction / Stealth Action / Survival Horror
- **Perspective:** Strictly 2D Top-Down
- **Game Modes:** 1v1 (Player vs. Player over Local Network, or Player vs. AI)
- **Target Platforms:** Web Browser Build (HTML5/WebAssembly) supporting both PC (Keyboard/Mouse) and Mobile (Touch/Virtual Joysticks)
- **High Concept:** An asymmetric 1v1 game set in a dark, painterly world where one player acts as the **Sheepherder** tasked with protecting a flock and hunting down an impostor, while the other player (or AI) acts as the **Monster** disguised as a sheep, blending into the swarm to covertly devour the flock before hunting the Sheepherder.

---

## 2. Core Gameplay Loop & Win/Loss Conditions

### 2.1 Core Gameplay Loop

1. **Pre-Round Setup (Lobby):** Both players connect via local P2P (or initialize AI) and select **one Perk** (which may be a passive trait, an active ability, or a Companion).
2. **Active Round:**
   * **Sheepherder** patrols the 2D map using a directional light source to inspect the flock, uses herding abilities (ringing a bell) to observe swarm behavior, and attempts to deduce which sheep is the Monster.
   * **Monster** mimics NPC sheep movement and swarm behaviors (wandering, manually triggering grass-eating animations, responding to the bell) while isolating and consuming NPC sheep.
3. **Escalation & Evolution Phases:**
   * **Phase 1 (5 Sheep Eaten):** Once the Monster has eaten **5 sheep**, it unlocks the ability to eat/kill the Sheepherder directly via melee attack.
   * **Phase 2 (All 10 Sheep Eaten):** If the Monster kills all **10 NPC sheep**, it sheds its disguise and evolves into a **giant spider monster**, becoming completely **unkillable** (immune to the Sheepherder's firearm) while hunting down the Sheepherder.
4. **Round Resolution & Scoring:** The round ends when a win condition is met or the 180-second timer expires. Points are tallied based on sheep casualties/survival.

### 2.2 Win & Loss Conditions

- **Sheepherder Victory:** Successfully shoots and hits the Monster with their firearm (prior to the Monster reaching its unkillable spider evolution).
- **Monster Victory:**
  * Consumes at least **5 NPC sheep** to unlock the lethal melee attack, then successfully eats/kills the Sheepherder.
  * *Escalation Path:* Eats all **10 NPC sheep** to evolve into the unkillable spider monster, then hunts and eats the Sheepherder.
  * *Ammo Depletion Scenario:* If the Sheepherder wastes all **3 bullets**, the Monster can no longer be killed and can freely hunt the flock and the Sheepherder until the round concludes.
- **Timeout & Draw Conditions:**
  * Round duration is **180 seconds**.
  * If time expires without a lethal resolution, points are compared. A **Draw** is a valid outcome if both players have an even score at the end of the match/round.

### 2.3 Scoring System

- **Monster Score:** Gains **+1 point** for every NPC sheep killed during the round.
- **Sheepherder Score:** Gains **+1 point** for every NPC sheep still alive at the end of the round.
- **Match Structure:** Best of 5 rounds, with players swapping roles after every round.

---

## 3. Character & Entity Specifications

### 3.1 The Sheepherder (Player 1)

- **Role:** Investigator / Protector / Hunter
- **Movement:**
  * *PC:* WASD directional movement on the 2D plane.
  * *Mobile:* On-screen virtual movement joystick.
- **Vision & Fog of War Mechanics:**
  * Equipped with a directional Light-Source (Flashlight/Torch) casting a light cone restricted by specific width and length parameters.
  * *Aiming/Rotation:* Rotates 360 degrees around the Sheepherder to match viewing direction (controlled via Mouse cursor on PC; secondary virtual joystick on Mobile).
  * *Strict Fog of War Rules:* Outside the visibility cone, the map is shrouded in heavy darkness. **Static map elements** (trees, bushes, barns, ground details) remain faintly visible in the dark, whereas **dynamic entities (NPC sheep and the Monster) are completely invisible** unless illuminated by the light cone. Players must rely on spatial audio cues to track unseen movement.
- **Combat & Firearm Mechanics:**
  * Equipped with a single-shot firearm with a **strict limit of 3 bullets per round**.
  * **Reloading:** Must manually or automatically reload after each shot with a long reload timer. Once all 3 bullets are expended, the weapon is permanently empty for the rest of the round.
  * **Friendly Fire / Consequence:** Shooting an NPC sheep kills it immediately (depleting the flock and preventing the Sheepherder from scoring that sheep). Shooting the Monster before it evolves into the spider results in an instant Sheepherder victory.
- **Sheepherder Base Abilities:**
  * **Bell:** Ringing the bell triggers a behavioral phase shift in the flock, causing nearby sheep to walk toward the Sheepherder.

### 3.2 The Monster (Player 2 or AI)

- **Role:** Deceiver / Predator
- **Appearance & Disguise ("No Built-in Tell"):**
  * Visually **100% identical** to an NPC sheep, spawning with a matching randomized visual seed.
  * **No Built-in Tell:** There are no passive visual or mechanical giveaways distinguishing the Monster from an NPC sheep. To survive, the Monster player must actively roleplay and mimic NPC sheep behavior (including manually pressing a dedicated button to play the **graze / eat grass** animation and reacting believably when the Sheepherder rings the bell).
  * **Camera / Framing:** For the Monster player, their disguised sheep character remains centered on the screen.
- **Movement:**
  * *PC/Mobile Controls:* Directional movement matching PC/Mobile inputs.
  * *AI Behavior Logic:* Behavior Tree with distinct operational states. Inputs for the tree include: time since last attack, the Sheepherder's light cone position/angle, distance to nearest sheep, and density of sheep within range.
- **Abilities & Progression:**
  * **Graze (Mimicry Action):** Dedicated button press (PC/Mobile) to lower head and eat grass, matching NPC sheep idle cycles.
  * **Consume Sheep:** Triggered via dedicated button press (PC) or virtual UI button (Mobile) when within melee proximity of an NPC sheep.
    * *Animation & Lockout:* Eating animation takes **1.0 second**. The Monster **cannot move or abort** during this animation, leaving it vulnerable.
    * *Cooldown:* Default **5.0 seconds** between consumptions.
    * *Evidence:* Blood from killed sheep remains permanently on the ground as physical evidence (no blood appears on the Monster's wool).
  * **Phase 1 Evolution (5 Sheep Eaten):** Unlocks the ability to kill/eat the Sheepherder using the same melee proximity attack mechanic used on sheep.
  * **Phase 2 Evolution (10 Sheep Eaten — Spider Form):** Upon eating all 10 sheep, the Monster transforms into a **giant spider monster**, becoming completely **unkillable** (bullets have no effect) and hunting down the Sheepherder.

### 3.3 NPC Sheep (The Flock)

- **Visual Differentiation:** Spawn with randomized, unique visual details (wool patterns, markings, accessories, or slight physical variations) generated from a deterministic seed so the Sheepherder can track and tell individual sheep apart.
- **Swarm & AI Behaviors:**
  * Act collectively as a dynamic swarm (flocking/boids behavior).
  * Operate on distinct behavioral phases: idle wandering, grazing (eating grass), bleating ("mähen" / audio cues), and reacting to the Sheepherder's bell (converging on the Sheepherder).
  * **Total Flock Size per Match:** 10 NPC sheep.

---

## 4. Perks (Loadout Upgrades)

Before each round begins, each player selects **1 Perk** from their respective pool. Companions count as a standard Perk slot.

### 4.1 Sheepherder Perks (Choose 1)

- **Brighter Flashlight (Passive):** Permanently increases the area/size of the flashlight visibility cone by **50%** for the entire round.
- **Faster Weapon Reload (Passive):** Reduces firearm reload duration by **50%**.
- **Friendly Shepherd Dog (Companion):** An AI dog that stays near the Sheepherder; it barks and faces directly toward the Monster whenever the Monster is actively in the middle of its eating animation.

### 4.2 Monster Perks (Choose 1)

- **Faster Consumption (Passive):** Increases eating/killing animation speed by **50%** (reducing vulnerability window from 1.0s to 0.5s).
- **Temporary Invisibility (Active):** Turns the Monster invisible for up to **5 seconds** (30-second cooldown). The duration meter drains slowly while standing still, and drains very rapidly while moving.
- **Allied Bat (Companion / Active):** Commands an allied bat to fly toward the Sheepherder, harassing them and reducing their flashlight effectiveness by **80% for 10 seconds** (30-second cooldown).

---

## 5. Gameplay Parameter Table

*(Baseline placeholder values for initial prototyping and balancing)*

| Category | Parameter | Default Value | Notes |
| :--- | :--- | :--- | :--- |
| **Match Rules** | Round Duration | `180s` | Even score at timeout results in a Draw |
| | Match Format | `Best of 5` | Players swap roles every round |
| | Flock Size | `10 NPC Sheep` | Plus 1 disguised Monster (11 sheep-like entities total) |
| **Sheepherder** | Base Movement Speed | `180 px/s` | Standard patrol speed |
| | Firearm Ammo Capacity | `3 Bullets` | Strict per-round limit; cannot be replenished |
| | Firearm Reload Time | `4.0s` | Reduced to `2.0s` with *Faster Weapon Reload* perk |
| | Flashlight Cone Angle | `60°` | Increased by 50% area with *Brighter Flashlight* perk |
| | Flashlight Cone Length | `350 px` | Blocked by solid obstacles (trees, barns, hay bales) |
| | Bell Cooldown | `12.0s` | Draws nearby sheep toward the Sheepherder |
| **Monster** | Base Movement Speed | `180 px/s` | Matches NPC sheep max speed for seamless mimicry |
| | Spider Form Speed | `230 px/s` | Unlocked at 10 sheep eaten; unkillable state |
| | Eat Animation Duration | `1.0s` | Movement locked; reduced to `0.5s` with *Faster Consumption* |
| | Eat Ability Cooldown | `5.0s` | Cooldown starts after eating animation completes |
| | Sheepherder Kill Threshold | `5 Sheep Eaten` | Unlocks melee kill prompt on Sheepherder |
| | Spider Evolution Threshold | `10 Sheep Eaten` | Transforms into unkillable spider monster |
| **Perks** | Invisibility Max Duration | `5.0s` | Drains `1.0x` when still, `3.0x` when moving (`30.0s` CD) |
| | Allied Bat Disruption | `10.0s` | Reduces flashlight radius/intensity by `80%` (`30.0s` CD) |

---

## 6. Level Design & World Environment

- **Map Layout & Dimensions:** Bounded 2D top-down environment set in open green fields with slight hills and patches of grass.
- **Line-of-Sight Obstacles:** Solid environmental props that block both movement and the Sheepherder's flashlight visibility cone (e.g., trees, barns, thick bushes, wooden structures, hay bales).
- **Map Boundaries:** Enclosed by non-traversable natural and man-made borders (e.g., rivers, wooden fences).

---

## 7. Art Direction & Audio Design

### 7.1 Visual & Art Style

- **Core Aesthetic:** Realistic painterly style with dark, atmospheric, slight horror undertones.
- **Visual References:** *Darkest Dungeon*, *Darkwood* (heavy shadows, textured brushwork, grim and tense atmosphere, stark contrast between the flashlight cone and surrounding darkness).
- **UI Art Style:** Grim, hand-painted parchment/iron aesthetic inspired by *Darkest Dungeon* and *Darkwood*.

### 7.2 Audio Design

- **Diegetic Sound Effects:** Sheep bleating ("mähen"), grass grazing rustles, Sheepherder's bell (crucial gameplay cue), gunshot and mechanical reload clicks, wet Monster eating cues, spider screech upon full evolution.
- **Music & Ambience:** Ambient wind, realistic, minimal, layered night sounds.
- **Spatial Audio Rules:** Critical for locating entities hidden in the Fog of War. Directional/distance-attenuated audio cues apply to the Shepherd Dog barking, unseen sheep moving through grass, and Monster consumption sounds.

---

## 8. User Interface (UI) & User Experience (UX)

### 8.1 Pre-Game Lobby UI

- **Design Philosophy:** Extremely simplified, frictionless interface optimized for browser play.
- **Functionality:**
  * Network connection status / Peer-to-Peer pairing (room code or LAN session join).
  * Role assignment indicator (Sheepherder vs. Monster).
  * Single-selection Perk widget (choosing 1 Perk/Companion).

### 8.2 In-Game HUD

- **PC HUD:**
  * Bullet counter (visual display of remaining bullets out of 3).
  * Reload progress indicator.
  * Active ability / Perk cooldown icons (Bell for Sheepherder; Graze, Eat, and active Perk for Monster).
  * Monster "Evolution Bar" (tracks progress toward the 5-sheep Herder kill unlock and 10-sheep Spider evolution).
  * *Monster-Only Counter:* Remaining living NPC sheep count.
- **Mobile HUD:** Identical telemetry to PC, adapted for touchscreens using responsive virtual joysticks (left for movement, right for Sheepherder flashlight aim) and ergonomic action buttons.
- **End-of-Round / Scoreboard Screen:** Displays round outcome, points earned (+1 per surviving sheep for Sheepherder; +1 per killed sheep for Monster), and overall Best-of-5 match standing.

---

## 9. Technical Architecture & Engineering Standards

### 9.1 Engine, Language & Target Build

- **Game Engine:** Godot Engine (**Strictly Version 4.7**)
- **Programming Language:** C# (.NET)
- **Export Target:** Web Browser Build (HTML5 / WebAssembly) supporting cross-play between desktop browsers (PC) and mobile browsers (iOS/Android).

### 9.2 Architectural Principles (SoC & DRY)

The codebase must strictly enforce **Separation of Concerns (SoC)** and **Don't Repeat Yourself (DRY)**:

- **`Abstractions/` Directory:** Core system contracts must be defined as C# interfaces inside a dedicated `Abstractions` folder (e.g., `IInputService`, `INetworkService`, `ISwarmService`, `ICombatService`, `IPerkService`, `IAudioService`).
- **Service Registration / Dependency Injection:** Systems must decouple implementation from consumption via a centralized service locator or dependency injection container, allowing seamless swapping between Player-controlled and AI-controlled implementations.
- **Shared Logic (DRY):** Input handling abstractions must unify PC (WASD/Mouse) and Mobile (Virtual Joysticks/Touch Buttons) inputs into normalized command vectors and action triggers before passing them to character controllers.

### 9.3 Proposed Project Directory Structure

```text
res://
├── Abstractions/             # C# Interfaces for all core services & entities
│   ├── IInputService.cs
│   ├── INetworkService.cs
│   ├── ISwarmService.cs
│   ├── ICombatService.cs
│   └── IPerkService.cs
├── Services/                 # Concrete implementations & Service Registry
├── Entities/                 # Sheepherder, Monster (Sheep & Spider), NPC Sheep, Companions
├── Systems/                  # Lighting/FoW Shaders, AI Behavior Trees, Swarm Boids
├── UI/                       # Simplified Lobby, Responsive Mobile/PC HUD
└── Assets/                   # Realistic painterly sprites, shaders, spatial audio
```

### 9.4 Networking & Browser Cross-Play

- **Topology:** Peer-to-Peer (P2P) over Local Area Network (LAN) / WebRTC or WebSockets.
- **Godot Multiplayer API:** Utilize `WebSocketMultiplayerPeer` (or `WebRTCMultiplayerPeer`) to ensure full compatibility with Godot 4.7 Browser Builds across both PC and Mobile devices.
- **State Synchronization Requirements:**
  * Position and rotation of Sheepherder (including flashlight cone angle).
  * Position, disguise seed, grazing state, and evolution state (Sheep vs. Spider) of the Monster, plus AI Companions.
  * Host-authoritative synchronization of NPC Sheep swarm positions, deterministic visual seeds, and behavioral phases (grazing, bell attraction).
  * Combat and world events (gunshots, bullet count updates, blood decal spawns, sheep consumption, score updates).