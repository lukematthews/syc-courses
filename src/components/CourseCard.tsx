import type { Course } from '../data/bundledCoursePack'
import { PennantStrip } from './PennantStrip'

type CourseCardProps = {
  course: Course
  onOpen: (courseId: string) => void
  label?: string
}

export function CourseCard({ course, onOpen, label = 'Course' }: CourseCardProps) {
  return (
    <button
      type="button"
      onClick={() => onOpen(course.id)}
      className="action-card tap-highlight w-full rounded-lg p-4 text-left"
    >
      <div className="flex items-center justify-between gap-4">
        <div className="min-w-0">
          <div className="text-3xl font-black leading-none text-slate-950">
            {label} {course.courseNumber}
          </div>
          {course.totalDistance && (
            <div className="mt-2 text-xl font-bold text-slate-800">{course.totalDistance}</div>
          )}
          {course.route && <div className="mt-1 text-sm font-semibold text-slate-600">{course.route}</div>}
        </div>
        <div className="shrink-0">
          <PennantStrip courseNumber={course.courseNumber} size="sm" layout="stack" />
        </div>
      </div>
    </button>
  )
}
