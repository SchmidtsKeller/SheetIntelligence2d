import React, { useEffect, useRef, useState } from 'react';
import {
  GAIT_CLIPS,
  GaitClipId,
  InterpolationMode,
  TransitionBlend,
  cubicBezierEase,
  evaluateBodyPose,
  evaluateLegPose,
  wrapPhase,
} from '../engine/keyframes';
import {
  ExtractedGsmRig,
  extractGsmRig,
  renderGsmCreature,
} from '../engine/spriteExtractor';
import { LightingMode, PainterlyGroundWorld } from '../engine/groundWorld';

export type LocomotionMode = 'treadmill' | 'roam';

export interface LiveTelemetry {
  phase: number;
  speedPx: number;
  groundedCount: number;
  liftedCount: number;
  activeTransition: string | null;
}

interface GsmCanvasStageProps {
  clipId: GaitClipId;
  interpMode: InterpolationMode;
  locomotionMode: LocomotionMode;
  lightingMode: LightingMode;
  isPlaying: boolean;
  speedMultiplier: number;
  creatureScale: number;
  showRigOverlay: boolean;
  scrubPhase: number | null;
  stepNonce: number;
  playheadRef: React.MutableRefObject<HTMLInputElement | null>;
  phaseReadoutRef: React.MutableRefObject<HTMLSpanElement | null>;
  onTelemetry: (t: LiveTelemetry) => void;
  onClipAutoSelect?: (clip: GaitClipId) => void;
}

