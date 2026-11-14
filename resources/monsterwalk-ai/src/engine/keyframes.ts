export type InterpolationMode = 'hermite' | 'bezier' | 'linear';
export type GaitClipId = 'idle' | 'stalk' | 'walk' | 'lunge';

export interface KeyframeSample {
  /** Normalized cycle timestamp in [0, 1] */
  t: number;
  /** Human-readable pose label for keyframe timeline markers */
  label: string;
  /** Anatomical forward/backward sweep (-1 rear push .. +1 forward reach) */
  coxaSwing: number;
  /** Proximal knee flex angle in radians */
  femurFlex: number;
  /** Medial knee flex angle in radians */
  tibiaFlex: number;
  /** Distal sharp tarsus curl in radians */
  tarsusCurl: number;
  /** Vertical leg elevation [0 = planted on earth, 1 = hoisted high in air] */
  lift: number;
  /** Radial reach scale (foreshortening during lift vs extension at plant) */
  reachScale: number;
  /** Body vertical bob / scale pulse (-0.03..+0.03) */
  bodyBob: number;
  /** Body lateral roll / sway (-1..+1) */
  bodySway: number;
  /** Sheep head subtle yaw/nod (-1..+1) */
  headNod: number;
}

export interface GaitClip {
  id: GaitClipId;
  name: string;
  description: string;
  cycleDuration: number;
  baseSpeedPx: number;
  /** Metachronal wave phase step between adjacent legs on the same flank */
  waveStep: number;
  /** Contralateral (left vs right) phase offset */
  sideOffset: number;
  /** Max coxa swing angle in radians */
  maxSwingRad: number;
  keyframes: KeyframeSample[];
}

export interface EvaluatedPose {
  coxaSwing: number;
  femurFlex: number;
  tibiaFlex: number;
  tarsusCurl: number;
  lift: number;
  reachScale: number;
  bodyBob: number;
  bodySway: number;
  headNod: number;
}

export interface LegJointPose {
  /** Signed socket rotation in canvas space (radians) */
  coxaAngle: number;
  /** Signed rotation deltas for subsequent joints (radians) */
  jointAngles: [number, number, number];
  /** Vertical lift [0..1] for shadow separation & rim highlight */
  lift: number;
  /** Radial extension multiplier around socket */
  reachScale: number;
  /** True when the sharp tip is planted against the ground */
  isGrounded: boolean;
  /** Peak pulse [0..1] right at ground strike impact */
  strikePulse: number;
  /** Local leg cycle phase in [0, 1) */
  legPhase: number;
}

export interface BodyPose {
  bobScale: number;
  swayRad: number;
  surgePx: number;
  headYawRad: number;
  headNodScale: number;
  elevationPx: number;
}

export interface TransitionBlend {
  fromClip: GaitClipId;
  toClip: GaitClipId;
  elapsed: number;
  duration: number;
}

