import { pennants } from '../data/pennants'
import { PennantStrip } from './PennantStrip'

export function PennantReference() {
  return (
    <div className="grid grid-cols-2 gap-4">
      {pennants.map((pennant) => (
        <div
          key={pennant.digit}
          className="surface rounded-lg p-4"
        >
          <PennantStrip courseNumber={pennant.digit} size="lg" showLabels />
        </div>
      ))}
    </div>
  )
}
