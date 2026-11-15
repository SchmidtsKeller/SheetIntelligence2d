# "No Built-in Tell" audit

GDD §3.2: nothing passive may distinguish the Monster from an NPC sheep. The Sheepherder may find it by what its player does, and by nothing else. This document is the checklist for that rule, how each point is checked, and the result for the Monster as built in #16 and for the round around it as built in #17.

Repeat the audit whenever the sheep body, the flock, the session's replication, the vision system, the round's setup or the Monster itself changes.

## How the Monster is built

The rule is kept by construction rather than by imitation. The Monster has no body of its own:

- Its body is the shared sheep scene ([entities/sheep/sheep.tscn](../entities/sheep/sheep.tscn)) with the same [SheepNetSync](../entities/sheep/sheep_net_sync.gd) an NPC sheep has, placed in the same layer of the arena.
- What makes it the Monster is one child node, [Monster](../entities/monster/monster.gd), which draws nothing and has no collision. On the Sheepherder's device it has no children either; camera and input exist only on the Monster's own device.
- Its look comes from the visual seed of the slot the flock leaves free ([RoundCast](../systems/flock/round_cast.gd)), generated like every other sheep's.
- Its player steers the body through the same motion model, the same grazing and the same bleat as the flock's minds do.

## Checklist

"Automated" names the test in [tests/unit/test_monster_no_tell.gd](../tests/unit/test_monster_no_tell.gd). It spawns the Monster and one NPC sheep (the "twin") with the same visual seed, steers both alike, and compares them on the Sheepherder's device. Every test runs twice: with the Sheepherder on the guest and on the host.

