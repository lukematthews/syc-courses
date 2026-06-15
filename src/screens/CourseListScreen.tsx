import * as Collapsible from '@radix-ui/react-collapsible'
import { useState, type ReactNode } from 'react'
import type { Course } from '../data/courses'
import { CourseCard } from '../components/CourseCard'
import { PennantStrip } from '../components/PennantStrip'
import { QuickBearingCard } from '../components/QuickBearingCard'
import { laidCourses } from '../data/laidCourses'

const courseSectionOpenState = {
  fixed: false,
  laid: false,
}

type CourseListScreenProps = {
  courses: Course[]
  onOpenCourse: (courseNumber: number) => void
  onOpenPennants: () => void
  onOpenQuickBearing: () => void
}

type CollapsibleCourseSectionProps = {
  title: string
  count: number
  sectionKey: keyof typeof courseSectionOpenState
  tone: 'fixed' | 'laid'
  children: ReactNode
}

function CollapsibleCourseSection({
  title,
  count,
  sectionKey,
  tone,
  children,
}: CollapsibleCourseSectionProps) {
  const [isOpen, setIsOpen] = useState(courseSectionOpenState[sectionKey])
  const toneClasses =
    tone === 'fixed'
      ? 'border-sky-200 bg-sky-100 text-sky-950'
      : 'border-amber-200 bg-amber-100 text-amber-950'
  const countClasses = tone === 'fixed' ? 'text-sky-800' : 'text-amber-800'
  const contentToneClasses =
    tone === 'fixed'
      ? 'border-sky-100 bg-sky-50/80'
      : 'border-amber-100 bg-amber-50/80'

  function handleOpenChange(next: boolean) {
    courseSectionOpenState[sectionKey] = next
    setIsOpen(next)
  }

  return (
    <Collapsible.Root className="space-y-2" open={isOpen} onOpenChange={handleOpenChange} asChild>
      <section>
        <Collapsible.Trigger
          className={`tap-highlight flex min-h-16 w-full items-center justify-between gap-4 rounded-lg border p-4 text-left shadow-sm ${toneClasses}`}
        >
          <div>
            <h2 className="text-2xl font-black leading-none">{title}</h2>
            <p className={`mt-2 text-lg font-bold ${countClasses}`}>{count} courses</p>
          </div>
          <span className="text-4xl font-black leading-none" aria-hidden="true">
            {isOpen ? '−' : '+'}
          </span>
        </Collapsible.Trigger>

        <Collapsible.Content
          className={`max-h-[58svh] overflow-y-auto overscroll-contain rounded-lg border p-2 pr-2 [-webkit-overflow-scrolling:touch] ${contentToneClasses}`}
        >
          <div className="space-y-3">{children}</div>
        </Collapsible.Content>
      </section>
    </Collapsible.Root>
  )
}

export function CourseListScreen({
  courses,
  onOpenCourse,
  onOpenPennants,
  onOpenQuickBearing,
}: CourseListScreenProps) {
  return (
    <main className="safe-page app-page">
      <header className="app-header px-5 pb-6 pt-[max(28px,env(safe-area-inset-top))]">
        <p className="text-lg font-black uppercase tracking-wide text-cyan-100">Race-day reference</p>
        <h1 className="mt-2 text-5xl font-black leading-none">SYC Courses</h1>
      </header>

      <div className="mx-auto flex w-full max-w-xl flex-col gap-5 px-4 py-4">
        <QuickBearingCard onOpen={onOpenQuickBearing} />

        <button
          type="button"
          onClick={onOpenPennants}
          className="action-card tap-highlight rounded-lg bg-cyan-50 p-4 text-left"
        >
          <div className="text-3xl font-black leading-none text-cyan-950">Pennant Reference</div>
          <div className="mt-3 flex items-center justify-between gap-3">
            <p className="text-xl font-bold text-cyan-950">Digits 0-9</p>
            <PennantStrip courseNumber="24" size="sm" layout="stack" />
          </div>
        </button>

        <CollapsibleCourseSection
          title="Fixed Mark Courses"
          count={courses.length}
          sectionKey="fixed"
          tone="fixed"
        >
          {courses.map((course) => (
            <CourseCard key={course.courseNumber} course={course} onOpen={onOpenCourse} />
          ))}
        </CollapsibleCourseSection>

        <CollapsibleCourseSection
          title="Laid Courses"
          count={laidCourses.length}
          sectionKey="laid"
          tone="laid"
        >
          {laidCourses.map((course) => (
            <CourseCard
              key={course.courseNumber}
              course={course}
              label="Course"
              onOpen={onOpenCourse}
            />
          ))}
        </CollapsibleCourseSection>
      </div>
    </main>
  )
}