export const GAIT_CLIPS: Record<GaitClipId, GaitClip> = {
  idle: {
    id: 'idle',
    name: 'Idle',
    description: 'Hoisted breathing & subtle chitinous weight shift',
    cycleDuration: 2.8,
    baseSpeedPx: 0,
    waveStep: 0.16,
    sideOffset: 0.5,
    maxSwingRad: 0.045,
    keyframes: [
      {
        t: 0.0,
        label: 'Rest',
        coxaSwing: 0.0,
        femurFlex: 0.0,
        tibiaFlex: 0.0,
        tarsusCurl: 0.0,
        lift: 0.0,
        reachScale: 1.0,
        bodyBob: 0.0,
        bodySway: 0.0,
        headNod: 0.0,
      },
      {
        t: 0.25,
        label: 'Inhale',
        coxaSwing: 0.35,
        femurFlex: 0.03,
        tibiaFlex: -0.04,
        tarsusCurl: 0.03,
        lift: 0.12,
        reachScale: 0.985,
        bodyBob: 0.018,
        bodySway: 0.4,
        headNod: 0.5,
      },
      {
        t: 0.5,
        label: 'Twitch',
        coxaSwing: 0.0,
        femurFlex: 0.05,
        tibiaFlex: -0.06,
        tarsusCurl: 0.05,
        lift: 0.18,
        reachScale: 0.975,
        bodyBob: 0.024,
        bodySway: 0.0,
        headNod: 0.9,
      },
      {
        t: 0.75,
        label: 'Settle',
        coxaSwing: -0.35,
        femurFlex: 0.02,
        tibiaFlex: -0.02,
        tarsusCurl: 0.01,
        lift: 0.04,
        reachScale: 1.005,
        bodyBob: -0.012,
        bodySway: -0.4,
        headNod: -0.3,
      },
      {
        t: 1.0,
        label: 'Rest',
        coxaSwing: 0.0,
        femurFlex: 0.0,
        tibiaFlex: 0.0,
        tarsusCurl: 0.0,
        lift: 0.0,
        reachScale: 1.0,
        bodyBob: 0.0,
        bodySway: 0.0,
        headNod: 0.0,
      },
    ],
  },

  stalk: {
    id: 'stalk',
    name: 'Stalk',
    description: 'Slow predatory creep with deliberate stabbing steps',
    cycleDuration: 1.65,
    baseSpeedPx: 125,
    waveStep: 0.22,
    sideOffset: 0.5,
    maxSwingRad: 0.21,
    keyframes: [
      {
        t: 0.0,
        label: 'Strike',
        coxaSwing: 0.96,
        femurFlex: -0.04,
        tibiaFlex: 0.06,
        tarsusCurl: -0.04,
        lift: 0.0,
        reachScale: 1.05,
        bodyBob: -0.014,
        bodySway: 0.6,
        headNod: 0.35,
      },
      {
        t: 0.28,
        label: 'Mid-Stance',
        coxaSwing: 0.12,
        femurFlex: 0.02,
        tibiaFlex: -0.02,
        tarsusCurl: 0.0,
        lift: 0.0,
        reachScale: 1.0,
        bodyBob: 0.006,
        bodySway: 0.15,
        headNod: 0.0,
      },
      {
        t: 0.56,
        label: 'Push-Off',
        coxaSwing: -0.94,
        femurFlex: 0.06,
        tibiaFlex: -0.05,
        tarsusCurl: 0.04,
        lift: 0.06,
        reachScale: 0.98,
        bodyBob: 0.016,
        bodySway: -0.65,
        headNod: -0.35,
      },
      {
        t: 0.74,
        label: 'High Lift',
        coxaSwing: -0.1,
        femurFlex: 0.22,
        tibiaFlex: -0.28,
        tarsusCurl: 0.22,
        lift: 0.98,
        reachScale: 0.85,
        bodyBob: 0.022,
        bodySway: -0.25,
        headNod: 0.2,
      },
      {
        t: 0.88,
        label: 'Reach',
        coxaSwing: 0.78,
        femurFlex: 0.12,
        tibiaFlex: -0.14,
        tarsusCurl: 0.08,
        lift: 0.55,
        reachScale: 0.96,
        bodyBob: 0.004,
        bodySway: 0.35,
        headNod: 0.5,
      },
      {
        t: 1.0,
        label: 'Strike',
        coxaSwing: 0.96,
        femurFlex: -0.04,
        tibiaFlex: 0.06,
        tarsusCurl: -0.04,
        lift: 0.0,
        reachScale: 1.05,
        bodyBob: -0.014,
        bodySway: 0.6,
        headNod: 0.35,
      },
    ],
  },

  walk: {
    id: 'walk',
    name: 'Walk',
    description: '20-leg metachronal stride at GSM hunt speed (300 px/s)',
    cycleDuration: 0.88,
    baseSpeedPx: 300,
    waveStep: 0.24,
    sideOffset: 0.5,
    maxSwingRad: 0.27,
    keyframes: [
      {
        t: 0.0,
        label: 'Strike',
        coxaSwing: 1.0,
        femurFlex: -0.06,
        tibiaFlex: 0.08,
        tarsusCurl: -0.05,
        lift: 0.0,
        reachScale: 1.06,
        bodyBob: -0.018,
        bodySway: 0.85,
        headNod: 0.45,
      },
      {
        t: 0.26,
        label: 'Drive',
        coxaSwing: 0.05,
        femurFlex: 0.02,
        tibiaFlex: -0.02,
        tarsusCurl: 0.0,
        lift: 0.0,
        reachScale: 1.0,
        bodyBob: 0.01,
        bodySway: 0.1,
        headNod: -0.15,
      },
      {
        t: 0.52,
        label: 'Push-Off',
        coxaSwing: -0.98,
        femurFlex: 0.07,
        tibiaFlex: -0.06,
        tarsusCurl: 0.05,
        lift: 0.08,
        reachScale: 0.97,
        bodyBob: 0.022,
        bodySway: -0.85,
        headNod: -0.45,
      },
      {
        t: 0.72,
        label: 'Peak Lift',
        coxaSwing: -0.05,
        femurFlex: 0.24,
        tibiaFlex: -0.31,
        tarsusCurl: 0.24,
        lift: 1.0,
        reachScale: 0.83,
        bodyBob: 0.024,
        bodySway: -0.2,
        headNod: 0.25,
      },
      {
        t: 0.88,
        label: 'Swing Reach',
        coxaSwing: 0.84,
        femurFlex: 0.11,
        tibiaFlex: -0.13,
        tarsusCurl: 0.07,
        lift: 0.45,
        reachScale: 0.99,
        bodyBob: -0.005,
        bodySway: 0.55,
        headNod: 0.6,
      },
      {
        t: 1.0,
        label: 'Strike',
        coxaSwing: 1.0,
        femurFlex: -0.06,
        tibiaFlex: 0.08,
        tarsusCurl: -0.05,
        lift: 0.0,
        reachScale: 1.06,
        bodyBob: -0.018,
        bodySway: 0.85,
        headNod: 0.45,
      },
    ],
  },

  lunge: {
    id: 'lunge',
    name: 'Lunge',
    description: 'Aggressive charging scramble with snapping chitinous stride',
    cycleDuration: 0.56,
    baseSpeedPx: 430,
    waveStep: 0.27,
    sideOffset: 0.5,
    maxSwingRad: 0.34,
    keyframes: [
      {
        t: 0.0,
        label: 'Impact',
        coxaSwing: 1.05,
        femurFlex: -0.09,
        tibiaFlex: 0.11,
        tarsusCurl: -0.07,
        lift: 0.0,
        reachScale: 1.08,
        bodyBob: -0.025,
        bodySway: 1.0,
        headNod: 0.7,
      },
      {
        t: 0.24,
        label: 'Propulsion',
        coxaSwing: 0.02,
        femurFlex: 0.03,
        tibiaFlex: -0.03,
        tarsusCurl: 0.0,
        lift: 0.0,
        reachScale: 0.99,
        bodyBob: 0.016,
        bodySway: 0.0,
        headNod: -0.2,
      },
      {
        t: 0.48,
        label: 'Kick',
        coxaSwing: -1.04,
        femurFlex: 0.1,
        tibiaFlex: -0.1,
        tarsusCurl: 0.08,
        lift: 0.12,
        reachScale: 0.96,
        bodyBob: 0.028,
        bodySway: -1.0,
        headNod: -0.6,
      },
      {
        t: 0.68,
        label: 'Vault Lift',
        coxaSwing: 0.02,
        femurFlex: 0.29,
        tibiaFlex: -0.36,
        tarsusCurl: 0.28,
        lift: 1.0,
        reachScale: 0.79,
        bodyBob: 0.028,
        bodySway: -0.25,
        headNod: 0.35,
      },
      {
        t: 0.86,
        label: 'Pounce',
        coxaSwing: 0.92,
        femurFlex: 0.12,
        tibiaFlex: -0.12,
        tarsusCurl: 0.05,
        lift: 0.42,
        reachScale: 1.02,
        bodyBob: -0.008,
        bodySway: 0.7,
        headNod: 0.85,
      },
      {
        t: 1.0,
        label: 'Impact',
        coxaSwing: 1.05,
        femurFlex: -0.09,
        tibiaFlex: 0.11,
        tarsusCurl: -0.07,
        lift: 0.0,
        reachScale: 1.08,
        bodyBob: -0.025,
        bodySway: 1.0,
        headNod: 0.7,
      },
    ],
  },
};

