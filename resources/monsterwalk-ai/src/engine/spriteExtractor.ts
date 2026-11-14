import {
  BODY_CENTER,
  GSM_LEG_SPECS,
  HEAD_PIVOT,
  LegRigSpec,
  SOURCE_IMAGE_SIZE,
  Vec2,
  assignPixelToLeg,
  bodySignedDistance,
  distToSegmentSq,
} from './gsmRig';
import { BodyPose, LegJointPose } from './keyframes';

export interface AtlasSpriteFrame {
  sx: number;
  sy: number;
  w: number;
  h: number;
  pivotX: number;
  pivotY: number;
}

export interface ExtractedLeg {
  spec: LegRigSpec;
  /** Atlas sprite frames for [root->j1, j1->j2, ...] */
  segments: AtlasSpriteFrame[];
  /** Local bone vector from segment start joint to end joint */
  boneVectors: Vec2[];
}

export interface ExtractedGsmRig {
  sourceSize: number;
  atlas: HTMLCanvasElement;
  torso: AtlasSpriteFrame;
  head: AtlasSpriteFrame;
  bodyShadow: AtlasSpriteFrame;
  legs: ExtractedLeg[];
}

interface PendingSprite {
  imageData: ImageData;
  w: number;
  h: number;
  pivotX: number;
  pivotY: number;
  assign: (frame: AtlasSpriteFrame) => void;
}

function createCanvas(w: number, h: number): HTMLCanvasElement {
  const c = document.createElement('canvas');
  c.width = Math.max(1, Math.ceil(w));
  c.height = Math.max(1, Math.ceil(h));
  return c;
}

/**
 * Strips #FF00FF chroma-key background with anti-aliased magenta spill suppression
 * so glossy black spider legs have clean dark edges against low-key horror scenes.
 */
function chromaKeyPixel(
  r: number,
  g: number,
  b: number,
  a: number
): [number, number, number, number] {
  if (a === 0) return [0, 0, 0, 0];

  const rbMin = Math.min(r, b);
  const magentaExcess = rbMin - g;

  if (r > 180 && b > 180 && g < 95 && magentaExcess > 72) {
    return [0, 0, 0, 0];
  }

  let outR = r;
  let outG = g;
  let outB = b;
  let outA = a;

  if (magentaExcess > 14 && r > g && b > g) {
    const t = Math.max(0, Math.min(1, (magentaExcess - 14) / 64));
    outA = Math.round(a * (1 - t));
    const neutralCap = g + 14;
    outR = Math.min(outR, Math.round(outR * (1 - t) + neutralCap * t));
    outB = Math.min(outB, Math.round(outB * (1 - t) + neutralCap * t));
  }

  return [outR, outG, outB, outA];
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error(`Failed to load creature image: ${src}`));
    img.src = src;
  });
}

function buildMaskedImageData(
  rgba: Uint8ClampedArray,
  size: number,
  minX: number,
  minY: number,
  maxX: number,
  maxY: number,
  pivotX: number,
  pivotY: number,
  alphaMask: Float32Array | null,
  maskMinX = 0,
  maskMinY = 0,
  maskW = 0
): { imageData: ImageData; w: number; h: number; pivotX: number; pivotY: number } {
  const x0 = Math.max(0, Math.floor(minX));
  const y0 = Math.max(0, Math.floor(minY));
  const x1 = Math.min(size - 1, Math.ceil(maxX));
  const y1 = Math.min(size - 1, Math.ceil(maxY));
  const w = Math.max(1, x1 - x0 + 1);
  const h = Math.max(1, y1 - y0 + 1);

  const imageData = new ImageData(w, h);
  const dst = imageData.data;

  for (let y = 0; y < h; y++) {
    const sy = y0 + y;
    for (let x = 0; x < w; x++) {
      const sx = x0 + x;
      const si = (sy * size + sx) * 4;
      const di = (y * w + x) * 4;
      const srcA = rgba[si + 3];
      if (srcA === 0) continue;

      let maskFactor = 1;
      if (alphaMask) {
        const mx = sx - maskMinX;
        const my = sy - maskMinY;
        if (mx < 0 || my < 0 || mx >= maskW) {
          maskFactor = 0;
        } else {
          const mIdx = my * maskW + mx;
          maskFactor = mIdx >= 0 && mIdx < alphaMask.length ? alphaMask[mIdx] : 0;
        }
      }
      if (maskFactor <= 0.004) continue;

      dst[di] = rgba[si];
      dst[di + 1] = rgba[si + 1];
      dst[di + 2] = rgba[si + 2];
      dst[di + 3] = Math.round(srcA * maskFactor);
    }
  }

  return {
    imageData,
    w,
    h,
    pivotX: pivotX - x0,
    pivotY: pivotY - y0,
  };
}

