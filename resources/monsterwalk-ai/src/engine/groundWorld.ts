export type LightingMode = 'tenebrism' | 'flashlight' | 'studio';

interface ScarMark {
  active: boolean;
  x: number;
  y: number;
  angle: number;
  age: number;
  maxAge: number;
}

interface DustMote {
  active: boolean;
  x: number;
  y: number;
  vx: number;
  vy: number;
  size: number;
  age: number;
  maxAge: number;
}

/**
 * Deterministic PRNG for procedural oil-canvas dirt & dead-grass ground texture.
 */
function mulberry32(seed: number) {
  return function () {
    let t = (seed += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export class PainterlyGroundWorld {
  private tileCanvas: HTMLCanvasElement;
  private tilePattern: CanvasPattern | null = null;
  private scars: ScarMark[];
  private scarCursor = 0;
  private dust: DustMote[];
  private dustCursor = 0;

  constructor(maxScars = 160, maxDust = 96) {
    this.tileCanvas = this.buildOilGroundTile(512);
    this.scars = Array.from({ length: maxScars }, () => ({
      active: false,
      x: 0,
      y: 0,
      angle: 0,
      age: 0,
      maxAge: 6,
    }));
    this.dust = Array.from({ length: maxDust }, () => ({
      active: false,
      x: 0,
      y: 0,
      vx: 0,
      vy: 0,
      size: 4,
      age: 0,
      maxAge: 0.7,
    }));
  }

  private buildOilGroundTile(size: number): HTMLCanvasElement {
    const canvas = document.createElement('canvas');
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext('2d')!;
    const rand = mulberry32(4177);

    // Base raw umber / charcoal earth
    ctx.fillStyle = '#14100d';
    ctx.fillRect(0, 0, size, size);

    // Broad muted oil-paint mud & moss washes (wrapped on edges for seamless tiling)
    for (let i = 0; i < 160; i++) {
      const x = rand() * size;
      const y = rand() * size;
      const rx = 28 + rand() * 75;
      const ry = 14 + rand() * 42;
      const rot = rand() * Math.PI;
      const palette = [
        'rgba(33, 26, 20, 0.34)',
        'rgba(24, 19, 15, 0.42)',
        'rgba(44, 38, 24, 0.22)',
        'rgba(14, 11, 9, 0.45)',
      ];
      const color = palette[Math.floor(rand() * palette.length)];

      for (const ox of [-size, 0, size]) {
        for (const oy of [-size, 0, size]) {
          if (
            x + ox + rx < 0 ||
            x + ox - rx > size ||
            y + oy + ry < 0 ||
            y + oy - ry > size
          ) {
            continue;
          }
          ctx.save();
          ctx.translate(x + ox, y + oy);
          ctx.rotate(rot);
          ctx.fillStyle = color;
          ctx.beginPath();
          ctx.ellipse(0, 0, rx, ry, 0, 0, Math.PI * 2);
          ctx.fill();
          ctx.restore();
        }
      }
    }

    // Muted impasto dead grass blades & earthy grit strokes
    ctx.lineCap = 'round';
    for (let i = 0; i < 380; i++) {
      const x = rand() * size;
      const y = rand() * size;
      const len = 8 + rand() * 20;
      const ang = (rand() - 0.5) * 1.4 - Math.PI / 2;
      const isGrass = rand() > 0.35;
      ctx.strokeStyle = isGrass
        ? `rgba(${56 + Math.floor(rand() * 22)}, ${52 + Math.floor(rand() * 18)}, ${32 + Math.floor(rand() * 14)}, ${0.14 + rand() * 0.16})`
        : `rgba(12, 9, 7, ${0.28 + rand() * 0.25})`;
      ctx.lineWidth = 1.2 + rand() * 2.2;

      for (const ox of [-size, 0, size]) {
        for (const oy of [-size, 0, size]) {
          if (x + ox < -24 || x + ox > size + 24 || y + oy < -24 || y + oy > size + 24) {
            continue;
          }
          ctx.beginPath();
          ctx.moveTo(x + ox, y + oy);
          ctx.quadraticCurveTo(
            x + ox + Math.cos(ang + 0.2) * len * 0.5,
            y + oy + Math.sin(ang + 0.2) * len * 0.5,
            x + ox + Math.cos(ang) * len,
            y + oy + Math.sin(ang) * len
          );
          ctx.stroke();
        }
      }
    }

    return canvas;
  }

  public spawnFootprint(x: number, y: number, angle: number): void {
    const s = this.scars[this.scarCursor];
    s.active = true;
    s.x = x;
    s.y = y;
    s.angle = angle;
    s.age = 0;
    s.maxAge = 5.5;
    this.scarCursor = (this.scarCursor + 1) % this.scars.length;

    // 2 small dust motes at sharp leg tip impact
    for (let k = 0; k < 2; k++) {
      const d = this.dust[this.dustCursor];
      const jitter = (k === 0 ? -1 : 1) * 0.8 + (Math.random() - 0.5) * 0.7;
      const spd = 18 + Math.random() * 26;
      d.active = true;
      d.x = x;
      d.y = y;
      d.vx = Math.cos(angle + jitter) * spd;
      d.vy = Math.sin(angle + jitter) * spd;
      d.size = 3 + Math.random() * 5;
      d.age = 0;
      d.maxAge = 0.45 + Math.random() * 0.35;
      this.dustCursor = (this.dustCursor + 1) % this.dust.length;
    }
  }

  public update(dt: number, scrollDx = 0, scrollDy = 0): void {
    for (let i = 0; i < this.scars.length; i++) {
      const s = this.scars[i];
      if (!s.active) continue;
      s.x += scrollDx;
      s.y += scrollDy;
      s.age += dt;
      if (s.age >= s.maxAge) s.active = false;
    }
    for (let i = 0; i < this.dust.length; i++) {
      const d = this.dust[i];
      if (!d.active) continue;
      d.x += d.vx * dt + scrollDx;
      d.y += d.vy * dt + scrollDy;
      d.vx *= 0.92;
      d.vy *= 0.92;
      d.age += dt;
      if (d.age >= d.maxAge) d.active = false;
    }
  }

  public renderGround(
    ctx: CanvasRenderingContext2D,
    viewW: number,
    viewH: number,
    offsetX: number,
    offsetY: number
  ): void {
    if (!this.tilePattern) {
      this.tilePattern = ctx.createPattern(this.tileCanvas, 'repeat');
    }

    ctx.save();
    if (this.tilePattern) {
      const wrapX = ((offsetX % 512) + 512) % 512;
      const wrapY = ((offsetY % 512) + 512) % 512;
      ctx.translate(wrapX - 512, wrapY - 512);
      ctx.fillStyle = this.tilePattern;
      ctx.fillRect(0, 0, viewW + 512, viewH + 512);
    } else {
      ctx.fillStyle = '#14100d';
      ctx.fillRect(0, 0, viewW, viewH);
    }
    ctx.restore();
  }

  /**
   * Renders piercing leg tip gouge scars and dirt dust puffs in world coordinates.
   */
  public renderContacts(
    ctx: CanvasRenderingContext2D,
    cameraX: number,
    cameraY: number
  ): void {
    ctx.save();
    ctx.translate(-cameraX, -cameraY);

    for (let i = 0; i < this.scars.length; i++) {
      const s = this.scars[i];
      if (!s.active) continue;
      const alpha = (1 - s.age / s.maxAge) * 0.55;
      ctx.save();
      ctx.translate(s.x, s.y);
      ctx.rotate(s.angle);
      ctx.fillStyle = `rgba(6, 4, 3, ${alpha.toFixed(3)})`;
      ctx.beginPath();
      ctx.ellipse(0, 0, 5.5, 2.8, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = `rgba(72, 58, 42, ${(alpha * 0.45).toFixed(3)})`;
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.ellipse(0, 0, 6.5, 3.6, 0, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    }

    for (let i = 0; i < this.dust.length; i++) {
      const d = this.dust[i];
      if (!d.active) continue;
      const t = d.age / d.maxAge;
      const alpha = (1 - t) * 0.28;
      ctx.fillStyle = `rgba(116, 102, 78, ${alpha.toFixed(3)})`;
      ctx.beginPath();
      ctx.arc(d.x, d.y, d.size * (0.7 + t * 1.4), 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.restore();
  }

  private cachedVignetteMode: LightingMode | null = null;
  private cachedVignetteW = 0;
  private cachedVignetteH = 0;
  private cachedVignetteX = 0;
  private cachedVignetteY = 0;
  private vignetteCanvas: HTMLCanvasElement | null = null;

  /**
   * Applies chiaroscuro tenebrism or Hide-in-Sheep-Clothing Sheepherder flashlight cone
   * over the rendered scene.
   */
  public renderLightingOverlay(
    ctx: CanvasRenderingContext2D,
    viewW: number,
    viewH: number,
    mode: LightingMode,
    creatureScreenX: number,
    creatureScreenY: number,
    flashlightOriginX: number,
    flashlightOriginY: number,
    flashlightAngle: number
  ): void {
    if (mode === 'studio' || mode === 'tenebrism') {
      const cx = mode === 'studio' ? Math.round(viewW * 0.5) : Math.round(creatureScreenX);
      const cy = mode === 'studio' ? Math.round(viewH * 0.5) : Math.round(creatureScreenY);
      const needsRebuild =
        !this.vignetteCanvas ||
        this.cachedVignetteMode !== mode ||
        this.cachedVignetteW !== viewW ||
        this.cachedVignetteH !== viewH ||
        Math.abs(this.cachedVignetteX - cx) > 6 ||
        Math.abs(this.cachedVignetteY - cy) > 6;

      if (needsRebuild) {
        if (!this.vignetteCanvas) {
          this.vignetteCanvas = document.createElement('canvas');
        }
        this.vignetteCanvas.width = Math.max(1, viewW);
        this.vignetteCanvas.height = Math.max(1, viewH);
        const vctx = this.vignetteCanvas.getContext('2d')!;
        vctx.clearRect(0, 0, viewW, viewH);

        if (mode === 'studio') {
          const grad = vctx.createRadialGradient(
            cx,
            cy,
            Math.min(viewW, viewH) * 0.34,
            cx,
            cy,
            Math.max(viewW, viewH) * 0.72
          );
          grad.addColorStop(0, 'rgba(0, 0, 0, 0)');
          grad.addColorStop(1, 'rgba(7, 5, 4, 0.55)');
          vctx.fillStyle = grad;
          vctx.fillRect(0, 0, viewW, viewH);
        } else {
          const radius = Math.max(360, Math.min(viewW, viewH) * 0.56);
          const grad = vctx.createRadialGradient(
            cx,
            cy,
            radius * 0.16,
            cx,
            cy,
            radius
          );
          grad.addColorStop(0, 'rgba(255, 240, 200, 0.05)');
          grad.addColorStop(0.42, 'rgba(10, 8, 6, 0.25)');
          grad.addColorStop(0.78, 'rgba(6, 5, 4, 0.80)');
          grad.addColorStop(1, 'rgba(4, 3, 2, 0.94)');
          vctx.fillStyle = grad;
          vctx.fillRect(0, 0, viewW, viewH);
        }

        this.cachedVignetteMode = mode;
        this.cachedVignetteW = viewW;
        this.cachedVignetteH = viewH;
        this.cachedVignetteX = cx;
        this.cachedVignetteY = cy;
      }

      ctx.drawImage(this.vignetteCanvas!, 0, 0);
      return;
    }

    // Flashlight mode: 60° Sheepherder cone sweeping across dark field
    ctx.save();
    const coneHalf = (34 * Math.PI) / 180;
    const coneLen = Math.max(viewW, viewH) * 0.85;

    ctx.beginPath();
    ctx.rect(0, 0, viewW, viewH);
    ctx.moveTo(flashlightOriginX, flashlightOriginY);
    ctx.arc(
      flashlightOriginX,
      flashlightOriginY,
      coneLen,
      flashlightAngle - coneHalf,
      flashlightAngle + coneHalf
    );
    ctx.closePath();
    ctx.fillStyle = 'rgba(4, 3, 2, 0.88)';
    ctx.fill('evenodd');

    const beamGrad = ctx.createRadialGradient(
      flashlightOriginX,
      flashlightOriginY,
      20,
      flashlightOriginX,
      flashlightOriginY,
      coneLen
    );
    beamGrad.addColorStop(0, 'rgba(246, 224, 172, 0.14)');
    beamGrad.addColorStop(0.5, 'rgba(220, 190, 130, 0.05)');
    beamGrad.addColorStop(1, 'rgba(4, 3, 2, 0.85)');

    ctx.beginPath();
    ctx.moveTo(flashlightOriginX, flashlightOriginY);
    ctx.arc(
      flashlightOriginX,
      flashlightOriginY,
      coneLen,
      flashlightAngle - coneHalf,
      flashlightAngle + coneHalf
    );
    ctx.closePath();
    ctx.fillStyle = beamGrad;
    ctx.fill();
    ctx.restore();
  }
}
