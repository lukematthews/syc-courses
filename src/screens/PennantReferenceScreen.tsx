import { useMemo, useState } from 'react'
import { PennantReference } from '../components/PennantReference'
import { PennantStrip } from '../components/PennantStrip'
import { courses } from '../data/courses'
import { laidCourses } from '../data/laidCourses'

type PennantReferenceScreenProps = {
  onBack: () => void
  onOpenCourse: (courseNumber: number) => void
}

const allCourseNumbers = new Set([...courses, ...laidCourses].map((course) => course.courseNumber))

export function PennantReferenceScreen({ onBack, onOpenCourse }: PennantReferenceScreenProps) {
  const [selectedDigits, setSelectedDigits] = useState('')
  const selectedCourseNumber = selectedDigits ? Number(selectedDigits) : null
  const canGo = selectedCourseNumber !== null && allCourseNumbers.has(selectedCourseNumber)
  const statusText = useMemo(() => {
    if (!selectedDigits) {
      return 'Tap flags to select a course'
    }
    if (canGo) {
      return `Course ${selectedDigits} ready`
    }
    return `No course ${selectedDigits}`
  }, [canGo, selectedDigits])

  function selectDigit(digit: string) {
    setSelectedDigits((current) => {
      const next = `${current}${digit}`.replace(/^0+/, '')
      return next.slice(0, 2)
    })
  }

  function goToCourse() {
    if (canGo && selectedCourseNumber !== null) {
      onOpenCourse(selectedCourseNumber)
    }
  }

  return (
    <main className="safe-page app-page">
      <header className="app-header sticky top-0 z-10 border-b border-white/10 px-4 pb-4 pt-[max(14px,env(safe-area-inset-top))]">
        <button
          type="button"
          onClick={onBack}
          className="nav-button tap-highlight rounded-md px-4 text-xl font-black"
        >
          ← Courses
        </button>
        <h1 className="mt-4 text-5xl font-black leading-none">Flags</h1>
      </header>

      <div className="mx-auto flex w-full max-w-xl flex-col gap-5 px-4 py-5">
        <section className="surface-strong rounded-lg p-4">
          <div className="flex items-start justify-between gap-4">
            <div className="min-w-0">
              <h2 className="text-2xl font-black text-slate-950">Quick Select</h2>
              <p className="mt-1 text-lg font-bold text-slate-700">{statusText}</p>
            </div>
            {selectedDigits && (
              <div className="min-w-16 text-right text-5xl font-black leading-none text-slate-950">
                {selectedDigits}
              </div>
            )}
          </div>

          {selectedDigits && (
            <div className="mt-4 flex min-h-28 items-center justify-center rounded-lg bg-slate-100 p-3">
              <PennantStrip courseNumber={selectedDigits} size="md" layout="stack" />
            </div>
          )}

          <div className="mt-4 grid grid-cols-3 gap-3">
            <button
              type="button"
              onClick={goToCourse}
              disabled={!canGo}
              className="tap-highlight min-h-12 rounded-md bg-slate-950 px-4 text-xl font-black text-white disabled:bg-slate-300 disabled:text-slate-600"
            >
              Go
            </button>
            <button
              type="button"
              onClick={() => setSelectedDigits((current) => current.slice(0, -1))}
              disabled={!selectedDigits}
              className="tap-highlight min-h-12 rounded-md border border-slate-300 bg-white px-4 text-xl font-black text-slate-950 disabled:text-slate-400"
            >
              Delete
            </button>
            <button
              type="button"
              onClick={() => setSelectedDigits('')}
              disabled={!selectedDigits}
              className="tap-highlight min-h-12 rounded-md border border-slate-300 bg-white px-4 text-xl font-black text-slate-950 disabled:text-slate-400"
            >
              Reset
            </button>
          </div>
        </section>

        <PennantReference selectedDigits={selectedDigits} onSelectDigit={selectDigit} />
      </div>
    </main>
  )
}
