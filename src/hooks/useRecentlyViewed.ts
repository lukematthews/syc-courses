import { useCallback, useState } from 'react'

const STORAGE_KEY = 'syc-courses.recently-viewed'
const MAX_RECENT = 5

function readRecentCourseNumbers() {
  try {
    if (typeof window === 'undefined') {
      return []
    }

    const rawValue = window.localStorage.getItem(STORAGE_KEY)

    if (!rawValue) {
      return []
    }

    const parsed = JSON.parse(rawValue)

    if (!Array.isArray(parsed)) {
      return []
    }

    return parsed.filter((value) => Number.isInteger(value)).slice(0, MAX_RECENT)
  } catch {
    return []
  }
}

export function useRecentlyViewed() {
  const [recentCourseNumbers, setRecentCourseNumbers] = useState<number[]>(readRecentCourseNumbers)

  const addRecentCourse = useCallback((courseNumber: number) => {
    setRecentCourseNumbers((current) => {
      const next = [courseNumber, ...current.filter((number) => number !== courseNumber)].slice(
        0,
        MAX_RECENT,
      )

      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(next))
      return next
    })
  }, [])

  return { recentCourseNumbers, addRecentCourse }
}
