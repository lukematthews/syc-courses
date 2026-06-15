import { CourseTable } from '../components/CourseTable'
import { PennantStrip } from '../components/PennantStrip'
import type { Course } from '../data/courses'

type CourseDetailScreenProps = {
  course: Course
  onBack: () => void
}

export function CourseDetailScreen({ course, onBack }: CourseDetailScreenProps) {
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
        <div className="mt-4 flex items-end justify-between gap-4">
          <h1 className="text-5xl font-black leading-none">Course {course.courseNumber}</h1>
          <div className="shrink-0">
            <PennantStrip courseNumber={course.courseNumber} size="md" layout="stack" />
          </div>
        </div>
      </header>

      <div className="mx-auto flex w-full max-w-xl flex-col gap-5 px-4 py-5">
        <section className="surface-strong rounded-lg bg-amber-50 p-4">
          <h2 className="text-xl font-black text-slate-950">Passing Instruction</h2>
          <p className="mt-1 text-2xl font-black leading-tight text-slate-950">{course.passInstruction}</p>
          {course.comparableCourseNote && (
            <p className="mt-3 text-xl font-bold text-slate-950">{course.comparableCourseNote}</p>
          )}
        </section>

        <section className="space-y-3">
          <h2 className="text-2xl font-black text-slate-950">Course Table</h2>
          <CourseTable rows={course.rows} />
        </section>

        <section className="space-y-3">
          <h2 className="text-2xl font-black text-slate-950">Chart</h2>
          <div className="surface overflow-hidden rounded-lg">
            <img className="block w-full" src={course.chartImage} alt={course.chartAlt} />
          </div>
        </section>

        {course.totalDistance && (
          <section className="surface rounded-lg p-4">
            <h2 className="text-xl font-black text-slate-950">Total Distance</h2>
            <p className="mt-1 text-4xl font-black text-slate-950">{course.totalDistance}</p>
          </section>
        )}
      </div>
    </main>
  )
}
