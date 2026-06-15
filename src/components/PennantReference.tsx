import { pennants } from '../data/pennants'
import { PennantStrip } from './PennantStrip'

export function PennantReference() {
  return (
    <div className="grid grid-cols-2 gap-4">
      {pennants.map((pennant) => (
        <div
          key={pennant.digit}
          className="rounded-lg border-2 border-slate-950 bg-white p-4 shadow-[0_4px_0_#07111f]"
        >
          <PennantStrip courseNumber={pennant.digit} size="lg" showLabels />
          <div className="mt-2 text-xl font-black text-slate-950">Digit {pennant.digit}</div>
        </div>
      ))}
    </div>
  )
}
