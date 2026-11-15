# Game Design & Technical Overview Document

## 1. Executive Summary & High Concept

- **Game Title:** Hide in Sheep Clothing
- **Genre:** Asymmetric Social Deduction / Stealth Action / Survival Horror
- **Perspective:** Strictly 2D Top-Down
- **Game Modes:** 1v1 Player vs. Player over Local Network. Offline, one player can also play a match against a computer opponent in either role (#57); the bots play by the same rules and see and hear only what a player could.
- **Target Platforms:** Web Browser Build (HTML5/WebAssembly) supporting both PC (Keyboard/Mouse) and Mobile (Touch/Virtual Joysticks)
- **High Concept:** An asymmetric 1v1 game set in a dark, painterly world where one player acts as the **Sheepherder** tasked with protecting a flock and hunting down an impostor, while the other player acts as the **Monster** disguised as a sheep, blending into the swarm to covertly devour the flock before hunting the Sheepherder.

---

## 2. Core Gameplay Loop & Win/Loss Conditions

### 2.1 Core Gameplay Loop

1. **Setup (Lobby):** Before the first round, both players pair once via local P2P (QR or text code, see 9.4). Before every round, each player selects **one Perk** (which may be a passive trait, an active ability, or a Companion).
2. **Active Round:**
   * **Sheepherder** patrols the 2D map using a rifle-mounted flashlight to inspect the flock, uses herding abilities (ringing a bell) to observe swarm behavior, and attempts to deduce which sheep is the Monster.
   * **Monster** mimics NPC sheep movement and swarm behaviors (wandering, manually triggering grass-eating animations and bleats, responding to the bell) while isolating and consuming NPC sheep.
3. **Escalation & Evolution Phases:**
   * **Phase 1 (5 Sheep Eaten):** Once the Monster has eaten **5 sheep**, it unlocks the ability to kill the Sheepherder with a single melee attack.
   * **Phase 2 (All 10 Sheep Eaten):** If the Monster eats all **10 NPC sheep**, it sheds its disguise and evolves into a **giant spider monster**, becoming completely **unkillable** (immune to the Sheepherder's firearm) while hunting down the Sheepherder.
   Every sheep the Monster eats counts toward both thresholds, including the bodies of sheep the Sheepherder shot (see 3.2).
4. **Round Resolution & Scoring:** The round ends when a win condition is met or the 180-second timer expires. Points are tallied based on sheep casualties/survival.

### 2.2 Win & Loss Conditions

- **Sheepherder Victory:** Successfully shoots and hits the Monster with their firearm (prior to the Monster reaching its unkillable "giant scary monster" (GSM) evolution).
- **Monster Victory:**
  * Consumes at least **5 NPC sheep** to unlock the lethal melee attack, then successfully eats/kills the Sheepherder.
  * *Escalation Path:* Eats all **10 NPC sheep** to evolve into the unkillable "giant scary monster" (GSM), then hunts and eats the Sheepherder.
  * *Ammo Depletion Scenario:* If the Sheepherder has used all bullets (**3**, or **4** with the *Spare Bullet* perk), the Monster can no longer be killed and can freely hunt the flock until the round concludes. It can still only kill the Sheepherder after eating **5 sheep**.
- **Timeout & Draw Conditions:**
  * Round duration is **180 seconds**.
  * If time expires without a lethal resolution, the player with more points wins the round. A round is a **Draw** only when the timer runs out with both players still alive and with equal points; a drawn round gives neither player a round win.

### 2.3 Scoring System

- **Monster Score:** Gains **+1 point** for every living NPC sheep it eats during the round. Sheep shot by the Sheepherder give the Monster **0 points**, even when it eats their bodies.
- **Sheepherder Score:** Gains **+1 point** for every NPC sheep still alive at the end of the round, and loses **2 points** for every NPC sheep they shot.
- **Match Structure:** Best of 5 rounds, decided by round wins. Roles are assigned at random for round 1, and players swap roles after every round. All 5 rounds are always played, even once the match is decided. Points only decide rounds that end on the timer. If both players have the same number of round wins after 5 rounds, the match is a **Draw**.

---

## 3. Character & Entity Specifications

### 3.1 The Sheepherder

- **Role:** Investigator / Protector / Hunter
- **Movement:**
  * *PC:* WASD directional movement on the 2D plane.
  * *Mobile:* On-screen virtual movement joystick.
- **Vision & Fog of War Mechanics:**
  * Equipped with a flashlight attached to the end of a single-shot rifle, casting a light cone restricted by specific width and length parameters. The Sheepherder holds the rifle in both hands, aiming the flashlight and the weapon wherever they point. 
  * *Aiming/Rotation:* Rotates 360 degrees around the Sheepherder to match viewing direction (controlled via Mouse cursor on PC; secondary virtual joystick on Mobile).
  * *Strict Fog of War Rules:* Outside the visibility cone, the map is shrouded in heavy darkness. **Static map elements** (trees, bushes, barns, ground details) remain faintly visible in the dark, whereas **dynamic entities (NPC sheep and the Monster) are completely invisible** unless illuminated by the light cone, even right next to the Sheepherder. **Blood** and the bodies of shot sheep are also only visible inside the light cone. Players must rely on spatial audio cues to track unseen movement.
- **Combat & Firearm Mechanics:**
  * Equipped with the aforementioned single-shot rifle with a **strict limit of 3 bullets per round** (4 with the *Spare Bullet* perk).
  * **Bullet Path:** A shot travels along the aim direction until it hits an NPC sheep, the Monster or a solid obstacle, or leaves the map. The light cone doesn't limit its range, so the Sheepherder can hit targets they can't see.
  * **Reloading:** Reloads automatically after each shot, using a long reload timer. Once all bullets are expended, the weapon is permanently empty for the rest of the round.
  * **Friendly Fire / Consequence:** Shooting an NPC sheep kills it immediately (depleting the flock and costing the Sheepherder **2 points**; the Monster gets nothing for it). The shot sheep's body stays on the ground for the rest of the round, with blood next to it. Shooting the Monster before it evolves into the spider results in an instant Sheepherder victory.
- **Sheepherder Base Abilities:**
  * **Bell:** Ringing the bell triggers a behavioral phase shift in the flock, causing nearby sheep to walk toward the Sheepherder.

### 3.2 The Monster

- **Role:** Deceiver / Predator
- **Appearance & Disguise ("No Built-in Tell"):**
  * Visually **100% identical** to an NPC sheep in style: it spawns with its own randomized visual seed, generated the same way as the NPC sheep's (it does not copy an existing sheep).
  * **No Built-in Tell:** There are no passive visual or mechanical giveaways distinguishing the Monster from an NPC sheep. To survive, the Monster player must actively roleplay and mimic NPC sheep behavior (including holding a dedicated button to play the **graze / eat grass** animation, pressing a dedicated button to **bleat**, and reacting believably when the Sheepherder rings the bell).
  * **Camera / Framing:** For the Monster player, their disguised sheep character remains centered on the screen.
- **Vision:**
  * Sees across the whole map in all directions (no light cone).
  * Line-of-sight obstacles block its view the same way they block the Sheepherder's flashlight: dynamic entities behind them are hidden.
  * It sees the Sheepherder's light wherever it falls, even when the Sheepherder is hidden.
- **Movement:**
  * *PC/Mobile Controls:* Directional movement matching PC/Mobile inputs, at the same speed as the NPC sheep.
  * *Sprint:* Holding a dedicated button moves the Monster at **1.5×** speed while its stamina lasts. NPC sheep never move this fast, so sprinting in view of the Sheepherder can give the Monster away. Not available in "giant scary monster" (GSM) form.
- **Abilities & Progression:**
  * **Graze (Mimicry Action):** Hold a dedicated button (PC/Mobile) to lower the head and eat grass, matching NPC sheep idle cycles. The Monster can't move while grazing.
  * **Bleat (Mimicry Action):** Press a dedicated button (PC/Mobile) to bleat like an NPC sheep.
  * **Consume Sheep:** Triggered via dedicated button press (PC) or virtual UI button (Mobile) when within melee proximity of an NPC sheep.
    * *Animation & Lockout:* Eating animation takes **1.0 second**. The Monster **cannot move or abort** during this animation, leaving it vulnerable.
    * *Cooldown:* Default **5.0 seconds** between consumptions.
    * *Evidence:* Blood from killed sheep remains permanently on the ground as physical evidence (no blood appears on the Monster's wool). An eaten sheep's body disappears; only the blood stays.
    * *Bodies of Shot Sheep:* The Monster can also eat the body of a sheep the Sheepherder shot. This works like eating a living sheep and counts toward both evolution thresholds, but gives no points (see 2.3), and the Shepherd Dog doesn't react to it.
  * **Phase 1 Evolution (5 Sheep Eaten):** Unlocks a one-attack kill on the Sheepherder, using the same melee proximity attack as on sheep. The Sheepherder dies instantly when the attack lands (so they can't shoot back), and the eating animation still plays.
  * **Phase 2 Evolution (10 Sheep Eaten — "giant scary monster" (GSM) Form):** Upon eating all 10 sheep, the Monster transforms into a **giant scary monster** (GSM), becoming completely **unkillable** (bullets have no effect) and hunting down the Sheepherder.

### 3.3 NPC Sheep (The Flock)

- **Visual Differentiation:** Spawn with randomized, unique visual details (wool patterns, markings, accessories, or slight physical variations) generated from a deterministic seed so the Sheepherder can track and tell individual sheep apart.
- **Swarm & AI Behaviors:**
  * Act collectively as a dynamic swarm (flocking/boids behavior).
  * Operate on distinct behavioral phases: idle wandering, grazing (eating grass), bleating ("mähen" / audio cues), and reacting to the Sheepherder's bell (converging on the Sheepherder).
  * **Total Flock Size per Round:** 10 NPC sheep.
- **Collision:** Sheep, including the Monster's sheep, are solid: they can't walk through each other or through the Sheepherder. The Sheepherder pushes sheep out of the way when walking into them.

---

## 4. Perks (Loadout Upgrades)

Before each round begins, each player selects **1 Perk** from their respective pool. Companions count as a standard Perk slot. The Sheepherder's choice is never shown to the Monster.

### 4.1 Sheepherder Perks (Choose 1)

- **Wide Flashlight (Passive):** Widens the flashlight cone angle by **50%** (60° → 90°) at the normal length, lighting **50%** more area for the entire round.
- **Long Flashlight (Passive):** Lengthens the flashlight cone (350 px → 429 px) at the normal angle, lighting **50%** more area for the entire round.
- **Faster Weapon Reload (Passive):** Reduces firearm reload duration by **50%**.
- **Friendly Shepherd Dog (Companion):** An AI dog that stays near the Sheepherder; it barks and faces directly toward the Monster whenever the Monster is actively in the middle of its eating animation. It only notices this within **800 px** of the dog (the loud hearing range), and it doesn't react when the Monster eats the body of a shot sheep. The dog passes through sheep and the Sheepherder, so it never blocks anyone.
- **Spare Bullet (Passive):** Adds a hidden **4th bullet**. Because the Monster never sees the Sheepherder's perk choice, it can't be sure the weapon is empty after 3 shots. The Monster may still work it out by ruling out the perks it can observe (cone shape, the dog, reload speed); this is accepted for now.

### 4.2 Monster Perks (Choose 1)

- **Faster Consumption (Passive):** Halves the eating/killing animation duration (vulnerability window **1.0s → 0.5s**).
- **Temporary Invisibility (Active):** Turns the Monster invisible for up to **5 seconds**. The duration meter drains slowly while standing still, and drains very rapidly while moving. Pressing the perk button again ends it early, and the rest of the meter is lost. The **30-second cooldown** starts when the invisibility ends. It can't be used in spider form or during the eating animation.
  * While invisible, the Monster can still be heard, it is still solid, and bullets still hit it. It cannot eat, it is hidden from the Shepherd Dog, and the NPC sheep no longer treat it as one of the flock.
  * The Monster's own player sees their character semi-transparent while it is invisible.
- **Allied Bat (Companion / Active):** Commands an allied bat to fly toward the Sheepherder, harassing them and shrinking their flashlight cone's length and angle by about **42%** each for **10 seconds**, which cuts the lit area by **80%** (30-second cooldown). The bat enters from a random position on the map edge nearest the Sheepherder. The 10 seconds start when the bat reaches the Sheepherder, and the cooldown starts when it leaves. Bullets pass through the bat. It can't be used in spider form.

---

## 5. Gameplay Parameter Table

*(Baseline placeholder values for initial prototyping and balancing)*

| Category | Parameter | Default Value | Notes |
| :--- | :--- | :--- | :--- |
| **Match Rules** | Round Duration | `180s` | At timeout the higher score wins the round; equal score with both players alive is a Draw |
| | Match Format | `Best of 5` | Decided by round wins; all 5 rounds are always played; equal round wins after 5 rounds is a Draw; roles are random in round 1, then swap every round |
| | Flock Size | `10 NPC Sheep` | Plus 1 disguised Monster (11 sheep-like entities total) |
| | Shot Sheep Penalty | `-2 points` | Sheepherder only; the Monster gets `0` for shot sheep, even when it eats their bodies |
| **Sheepherder** | Base Movement Speed | `180 px/s` | Standard patrol speed |
| | Firearm Ammo Capacity | `3 Bullets` | Strict per-round limit; cannot be replenished; `4` with *Spare Bullet* perk |
| | Firearm Reload Time | `4.0s` | Automatic after each shot; reduced to `2.0s` with *Faster Weapon Reload* perk |
| | Flashlight Cone Angle | `60°` | `90°` with *Wide Flashlight* perk |
| | Flashlight Cone Length | `350 px` | Blocked by solid obstacles (trees, barns, hay bales); `429 px` with *Long Flashlight* perk |
| | Bell Cooldown | `12.0s` | Draws nearby sheep toward the Sheepherder |
| | Bell Radius | `400 px` | Sheep within this distance walk toward the Sheepherder |
| **Monster** | Base Movement Speed | `180 px/s` | Same as the NPC sheep movement speed for seamless mimicry |
| | Sprint Speed | `270 px/s` | `1.5×` base speed while the sprint button is held; sheep form only |
| | Sprint Stamina | `3.0s` | Drains while sprinting; refills at `0.5×` speed while not sprinting (`6.0s` from empty to full) |
| | "Giant Scary Monster" (GSM) Form Speed | `300 px/s` | Unlocked at 10 sheep eaten; unkillable state; faster than sprinting, no sprint in "giant scary monster" (GSM) form |
| | Eat Animation Duration | `1.0s` | Movement locked; reduced to `0.5s` with *Faster Consumption*; also plays on the Sheepherder kill |
| | Eat Ability Cooldown | `5.0s` | Cooldown starts after eating animation completes |
| | Melee Range | `48 px` | Center-to-center distance to eat a sheep or kill the Sheepherder |
| | Sheepherder Kill Threshold | `5 Sheep Eaten` | Unlocks the one-attack melee kill on the Sheepherder |
| | "Giant Scary Monster" (GSM) Evolution Threshold | `10 Sheep Eaten` | Transforms into unkillable "giant scary monster" (GSM) monster |
| **NPC Sheep** | Movement Speed | `180 px/s` | One speed for wandering and walking to the bell; same as the Monster |
| | Graze Duration | `3.0–6.0s` | Random per graze; the sheep stands still with its head lowered |
| **Perks** | Invisibility Max Duration | `5.0s` | Drains `1.0x` when still, `3.0x` when moving (`30.0s` CD, from when it ends); can be ended early |
| | Allied Bat Disruption | `10.0s` | Shrinks flashlight cone length and angle by `~42%` each, cutting the lit area by `80%`, from when the bat arrives (`30.0s` CD, from when it leaves) |
| **Audio** | Hearing Range (quiet) | `400 px` | Sheep moving through grass |
| | Hearing Range (loud) | `800 px` | Bleating, Monster eating, dog barking |
| | Hearing Range (bell, gunshot) | `Whole map` | Lets both players keep track of bell rings and shots fired |
| **Arena** | Arena Size | `3200 × 2400 px` | One arena; the border fences and river are included |

---

## 6. Level Design & World Environment

- **Map Layout & Dimensions:** Bounded 2D top-down environment set in open green fields with slight hills and patches of grass. There is one arena of **3200 × 2400 px**, borders included.
- **Line-of-Sight Obstacles:** Solid environmental props that block movement, the Sheepherder's flashlight visibility cone, and the Monster's view (e.g., trees, barns, thick bushes, wooden structures, hay bales).
- **Map Boundaries:** Enclosed by non-traversable natural and man-made borders (e.g., rivers, wooden fences).

---

## 7. Art Direction & Audio Design

### 7.1 Visual & Art Style

- See file "art_style_giant_scary_monster.md"

### 7.2 Audio Design

- **Diegetic Sound Effects:** Sheep bleating ("mähen"), grass grazing rustles, Sheepherder's bell (crucial gameplay cue), gunshot and mechanical reload clicks, wet Monster eating cues, "Giant Scary Monster" (GSM) screech upon full evolution.
- **Music & Ambience:** Ambient wind, realistic, minimal, layered night sounds.
- **Spatial Audio Rules:** Critical for locating entities hidden in the Fog of War. Directional/distance-attenuated audio cues apply to the Shepherd Dog barking, unseen sheep moving through grass, and Monster consumption sounds.

---

## 8. User Interface (UI) & User Experience (UX)

### 8.1 Pre-Game Lobby UI

- **Design Philosophy:** Extremely simplified, frictionless interface optimized for browser play.
- **Functionality:**
  * Network connection status / Peer-to-Peer pairing by scanning each other's QR codes or exchanging text codes (see 9.4).
  * Role assignment indicator (Sheepherder vs. Monster).
  * Single-selection Perk widget (choosing 1 Perk/Companion). The Sheepherder's choice is never shown to the Monster.

### 8.2 In-Game HUD

- **PC HUD:** Each player sees only the HUD elements for their current role.
  * *Both Roles:*
    * Round timer (remaining time of the current round).
  * *Sheepherder Only:*
    * Bullet counter (visual display of remaining bullets out of 3, or 4 with *Spare Bullet*).
    * Reload progress indicator.
    * Bell cooldown icon.
  * *Monster Only:*
    * Action and cooldown icons for Graze, Bleat, Eat, and the active Perk, plus the sprint stamina meter.
    * "Evolution Bar" (tracks progress toward the 5-sheep Herder kill unlock and 10-sheep "Giant Scary Monster" (GSM) evolution).
    * Remaining living NPC sheep count.
- **Mobile HUD:** Identical telemetry to PC, adapted for touchscreens using responsive virtual joysticks (left for movement, right for Sheepherder flashlight aim) and ergonomic action buttons.
- **End-of-Round / Scoreboard Screen:** Displays round outcome, points earned (+1 per surviving sheep and -2 per shot sheep for the Sheepherder; +1 per living sheep eaten for the Monster), and the Best-of-5 round-win standing.

---

## 9. Technical Architecture & Engineering Standards

### 9.1 Engine, Language & Target Build

- **Game Engine:** Godot Engine (**Strictly Version 4.7**)
- **Programming Language:** GDScript (Godot 4.7 can't export C# projects to the Web)
- **Export Target:** Web Browser Build (HTML5 / WebAssembly) supporting cross-play between desktop browsers (PC) and mobile browsers (iOS/Android).
- **Web Audio:** Web builds play audio in *Sample* mode by default, where Godot's docs warn that "positional audio may not always work correctly depending on the node's properties". *Stream* mode supports all audio features but adds latency, especially without *Thread Support*. The spatial audio from 7.2 must be tested early in the web build.

### 9.2 Architectural Principles (SoC & DRY)

The codebase must strictly enforce **Separation of Concerns (SoC)** and **Don't Repeat Yourself (DRY)**:

- **`abstractions/` Directory:** Core system contracts must be defined as abstract GDScript classes (`@abstract`, available since Godot 4.5) inside a dedicated `abstractions` folder (e.g., `InputService`, `NetworkService`, `SwarmService`, `CombatService`, `PerkService`, `AudioService`). GDScript has no interfaces and allows only single inheritance, so each abstract class must extend the engine type its implementations need (e.g., `Node`).
- **Service Registration / Dependency Injection:** Systems must decouple implementation from consumption via a centralized service locator or dependency injection container.
- **Shared Logic (DRY):** Input handling abstractions must unify PC (WASD/Mouse) and Mobile (Virtual Joysticks/Touch Buttons) inputs into normalized command vectors and action triggers before passing them to character controllers. Mobile controls use Godot's built-in `VirtualJoystick` and `TouchScreenButton` nodes, which trigger the same input actions as the keyboard.

### 9.3 Proposed Project Directory Structure

```text
res://
├── abstractions/             # Abstract GDScript classes for all core services & entities
│   ├── input_service.gd
│   ├── network_service.gd
│   ├── swarm_service.gd
│   ├── combat_service.gd
│   ├── perk_service.gd
│   └── audio_service.gd
├── services/                 # Concrete implementations & Service Registry
├── entities/                 # Sheepherder, Monster (Sheep & "Giant Scary Monster" / GSM), NPC Sheep, Companions
├── systems/                  # Lighting/FoW Shaders, NPC & Companion AI, Swarm Boids
├── ui/                       # Simplified Lobby, Responsive Mobile/PC HUD
└── assets/                   # Realistic painterly sprites, shaders, spatial audio
```

### 9.4 Networking & Browser Cross-Play

- **Topology:** Peer-to-Peer (P2P) over WebRTC on the local network, without any server. Both devices must be on the same network; Wi-Fi networks that block traffic between devices (e.g., guest networks with client isolation) can't be used.
- **Hosting:** The web build is served as a static website over HTTPS and runs as its own page (not embedded in another site's frame). Browsers only allow camera and clipboard access over HTTPS.
  * If the host can't send the cross-origin isolation headers that *Thread Support* requires, either export without *Thread Support* or enable the *Progressive Web App* export option, which ensures those headers.
- **Pairing via QR Code or Text Code:**
  1. The host creates a WebRTC offer, waits until candidate gathering is complete (`GATHERING_STATE_COMPLETE`) so all connection data is in one message, and shows it as a QR code plus a copyable text code.
  2. The guest scans the QR code (or pastes the text code), creates the answer, and shows it the same way.
  3. The host scans or pastes the answer, and the devices connect.
  * Without a camera, players send each other the text code instead, e.g., through a messenger app.
  * The connection data should be compressed before encoding, to keep the QR code small enough to scan from a screen. The real data size is untested, so pairing should be prototyped first.
  * Godot's `CameraServer` is not implemented on the Web, so scanning must use the browser's camera through `JavaScriptBridge`.
  * Godot has no built-in QR code generator, and its only QR code support (OpenXR spatial entities) is for XR headsets. QR generation and decoding need either a JavaScript library (added through the web export's *Head Include* option and served with the game files) or a GDScript implementation.
  * Godot's docs say Web clipboard access "might not be reliable when accessed from GDScript", so copy and paste must be tested early.
  * *Decided (#7):* QR codes are made with the JavaScript library qrcode-generator and read with jsQR, both shipped with the game files. Copy, paste and the camera preview are HTML laid over the game. A code is the session description with all candidates, trimmed and compressed, as Base32 text (A–Z, 2–7), so the same text works as QR code and as text code. Measured sizes and browser results are in docs/pairing.md.
  * *Decided (#56):* **Host** and **Join** first ask for the camera, and it stays on until the device's code is made: only then do browsers put the device's real addresses into the code, instead of hidden `.local` names that the other device often can't resolve. The guest's answer leaves starting the encryption (DTLS) to the host, and the host waits 30 s for the connection after reading the answer. Findings are in docs/pairing.md.
- **Godot Multiplayer API:** Use `WebRTCMultiplayerPeer`. A Web build can only be a WebSocket client, so `WebSocketMultiplayerPeer` would require a separate server.
- **State Synchronization Requirements:**
  * Position and rotation of Sheepherder (including flashlight cone angle).
  * Position, disguise seed, grazing state, and evolution state (Sheep vs. "Giant Scary Monster" / GSM) of the Monster, plus AI Companions.
  * Host-authoritative synchronization of NPC Sheep swarm positions, deterministic visual seeds, and behavioral phases (grazing, bell attraction).
  * Combat and world events (gunshots, bullet count updates, blood decal spawns, sheep consumption, score updates).