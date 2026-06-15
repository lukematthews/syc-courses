import { useEffect, type ReactNode } from 'react'
import type { Mark } from '../data/marks'
import { useCurrentPosition } from '../hooks/useCurrentPosition'
import {
  applyMagneticVariation,
  calculateBearingTrue,
  calculateDistanceNm,
  formatBearing,
  formatDistanceNm,
  MAGNETIC_VARIATION_DEGREES,
} from '../utils/navigation'

type QuickBearingResultProps = {
  mark: Mark
  compact?: boolean
}

function ResultTile({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="rounded-lg border-2 border-slate-950 bg-white p-3">
      <div className="text-base font-black uppercase text-slate-700">{label}</div>
      <div className="mt-1 text-3xl font-black leading-none text-slate-950">{children}</div>
    </div>
  )
}

function formatUpdatedTime(timestamp: number) {
  return new Date(timestamp).toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  })
}

export function QuickBearingResult({ mark, compact = false }: QuickBearingResultProps) {
  const { position, status, errorMessage, requestPosition } = useCurrentPosition()

  useEffect(() => {
    requestPosition()
  }, [requestPosition])

  const trueBearing =
    position &&
    calculateBearingTrue(
      position.coords.latitude,
      position.coords.longitude,
      mark.latitude,
      mark.longitude,
    )
  const displayedBearing =
    typeof trueBearing === 'number' && MAGNETIC_VARIATION_DEGREES !== null
      ? applyMagneticVariation(trueBearing, MAGNETIC_VARIATION_DEGREES)
      : trueBearing
  const bearingMode = MAGNETIC_VARIATION_DEGREES === null ? 'T' : 'M'
  const distance =
    position &&
    calculateDistanceNm(
      position.coords.latitude,
      position.coords.longitude,
      mark.latitude,
      mark.longitude,
    )

  return (
    <section className="rounded-lg border-2 border-slate-950 bg-cyan-100 p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h2 className="text-2xl font-black text-slate-950">{mark.name}</h2>
          {mark.description && <p className="mt-1 text-lg font-bold text-slate-800">{mark.description}</p>}
        </div>
        <button
          type="button"
          onClick={requestPosition}
          className="tap-highlight min-h-12 shrink-0 rounded-md border-2 border-slate-950 bg-white px-4 text-lg font-black text-slate-950"
        >
          Refresh
        </button>
      </div>

      {status === 'loading' && (
        <div className="mt-4 rounded-md bg-white p-4 text-2xl font-black text-slate-950">
          Getting GPS position...
        </div>
      )}

      {status === 'error' && (
        <div className="mt-4 rounded-md border-2 border-red-900 bg-red-100 p-4 text-xl font-black text-red-950">
          {errorMessage}
        </div>
      )}

      {position && typeof displayedBearing === 'number' && typeof distance === 'number' && (
        <div className={`mt-4 grid gap-3 ${compact ? 'grid-cols-2' : 'grid-cols-1 sm:grid-cols-2'}`}>
          <ResultTile label="Bearing">
            {formatBearing(displayedBearing)} {bearingMode}
          </ResultTile>
          <ResultTile label="Distance">{formatDistanceNm(distance)}</ResultTile>
          <ResultTile label="Accuracy">±{Math.round(position.coords.accuracy)} m</ResultTile>
          <ResultTile label="Updated">{formatUpdatedTime(position.timestamp)}</ResultTile>
        </div>
      )}
    </section>
  )
}