export const GsmCanvasStage: React.FC<GsmCanvasStageProps> = ({
  clipId,
  interpMode,
  locomotionMode,
  lightingMode,
  isPlaying,
  speedMultiplier,
  creatureScale,
  showRigOverlay,
  scrubPhase,
  stepNonce,
  playheadRef,
  phaseReadoutRef,
  onTelemetry,
  onClipAutoSelect,
}) => {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rigRef = useRef<ExtractedGsmRig | null>(null);
  const worldRef = useRef<PainterlyGroundWorld | null>(null);

  const [loadStatus, setLoadStatus] = useState<'loading' | 'ready' | 'error'>('loading');
  const [loadError, setLoadError] = useState<string>('');

  // Mutable simulation state kept outside React reconciliation
  const simRef = useRef({
    activeClip: clipId,
    transition: null as TransitionBlend | null,
    phase: 0,
    scrollX: 0,
    scrollY: 0,
    // Free-roam world pose (sprite faces +Y when angle=0; heading=0 => facing -Y up on screen)
    worldX: 0,
    worldY: 0,
    heading: -Math.PI / 2, // facing up-right slightly at spawn
    turnBias: 0,
    roamTarget: null as { x: number; y: number } | null,
    pointerX: 720,
    pointerY: 450,
    prevGrounded: new Array(20).fill(true) as boolean[],
    lastTelemetryTime: 0,
  });

  const dirtyRef = useRef(true);
  const scheduleWakeRef = useRef<(() => void) | null>(null);

  // Mirror React props into refs so the rAF loop never tears down
  const propsRef = useRef({
    clipId,
    interpMode,
    locomotionMode,
    lightingMode,
    isPlaying,
    speedMultiplier,
    creatureScale,
    showRigOverlay,
    scrubPhase,
    onTelemetry,
    onClipAutoSelect,
  });

  useEffect(() => {
    const prevClip = propsRef.current.clipId;
    propsRef.current = {
      clipId,
      interpMode,
      locomotionMode,
      lightingMode,
      isPlaying,
      speedMultiplier,
      creatureScale,
      showRigOverlay,
      scrubPhase,
      onTelemetry,
      onClipAutoSelect,
    };
    dirtyRef.current = true;

    // Initiate smooth state crossfade whenever clipId changes
    if (prevClip !== clipId) {
      const sim = simRef.current;
      sim.transition = {
        fromClip: sim.activeClip,
        toClip: clipId,
        elapsed: 0,
        duration: 0.36,
      };
      sim.activeClip = clipId;
    }
    scheduleWakeRef.current?.();
  }, [
    clipId,
    interpMode,
    locomotionMode,
    lightingMode,
    isPlaying,
    speedMultiplier,
    creatureScale,
    showRigOverlay,
    scrubPhase,
    onTelemetry,
    onClipAutoSelect,
  ]);

  // Apply explicit scrub position
  useEffect(() => {
    if (scrubPhase !== null) {
      simRef.current.phase = wrapPhase(scrubPhase);
      dirtyRef.current = true;
      scheduleWakeRef.current?.();
    }
  }, [scrubPhase]);

  // Apply manual frame step
  useEffect(() => {
    if (stepNonce > 0) {
      simRef.current.phase = wrapPhase(simRef.current.phase + 0.04);
      dirtyRef.current = true;
      scheduleWakeRef.current?.();
    }
  }, [stepNonce]);

  // Reset roam position when switching to roam mode
  useEffect(() => {
    if (locomotionMode === 'roam') {
      simRef.current.worldX = 0;
      simRef.current.worldY = 0;
      simRef.current.roamTarget = null;
    } else {
      simRef.current.heading = -Math.PI / 2;
      simRef.current.turnBias = 0;
      simRef.current.roamTarget = null;
    }
    dirtyRef.current = true;
    scheduleWakeRef.current?.();
  }, [locomotionMode]);

  // Load and segment the GSM image once
  useEffect(() => {
    let cancelled = false;
    worldRef.current = new PainterlyGroundWorld();
    extractGsmRig('/assets/aistudio/image_e3dec876.png')
      .then((rig) => {
        if (cancelled) return;
        rigRef.current = rig;
        dirtyRef.current = true;
        scheduleWakeRef.current?.();
        setLoadStatus('ready');
      })
      .catch((err) => {
        if (cancelled) return;
        setLoadError(err instanceof Error ? err.message : 'Unable to load GSM sprite');
        setLoadStatus('error');
      });

    return () => {
      cancelled = true;
    };
  }, []);

  // Main 60Hz Canvas2D simulation & rendering loop
  useEffect(() => {
    const canvas = canvasRef.current;
    const container = containerRef.current;
    if (!canvas || !container) return;

    const ctx = canvas.getContext('2d', { alpha: false });
    if (!ctx) return;

    let viewW = container.clientWidth || 1280;
    let viewH = container.clientHeight || 800;
    let dpr = Math.min(window.devicePixelRatio || 1, 1.5);

    const syncSize = () => {
      viewW = container.clientWidth || window.innerWidth;
      viewH = container.clientHeight || window.innerHeight;
      dpr = Math.min(window.devicePixelRatio || 1, 1.5);
      canvas.width = Math.max(1, Math.round(viewW * dpr));
      canvas.height = Math.max(1, Math.round(viewH * dpr));
      dirtyRef.current = true;
      scheduleWakeRef.current?.();
    };
    syncSize();

    const ro = new ResizeObserver(syncSize);
    ro.observe(container);

    const keysDown = new Set<string>();
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
      keysDown.add(e.code);
    };
    const onKeyUp = (e: KeyboardEvent) => {
      keysDown.delete(e.code);
    };
    const clearKeys = () => keysDown.clear();

    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('keyup', onKeyUp);
    window.addEventListener('blur', clearKeys);
    document.addEventListener('visibilitychange', clearKeys);

    let rafId = 0;
    let timeoutId = 0;
    let isLoopScheduled = false;
    let lastTime = performance.now();

    const scheduleNext = () => {
      if (isLoopScheduled) return;
      isLoopScheduled = true;
      rafId = requestAnimationFrame(tick);
    };

    scheduleWakeRef.current = () => {
      lastTime = performance.now();
      scheduleNext();
    };

    const tick = (now: number) => {
      isLoopScheduled = false;
      const rawDt = (now - lastTime) / 1000;
      lastTime = now;
      const dt = Math.min(rawDt, 0.05);

      const p = propsRef.current;
      const sim = simRef.current;
      const rig = rigRef.current;
      const world = worldRef.current;

      const wasDirty = dirtyRef.current;
      if (!p.isPlaying && !sim.transition && !wasDirty) {
        return;
      }
      dirtyRef.current = false;

      // Update state crossfade
      let activeClip = GAIT_CLIPS[sim.activeClip];
      let blendTarget: { clip: typeof activeClip; alpha: number } | undefined;

      if (sim.transition) {
        sim.transition.elapsed += dt;
        const alpha = Math.min(1, sim.transition.elapsed / sim.transition.duration);
        if (alpha >= 1) {
          sim.activeClip = sim.transition.toClip;
          sim.transition = null;
          activeClip = GAIT_CLIPS[sim.activeClip];
        } else {
          activeClip = GAIT_CLIPS[sim.transition.fromClip];
          blendTarget = {
            clip: GAIT_CLIPS[sim.transition.toClip],
            alpha,
          };
        }
      }

      // Compute effective ground speed across crossfade
      let effectiveSpeed = activeClip.baseSpeedPx;
      let effectiveCycleDur = activeClip.cycleDuration;
      if (blendTarget) {
        const w = cubicBezierEase(blendTarget.alpha);
        effectiveSpeed =
          activeClip.baseSpeedPx * (1 - w) + blendTarget.clip.baseSpeedPx * w;
        effectiveCycleDur =
          activeClip.cycleDuration * (1 - w) + blendTarget.clip.cycleDuration * w;
      }

      // Steering / Movement in Free Roam vs Treadmill
      let currentSpeed = effectiveSpeed * (p.isPlaying ? p.speedMultiplier : 0);
      let turnBias = 0;

      if (p.locomotionMode === 'roam' && p.isPlaying) {
        let vx = 0;
        let vy = 0;
        if (keysDown.has('KeyW') || keysDown.has('ArrowUp')) vy -= 1;
        if (keysDown.has('KeyS') || keysDown.has('ArrowDown')) vy += 1;
        if (keysDown.has('KeyA') || keysDown.has('ArrowLeft')) vx -= 1;
        if (keysDown.has('KeyD') || keysDown.has('ArrowRight')) vx += 1;

        if (vx !== 0 || vy !== 0) {
          sim.roamTarget = null;
          const targetHeading = Math.atan2(vy, vx);
          let diff = targetHeading - sim.heading;
          while (diff > Math.PI) diff -= Math.PI * 2;
          while (diff < -Math.PI) diff += Math.PI * 2;
          const maxTurn = 3.2 * dt;
          const stepTurn = Math.max(-maxTurn, Math.min(maxTurn, diff * 4.5 * dt));
          sim.heading += stepTurn;
          turnBias = Math.max(-1, Math.min(1, diff / 1.2));

          // Auto-transition from Idle to Walk when steering
          if (sim.activeClip === 'idle' && p.onClipAutoSelect) {
            p.onClipAutoSelect('walk');
          }
        } else if (sim.roamTarget) {
          const dx = sim.roamTarget.x - sim.worldX;
          const dy = sim.roamTarget.y - sim.worldY;
          const dist = Math.hypot(dx, dy);
          if (dist < 22) {
            sim.roamTarget = null;
            if (sim.activeClip !== 'idle' && p.onClipAutoSelect) {
              p.onClipAutoSelect('idle');
            }
          } else {
            const targetHeading = Math.atan2(dy, dx);
            let diff = targetHeading - sim.heading;
            while (diff > Math.PI) diff -= Math.PI * 2;
            while (diff < -Math.PI) diff += Math.PI * 2;
            const maxTurn = 3.2 * dt;
            sim.heading += Math.max(-maxTurn, Math.min(maxTurn, diff * 4.2 * dt));
            turnBias = Math.max(-1, Math.min(1, diff / 1.2));

            if (sim.activeClip === 'idle' && p.onClipAutoSelect) {
              p.onClipAutoSelect('walk');
            }
          }
        }
        sim.turnBias += (turnBias - sim.turnBias) * Math.min(1, dt * 8);

        // Move GSM across world bounds (clamped inside stage safe area)
        const moveDist = currentSpeed * dt;
        sim.worldX += Math.cos(sim.heading) * moveDist;
        sim.worldY += Math.sin(sim.heading) * moveDist;
        const limitX = Math.max(120, viewW * 0.36);
        const limitY = Math.max(100, viewH * 0.32);
        sim.worldX = Math.max(-limitX, Math.min(limitX, sim.worldX));
        sim.worldY = Math.max(-limitY, Math.min(limitY, sim.worldY));
      } else {
        sim.turnBias += (0 - sim.turnBias) * Math.min(1, dt * 8);
      }

      // Advance keyframe cycle phase
      if (p.isPlaying && p.scrubPhase === null) {
        const phaseDelta = (dt * p.speedMultiplier) / Math.max(0.2, effectiveCycleDur);
        sim.phase = wrapPhase(sim.phase + phaseDelta);
      }

      // Scroll treadmill earth opposite creature's facing direction (facing -Y upward)
      let scrollDx = 0;
      let scrollDy = 0;
      if (p.locomotionMode === 'treadmill' && p.isPlaying) {
        // Creature faces upward (-Y) in treadmill mode, so ground moves downward (+Y)
        scrollDy = currentSpeed * dt;
        sim.scrollY += scrollDy;
      }

      if (world) {
        world.update(p.isPlaying ? dt : 0, scrollDx, scrollDy);
      }

      // Evaluate 20 leg poses & central body pose from keyframe engine
      const legPoses = [];
      let groundedCount = 0;
      let liftedCount = 0;
      if (rig) {
        for (let i = 0; i < rig.legs.length; i++) {
          const leg = rig.legs[i];
          const lp = evaluateLegPose(
            activeClip,
            leg.spec.index,
            leg.spec.side,
            sim.phase,
            p.interpMode,
            sim.turnBias,
            blendTarget
          );
          legPoses.push(lp);
          if (lp.isGrounded) groundedCount++;
          else liftedCount++;
        }
      }

      const bodyPose = evaluateBodyPose(
        activeClip,
        sim.phase,
        p.interpMode,
        sim.turnBias,
        blendTarget
      );

      // Creature screen placement
      const creatureScreenX =
        viewW * 0.5 + (p.locomotionMode === 'roam' ? sim.worldX : 0);
      const creatureScreenY =
        viewH * 0.44 + (p.locomotionMode === 'roam' ? sim.worldY : 0);
      // In source image, sheep faces +Y (pi/2). Rotate by (heading - pi/2)
      const spriteRot =
        p.locomotionMode === 'roam' ? sim.heading - Math.PI / 2 : Math.PI; // -Math.PI/2 - pi/2 = -pi -> facing UP (-Y)

      // Light direction vector in local sprite coordinates
      const localLightAngle = -0.78 - spriteRot;
      const lightDir = {
        x: Math.cos(localLightAngle),
        y: Math.sin(localLightAngle),
      };

      // ================= RENDER FRAME =================
      ctx.save();
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

      if (world) {
        world.renderGround(ctx, viewW, viewH, sim.scrollX, sim.scrollY);
        world.renderContacts(ctx, -viewW * 0.5, -viewH * 0.44);
      } else {
        ctx.fillStyle = '#14100d';
        ctx.fillRect(0, 0, viewW, viewH);
      }

      // Draw roam click waypoint if active
      if (p.locomotionMode === 'roam' && sim.roamTarget) {
        const tx = viewW * 0.5 + sim.roamTarget.x;
        const ty = viewH * 0.44 + sim.roamTarget.y;
        ctx.save();
        ctx.strokeStyle = 'rgba(197, 155, 76, 0.5)';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.arc(tx, ty, 14 + Math.sin(now * 0.008) * 3, 0, Math.PI * 2);
        ctx.stroke();
        ctx.restore();
      }

      // Render articulated GSM creature
      if (rig) {
        const baseFit = Math.min(viewW * 0.62, viewH * 0.68) / rig.sourceSize;
        const scale = baseFit * p.creatureScale;

        ctx.save();
        ctx.translate(creatureScreenX, creatureScreenY);
        ctx.rotate(spriteRot);
        ctx.scale(scale, scale);

        const legTransforms = renderGsmCreature(ctx, rig, legPoses, bodyPose, {
          lightDir,
          showRigOverlay: p.showRigOverlay,
        });

        ctx.restore();

        // Spawn ground impact marks right when a leg transitions from swing -> grounded
        if (world && p.isPlaying && effectiveSpeed > 5) {
          const cosR = Math.cos(spriteRot);
          const sinR = Math.sin(spriteRot);
          for (let i = 0; i < legTransforms.length; i++) {
            const wasGrounded = sim.prevGrounded[i];
            const nowGrounded = legTransforms[i].isGrounded;
            if (!wasGrounded && nowGrounded) {
              const tip = legTransforms[i].joints[legTransforms[i].joints.length - 1];
              const wx =
                (p.locomotionMode === 'roam' ? sim.worldX : 0) +
                (tip.x * cosR - tip.y * sinR) * scale;
              const wy =
                (p.locomotionMode === 'roam' ? sim.worldY : 0) +
                (tip.x * sinR + tip.y * cosR) * scale;
              world.spawnFootprint(wx, wy, spriteRot);
            }
            sim.prevGrounded[i] = nowGrounded;
          }
        }
      }

      // Lighting overlay (Tenebrism / Sheepherder Flashlight Cone / Studio)
      if (world) {
        const originX = viewW * 0.14;
        const originY = viewH * 0.78;
        const flashAngle = Math.atan2(
          sim.pointerY - originY,
          sim.pointerX - originX
        );
        world.renderLightingOverlay(
          ctx,
          viewW,
          viewH,
          p.lightingMode,
          creatureScreenX,
          creatureScreenY,
          originX,
          originY,
          flashAngle
        );
      }

      ctx.restore();

      // High-frequency DOM playhead update without React re-render
      if (playheadRef.current && p.scrubPhase === null) {
        playheadRef.current.value = sim.phase.toFixed(3);
      }
      if (phaseReadoutRef.current) {
        phaseReadoutRef.current.textContent = sim.phase.toFixed(2);
      }

      // Throttled telemetry callback (~12Hz, or immediate when manually scrubbed/paused)
      if (wasDirty || now - sim.lastTelemetryTime > 85) {
        sim.lastTelemetryTime = now;
        p.onTelemetry({
          phase: sim.phase,
          speedPx: Math.round(currentSpeed),
          groundedCount,
          liftedCount,
          activeTransition: sim.transition
            ? `${GAIT_CLIPS[sim.transition.fromClip].name} → ${GAIT_CLIPS[sim.transition.toClip].name}`
            : null,
        });
      }

      if (p.isPlaying || sim.transition || dirtyRef.current) {
        const frameEnd = performance.now();
        const renderCostMs = frameEnd - now;
        if (renderCostMs > 12) {
          timeoutId = window.setTimeout(scheduleNext, Math.min(20, Math.round(renderCostMs * 0.4)));
        } else {
          scheduleNext();
        }
      }
    };

    scheduleNext();

    return () => {
      scheduleWakeRef.current = null;
      cancelAnimationFrame(rafId);
      clearTimeout(timeoutId);
      ro.disconnect();
      window.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('keyup', onKeyUp);
      window.removeEventListener('blur', clearKeys);
      document.removeEventListener('visibilitychange', clearKeys);
    };
  }, [playheadRef, phaseReadoutRef]);

  const handlePointerMove = (e: React.PointerEvent<HTMLCanvasElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    simRef.current.pointerX = e.clientX - rect.left;
    simRef.current.pointerY = e.clientY - rect.top;
    if (lightingMode === 'flashlight') {
      dirtyRef.current = true;
      scheduleWakeRef.current?.();
    }
  };

  const handleCanvasClick = (e: React.PointerEvent<HTMLCanvasElement>) => {
    if (locomotionMode !== 'roam') return;
    const rect = e.currentTarget.getBoundingClientRect();
    const cx = e.clientX - rect.left - rect.width * 0.5;
    const cy = e.clientY - rect.top - rect.height * 0.44;
    simRef.current.roamTarget = { x: cx, y: cy };
    dirtyRef.current = true;
    scheduleWakeRef.current?.();
  };

  return (
    <div
      ref={containerRef}
      className="relative w-full h-full overflow-hidden bg-[#0b0908] select-none"
    >
      <canvas
        ref={canvasRef}
        data-testid="gsm-animation-canvas"
        onPointerMove={handlePointerMove}
        onPointerDown={handleCanvasClick}
        className={`block w-full h-full ${
          locomotionMode === 'roam' ? 'cursor-crosshair' : 'cursor-default'
        }`}
      />

      {loadStatus === 'loading' && (
        <div className="absolute inset-0 flex items-center justify-center bg-[#0b0908]/90 pointer-events-none">
          <div className="text-center space-y-2">
            <p className="font-display text-2xl tracking-wide text-[#e6dfd1]">
              Segmenting 20-Leg Rig…
            </p>
            <p className="text-sm text-[#a89e8c]">
              Extracting chroma-keyed torso and chitinous bone chains
            </p>
          </div>
        </div>
      )}

      {loadStatus === 'error' && (
        <div className="absolute inset-0 flex items-center justify-center bg-[#0b0908]/95">
          <div className="max-w-md border border-[#9e2a2b]/50 bg-[#161210] p-6 text-center space-y-2">
            <p className="font-display text-xl text-[#e6dfd1]">Sprite Load Error</p>
            <p className="text-sm text-[#c7bcae]">{loadError}</p>
          </div>
        </div>
      )}
    </div>
  );
};
