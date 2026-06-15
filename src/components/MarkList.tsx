import type { Mark } from '../data/marks'

type MarkListProps = {
  marks: Mark[]
  selectedMarkId?: string
  onSelectMark: (mark: Mark) => void
}

export function MarkList({ marks, selectedMarkId, onSelectMark }: MarkListProps) {
  return (
    <div className="space-y-4">
      {marks.map((mark) => (
        <button
          key={mark.id}
          type="button"
          onClick={() => onSelectMark(mark)}
          className={`action-card tap-highlight w-full rounded-lg p-4 text-left ${
            selectedMarkId === mark.id
              ? 'border-cyan-700 bg-cyan-50'
              : 'border-slate-200 bg-white'
          }`}
        >
          <div className="flex items-center justify-between gap-4">
            <div>
              <div className="text-3xl font-black leading-none text-slate-950">{mark.name}</div>
              {mark.description && (
                <div className="mt-2 text-lg font-bold text-slate-800">{mark.description}</div>
              )}
            </div>
            <div className="text-3xl font-black text-slate-950">›</div>
          </div>
        </button>
      ))}
    </div>
  )
}
