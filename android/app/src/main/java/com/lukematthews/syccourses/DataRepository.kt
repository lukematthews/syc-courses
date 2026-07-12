package com.lukematthews.syccourses

import android.content.Context
import kotlinx.serialization.json.Json

class DataRepository(context: Context) {
    private val assets = context.assets
    private val json = Json { ignoreUnknownKeys = true }

    val fixedCourses: List<Course> by lazy { decode("fixed-courses.json") }
    val laidCourses: List<Course> by lazy { decode("laid-courses.json") }
    val marks: List<Mark> by lazy { decode("marks.json") }
    val allCourses: List<Course> get() = fixedCourses + laidCourses

    private inline fun <reified T> decode(file: String): T =
        json.decodeFromString(assets.open(file).bufferedReader().use { it.readText() })

    fun course(number: Int) = allCourses.firstOrNull { it.courseNumber == number }
    fun markById(id: String) = marks.firstOrNull { it.id == id }

    fun mark(named: String): Mark? {
        val key = named.normalizedMarkName()
        val lookup = if (key == "start" || key == "finish") "syc 4" else key
        return marks.firstOrNull { mark ->
            mark.name.normalizedMarkName() == lookup || mark.aliases.any { it.normalizedMarkName() == lookup }
        }
    }
}

fun String.normalizedMarkName(): String = replace(Regex("\\s*\\([^)]*\\)"), "")
    .replace(Regex("\\s+"), " ").trim().lowercase()