| # | What must not differ | How it is checked | Result |
|:--|:--|:--|:--|
| 1 | **Appearance generation:** same scene, same catalog, same way from seed to look | Automated (`built_like_a_sheep`): scene file, catalog and appearance fingerprint are equal for the same seed | Pass |
| 2 | **Structure:** nodes, groups, physics layers, vision target | Automated (`built_like_a_sheep`): the two trees are identical except for the one `Monster` node, which has no children; same groups, collision layers and masks, same `VisionTarget` kind, radius and faded part | Pass |
| 3 | **Draw order:** same layer, same sorting | Automated (`built_like_a_sheep`): same parent, the arena's Y-sorted entities layer; nothing on the Monster changes `z_index` or sorting | Pass |
| 4 | **Animation timing:** walk, idle, graze and bleat start, run and end alike | Automated (`behaves_like_a_sheep`): in every drawn frame the two show the same state, and the same painted frame of the same animation at the same speed (#74), while walking, grazing, bleating and stopping. Which frames play depends only on the state and the shown speed; the first frame of a loop comes from the visual seed, like the look | Pass |
| 5 | **Interpolation and latency:** the Monster's picture is as old and as smooth as a sheep's | Automated (`behaves_like_a_sheep`): position within 0.01 px and heading within 0.0001 rad in every drawn frame, on both devices. Two real instances (`tools/test_two_instances.sh monster`, also with latency, jitter and loss): no jumps | Pass, see *Limits* |
| 6 | **Movement audio:** footsteps start and stop alike | Automated (`behaves_like_a_sheep`): the looping sounds of both are switched on and off at the same moments. Both follow the sheep's shown picture, not its body, so on the device that simulates the flock no sheep sounds ahead of where it is seen (`tests/unit/test_sheep_body.gd`) | Pass |
| 7 | **Bleat audio:** same sound set, same place, same range | Automated (`behaves_like_a_sheep`): one bleat each plays the same event at each sheep; the Monster's bleat is the body's own `bleat()`. The audio service (#10) plays an event the same way whoever causes it: the same cue, variations and range | Pass |
| 8 | **Collision:** the Sheepherder pushes it like a sheep; sheep keep the same distance | Automated (`pushed_like_a_sheep`): the same push moves both bodies equally on the device that simulates them. Same collision shape, layer and mask (point 2); the flock treats the Monster as a neighbour | Pass |
| 9 | **Light:** lit, half lit and dark alike, by the flashlight and by torches | Automated (`lit_like_a_sheep`): the vision system fades both to the same value with the same colour in the light, at its edge and in the dark. Light levels depend on position only ([LightRules](../systems/vision/light_rules.gd)); a torch's light and the flashlight's fade are the same function for every body (`tests/unit/test_lighting.gd`) | Pass |
| 10 | **Nothing else on screen:** no marker, name, outline, HUD entry or sound that only the Monster has | By reading the code: `Monster` adds nothing to the Sheepherder's device besides itself; the sandbox's status line does not say where the Monster is | Pass |
| 11 | **Before the round starts:** during the countdown the flock already wanders, but the Monster's player cannot move yet | Automated (`tests/unit/test_round_screen.gd`, `the_sheepherder_starts_in_their_corner_far_from_the_flock`): the Sheepherder starts in their corner and the Monster in the flock's area, further apart than the flashlight reaches, and the Sheepherder cannot walk before the round is active either (`nobody_can_act_before_the_countdown_is_over`). So the one sheep that cannot move yet is not in the light | Pass |

## Differences that exist and cannot be seen

- The extra child node `Monster` (a `Node2D` that draws nothing).
- The entity's node name: `monster_<id>` instead of `sheep_<id>`.
- NPC sheep carry the meta value `mind_seed`; the Monster does not.
- `SheepNetSync.live_on_owner` is set for the Monster. It only has an effect on the Monster's own device.

All positions are sent to both devices; what is hidden is hidden when it is drawn (see [networking.md](networking.md)). A modified client could read any of the above. That is accepted for a local 1v1 game without anti-cheat.

## Tells that are intended

These are things the Monster's player does, and the Sheepherder is meant to catch them (GDD §3.2):

- **Sprinting:** 270 px/s instead of 180, with the walk animation running faster to match, the painted sprint frames instead of the walk frames, and a louder rustle (`grass_run`, #73). The sprint frames show for any sheep body that is shown faster than 1.25 times the sheep speed: the sprinting Monster, and any sheep, the Monster's included, while the Sheepherder pushes it along. The rustle goes by the speed of the simulated body, faster than a sheep can be, and travels in the snapshots like grazing. The same would happen to an NPC sheep, but none moves that fast.
- **Eating:** the 1.0 s eating animation (the painted `eat_feed` frames since #95: the body splits open into a maw of teeth and swallows the prey; only a devouring body plays them), the loud eating sound, the blood on the ground and the missing sheep.
- **The spider:** it is not a disguise.
- **Behaving unlike a sheep:** walking too straight, too far, never grazing, ignoring the bell.

## Limits

- **Packet loss with a hosting Sheepherder.** When the Sheepherder hosts, the flock is simulated on their device and the Monster arrives over the network. Both are drawn from the same buffer with the same delay, but only the Monster's snapshots can be lost. One lost snapshot is bridged without a trace; several in a row make the Monster keep its course for up to 0.1 s and then stand still until the next one arrives, which an NPC sheep on that device never does. On a local network this is rare, and the two-instance check sees no jumps with 10 % loss. It is the one way left in which the network could give the Monster away. When the picture then catches up, it moves faster than a sheep for a moment. The louder running rustle does not follow: whether a sheep runs travels in the snapshots, like grazing.
- **Not checked by a human yet.** The automated audit compares numbers. Nobody has yet sat in front of two devices and tried to pick the Monster out by eye and ear; do that with the steps below before a release.

## Repeating the audit by hand

Start the Monster sandbox twice. The host plays the Sheepherder, the guest the Monster:

```bash
godot --path . res://entities/monster/sandbox/monster_sandbox.tscn -- --host
```

```bash
godot --path . res://entities/monster/sandbox/monster_sandbox.tscn -- --join
```

With `--monster` on the host the roles are the other way round; check both. Add `--net-latency=80 --net-jitter=40 --net-loss=10` to both for a bad connection.

1. The Monster's player stands still, walks a few steps, grazes and bleats, as the sheep around it do. The Sheepherder's player, who does not know which sheep it is, lights the flock and tries to name it. They must not do better than guessing.
2. Look for: a sheep that is drawn in front of or behind others wrongly, moves more smoothly or more jerkily, turns differently, starts or stops its animation late, sounds different, or is lit differently at the edge of the light.
3. The Sheepherder walks into sheep. All of them give way alike.
4. Then the Monster's player sprints and eats. Now the Sheepherder should be able to tell.
