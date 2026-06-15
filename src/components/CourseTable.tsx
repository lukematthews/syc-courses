import { Fragment, useState } from 'react'
import { MarkBearingInlinePanel } from './MarkBearingInlinePanel'
import type { CourseRow } from '../data/courses'
import { findMarkByName } from '../data/marks'

type CourseTableProps = {
  rows: CourseRow[]
}

export function CourseTable({ rows }: CourseTableProps) {
  const [expandedRowIndex, setExpandedRowIndex] = useState<number | null>(null)

  return (
    <div className="overflow-hidden rounded-lg border-2 border-slate-950 bg-white">
      <table className="w-full table-fixed border-collapse text-left">
        <thead className="bg-slate-950 text-white">
          <tr>
            <th className="w-[36%] px-2 py-3 text-lg font-black">Mark</th>
            <th className="w-[20%] px-2 py-3 text-lg font-black">Side</th>
            <th className="w-[22%] px-2 py-3 text-lg font-black">Bearing</th>
            <th className="w-[22%] px-2 py-3 text-lg font-black">Distance</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row, index) => {
            const isSummary = row.mark === 'TOTAL' || row.mark === 'SUB-TOTAL'
            const mark = !isSummary && row.mark !== 'FINISH' ? findMarkByName(row.mark) : undefined
            const isExpanded = expandedRowIndex === index
            const rowContent = (
              <>
                <td className="break-words px-2 py-4 text-lg font-black text-slate-950">
                  <span>{row.mark}</span>
                  {mark && <span className="mt-1 block text-sm font-black text-cyan-800">bearing ›</span>}
                </td>
                <td className="break-words px-2 py-4 text-lg font-bold text-slate-900">
                  {row.side}
                </td>
                <td className="break-words px-2 py-4 text-lg font-bold text-slate-900">
                  {row.bearing}
                </td>
                <td className="break-words px-2 py-4 text-lg font-black text-slate-950">
                  {row.distance}
                </td>
              </>
            )

            return (
              <Fragment key={`${row.mark}-${index}`}>
                {mark ? (
                  <tr
                    onClick={() => setExpandedRowIndex(isExpanded ? null : index)}
                    className={`tap-highlight cursor-pointer border-t-2 border-slate-200 ${
                      isExpanded ? 'bg-cyan-50' : ''
                    }`}
                  >
                    {rowContent}
                  </tr>
                ) : (
                  <tr
                    className={`border-t-2 ${
                      isSummary ? 'border-slate-950 bg-slate-100' : 'border-slate-200'
                    }`}
                  >
                    {rowContent}
                  </tr>
                )}
                {mark && isExpanded && (
                  <tr>
                    <td colSpan={4} className="p-0">
                      <MarkBearingInlinePanel mark={mark} />
                    </td>
                  </tr>
                )}
              </Fragment>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
