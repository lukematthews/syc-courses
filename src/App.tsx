import { useEffect, useMemo, useState } from 'react'
import { courses } from './data/courses'
import { laidCourses } from './data/laidCourses'
import { CourseDetailScreen } from './screens/CourseDetailScreen'
import { CourseListScreen } from './screens/CourseListScreen'
import { PennantReferenceScreen } from './screens/PennantReferenceScreen'
import { QuickBearingScreen } from './screens/QuickBearingScreen'

type Screen =
  | { name: 'courses' }
  | { name: 'detail'; courseNumber: number }
  | { name: 'pennants' }
  | { name: 'quick-bearing' }

function App() {
  const [screen, setScreen] = useState<Screen>({ name: 'courses' })

  useEffect(() => {
    window.scrollTo({ top: 0, left: 0, behavior: 'instant' })
  }, [screen])

  const selectedCourse = useMemo(() => {
    if (screen.name !== 'detail') {
      return undefined
    }

    return [...courses, ...laidCourses].find((course) => course.courseNumber === screen.courseNumber)
  }, [screen])

  if (screen.name === 'pennants') {
    return <PennantReferenceScreen onBack={() => setScreen({ name: 'courses' })} />
  }

  if (screen.name === 'quick-bearing') {
    return <QuickBearingScreen onBack={() => setScreen({ name: 'courses' })} />
  }

  if (screen.name === 'detail' && selectedCourse) {
    return (
      <CourseDetailScreen
        course={selectedCourse}
        onBack={() => setScreen({ name: 'courses' })}
      />
    )
  }

  return (
    <CourseListScreen
      courses={courses}
      onOpenCourse={(courseNumber) => setScreen({ name: 'detail', courseNumber })}
      onOpenPennants={() => setScreen({ name: 'pennants' })}
      onOpenQuickBearing={() => setScreen({ name: 'quick-bearing' })}
    />
  )
}

export default App
