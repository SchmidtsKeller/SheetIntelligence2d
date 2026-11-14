/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useCallback, useEffect, useRef, useState } from 'react';
import { GaitClipId, InterpolationMode } from './engine/keyframes';
import { LightingMode } from './engine/groundWorld';
import {
  GsmCanvasStage,
  LiveTelemetry,
  LocomotionMode,
} from './components/GsmCanvasStage';
import { AnimationTimelineBar } from './components/AnimationTimelineBar';
import { RigInspectorDrawer } from './components/RigInspectorDrawer';

export default function App() {
  const [clipId, setClipId] = useState<GaitClipId>('walk');
  const [interpMode, setInterpMode] = useState<InterpolationMode>('hermite');
  const [locomotionMode, setLocomotionMode] = useState<LocomotionMode>('treadmill');
  const [lightingMode, setLightingMode] = useState<LightingMode>('tenebrism');
  const [isPlaying, setIsPlaying] = useState<boolean>(true);
  const [speedMultiplier, setSpeedMultiplier] = useState<number>(1.0);
  const [creatureScale, setCreatureScale] = useState<number>(0.84);
  const [showRigOverlay, setShowRigOverlay] = useState<boolean>(false);
  const [scrubPhase, setScrubPhase] = useState<number | null>(null);
  const [stepNonce, setStepNonce] = useState<number>(0);

  const [inspectorOpen, setInspectorOpen] = useState<boolean>(() =>
    typeof window !== 'undefined' ? window.innerWidth >= 1024 : true
  );

  const [telemetry, setTelemetry] = useState<LiveTelemetry>({
    phase: 0,
    speedPx: 300,
    groundedCount: 12,
    liftedCount: 8,
    activeTransition: null,
  });

  const playheadRef = useRef<HTMLInputElement | null>(null);
  const phaseReadoutRef = useRef<HTMLSpanElement | null>(null);

  // Sync key animation engine state to body dataset
  useEffect(() => {
    document.body.dataset.state = isPlaying ? 'playing' : 'paused';
    document.body.dataset.gait = clipId;
    document.body.dataset.interp = interpMode;
    document.body.dataset.locomotion = locomotionMode;
  }, [isPlaying, clipId, interpMode, locomotionMode]);

  // Global hotkeys (Space = Play/Pause, 1-4 = Gait Clips, R = Rig Overlay)
  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) {
        return;
      }
      if (e.code === 'Space') {
        e.preventDefault();
        setIsPlaying((prev) => !prev);
      } else if (e.key === '1') {
        setClipId('idle');
      } else if (e.key === '2') {
        setClipId('stalk');
      } else if (e.key === '3') {
        setClipId('walk');
      } else if (e.key === '4') {
        setClipId('lunge');
      } else if (e.key === 'r' || e.key === 'R') {
        setShowRigOverlay((prev) => !prev);
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, []);

  const handleTogglePlay = useCallback(() => {
    setScrubPhase(null);
    setIsPlaying((prev) => !prev);
  }, []);

  const handleStepFrame = useCallback(() => {
    setIsPlaying(false);
    setScrubPhase(null);
    setStepNonce((n) => n + 1);
  }, []);

  const handleJumpToKeyframe = useCallback((phase: number) => {
    setIsPlaying(false);
    setScrubPhase(phase);
    if (playheadRef.current) {
      playheadRef.current.value = phase.toFixed(3);
    }
    if (phaseReadoutRef.current) {
      phaseReadoutRef.current.textContent = phase.toFixed(2);
    }
  }, []);

  const handleSelectClip = useCallback((id: GaitClipId) => {
    setScrubPhase(null);
    setClipId(id);
    if (id !== 'idle') {
      setIsPlaying(true);
    }
  }, []);

  return (
    <main className="relative w-screen h-screen overflow-hidden bg-[#0b0908]">
      {/* Full-Viewport 2D Top-Down Animation Stage */}
      <GsmCanvasStage
        clipId={clipId}
        interpMode={interpMode}
        locomotionMode={locomotionMode}
        lightingMode={lightingMode}
        isPlaying={isPlaying}
        speedMultiplier={speedMultiplier}
        creatureScale={creatureScale}
        showRigOverlay={showRigOverlay}
        scrubPhase={scrubPhase}
        stepNonce={stepNonce}
        playheadRef={playheadRef}
        phaseReadoutRef={phaseReadoutRef}
        onTelemetry={setTelemetry}
        onClipAutoSelect={setClipId}
      />

      {/* Non-blocking Floating Studio HUD */}
      <div className="pointer-events-none fixed inset-0 flex flex-col justify-between p-4 sm:p-5">
        {/* Top Row: Quiet Editorial Title + Inspector Toggle/Drawer */}
        <div className="flex items-start justify-between gap-4">
          <header className="pointer-events-auto max-w-sm">
            <h1 className="font-display text-2xl sm:text-3xl font-semibold tracking-tight text-[#f5efe4] leading-tight">
              Giant Scary Monster
            </h1>
            <p className="mt-0.5 text-xs text-[#9e9484]">
              Hide in Sheep Clothing · 20-Leg Keyframe Gait Engine
            </p>
          </header>

          <RigInspectorDrawer
            isOpen={inspectorOpen}
            onToggleOpen={() => setInspectorOpen((o) => !o)}
            clipId={clipId}
            interpMode={interpMode}
            locomotionMode={locomotionMode}
            lightingMode={lightingMode}
            creatureScale={creatureScale}
            showRigOverlay={showRigOverlay}
            telemetry={telemetry}
            onChangeInterp={setInterpMode}
            onChangeLocomotion={setLocomotionMode}
            onChangeLighting={setLightingMode}
            onChangeScale={setCreatureScale}
            onToggleRigOverlay={() => setShowRigOverlay((r) => !r)}
          />
        </div>

        {/* Bottom Dock: Playback, Gait Transitions & Keyframe Timeline */}
        <div className="w-full">
          <AnimationTimelineBar
            clipId={clipId}
            isPlaying={isPlaying}
            speedMultiplier={speedMultiplier}
            playheadRef={playheadRef}
            phaseReadoutRef={phaseReadoutRef}
            onSelectClip={handleSelectClip}
            onTogglePlay={handleTogglePlay}
            onStepFrame={handleStepFrame}
            onSelectSpeed={setSpeedMultiplier}
            onScrubStart={() => setIsPlaying(false)}
            onScrubChange={(val) => setScrubPhase(val)}
            onScrubEnd={() => setScrubPhase(null)}
            onJumpToKeyframe={handleJumpToKeyframe}
          />
        </div>
      </div>
    </main>
  );
}