/**
 * Extracts chroma-keyed torso, independent head layer, and 20 articulated multi-bone
 * painted leg rigs into ONE packed sprite atlas for fast single-texture Canvas2D rendering.
 */
export async function extractGsmRig(
  imageSrc = '/assets/aistudio/image_e3dec876.png'
): Promise<ExtractedGsmRig> {
  const img = await loadImage(imageSrc);
  const size = SOURCE_IMAGE_SIZE;

  const srcCanvas = createCanvas(size, size);
  const srcCtx = srcCanvas.getContext('2d', { willReadFrequently: true })!;
  srcCtx.drawImage(img, 0, 0, size, size);
  const imgData = srcCtx.getImageData(0, 0, size, size);
  const raw = imgData.data;

  // Step 1: Chroma-key entire 1024x1024 image once
  const clean = new Uint8ClampedArray(raw.length);
  for (let i = 0; i < raw.length; i += 4) {
    const [r, g, b, a] = chromaKeyPixel(raw[i], raw[i + 1], raw[i + 2], raw[i + 3]);
    clean[i] = r;
    clean[i + 1] = g;
    clean[i + 2] = b;
    clean[i + 3] = a;
  }

  // Step 2: Classify non-background pixels to nearest leg
  const pixelLeg = new Int16Array(size * size).fill(-1);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const idx = y * size + x;
      if (clean[idx * 4 + 3] === 0) continue;
      if (bodySignedDistance(x, y) < -0.06) continue;
      pixelLeg[idx] = assignPixelToLeg(x, y).legIndex;
    }
  }

  const pending: PendingSprite[] = [];
  let torsoFrame!: AtlasSpriteFrame;
  let headFrame!: AtlasSpriteFrame;
  let bodyShadowFrame!: AtlasSpriteFrame;

  // Step 3: Torso
  const torsoBounds = { minX: 375, minY: 235, maxX: 650, maxY: 715 };
  const tW = torsoBounds.maxX - torsoBounds.minX + 1;
  const tH = torsoBounds.maxY - torsoBounds.minY + 1;
  const torsoMask = new Float32Array(tW * tH);
  for (let y = torsoBounds.minY; y <= torsoBounds.maxY; y++) {
    for (let x = torsoBounds.minX; x <= torsoBounds.maxX; x++) {
      const sdf = bodySignedDistance(x, y);
      let alpha = 1 - Math.max(0, Math.min(1, (sdf + 0.03) / 0.08));
      if (y > 672) {
        alpha *= Math.max(0, 1 - (y - 672) / 36);
      }
      torsoMask[(y - torsoBounds.minY) * tW + (x - torsoBounds.minX)] = alpha;
    }
  }
  const torsoCrop = buildMaskedImageData(
    clean,
    size,
    torsoBounds.minX,
    torsoBounds.minY,
    torsoBounds.maxX,
    torsoBounds.maxY,
    BODY_CENTER.x,
    BODY_CENTER.y,
    torsoMask,
    torsoBounds.minX,
    torsoBounds.minY,
    tW
  );
  pending.push({
    ...torsoCrop,
    assign: (f) => {
      torsoFrame = f;
    },
  });

  // Step 4: Head Layer
  const headBounds = { minX: 390, minY: 660, maxX: 634, maxY: 902 };
  const hW = headBounds.maxX - headBounds.minX + 1;
  const hH = headBounds.maxY - headBounds.minY + 1;
  const headMask = new Float32Array(hW * hH);
  for (let y = headBounds.minY; y <= headBounds.maxY; y++) {
    for (let x = headBounds.minX; x <= headBounds.maxX; x++) {
      const sdf = bodySignedDistance(x, y);
      let alpha = 1 - Math.max(0, Math.min(1, (sdf + 0.02) / 0.08));
      if (y < 698) {
        alpha *= Math.max(0, (y - 660) / 38);
      }
      headMask[(y - headBounds.minY) * hW + (x - headBounds.minX)] = alpha;
    }
  }
  const headCrop = buildMaskedImageData(
    clean,
    size,
    headBounds.minX,
    headBounds.minY,
    headBounds.maxX,
    headBounds.maxY,
    HEAD_PIVOT.x,
    HEAD_PIVOT.y,
    headMask,
    headBounds.minX,
    headBounds.minY,
    hW
  );
  pending.push({
    ...headCrop,
    assign: (f) => {
      headFrame = f;
    },
  });

  // Step 5: Pre-baked soft radial body shadow
  const bsCanvas = createCanvas(360, 540);
  const bsCtx = bsCanvas.getContext('2d')!;
  const bsGrad = bsCtx.createRadialGradient(180, 270, 24, 180, 270, 245);
  bsGrad.addColorStop(0, 'rgba(3, 2, 2, 0.72)');
  bsGrad.addColorStop(0.55, 'rgba(3, 2, 2, 0.36)');
  bsGrad.addColorStop(1, 'rgba(3, 2, 2, 0)');
  bsCtx.fillStyle = bsGrad;
  bsCtx.beginPath();
  bsCtx.ellipse(180, 270, 155, 255, 0, 0, Math.PI * 2);
  bsCtx.fill();
  pending.push({
    imageData: bsCtx.getImageData(0, 0, 360, 540),
    w: 360,
    h: 540,
    pivotX: 180,
    pivotY: 270,
    assign: (f) => {
      bodyShadowFrame = f;
    },
  });

  // Step 6: 20 multi-segment legs
  const jointCapOverlapPx = 15;
  const legs: ExtractedLeg[] = GSM_LEG_SPECS.map((spec, legIdx) => {
    const pts = spec.points;
    const segments: AtlasSpriteFrame[] = new Array(pts.length - 1);
    const boneVectors: Vec2[] = [];

    for (let s = 0; s < pts.length - 1; s++) {
      const a = pts[s];
      const b = pts[s + 1];
      boneVectors.push({ x: b.x - a.x, y: b.y - a.y });

      const pad = 42;
      const minX = Math.max(0, Math.floor(Math.min(a.x, b.x) - pad));
      const maxX = Math.min(size - 1, Math.ceil(Math.max(a.x, b.x) + pad));
      const minY = Math.max(0, Math.floor(Math.min(a.y, b.y) - pad));
      const maxY = Math.min(size - 1, Math.ceil(Math.max(a.y, b.y) + pad));
      const mW = maxX - minX + 1;
      const mH = maxY - minY + 1;
      const mask = new Float32Array(mW * mH);

      const segDx = b.x - a.x;
      const segDy = b.y - a.y;
      const segLen = Math.hypot(segDx, segDy) || 1;
      const ux = segDx / segLen;
      const uy = segDy / segLen;

      for (let y = minY; y <= maxY; y++) {
        for (let x = minX; x <= maxX; x++) {
          const idx = y * size + x;
          if (clean[idx * 4 + 3] === 0) continue;
          const assigned = pixelLeg[idx];
          if (assigned !== -1 && assigned !== legIdx) continue;
          if (bodySignedDistance(x, y) < -0.07) continue;

          const px = x - a.x;
          const py = y - a.y;
          const proj = px * ux + py * uy;

          const minProj = s === 0 ? -24 : -jointCapOverlapPx;
          const maxProj = s === pts.length - 2 ? segLen + 26 : segLen + jointCapOverlapPx;
          if (proj < minProj || proj > maxProj) continue;

          let capAlpha = 1.0;
          if (s > 0 && proj < 0) {
            capAlpha = Math.max(0, 1 + proj / jointCapOverlapPx);
          } else if (s < pts.length - 2 && proj > segLen) {
            capAlpha = Math.max(0, 1 - (proj - segLen) / jointCapOverlapPx);
          }

          const { distSq } = distToSegmentSq(x, y, a.x, a.y, b.x, b.y);
          if (distSq > 40 * 40) continue;

          mask[(y - minY) * mW + (x - minX)] = capAlpha;
        }
      }

      const crop = buildMaskedImageData(
        clean,
        size,
        minX,
        minY,
        maxX,
        maxY,
        a.x,
        a.y,
        mask,
        minX,
        minY,
        mW
      );
      const segIdx = s;
      pending.push({
        ...crop,
        assign: (f) => {
          segments[segIdx] = f;
        },
      });
    }

    return { spec, segments, boneVectors };
  });

  // Step 7: Shelf-pack all cropped sprites into a single 2048-wide atlas canvas
  const atlasW = 2048;
  const padGap = 2;
  let curX = padGap;
  let curY = padGap;
  let rowH = 0;
  const placed: { item: PendingSprite; sx: number; sy: number }[] = [];

  for (const item of pending) {
    if (curX + item.w + padGap > atlasW) {
      curX = padGap;
      curY += rowH + padGap;
      rowH = 0;
    }
    placed.push({ item, sx: curX, sy: curY });
    item.assign({
      sx: curX,
      sy: curY,
      w: item.w,
      h: item.h,
      pivotX: item.pivotX,
      pivotY: item.pivotY,
    });
    curX += item.w + padGap;
    if (item.h > rowH) rowH = item.h;
  }

  const atlasH = Math.max(1, curY + rowH + padGap);
  const atlas = createCanvas(atlasW, atlasH);
  const atlasCtx = atlas.getContext('2d')!;
  for (const p of placed) {
    atlasCtx.putImageData(p.item.imageData, p.sx, p.sy);
  }

  return {
    sourceSize: size,
    atlas,
    torso: torsoFrame,
    head: headFrame,
    bodyShadow: bodyShadowFrame,
    legs,
  };
}

