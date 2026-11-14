export interface Vec2 {
  x: number;
  y: number;
}

export type Side = 'L' | 'R';

export interface LegRigSpec {
  id: string;
  side: Side;
  /** 0 = rear-most (near sheep rump), 9 = front-most (near sheep head) */
  index: number;
  /** Polyline in 1024x1024 source image coordinates: [root, ...joints, tip] */
  points: Vec2[];
  /** Approximate half-width of the leg in source pixels for segmentation weighting */
  width: number;
  /** Natural swing amplitude multiplier for this leg's anatomical position */
  swingGain: number;
  /** Natural curl bias for outer joints */
  flexGain: number;
}

export const SOURCE_IMAGE_SIZE = 1024;
export const BODY_CENTER: Vec2 = { x: 512, y: 486 };
export const HEAD_PIVOT: Vec2 = { x: 512, y: 690 };

/**
 * Calibrated 20-leg skeletal coordinates measured directly from
 * /public/assets/aistudio/image_e3dec876.png (1024x1024).
 * Sheep faces +Y (downward in source image: rump at y~270, snout at y~885).
 */
export const GSM_LEG_SPECS: LegRigSpec[] = [
  // ================= LEFT FLANK (Rear 0 -> Front 9) =================
  {
    id: 'L0',
    side: 'L',
    index: 0,
    points: [
      { x: 424, y: 295 },
      { x: 416, y: 170 },
      { x: 244, y: 96 },
      { x: 215, y: 162 },
      { x: 202, y: 206 },
    ],
    width: 22,
    swingGain: 0.78,
    flexGain: 0.85,
  },
  {
    id: 'L1',
    side: 'L',
    index: 1,
    points: [
      { x: 408, y: 318 },
      { x: 356, y: 224 },
      { x: 274, y: 178 },
      { x: 152, y: 204 },
      { x: 74, y: 342 },
    ],
    width: 24,
    swingGain: 0.92,
    flexGain: 0.95,
  },
  {
    id: 'L2',
    side: 'L',
    index: 2,
    points: [
      { x: 398, y: 344 },
      { x: 328, y: 282 },
      { x: 256, y: 244 },
      { x: 152, y: 274 },
      { x: 56, y: 404 },
    ],
    width: 23,
    swingGain: 0.96,
    flexGain: 1.0,
  },
  {
    id: 'L3',
    side: 'L',
    index: 3,
    points: [
      { x: 392, y: 376 },
      { x: 294, y: 321 },
      { x: 178, y: 348 },
      { x: 95, y: 454 },
      { x: 34, y: 586 },
    ],
    width: 24,
    swingGain: 1.0,
    flexGain: 1.05,
  },
  {
    id: 'L4',
    side: 'L',
    index: 4,
    points: [
      { x: 388, y: 412 },
      { x: 265, y: 370 },
      { x: 170, y: 412 },
      { x: 126, y: 440 },
      { x: 102, y: 456 },
    ],
    width: 21,
    swingGain: 0.96,
    flexGain: 0.95,
  },
  {
    id: 'L5',
    side: 'L',
    index: 5,
    points: [
      { x: 388, y: 448 },
      { x: 247, y: 428 },
      { x: 164, y: 486 },
      { x: 84, y: 574 },
      { x: 44, y: 678 },
    ],
    width: 23,
    swingGain: 1.06,
    flexGain: 1.05,
  },
  {
    id: 'L6',
    side: 'L',
    index: 6,
    points: [
      { x: 390, y: 488 },
      { x: 242, y: 489 },
      { x: 164, y: 557 },
      { x: 88, y: 652 },
      { x: 56, y: 760 },
    ],
    width: 23,
    swingGain: 1.05,
    flexGain: 1.0,
  },
  {
    id: 'L7',
    side: 'L',
    index: 7,
    points: [
      { x: 395, y: 528 },
      { x: 252, y: 554 },
      { x: 166, y: 636 },
      { x: 99, y: 738 },
      { x: 80, y: 862 },
    ],
    width: 23,
    swingGain: 1.02,
    flexGain: 1.0,
  },
  {
    id: 'L8',
    side: 'L',
    index: 8,
    points: [
      { x: 404, y: 574 },
      { x: 294, y: 639 },
      { x: 196, y: 706 },
      { x: 166, y: 778 },
      { x: 282, y: 862 },
    ],
    width: 23,
    swingGain: 0.96,
    flexGain: 0.95,
  },
  {
    id: 'L9',
    side: 'L',
    index: 9,
    points: [
      { x: 416, y: 626 },
      { x: 346, y: 693 },
      { x: 294, y: 774 },
      { x: 365, y: 888 },
      { x: 452, y: 958 },
    ],
    width: 23,
    swingGain: 0.88,
    flexGain: 0.9,
  },

  // ================= RIGHT FLANK (Rear 0 -> Front 9) =================
  {
    id: 'R0',
    side: 'R',
    index: 0,
    points: [
      { x: 604, y: 295 },
      { x: 610, y: 170 },
      { x: 780, y: 98 },
      { x: 808, y: 162 },
      { x: 820, y: 206 },
    ],
    width: 22,
    swingGain: 0.78,
    flexGain: 0.85,
  },
  {
    id: 'R1',
    side: 'R',
    index: 1,
    points: [
      { x: 620, y: 318 },
      { x: 668, y: 224 },
      { x: 752, y: 178 },
      { x: 874, y: 204 },
      { x: 950, y: 342 },
    ],
    width: 24,
    swingGain: 0.92,
    flexGain: 0.95,
  },
  {
    id: 'R2',
    side: 'R',
    index: 2,
    points: [
      { x: 630, y: 344 },
      { x: 703, y: 286 },
      { x: 776, y: 244 },
      { x: 876, y: 274 },
      { x: 968, y: 404 },
    ],
    width: 23,
    swingGain: 0.96,
    flexGain: 1.0,
  },
  {
    id: 'R3',
    side: 'R',
    index: 3,
    points: [
      { x: 636, y: 376 },
      { x: 733, y: 325 },
      { x: 848, y: 350 },
      { x: 932, y: 452 },
      { x: 984, y: 583 },
    ],
    width: 24,
    swingGain: 1.0,
    flexGain: 1.05,
  },
  {
    id: 'R4',
    side: 'R',
    index: 4,
    points: [
      { x: 638, y: 412 },
      { x: 761, y: 375 },
      { x: 860, y: 417 },
      { x: 898, y: 440 },
      { x: 922, y: 454 },
    ],
    width: 21,
    swingGain: 0.96,
    flexGain: 0.95,
  },
  {
    id: 'R5',
    side: 'R',
    index: 5,
    points: [
      { x: 638, y: 448 },
      { x: 777, y: 428 },
      { x: 859, y: 479 },
      { x: 944, y: 566 },
      { x: 982, y: 672 },
    ],
    width: 23,
    swingGain: 1.06,
    flexGain: 1.05,
  },
  {
    id: 'R6',
    side: 'R',
    index: 6,
    points: [
      { x: 636, y: 488 },
      { x: 781, y: 499 },
      { x: 857, y: 554 },
      { x: 937, y: 628 },
      { x: 976, y: 732 },
    ],
    width: 23,
    swingGain: 1.05,
    flexGain: 1.0,
  },
  {
    id: 'R7',
    side: 'R',
    index: 7,
    points: [
      { x: 630, y: 528 },
      { x: 770, y: 559 },
      { x: 864, y: 634 },
      { x: 934, y: 730 },
      { x: 948, y: 856 },
    ],
    width: 23,
    swingGain: 1.02,
    flexGain: 1.0,
  },
  {
    id: 'R8',
    side: 'R',
    index: 8,
    points: [
      { x: 620, y: 574 },
      { x: 728, y: 642 },
      { x: 822, y: 706 },
      { x: 866, y: 776 },
      { x: 742, y: 862 },
    ],
    width: 23,
    swingGain: 0.96,
    flexGain: 0.95,
  },
  {
    id: 'R9',
    side: 'R',
    index: 9,
    points: [
      { x: 608, y: 626 },
      { x: 678, y: 693 },
      { x: 730, y: 780 },
      { x: 671, y: 888 },
      { x: 584, y: 958 },
    ],
    width: 23,
    swingGain: 0.88,
    flexGain: 0.9,
  },
];

