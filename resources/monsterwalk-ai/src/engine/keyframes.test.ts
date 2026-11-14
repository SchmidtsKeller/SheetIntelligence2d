import test from 'node:test';
import assert from 'node:assert/strict';
import {
  GAIT_CLIPS,
  sampleClip,
  blendEvaluatedPoses,
  evaluateLegPose,
  evaluateBodyPose,
  wrapPhase,
  catmullRom,
} from './keyframes';
import { GSM_LEG_SPECS, bodySignedDistance, assignPixelToLeg } from './gsmRig';

test('wrapPhase normalizes negative and >1 values into [0, 1)', () => {
  assert.ok(Math.abs(wrapPhase(0) - 0) < 1e-9);
  assert.ok(Math.abs(wrapPhase(1) - 0) < 1e-9);
  assert.ok(Math.abs(wrapPhase(1.25) - 0.25) < 1e-9);
  assert.ok(Math.abs(wrapPhase(-0.25) - 0.75) < 1e-9);
});

test('catmullRom passes cleanly through control knots p1 and p2', () => {
  assert.ok(Math.abs(catmullRom(0, 10, 20, 30, 0) - 10) < 1e-9);
  assert.ok(Math.abs(catmullRom(0, 10, 20, 30, 1) - 20) < 1e-9);
});

test('sampleClip loops seamlessly across phase 0/1 boundary in all modes', () => {
  const modes = ['hermite', 'bezier', 'linear'] as const;
  for (const clipId of Object.keys(GAIT_CLIPS) as (keyof typeof GAIT_CLIPS)[]) {
    const clip = GAIT_CLIPS[clipId];
    for (const mode of modes) {
      const p0 = sampleClip(clip, 0.0, mode);
      const pEnd = sampleClip(clip, 0.9999, mode);
      const pStart = sampleClip(clip, 0.0001, mode);
      assert.ok(
        Math.abs(p0.coxaSwing - pEnd.coxaSwing) < 0.015,
        `${clipId} (${mode}) discontinuity at loop seam`
      );
      assert.ok(
        Math.abs(p0.lift - pStart.lift) < 0.015,
        `${clipId} (${mode}) lift discontinuity at loop seam`
      );
    }
  }
});

test('hermite interpolation produces smooth finite derivatives with no spikes', () => {
  const clip = GAIT_CLIPS.walk;
  let prev = sampleClip(clip, 0, 'hermite');
  const step = 0.01;
  for (let t = step; t <= 1.0; t += step) {
    const cur = sampleClip(clip, t, 'hermite');
    assert.ok(Number.isFinite(cur.coxaSwing));
    assert.ok(Number.isFinite(cur.lift));
    assert.ok(Math.abs(cur.coxaSwing - prev.coxaSwing) < 0.2);
    prev = cur;
  }
});

test('crossfadePose blends smoothly between idle and walk without jumps', () => {
  const idle = sampleClip(GAIT_CLIPS.idle, 0.3, 'hermite');
  const walk = sampleClip(GAIT_CLIPS.walk, 0.3, 'hermite');

  const start = blendEvaluatedPoses(idle, walk, 0);
  const mid = blendEvaluatedPoses(idle, walk, 0.5);
  const end = blendEvaluatedPoses(idle, walk, 1);

  assert.ok(Math.abs(start.coxaSwing - idle.coxaSwing) < 1e-9);
  assert.ok(Math.abs(end.coxaSwing - walk.coxaSwing) < 1e-9);
  assert.ok(
    Math.abs(mid.coxaSwing - 0.5 * (idle.coxaSwing + walk.coxaSwing)) < 1e-9
  );
});

test('20-leg metachronal gait maintains grounded stability (>= 8 legs planted) across full walk cycle', () => {
  const clip = GAIT_CLIPS.walk;
  for (let step = 0; step < 40; step++) {
    const phase = step / 40;
    let groundedCount = 0;
    let liftedCount = 0;
    for (const leg of GSM_LEG_SPECS) {
      const pose = evaluateLegPose(clip, leg.index, leg.side, phase, 'hermite');
      assert.ok(Number.isFinite(pose.coxaAngle));
      assert.ok(pose.lift >= 0 && pose.lift <= 1);
      if (pose.isGrounded) groundedCount++;
      else liftedCount++;
    }
    assert.ok(
      groundedCount >= 8,
      `Too few grounded legs (${groundedCount}/20) at phase=${phase}`
    );
    assert.ok(
      liftedCount >= 4,
      `Too few swinging legs (${liftedCount}/20) at phase=${phase}`
    );
  }
});

test('steering turnBias creates differential left/right coxa sweep and head tracking', () => {
  const clip = GAIT_CLIPS.walk;
  const leftTurnBody = evaluateBodyPose(clip, 0.25, 'hermite', -1);
  const rightTurnBody = evaluateBodyPose(clip, 0.25, 'hermite', 1);
  assert.ok(leftTurnBody.headYawRad < rightTurnBody.headYawRad);

  const leftLegRightTurn = evaluateLegPose(clip, 5, 'L', 0.0, 'hermite', 1);
  const rightLegRightTurn = evaluateLegPose(clip, 5, 'R', 0.5, 'hermite', 1);
  // Outer left leg sweeps wider than inner right leg when turning right
  assert.ok(Math.abs(leftLegRightTurn.coxaAngle) > Math.abs(rightLegRightTurn.coxaAngle));
});

test('GSM rig defines exactly 20 legs (10 Left, 10 Right) with valid torso separation', () => {
  assert.equal(GSM_LEG_SPECS.length, 20);
  const left = GSM_LEG_SPECS.filter((l) => l.side === 'L');
  const right = GSM_LEG_SPECS.filter((l) => l.side === 'R');
  assert.equal(left.length, 10);
  assert.equal(right.length, 10);

  // Center of sheep body should be well inside torso SDF
  assert.ok(bodySignedDistance(512, 480) < -0.5);
  // Sheep snout should be inside head SDF
  assert.ok(bodySignedDistance(512, 840) < 0);
  // Outer leg tip should be outside body SDF and assigned to L5
  assert.ok(bodySignedDistance(44, 678) > 0);
  const assigned = assignPixelToLeg(44, 678);
  assert.equal(GSM_LEG_SPECS[assigned.legIndex].id, 'L5');
});
