import type { Course } from '../data/bundledCoursePack'
import { CourseCard } from './CourseCard'

type RecentlyViewedProps = {
  courses: Course[]
  recentCourseNumbers: number[]
  onOpenCourse: (courseId: string) => void
}

export function RecentlyViewed({ courses, recentCourseNumbers, onOpenCourse }: RecentlyViewedProps) {
  const recentCourses = recentCourseNumbers
    .map((courseNumber) => courses.find((course) => course.courseNumber === courseNumber))
    .filter((course): course is Course => Boolean(course))

  if (recentCourses.length === 0) {
    return null
  }

  return (
    <section className="space-y-3">
      <h2 className="text-2xl font-black text-slate-950">Recently Viewed</h2>
      <div className="space-y-4">
        {recentCourses.map((course) => (
          <CourseCard key={course.id} course={course} onOpen={onOpenCourse} />
        ))}
      </div>
    </section>
  )
}