/**
 * Checks whether a 1024x1024 source pixel lies inside the central sheep torso/head mask.
 * Returns normalized signed depth: < 0 inside body, > 0 outside body.
 */
export function bodySignedDistance(x: number, y: number): number {
  // Upper/mid wool torso ellipse (covers top rump wool y~248 to shoulder y~684)
  const tx = (x - 512) / 110;
  const ty = (y - 466) / 220;
  const torsoDist = Math.hypot(tx, ty) - 1.0;

  // Neck & sheep head tapered capsule from y=625 to y=892
  if (y > 625 && y < 898) {
    const t = Math.max(0, Math.min(1, (y - 625) / 262));
    // Ears flare out around t=0.45..0.58 (y~745..780)
    const earFlare = Math.exp(-Math.pow((t - 0.52) / 0.11, 2)) * 48;
    const halfW = 92 * (1 - t * 0.70) + earFlare;
    const headDist = (Math.abs(x - 512) - halfW) / 60;
    return Math.min(torsoDist, headDist);
  }
  return torsoDist;
}

export function distToSegmentSq(
  px: number,
  py: number,
  ax: number,
  ay: number,
  bx: number,
  by: number
): { distSq: number; t: number } {
  const vx = bx - ax;
  const vy = by - ay;
  const lenSq = vx * vx + vy * vy;
  if (lenSq < 1e-6) {
    const dx = px - ax;
    const dy = py - ay;
    return { distSq: dx * dx + dy * dy, t: 0 };
  }
  let t = ((px - ax) * vx + (py - ay) * vy) / lenSq;
  if (t < 0) t = 0;
  else if (t > 1) t = 1;
  const cx = ax + t * vx;
  const cy = ay + t * vy;
  const dx = px - cx;
  const dy = py - cy;
  return { distSq: dx * dx + dy * dy, t };
}

