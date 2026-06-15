import { PennantReference } from '../components/PennantReference'

type PennantReferenceScreenProps = {
  onBack: () => void
}

export function PennantReferenceScreen({ onBack }: PennantReferenceScreenProps) {
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
        <h1 className="mt-4 text-5xl font-black leading-none">Pennants</h1>
      </header>

      <div className="mx-auto w-full max-w-xl px-4 py-5">
        <PennantReference />
      </div>
    </main>
  )
}
