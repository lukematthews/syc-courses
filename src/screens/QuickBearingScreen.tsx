import { useState } from 'react'
import { MarkList } from '../components/MarkList'
import { QuickBearingResult } from '../components/QuickBearingResult'
import { marks, type Mark } from '../data/marks'

type QuickBearingScreenProps = {
  onBack: () => void
}

export function QuickBearingScreen({ onBack }: QuickBearingScreenProps) {
  const [selectedMark, setSelectedMark] = useState<Mark | null>(null)

  return (
    <main className="safe-page bg-slate-100">
      <header className="sticky top-0 z-10 border-b-2 border-slate-950 bg-slate-950 px-4 pb-4 pt-[max(14px,env(safe-area-inset-top))] text-white">
        <button
          type="button"
          onClick={onBack}
          className="tap-highlight min-h-12 rounded-md border-2 border-white px-4 text-xl font-black"
        >
          ← Courses
        </button>
        <h1 className="mt-4 text-5xl font-black leading-none">Quick Bearing</h1>
      </header>

      <div className="mx-auto flex w-full max-w-xl flex-col gap-5 px-4 py-5">
        {selectedMark && <QuickBearingResult mark={selectedMark} />}

        <section className="space-y-3">
          <h2 className="text-2xl font-black text-slate-950">Choose a mark</h2>
          <MarkList
            marks={marks}
            selectedMarkId={selectedMark?.id}
            onSelectMark={setSelectedMark}
          />
        </section>
      </div>
    </main>
  )
}
