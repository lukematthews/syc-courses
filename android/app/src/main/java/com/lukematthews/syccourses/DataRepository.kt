package com.lukematthews.syccourses

import android.content.Context
import kotlinx.serialization.json.Json

class DataRepository(context: Context) {
    private val assets = context.assets
    private val json = Json { ignoreUnknownKeys = true }

    val coursePack: CoursePack by lazy { decode("course-pack.json") }
    val fixedCourses: List<Course> by lazy { decode(coursePack.resources.fixedCourses) }
    val laidCourses: List<Course> by lazy { decode(coursePack.resources.laidCourses) }
    val marks: List<Mark> by lazy { decode(coursePack.resources.marks) }
    val portPhillipCoastline: CoastlineData by lazy { decode("port-phillip-coastline.json") }
    val allCourses: List<Course> get() = fixedCourses + laidCourses
    val courseGroups: List<CourseGroup> get() = coursePack.courseGroups.ifEmpty {
        coursePack.courseKinds.map { kind ->
            CourseGroup(kind.name, if (kind == CourseKind.fixed) "Fixed Mark Courses" else "Laid Courses", kind)
        }
    }

    fun courses(groupId: String) = allCourses.filter { (it.groupId ?: it.kind.name) == groupId }

    private inline fun <reified T> decode(file: String): T =
        json.decodeFromString(assets.open(file).bufferedReader().use { it.readText() })

    fun course(number: Int) = allCourses.firstOrNull { it.courseNumber == number }
    fun course(id: String) = allCourses.firstOrNull { it.id == id }
    fun markById(id: String) = marks.firstOrNull { it.id == id }
    fun startLineMarks() = coursePack.navigation.startLineMarkIds.mapNotNull(::markById)
    fun finishLineMarks() = coursePack.navigation.finishLineMarkIds.mapNotNull(::markById)
    fun startFinishMark() = markById(coursePack.navigation.startFinishMarkId)
    fun markHotspots(resource: String): List<MarkHotspot> = decode(resource)

    fun mark(named: String): Mark? {
        val key = named.normalizedMarkName()
        if (key == "start" || key == "finish") return startFinishMark()
        val lookup = key
        return marks.firstOrNull { mark ->
            mark.name.normalizedMarkName() == lookup || mark.aliases.any { it.normalizedMarkName() == lookup }
        }
    }
}

fun String.normalizedMarkName(): String = replace(Regex("\\s*\\([^)]*\\)"), "")
    .replace(Regex("\\s+"), " ").trim().lowercase()
