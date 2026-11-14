import React, { useMemo } from 'react';
import { SlidersHorizontal, X } from 'lucide-react';
import {
  GAIT_CLIPS,
  GaitClipId,
  InterpolationMode,
  sampleClip,
} from '../engine/keyframes';
import { LightingMode } from '../engine/groundWorld';
import { LiveTelemetry, LocomotionMode } from './GsmCanvasStage';

interface RigInspectorDrawerProps {
  isOpen: boolean;
  onToggleOpen: () => void;
  clipId: GaitClipId;
  interpMode: InterpolationMode;
  locomotionMode: LocomotionMode;
  lightingMode: LightingMode;
  creatureScale: number;
  showRigOverlay: boolean;
  telemetry: LiveTelemetry;
  onChangeInterp: (mode: InterpolationMode) => void;
  onChangeLocomotion: (mode: LocomotionMode) => void;
  onChangeLighting: (mode: LightingMode) => void;
  onChangeScale: (scale: number) => void;
  onToggleRigOverlay: () => void;
}

const INTERP_OPTIONS: { id: InterpolationMode; label: string }[] = [
  { id: 'hermite', label: 'Hermite' },
  { id: 'bezier', label: 'Cubic' },
  { id: 'linear', label: 'Linear' },
];

const LIGHTING_OPTIONS: { id: LightingMode; label: string }[] = [
  { id: 'tenebrism', label: 'Tenebrism' },
  { id: 'flashlight', label: 'Flashlight' },
  { id: 'studio', label: 'Studio' },
];

