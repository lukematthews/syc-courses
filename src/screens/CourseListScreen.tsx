import type { Course } from '../data/courses'
import { CourseCard } from '../components/CourseCard'
import { PennantStrip } from '../components/PennantStrip'
import { QuickBearingCard } from '../components/QuickBearingCard'
import { RecentlyViewed } from '../components/RecentlyViewed'

type CourseListScreenProps = {
  courses: Course[]
  recentCourseNumbers: number[]
  onOpenCourse: (courseNumber: number) => void
  onOpenPennants: () => void
  onOpenQuickBearing: () => void
}

export function CourseListScreen({
  courses,
  recentCourseNumbers,
  onOpenCourse,
  onOpenPennants,
  onOpenQuickBearing,
}: CourseListScreenProps) {
  return (
    <main className="safe-page bg-slate-100">
      <header className="bg-slate-950 px-5 pb-6 pt-[max(28px,env(safe-area-inset-top))] text-white">
        <p className="text-lg font-black uppercase tracking-wide text-cyan-200">Race-day reference</p>
        <h1 className="mt-2 text-5xl font-black leading-none">SYC Courses</h1>
      </header>

      <div className="mx-auto flex w-full max-w-xl flex-col gap-7 px-4 py-5">
        <RecentlyViewed
          courses={courses}
          recentCourseNumbers={recentCourseNumbers}
          onOpenCourse={onOpenCourse}
        />

        <QuickBearingCard onOpen={onOpenQuickBearing} />

        <button
          type="button"
          onClick={onOpenPennants}
          className="tap-highlight rounded-lg border-2 border-cyan-950 bg-cyan-100 p-4 text-left shadow-[0_4px_0_#083344] transition active:translate-y-1 active:shadow-none"
        >
          <div className="text-3xl font-black leading-none text-cyan-950">Pennant Reference</div>
          <div className="mt-3 flex items-center justify-between gap-3">
            <p className="text-xl font-bold text-cyan-950">Digits 0-9</p>
            <PennantStrip courseNumber="24" size="sm" layout="stack" />
          </div>
        </button>

        <section className="space-y-4">
          <h2 className="text-2xl font-black text-slate-950">All Courses</h2>
          <div className="space-y-4">
            {courses.map((course) => (
              <CourseCard key={course.courseNumber} course={course} onOpen={onOpenCourse} />
            ))}
          </div>
        </section>
      </div>
    </main>
  )
}
