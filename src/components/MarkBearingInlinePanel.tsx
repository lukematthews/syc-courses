import type { Mark } from '../data/marks'
import { QuickBearingResult } from './QuickBearingResult'

type MarkBearingInlinePanelProps = {
  mark: Mark
}

export function MarkBearingInlinePanel({ mark }: MarkBearingInlinePanelProps) {
  return (
    <div className="border-t border-slate-200 bg-cyan-50 p-3">
      <QuickBearingResult mark={mark} compact />
    </div>
  )
}
