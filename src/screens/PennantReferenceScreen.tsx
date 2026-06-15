import { PennantReference } from '../components/PennantReference'

type PennantReferenceScreenProps = {
  onBack: () => void
}

export function PennantReferenceScreen({ onBack }: PennantReferenceScreenProps) {
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
        <h1 className="mt-4 text-5xl font-black leading-none">Pennants</h1>
      </header>

      <div className="mx-auto w-full max-w-xl px-4 py-5">
        <PennantReference />
      </div>
    </main>
  )
}