export function wrapPhase(phase: number): number {
  const m = phase % 1;
  return m < 0 ? m + 1 : m;
}

export function cubicBezierEase(u: number): number {
  const t = Math.max(0, Math.min(1, u));
  return t * t * (3 - 2 * t);
}

/**
 * Uniform/non-uniform Catmull-Rom cubic Hermite interpolation over periodic keyframes.
 */
export function catmullRom(p0: number, p1: number, p2: number, p3: number, u: number): number {
  const u2 = u * u;
  const u3 = u2 * u;
  return (
    0.5 *
    (2 * p1 +
      (-p0 + p2) * u +
      (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2 +
      (-p0 + 3 * p1 - 3 * p2 + p3) * u3)
  );
}

function interpolateChannel(
  kfs: KeyframeSample[],
  idx: number,
  u: number,
  key: keyof Omit<KeyframeSample, 't' | 'label'>,
  mode: InterpolationMode
): number {
  const n = kfs.length - 1; // last keyframe mirrors first at t=1.0
  const p1 = kfs[idx][key];
  const p2 = kfs[idx + 1][key];

  if (mode === 'linear') {
    return p1 + (p2 - p1) * u;
  }
  if (mode === 'bezier') {
    const e = cubicBezierEase(u);
    return p1 + (p2 - p1) * e;
  }

  // Periodic wrap indices for C1 continuous loop at t = 0 / 1
  const idx0 = (idx - 1 + n) % n;
  const idx3 = (idx + 2) % n;
  const p0 = kfs[idx0][key];
  const p3 = kfs[idx3][key];
  return catmullRom(p0, p1, p2, p3, u);
}

/**
 * Evaluates a GaitClip at normalized phase in [0, 1) using the chosen interpolation curve.
 */
export function sampleClip(
  clip: GaitClip,
  phase: number,
  mode: InterpolationMode = 'hermite'
): EvaluatedPose {
  const p = wrapPhase(phase);
  const kfs = clip.keyframes;
  let seg = 0;
  for (let i = 0; i < kfs.length - 1; i++) {
    if (p >= kfs[i].t && p <= kfs[i + 1].t) {
      seg = i;
      break;
    }
  }
  const t0 = kfs[seg].t;
  const t1 = kfs[seg + 1].t;
  const span = Math.max(1e-6, t1 - t0);
  const u = (p - t0) / span;

  return {
    coxaSwing: interpolateChannel(kfs, seg, u, 'coxaSwing', mode),
    femurFlex: interpolateChannel(kfs, seg, u, 'femurFlex', mode),
    tibiaFlex: interpolateChannel(kfs, seg, u, 'tibiaFlex', mode),
    tarsusCurl: interpolateChannel(kfs, seg, u, 'tarsusCurl', mode),
    lift: Math.max(0, Math.min(1.08, interpolateChannel(kfs, seg, u, 'lift', mode))),
    reachScale: interpolateChannel(kfs, seg, u, 'reachScale', mode),
    bodyBob: interpolateChannel(kfs, seg, u, 'bodyBob', mode),
    bodySway: interpolateChannel(kfs, seg, u, 'bodySway', mode),
    headNod: interpolateChannel(kfs, seg, u, 'headNod', mode),
  };
}

export function blendEvaluatedPoses(
  a: EvaluatedPose,
  b: EvaluatedPose,
  alpha: number
): EvaluatedPose {
  const w = cubicBezierEase(alpha);
  const iw = 1 - w;
  return {
    coxaSwing: a.coxaSwing * iw + b.coxaSwing * w,
    femurFlex: a.femurFlex * iw + b.femurFlex * w,
    tibiaFlex: a.tibiaFlex * iw + b.tibiaFlex * w,
    tarsusCurl: a.tarsusCurl * iw + b.tarsusCurl * w,
    lift: a.lift * iw + b.lift * w,
    reachScale: a.reachScale * iw + b.reachScale * w,
    bodyBob: a.bodyBob * iw + b.bodyBob * w,
    bodySway: a.bodySway * iw + b.bodySway * w,
    headNod: a.headNod * iw + b.headNod * w,
  };
}

/**
 * Computes the exact phase for one of the 20 legs using a creeping metachronal
 * wave from rear (0) to front (9) and alternating contralateral balance.
 */
export function computeLegPhase(
  clip: GaitClip,
  legIndex: number,
  side: 'L' | 'R',
  cyclePhase: number
): number {
  const waveOffset = (9 - legIndex) * clip.waveStep;
  const sidePhase = side === 'R' ? clip.sideOffset : 0;
  // Tiny organic jitter so opposite sides feel terrifyingly biological rather than robotic
  const organicJitter = Math.sin(legIndex * 1.9 + (side === 'R' ? 2.1 : 0)) * 0.025;
  return wrapPhase(cyclePhase + waveOffset + sidePhase + organicJitter);
}

/**
 * Evaluates a single leg's articulated joint rotations & ground-contact telemetry.
 */
export function evaluateLegPose(
  clip: GaitClip,
  legIndex: number,
  side: 'L' | 'R',
  cyclePhase: number,
  mode: InterpolationMode,
  turnBias = 0,
  blendTarget?: { clip: GaitClip; alpha: number }
): LegJointPose {
  const localPhase = computeLegPhase(clip, legIndex, side, cyclePhase);
  let pose = sampleClip(clip, localPhase, mode);
  let swingRad = clip.maxSwingRad;

  if (blendTarget && blendTarget.alpha > 0 && blendTarget.alpha < 1) {
    const targetPhase = computeLegPhase(blendTarget.clip, legIndex, side, cyclePhase);
    const targetPose = sampleClip(blendTarget.clip, targetPhase, mode);
    pose = blendEvaluatedPoses(pose, targetPose, blendTarget.alpha);
    const w = cubicBezierEase(blendTarget.alpha);
    swingRad = clip.maxSwingRad * (1 - w) + blendTarget.clip.maxSwingRad * w;
  } else if (blendTarget && blendTarget.alpha >= 1) {
    const targetPhase = computeLegPhase(blendTarget.clip, legIndex, side, cyclePhase);
    pose = sampleClip(blendTarget.clip, targetPhase, mode);
    swingRad = blendTarget.clip.maxSwingRad;
  }

  // Differential steering bias when turning in Free Roam:
  // outer flank lengthens stride, inner flank tightens stride.
  const turnSign = side === 'L' ? 1 : -1;
  const turnGain = Math.max(0.45, Math.min(1.45, 1 + turnBias * turnSign * 0.35));

  // Anatomical position scaling along flank (middle legs sweep wide, front/rear anchor)
  const midBell = 1.0 - Math.abs(legIndex - 4.5) * 0.035;
  const sideSign = side === 'L' ? -1 : 1;

  // In source sprite coords (+Y = forward head):
  // Left legs (-X) rotate negative (CCW) to swing forward (+Y).
  // Right legs (+X) rotate positive (CW) to swing forward (+Y).
  const coxaAngle = sideSign * pose.coxaSwing * swingRad * midBell * turnGain;

  // Joint flex curls inward/upward when lifted, extends outward when planting
  const j1 = -sideSign * pose.femurFlex * 0.95;
  const j2 = -sideSign * pose.tibiaFlex * 0.9;
  const j3 = -sideSign * pose.tarsusCurl * 0.85;

  const lift = Math.max(0, Math.min(1, pose.lift));
  const isGrounded = lift < 0.14;

  // Strike pulse peaks right after t=0 (when tip stabs into earth)
  const distFromStrike = Math.min(localPhase, 1 - localPhase);
  const strikePulse =
    clip.baseSpeedPx > 0 ? Math.max(0, 1 - distFromStrike / 0.075) : 0;

  return {
    coxaAngle,
    jointAngles: [j1, j2, j3],
    lift,
    reachScale: pose.reachScale,
    isGrounded,
    strikePulse,
    legPhase: localPhase,
  };
}

/**
 * Evaluates central sheep body secondary motion (sway, heave, head tracking)
 * from the active clip and optional state transition crossfade.
 */
export function evaluateBodyPose(
  clip: GaitClip,
  cyclePhase: number,
  mode: InterpolationMode,
  turnBias = 0,
  blendTarget?: { clip: GaitClip; alpha: number }
): BodyPose {
  // Body sways at 2x leg stride frequency (left wave + right wave)
  const bodyPhase = wrapPhase(cyclePhase * 2);
  let pose = sampleClip(clip, bodyPhase, mode);
  let speed = clip.baseSpeedPx;

  if (blendTarget && blendTarget.alpha > 0) {
    const targetPose = sampleClip(blendTarget.clip, bodyPhase, mode);
    pose = blendEvaluatedPoses(pose, targetPose, blendTarget.alpha);
    const w = cubicBezierEase(blendTarget.alpha);
    speed = clip.baseSpeedPx * (1 - w) + blendTarget.clip.baseSpeedPx * w;
  }

  const speedFactor = Math.min(1, speed / 300);
  // Continuous sway sinusoid anchored to phase for smooth lateral rocking
  const swayWave = Math.sin(cyclePhase * Math.PI * 2) * 0.036 * (0.35 + speedFactor * 0.85);

  return {
    bobScale: 1 + pose.bodyBob,
    swayRad: swayWave + pose.bodySway * 0.012,
    surgePx: Math.cos(cyclePhase * Math.PI * 4) * 4.5 * speedFactor,
    headYawRad: Math.max(-0.24, Math.min(0.24, turnBias * 0.28 + Math.sin(cyclePhase * Math.PI * 2 + 0.6) * 0.045)),
    headNodScale: 1 + pose.headNod * 0.025,
    elevationPx: 54 + pose.bodyBob * 180,
  };
}