export interface ComputedLegWorldTransform {
  legId: string;
  side: 'L' | 'R';
  joints: Vec2[];
  groundTip: Vec2;
  lift: number;
  isGrounded: boolean;
  strikePulse: number;
}

function rotateVec(x: number, y: number, rad: number): Vec2 {
  const c = Math.cos(rad);
  const s = Math.sin(rad);
  return { x: x * c - y * s, y: x * s + y * c };
}

export function computeLegKinematics(
  leg: ExtractedLeg,
  pose: LegJointPose,
  bodyPose: BodyPose
): {
  worldJoints: Vec2[];
  segmentAngles: number[];
  reachScale: number;
} {
  const root = leg.spec.points[0];
  const rootLocal = rotateVec(
    root.x - BODY_CENTER.x,
    root.y - BODY_CENTER.y,
    bodyPose.swayRad
  );

  const joints: Vec2[] = [
    {
      x: rootLocal.x * bodyPose.bobScale,
      y: rootLocal.y * bodyPose.bobScale + bodyPose.surgePx,
    },
  ];
  const segmentAngles: number[] = [];

  let cumAngle = pose.coxaAngle + bodyPose.swayRad;
  const liftForeshorten = pose.reachScale;

  for (let s = 0; s < leg.boneVectors.length; s++) {
    if (s > 0) {
      const jointFlex = pose.jointAngles[Math.min(s - 1, pose.jointAngles.length - 1)];
      cumAngle += jointFlex * leg.spec.flexGain;
    }
    segmentAngles.push(cumAngle);

    const bv = leg.boneVectors[s];
    const segScale = s === 0 ? 0.96 + 0.04 * liftForeshorten : liftForeshorten;
    const rotated = rotateVec(bv.x * segScale, bv.y * segScale, cumAngle);
    const prev = joints[joints.length - 1];
    joints.push({
      x: prev.x + rotated.x,
      y: prev.y + rotated.y,
    });
  }

  return { worldJoints: joints, segmentAngles, reachScale: liftForeshorten };
}

