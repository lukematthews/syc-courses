import type { Mark } from '../data/marks'
import { QuickBearingResult } from './QuickBearingResult'

type MarkBearingInlinePanelProps = {
  mark: Mark
}

export function MarkBearingInlinePanel({ mark }: MarkBearingInlinePanelProps) {
  return (
    <div className="border-t-2 border-slate-950 bg-cyan-50 p-3">
      <QuickBearingResult mark={mark} compact />
    </div>
  )
}
