import type { Course } from '../data/courses'
import { PennantStrip } from './PennantStrip'

type CourseCardProps = {
  course: Course
  onOpen: (courseNumber: number) => void
}

export function CourseCard({ course, onOpen }: CourseCardProps) {
  return (
    <button
      type="button"
      onClick={() => onOpen(course.courseNumber)}
      className="tap-highlight w-full rounded-lg border-2 border-slate-950 bg-white p-4 text-left shadow-[0_4px_0_#07111f] transition active:translate-y-1 active:shadow-none"
    >
      <div className="flex items-center justify-between gap-4">
        <div className="min-w-0">
          <div className="text-3xl font-black leading-none text-slate-950">
            Course {course.courseNumber}
          </div>
          {course.totalDistance && (
            <div className="mt-2 text-xl font-bold text-slate-800">{course.totalDistance}</div>
          )}
        </div>
        <div className="shrink-0">
          <PennantStrip courseNumber={course.courseNumber} size="sm" layout="stack" />
        </div>
      </div>
    </button>
  )
}
