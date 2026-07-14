package com.lukematthews.syccourses

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Test

class CoursePackModelTest {
    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun courseUsesCompoundIdentityAndExplicitKind() {
        val course = json.decodeFromString<Course>(
            """{
                "id":"sandringham-yacht-club-2025-2028/fixed/course-4",
                "packId":"sandringham-yacht-club-2025-2028",
                "kind":"fixed",
                "courseNumber":4,
                "rows":[]
            }""",
        )

        assertEquals("sandringham-yacht-club-2025-2028/fixed/course-4", course.id)
        assertEquals(CourseKind.fixed, course.kind)
        assertEquals(4, course.courseNumber)
    }

    @Test
    fun packDefinesNavigationMarksByStableId() {
        val pack = json.decodeFromString<CoursePack>(
            """{
                "schemaVersion":1,
                "packId":"test-pack",
                "assetNamespace":"test",
                "name":"Test Pack",
                "shortName":"Test",
                "organiser":"Test Club",
                "version":"1",
                "source":{"type":"official-course-booklet","title":"Test Instructions"},
                "courseKinds":["fixed"],
                "navigation":{
                    "startLineMarkIds":["tower","outer"],
                    "finishLineMarkIds":["tower","outer"],
                    "startFinishMarkId":"outer"
                },
                "resources":{
                    "fixedCourses":"fixed-courses.json",
                    "laidCourses":"laid-courses.json",
                    "marks":"marks.json",
                    "courseCharts":"/course-charts/test"
                }
            }""",
        )

        assertEquals(listOf("tower", "outer"), pack.navigation.startLineMarkIds)
        assertEquals("outer", pack.navigation.startFinishMarkId)
    }
}
