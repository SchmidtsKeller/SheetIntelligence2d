import React from 'react';
import { Pause, Play, StepForward } from 'lucide-react';
import { GAIT_CLIPS, GaitClipId } from '../engine/keyframes';

interface AnimationTimelineBarProps {
  clipId: GaitClipId;
  isPlaying: boolean;
  speedMultiplier: number;
  playheadRef: React.MutableRefObject<HTMLInputElement | null>;
  phaseReadoutRef: React.MutableRefObject<HTMLSpanElement | null>;
  onSelectClip: (id: GaitClipId) => void;
  onTogglePlay: () => void;
  onStepFrame: () => void;
  onSelectSpeed: (spd: number) => void;
  onScrubStart: () => void;
  onScrubChange: (phase: number) => void;
  onScrubEnd: () => void;
  onJumpToKeyframe: (phase: number) => void;
}

const CLIP_ORDER: GaitClipId[] = ['idle', 'stalk', 'walk', 'lunge'];
const SPEED_OPTIONS = [0.5, 1.0, 1.5];

export const AnimationTimelineBar: React.FC<AnimationTimelineBarProps> = ({
  clipId,
  isPlaying,
  speedMultiplier,
  playheadRef,
  phaseReadoutRef,
  onSelectClip,
  onTogglePlay,
  onStepFrame,
  onSelectSpeed,
  onScrubStart,
  onScrubChange,
  onScrubEnd,
  onJumpToKeyframe,
}) => {
  const activeClip = GAIT_CLIPS[clipId];
  // Exclude duplicate t=1.0 terminal knot from clickable diamonds so labels stay clean
  const markerKeyframes = activeClip.keyframes.slice(0, -1);

  return (
    <section
      aria-label="Keyframe Animation Controls"
      className="pointer-events-auto w-full max-w-4xl mx-auto rounded-xl border border-[#d8cfb8]/15 bg-[#13100d]/95 px-4 py-3 shadow-[0_20px_50px_rgba(0,0,0,0.75)]"
    >
      {/* Top row: Transport + Gait States + Speed */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        {/* Playback Transport */}
        <div className="flex items-center gap-2 shrink-0">
          <button
            type="button"
            onClick={onTogglePlay}
            aria-label={isPlaying ? 'Pause animation' : 'Play animation'}
            className="inline-flex items-center gap-2 rounded-lg bg-[#9e2a2b] px-3.5 py-2 text-xs font-medium text-[#f5efe4] hover:bg-[#b53334] transition-colors whitespace-nowrap shrink-0 cursor-pointer focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#e6dfd1]"
          >
            {isPlaying ? <Pause className="w-3.5 h-3.5" /> : <Play className="w-3.5 h-3.5" />}
            <span>{isPlaying ? 'Pause' : 'Play'}</span>
          </button>

          <button
            type="button"
            onClick={onStepFrame}
            aria-label="Step forward one frame"
            className="inline-flex items-center gap-1.5 rounded-lg border border-[#d8cfb8]/18 bg-[#1d1814] px-3 py-2 text-xs font-medium text-[#d8cfb8] hover:bg-[#27201b] hover:text-[#f5efe4] transition-colors whitespace-nowrap shrink-0 cursor-pointer focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#e6dfd1]"
          >
            <StepForward className="w-3.5 h-3.5" />
            <span>Step</span>
          </button>
        </div>

        {/* Gait Clip Selector (triggers smooth state crossfades) */}
        <div
          role="group"
          aria-label="Gait animation state"
          className="flex items-center gap-1 rounded-lg bg-[#0d0a08] p-1 border border-[#d8cfb8]/10"
        >
          {CLIP_ORDER.map((id) => {
            const active = clipId === id;
            return (
              <button
                key={id}
                type="button"
                aria-pressed={active}
                onClick={() => onSelectClip(id)}
                className={`px-3 py-1.5 rounded-md text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-[#e6dfd1] ${
                  active
                    ? 'bg-[#2a221c] text-[#f5efe4] border border-[#c59b4c]/40'
                    : 'text-[#9e9484] hover:text-[#e6dfd1]'
                }`}
              >
                {GAIT_CLIPS[id].name}
              </button>
            );
          })}
        </div>

        {/* Playback Speed Multiplier */}
        <div
          role="group"
          aria-label="Playback speed"
          className="hidden sm:flex items-center gap-1 rounded-lg bg-[#0d0a08] p-1 border border-[#d8cfb8]/10 shrink-0"
        >
          {SPEED_OPTIONS.map((spd) => {
            const active = Math.abs(speedMultiplier - spd) < 0.01;
            return (
              <button
                key={spd}
                type="button"
                aria-pressed={active}
                onClick={() => onSelectSpeed(spd)}
                className={`px-2.5 py-1.5 rounded-md text-xs font-mono-tabular transition-colors whitespace-nowrap shrink-0 cursor-pointer focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-[#e6dfd1] ${
                  active
                    ? 'bg-[#2a221c] text-[#f5efe4]'
                    : 'text-[#9e9484] hover:text-[#e6dfd1]'
                }`}
              >
                {spd.toFixed(1)}×
              </button>
            );
          })}
        </div>
      </div>

      {/* Bottom row: Keyframe Timeline Scrubber & Keyframe Markers */}
      <div className="mt-3 pt-2.5 border-t border-[#d8cfb8]/10">
        <div className="flex items-center justify-between gap-3 mb-1.5">
          <div className="flex items-center gap-2 text-xs text-[#9e9484] min-w-0">
            <span className="whitespace-nowrap">Cycle Keyframes</span>
            <span aria-hidden="true" className="hidden sm:inline">·</span>
            <span className="hidden sm:inline text-[#c7bcae] truncate">{activeClip.description}</span>
          </div>
          <div className="flex items-center gap-1.5 text-xs font-mono-tabular text-[#c7bcae] shrink-0">
            <span className="text-[#8f8575]">Phase</span>
            <span ref={phaseReadoutRef} className="text-[#f5efe4] w-9 text-right">
              0.00
            </span>
          </div>
        </div>

        <div className="relative pt-1 pb-5">
          <input
            ref={playheadRef}
            type="range"
            min={0}
            max={1}
            step={0.001}
            defaultValue={0}
            aria-label="Scrub animation cycle phase"
            onPointerDown={onScrubStart}
            onPointerUp={onScrubEnd}
            onBlur={onScrubEnd}
            onChange={(e) => onScrubChange(parseFloat(e.target.value))}
            className="studio-range relative z-10 w-full block"
          />

          {/* Clickable Keyframe Diamond Markers along track */}
          <div className="absolute left-2 right-2 top-5 h-5 pointer-events-none">
            {markerKeyframes.map((kf) => {
              const shortLabel = kf.label
                .replace('Peak Lift', 'Lift')
                .replace('Swing Reach', 'Reach')
                .replace('Push-Off', 'Push')
                .replace('Mid-Stance', 'Stance')
                .replace('High Lift', 'Lift')
                .replace('Propulsion', 'Drive')
                .replace('Vault Lift', 'Vault');
              return (
                <button
                  key={`${clipId}-${kf.t}-${kf.label}`}
                  type="button"
                  onClick={() => onJumpToKeyframe(kf.t)}
                  style={{ left: `${kf.t * 100}%` }}
                  aria-label={`Jump to keyframe ${kf.label} at phase ${kf.t.toFixed(2)}`}
                  className="pointer-events-auto absolute -translate-x-1/2 -top-0.5 flex flex-col items-center group cursor-pointer focus-visible:outline-2 focus-visible:outline-[#e6dfd1]"
                >
                  <span className="w-2 h-2 rotate-45 bg-[#c59b4c] border border-[#0b0908] group-hover:scale-125 group-hover:bg-[#f5efe4] transition-transform" />
                  <span className="mt-1 text-[9.5px] sm:text-[10px] leading-none text-[#c4b9a6] group-hover:text-[#f5efe4] whitespace-nowrap">
                    <span className="sm:hidden">{shortLabel}</span>
                    <span className="hidden sm:inline">{kf.label}</span>
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      </div>
    </section>
  );
};
