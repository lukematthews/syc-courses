import * as Collapsible from '@radix-ui/react-collapsible'
import { useState, type ReactNode } from 'react'
import { allCourses, courseGroups, coursePack } from '../data/bundledCoursePack'
import { CourseCard } from '../components/CourseCard'
import { QuickBearingCard } from '../components/QuickBearingCard'

const courseSectionOpenState: Record<string, boolean> = {}

type CourseListScreenProps = {
  onOpenCourse: (courseId: string) => void
  onOpenPennants: () => void
  onOpenQuickBearing: () => void
}

type CollapsibleCourseSectionProps = {
  title: string
  count: number
  sectionKey: string
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
          className={`course-scroll-panel rounded-lg border p-2 pr-2 ${contentToneClasses}`}
        >
          <div className="space-y-3">{children}</div>
        </Collapsible.Content>
      </section>
    </Collapsible.Root>
  )
}

export function CourseListScreen({
  onOpenCourse,
  onOpenPennants,
  onOpenQuickBearing,
}: CourseListScreenProps) {
  return (
    <main className="safe-page app-page">
      <header className="app-header px-5 pb-6 pt-[max(28px,env(safe-area-inset-top))]">
        <p className="text-lg font-black uppercase tracking-wide text-cyan-100">Race-day reference</p>
        <h1 className="mt-2 text-5xl font-black leading-none">{coursePack.name}</h1>
      </header>

      <div className="mx-auto flex w-full max-w-xl flex-col gap-5 px-4 py-4">
        <QuickBearingCard onOpen={onOpenQuickBearing} />

        <button
          type="button"
          onClick={onOpenPennants}
          className="action-card tap-highlight rounded-lg bg-cyan-50 p-4 text-left"
        >
          <div className="text-3xl font-black leading-none text-cyan-950">Flags</div>
        </button>

        {courseGroups.map((group) => {
          const groupedCourses = allCourses.filter((course) => (course.groupId ?? course.kind) === group.id)
          if (!groupedCourses.length) return null
          return (
            <CollapsibleCourseSection key={group.id} title={group.name} count={groupedCourses.length} sectionKey={group.id} tone={group.kind}>
              {groupedCourses.map((course) => <CourseCard key={course.id} course={course} onOpen={onOpenCourse} />)}
            </CollapsibleCourseSection>
          )
        })}
      </div>
    </main>
  )
}
