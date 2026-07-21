import { useEffect, useMemo, useState } from 'react'
import { allCourses } from './data/bundledCoursePack'
import { CourseDetailScreen } from './screens/CourseDetailScreen'
import { CourseListScreen } from './screens/CourseListScreen'
import { PennantReferenceScreen } from './screens/PennantReferenceScreen'
import { QuickBearingScreen } from './screens/QuickBearingScreen'

type Screen =
  | { name: 'courses' }
  | { name: 'detail'; courseId: string }
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

    return allCourses.find((course) => course.id === screen.courseId)
  }, [screen])

  if (screen.name === 'pennants') {
    return (
      <PennantReferenceScreen
        onBack={() => setScreen({ name: 'courses' })}
        onOpenCourse={(courseNumber) => {
          const course = allCourses.find((candidate) => candidate.courseNumber === courseNumber)
          if (course) setScreen({ name: 'detail', courseId: course.id })
        }}
      />
    )
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
      onOpenCourse={(courseId) => setScreen({ name: 'detail', courseId })}
      onOpenPennants={() => setScreen({ name: 'pennants' })}
      onOpenQuickBearing={() => setScreen({ name: 'quick-bearing' })}
    />
  )
}

export default App