export const RigInspectorDrawer: React.FC<RigInspectorDrawerProps> = ({
  isOpen,
  onToggleOpen,
  clipId,
  interpMode,
  locomotionMode,
  lightingMode,
  creatureScale,
  showRigOverlay,
  telemetry,
  onChangeInterp,
  onChangeLocomotion,
  onChangeLighting,
  onChangeScale,
  onToggleRigOverlay,
}) => {
  const clip = GAIT_CLIPS[clipId];

  // Sample curve SVG paths across [0..1] whenever clip or interpolation mode changes
  const { swingPath, liftPath, flexPath, knotDots } = useMemo(() => {
    const W = 256;
    const H = 84;
    const midY = H * 0.5;
    const steps = 64;

    const toSvg = (t: number, normVal: number) => ({
      x: t * W,
      y: midY - normVal * (H * 0.38),
    });

    let sPath = '';
    let lPath = '';
    let fPath = '';

    for (let i = 0; i <= steps; i++) {
      const t = i / steps;
      const pose = sampleClip(clip, t, interpMode);
      const sp = toSvg(t, pose.coxaSwing);
      const lp = toSvg(t, pose.lift * 2 - 1);
      const fp = toSvg(t, pose.femurFlex * 3.0);
      const cmd = i === 0 ? 'M' : 'L';
      sPath += `${cmd}${sp.x.toFixed(1)},${sp.y.toFixed(1)} `;
      lPath += `${cmd}${lp.x.toFixed(1)},${lp.y.toFixed(1)} `;
      fPath += `${cmd}${fp.x.toFixed(1)},${fp.y.toFixed(1)} `;
    }

    const dots = clip.keyframes.map((kf) => ({
      x: kf.t * W,
      y: toSvg(kf.t, kf.coxaSwing).y,
      label: kf.label,
    }));

    return { swingPath: sPath, liftPath: lPath, flexPath: fPath, knotDots: dots };
  }, [clip, interpMode]);

  if (!isOpen) {
    return (
      <button
        type="button"
        onClick={onToggleOpen}
        aria-label="Open animation inspector"
        className="pointer-events-auto inline-flex items-center gap-2 rounded-lg border border-[#d8cfb8]/18 bg-[#13100d]/95 px-3.5 py-2 text-xs font-medium text-[#e6dfd1] hover:bg-[#1e1914] transition-colors shadow-lg whitespace-nowrap shrink-0 cursor-pointer focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#e6dfd1]"
      >
        <SlidersHorizontal className="w-3.5 h-3.5 text-[#c59b4c]" />
        <span>Inspector</span>
      </button>
    );
  }

  const playheadX = telemetry.phase * 256;

  return (
    <aside
      aria-label="Rig and Keyframe Inspector"
      className="pointer-events-auto w-76 max-w-[calc(100vw-2rem)] rounded-xl border border-[#d8cfb8]/15 bg-[#13100d]/95 p-4 shadow-[0_20px_50px_rgba(0,0,0,0.8)] space-y-4"
    >
      {/* Header */}
      <div className="flex items-center justify-between gap-2 pb-2.5 border-b border-[#d8cfb8]/10">
        <h2 className="font-display text-lg font-semibold tracking-wide text-[#f5efe4]">
          Gait & Rig Controls
        </h2>
        <button
          type="button"
          onClick={onToggleOpen}
          aria-label="Close animation inspector"
          className="p-1.5 rounded-md text-[#9e9484] hover:text-[#f5efe4] hover:bg-[#1f1a15] transition-colors cursor-pointer focus-visible:outline-2 focus-visible:outline-[#e6dfd1]"
        >
          <X className="w-4 h-4" />
        </button>
      </div>

      {/* Live Keyframe Curve Plot */}
      <div className="space-y-2">
        <div className="flex items-center justify-between text-xs">
          <span className="text-[#c7bcae] font-medium">Interpolation Curve</span>
          <span className="font-mono-tabular text-[#8f8575]">
            {telemetry.activeTransition ? telemetry.activeTransition : clip.name}
          </span>
        </div>

        <div
          role="group"
          aria-label="Keyframe interpolation curve"
          className="grid grid-cols-3 gap-1 rounded-lg bg-[#0b0908] p-1 border border-[#d8cfb8]/10"
        >
          {INTERP_OPTIONS.map((opt) => {
            const active = interpMode === opt.id;
            return (
              <button
                key={opt.id}
                type="button"
                aria-pressed={active}
                onClick={() => onChangeInterp(opt.id)}
                className={`py-1.5 px-2 rounded-md text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer focus-visible:outline-2 focus-visible:outline-[#e6dfd1] ${
                  active
                    ? 'bg-[#2a221c] text-[#f5efe4]'
                    : 'text-[#8f8575] hover:text-[#d8cfb8]'
                }`}
              >
                {opt.label}
              </button>
            );
          })}
        </div>

        {/* SVG Keyframe Spline Graph */}
        <div className="rounded-lg bg-[#0b0908] border border-[#d8cfb8]/10 p-2">
          <svg
            viewBox="0 0 256 84"
            className="w-full h-20 overflow-visible"
            aria-label="Keyframe swing, lift, and femur flex curves"
          >
            <line x1="0" y1="42" x2="256" y2="42" stroke="rgba(216,207,184,0.10)" strokeDasharray="3 3" />
            <path d={flexPath} fill="none" stroke="rgba(168, 158, 140, 0.45)" strokeWidth="1.2" />
            <path d={liftPath} fill="none" stroke="#9e2a2b" strokeWidth="1.6" />
            <path d={swingPath} fill="none" stroke="#c59b4c" strokeWidth="1.8" />
            {knotDots.map((dot, idx) => (
              <circle
                key={`${dot.label}-${idx}`}
                cx={dot.x}
                cy={dot.y}
                r="2.8"
                fill="#f5efe4"
                stroke="#0b0908"
                strokeWidth="1"
              />
            ))}
            <line
              x1={playheadX}
              y1="2"
              x2={playheadX}
              y2="82"
              stroke="#f5efe4"
              strokeOpacity="0.6"
              strokeWidth="1.2"
            />
          </svg>
          <div className="mt-1.5 flex items-center gap-3 text-[11px] text-[#9e9484]">
            <span className="inline-flex items-center gap-1">
              <span className="w-2.5 h-0.5 bg-[#c59b4c]" />
              Swing
            </span>
            <span className="inline-flex items-center gap-1">
              <span className="w-2.5 h-0.5 bg-[#9e2a2b]" />
              Lift
            </span>
            <span className="inline-flex items-center gap-1">
              <span className="w-2.5 h-0.5 bg-[#a89e8c]/60" />
              Flex
            </span>
          </div>
        </div>
      </div>

      {/* Locomotion Stage Mode */}
      <div className="space-y-1.5">
        <span className="block text-xs font-medium text-[#c7bcae]">Stage Navigation</span>
        <div
          role="group"
          aria-label="Stage navigation mode"
          className="grid grid-cols-2 gap-1 rounded-lg bg-[#0b0908] p-1 border border-[#d8cfb8]/10"
        >
          <button
            type="button"
            aria-pressed={locomotionMode === 'treadmill'}
            onClick={() => onChangeLocomotion('treadmill')}
            className={`py-1.5 px-2 rounded-md text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer focus-visible:outline-2 focus-visible:outline-[#e6dfd1] ${
              locomotionMode === 'treadmill'
                ? 'bg-[#2a221c] text-[#f5efe4]'
                : 'text-[#8f8575] hover:text-[#d8cfb8]'
            }`}
          >
            Treadmill
          </button>
          <button
            type="button"
            aria-pressed={locomotionMode === 'roam'}
            onClick={() => onChangeLocomotion('roam')}
            className={`py-1.5 px-2 rounded-md text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer focus-visible:outline-2 focus-visible:outline-[#e6dfd1] ${
              locomotionMode === 'roam'
                ? 'bg-[#2a221c] text-[#f5efe4]'
                : 'text-[#8f8575] hover:text-[#d8cfb8]'
            }`}
          >
            Free Roam
          </button>
        </div>
        {locomotionMode === 'roam' && (
          <p className="text-[11px] text-[#8f8575]">
            Use WASD / Arrows or click ground to steer.
          </p>
        )}
      </div>

      {/* Chiaroscuro Lighting Mode */}
      <div className="space-y-1.5">
        <span className="block text-xs font-medium text-[#c7bcae]">Scene Lighting</span>
        <div
          role="group"
          aria-label="Scene lighting mode"
          className="grid grid-cols-3 gap-1 rounded-lg bg-[#0b0908] p-1 border border-[#d8cfb8]/10"
        >
          {LIGHTING_OPTIONS.map((opt) => {
            const active = lightingMode === opt.id;
            return (
              <button
                key={opt.id}
                type="button"
                aria-pressed={active}
                onClick={() => onChangeLighting(opt.id)}
                className={`py-1.5 px-2 rounded-md text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer focus-visible:outline-2 focus-visible:outline-[#e6dfd1] ${
                  active
                    ? 'bg-[#2a221c] text-[#f5efe4]'
                    : 'text-[#8f8575] hover:text-[#d8cfb8]'
                }`}
              >
                {opt.label}
              </button>
            );
          })}
        </div>
      </div>

      {/* Creature Scale + Rig Overlay */}
      <div className="space-y-3 pt-1 border-t border-[#d8cfb8]/10">
        <div className="space-y-1.5">
          <div className="flex items-center justify-between text-xs">
            <label htmlFor="gsm-scale-slider" className="text-[#c7bcae] font-medium">
              Creature Scale
            </label>
            <span className="font-mono-tabular text-[#f5efe4]">
              {creatureScale.toFixed(2)}×
            </span>
          </div>
          <input
            id="gsm-scale-slider"
            type="range"
            min={0.5}
            max={1.15}
            step={0.05}
            value={creatureScale}
            onChange={(e) => onChangeScale(parseFloat(e.target.value))}
            className="studio-range w-full block"
          />
        </div>

        <button
          type="button"
          role="switch"
          aria-checked={showRigOverlay}
          onClick={onToggleRigOverlay}
          className="w-full flex items-center justify-between rounded-lg border border-[#d8cfb8]/14 bg-[#1a1612] px-3 py-2 text-xs font-medium text-[#d8cfb8] hover:bg-[#231d17] transition-colors cursor-pointer focus-visible:outline-2 focus-visible:outline-[#e6dfd1]"
        >
          <span className="whitespace-nowrap">20-Leg Skeletal Rig</span>
          <span className="font-mono-tabular text-[#c59b4c]">
            {showRigOverlay ? 'Visible' : 'Hidden'}
          </span>
        </button>
      </div>

      {/* Live Grounding Telemetry */}
      <div className="pt-2.5 border-t border-[#d8cfb8]/10 grid grid-cols-3 gap-2 text-center">
        <div>
          <div className="text-[11px] text-[#8f8575]">Velocity</div>
          <div className="font-mono-tabular text-sm text-[#f5efe4]">
            {telemetry.speedPx} px/s
          </div>
        </div>
        <div>
          <div className="text-[11px] text-[#8f8575]">Planted</div>
          <div className="font-mono-tabular text-sm text-[#c59b4c]">
            {telemetry.groundedCount}/20
          </div>
        </div>
        <div>
          <div className="text-[11px] text-[#8f8575]">Swinging</div>
          <div className="font-mono-tabular text-sm text-[#d8cfb8]">
            {telemetry.liftedCount}/20
          </div>
        </div>
      </div>
    </aside>
  );
};