export interface PixelRigAssignment {
  legIndex: number;
  segmentIndex: number;
  dist: number;
}

const LEG_PADDED_BOUNDS = GSM_LEG_SPECS.map((leg) => {
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  for (const pt of leg.points) {
    if (pt.x < minX) minX = pt.x;
    if (pt.y < minY) minY = pt.y;
    if (pt.x > maxX) maxX = pt.x;
    if (pt.y > maxY) maxY = pt.y;
  }
  const pad = 54;
  return {
    minX: minX - pad,
    minY: minY - pad,
    maxX: maxX + pad,
    maxY: maxY + pad,
  };
});

/**
 * Classifies a non-torso pixel (x, y) to its closest leg and bone segment
 * in GSM_LEG_SPECS.
 */
export function assignPixelToLeg(x: number, y: number): PixelRigAssignment {
  let bestLeg = 0;
  let bestSeg = 0;
  let bestScore = Infinity;

  for (let l = 0; l < GSM_LEG_SPECS.length; l++) {
    const leg = GSM_LEG_SPECS[l];
    if (leg.side === 'L' && x > 528) continue;
    if (leg.side === 'R' && x < 496) continue;

    const bb = LEG_PADDED_BOUNDS[l];
    if (x < bb.minX || x > bb.maxX || y < bb.minY || y > bb.maxY) continue;

    const pts = leg.points;
    // Slight foreground bias for L1/R1 over L0/R0 and L3/R3 over L4/R4 at overlap joints
    const depthBiasSq = leg.index === 0 || leg.index === 4 ? 196 : 0;
    for (let s = 0; s < pts.length - 1; s++) {
      const { distSq } = distToSegmentSq(
        x,
        y,
        pts[s].x,
        pts[s].y,
        pts[s + 1].x,
        pts[s + 1].y
      );
      const weighted = distSq + depthBiasSq;
      if (weighted < bestScore) {
        bestScore = weighted;
        bestLeg = l;
        bestSeg = s;
      }
    }
  }

  // Fallback pass without bbox prune only if pixel lay outside all padded boxes
  if (bestScore === Infinity) {
    for (let l = 0; l < GSM_LEG_SPECS.length; l++) {
      const leg = GSM_LEG_SPECS[l];
      if (leg.side === 'L' && x > 528) continue;
      if (leg.side === 'R' && x < 496) continue;
      const pts = leg.points;
      for (let s = 0; s < pts.length - 1; s++) {
        const { distSq } = distToSegmentSq(
          x,
          y,
          pts[s].x,
          pts[s].y,
          pts[s + 1].x,
          pts[s + 1].y
        );
        if (distSq < bestScore) {
          bestScore = distSq;
          bestLeg = l;
          bestSeg = s;
        }
      }
    }
  }

  return { legIndex: bestLeg, segmentIndex: bestSeg, dist: Math.sqrt(bestScore) };
}