function drawAtlasFrame(
  ctx: CanvasRenderingContext2D,
  atlas: HTMLCanvasElement,
  f: AtlasSpriteFrame
) {
  ctx.drawImage(atlas, f.sx, f.sy, f.w, f.h, -f.pivotX, -f.pivotY, f.w, f.h);
}

/**
 * Renders the complete articulated GSM creature onto ctx at (0, 0) in local
 * sprite coordinates (1024-scale space, facing +Y) using a single sprite atlas.
 */
export function renderGsmCreature(
  ctx: CanvasRenderingContext2D,
  rig: ExtractedGsmRig,
  legPoses: LegJointPose[],
  bodyPose: BodyPose,
  options: {
    lightDir: Vec2;
    showRigOverlay: boolean;
  }
): ComputedLegWorldTransform[] {
  const computed: ComputedLegWorldTransform[] = [];

  const legKinematics = rig.legs.map((leg, i) => {
    const pose = legPoses[i];
    const kin = computeLegKinematics(leg, pose, bodyPose);
    const tip = kin.worldJoints[kin.worldJoints.length - 1];
    const elevationDrop = bodyPose.elevationPx * (1 - pose.lift * 0.55);
    const groundTip = {
      x: tip.x + options.lightDir.x * elevationDrop,
      y: tip.y + options.lightDir.y * elevationDrop,
    };
    computed.push({
      legId: leg.spec.id,
      side: leg.spec.side,
      joints: kin.worldJoints,
      groundTip,
      lift: pose.lift,
      isGrounded: pose.isGrounded,
      strikePulse: pose.strikePulse,
    });
    return { leg, pose, kin, groundTip };
  });

  // 1. Cast shadows far beneath the elevated creature
  ctx.save();
  const bodyShadowX = options.lightDir.x * bodyPose.elevationPx * 1.15;
  const bodyShadowY = options.lightDir.y * bodyPose.elevationPx * 1.15 + bodyPose.surgePx;
  ctx.save();
  ctx.translate(bodyShadowX, bodyShadowY + 18);
  ctx.rotate(bodyPose.swayRad);
  drawAtlasFrame(ctx, rig.atlas, rig.bodyShadow);
  ctx.restore();

  // Batched leg cast shadows (1 path per leg instead of per segment)
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  ctx.lineWidth = 14;
  ctx.strokeStyle = 'rgba(4, 3, 2, 0.44)';
  ctx.beginPath();
  for (const item of legKinematics) {
    const j = item.kin.worldJoints;
    for (let s = 0; s < j.length; s++) {
      const t = s / (j.length - 1);
      const off = bodyPose.elevationPx * (1.0 - t * (1 - item.pose.lift * 0.65));
      const sx = j[s].x + options.lightDir.x * off;
      const sy = j[s].y + options.lightDir.y * off;
      if (s === 0) ctx.moveTo(sx, sy);
      else ctx.lineTo(sx, sy);
    }
  }
  ctx.stroke();
  ctx.restore();

  // 2. Render all 20 articulated legs from single atlas
  const sortedLegs = [...legKinematics].sort((a, b) => {
    const liftDiff = a.pose.lift - b.pose.lift;
    if (Math.abs(liftDiff) > 0.08) return liftDiff;
    const aTucked = a.leg.spec.index === 0 || a.leg.spec.index === 4 ? 0 : 1;
    const bTucked = b.leg.spec.index === 0 || b.leg.spec.index === 4 ? 0 : 1;
    return aTucked - bTucked;
  });
  for (const item of sortedLegs) {
    const { leg, kin } = item;
    for (let s = 0; s < leg.segments.length; s++) {
      const seg = leg.segments[s];
      const joint = kin.worldJoints[s];
      const angle = kin.segmentAngles[s];
      const segScale = s === 0 ? 0.96 + 0.04 * kin.reachScale : kin.reachScale;

      ctx.save();
      ctx.translate(joint.x, joint.y);
      ctx.rotate(angle);
      ctx.scale(segScale, segScale);
      drawAtlasFrame(ctx, rig.atlas, seg);
      ctx.restore();
    }
  }

  // 3. Render hoisted Central Sheep Torso
  ctx.save();
  ctx.translate(0, bodyPose.surgePx);
  ctx.rotate(bodyPose.swayRad);
  ctx.scale(bodyPose.bobScale, bodyPose.bobScale);
  drawAtlasFrame(ctx, rig.atlas, rig.torso);
  ctx.restore();

  // 4. Render Sheep Head Layer
  ctx.save();
  const neckOffset = rotateVec(
    HEAD_PIVOT.x - BODY_CENTER.x,
    HEAD_PIVOT.y - BODY_CENTER.y,
    bodyPose.swayRad
  );
  ctx.translate(
    neckOffset.x * bodyPose.bobScale,
    neckOffset.y * bodyPose.bobScale + bodyPose.surgePx
  );
  ctx.rotate(bodyPose.swayRad * 0.7 + bodyPose.headYawRad);
  ctx.scale(bodyPose.bobScale, bodyPose.bobScale * bodyPose.headNodScale);
  drawAtlasFrame(ctx, rig.atlas, rig.head);
  ctx.restore();

  // 5. Optional Rig & Contact Overlay
  if (options.showRigOverlay) {
    ctx.save();
    for (const item of computed) {
      const pts = item.joints;
      ctx.strokeStyle = item.isGrounded
        ? 'rgba(197, 155, 76, 0.78)'
        : 'rgba(218, 78, 72, 0.88)';
      ctx.lineWidth = 2.4;
      ctx.beginPath();
      ctx.moveTo(pts[0].x, pts[0].y);
      for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y);
      ctx.stroke();

      for (let i = 0; i < pts.length - 1; i++) {
        ctx.fillStyle = i === 0 ? '#9e2a2b' : '#e6dfd1';
        ctx.beginPath();
        ctx.arc(pts[i].x, pts[i].y, i === 0 ? 5 : 3.5, 0, Math.PI * 2);
        ctx.fill();
      }

      const tip = pts[pts.length - 1];
      ctx.strokeStyle = item.isGrounded
        ? 'rgba(197, 155, 76, 0.95)'
        : 'rgba(230, 223, 209, 0.35)';
      ctx.lineWidth = item.isGrounded ? 2.5 : 1.2;
      ctx.beginPath();
      ctx.arc(tip.x, tip.y, item.isGrounded ? 10 + item.strikePulse * 6 : 6, 0, Math.PI * 2);
      ctx.stroke();
    }

    ctx.strokeStyle = 'rgba(230, 223, 209, 0.65)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(0, bodyPose.surgePx, 12, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }

  return computed;
}
