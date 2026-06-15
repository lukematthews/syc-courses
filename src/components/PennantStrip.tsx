import { getPennant, type PennantDefinition } from '../data/pennants'

type PennantStripProps = {
  courseNumber: number | string
  size?: 'sm' | 'md' | 'lg'
  layout?: 'row' | 'stack'
  showLabels?: boolean
}

const sizeClasses = {
  sm: 'h-8 w-24',
  md: 'h-11 w-32',
  lg: 'h-20 w-full max-w-56',
}

function PennantIcon({ pennant, className }: { pennant: PennantDefinition; className: string }) {
  return (
    <img
      src={pennant.imageSrc}
      alt={`Pennant ${pennant.digit}`}
      className={`${className} select-none object-contain`}
      draggable={false}
    />
  )
}

export function PennantStrip({
  courseNumber,
  size = 'md',
  layout = 'row',
  showLabels = false,
}: PennantStripProps) {
  const digits = String(courseNumber).split('')
  const className = sizeClasses[size]
  const containerClassName =
    layout === 'stack'
      ? 'flex flex-col items-center gap-1'
      : 'flex flex-wrap items-center gap-2'

  return (
    <div className={containerClassName} aria-label={`Numeral pennants for ${courseNumber}`}>
      {digits.map((digit, index) => {
        const pennant = getPennant(digit)

        if (!pennant) {
          return null
        }

        return (
          <div key={`${digit}-${index}`} className="flex flex-col items-center gap-1">
            <PennantIcon pennant={pennant} className={className} />
            {showLabels && <span className="text-lg font-black text-slate-950">{digit}</span>}
          </div>
        )
      })}
    </div>
  )
}
