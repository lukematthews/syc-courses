import { pennants } from '../data/pennants'
import { PennantStrip } from './PennantStrip'

type PennantReferenceProps = {
  selectedDigits?: string
  onSelectDigit?: (digit: string) => void
}

export function PennantReference({ selectedDigits = '', onSelectDigit }: PennantReferenceProps) {
  return (
    <div className="grid grid-cols-2 gap-2">
      {pennants.map((pennant) => (
        <button
          key={pennant.digit}
          type="button"
          onClick={() => onSelectDigit?.(pennant.digit)}
          className={`surface tap-highlight rounded-lg p-2 transition active:scale-[0.99] ${
            selectedDigits.includes(pennant.digit) ? 'ring-4 ring-cyan-500' : ''
          }`}
        >
          <PennantStrip courseNumber={pennant.digit} size="lg" showLabels />
        </button>
      ))}
    </div>
  )
}
