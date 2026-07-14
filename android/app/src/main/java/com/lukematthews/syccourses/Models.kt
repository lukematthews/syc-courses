package com.lukematthews.syccourses

import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

@Serializable
data class Course(
    val courseNumber: Int,
    val route: String? = null,
    val passInstruction: String = "",
    val rows: List<CourseLeg>,
    val totalDistance: String = "",
    val chartImage: String = "",
    val chartAlt: String = "",
    val dataStatus: String = "",
    val sourcePage: Int = 0,
    val comparableCourseNote: String? = null,
)

@Serializable
data class CourseLeg(val mark: String, val side: String, val bearing: String, val distance: String)

@Serializable
data class Mark(
    val id: String,
    val name: String,
    val aliases: List<String> = emptyList(),
    val latitude: Double,
    val longitude: Double,
    val description: String? = null,
    val coordinatesStatus: String = "",
)

@Serializable
data class CoastlineData(
    val attribution: String,
    val paths: List<List<List<Double>>>,
    val landPolygons: List<List<List<List<Double>>>> = emptyList(),
)

@Serializable
data class TrackPoint(val latitude: Double, val longitude: Double, val timestampMillis: Long)

@Serializable
data class SavedRaceTrack(
    val id: String = UUID.randomUUID().toString(),
    val startedAtMillis: Long = System.currentTimeMillis(),
    val name: String? = null,
    val endedAtMillis: Long = startedAtMillis,
    val points: List<TrackPoint> = emptyList(),
) {
    val displayName: String get() = name?.takeIf { it.isNotBlank() } ?: "Race ${Instant.ofEpochMilli(startedAtMillis)}"
}

data class NavigationFix(
    val latitude: Double,
    val longitude: Double,
    val sogKnots: Double? = null,
    val cogDegrees: Double? = null,
    val headingDegrees: Double? = null,
    val timestampMillis: Long = System.currentTimeMillis(),
    val source: NavigationSource,
    val horizontalAccuracyMeters: Double? = null,
    val hdop: Double? = null,
    val validFix: Boolean = true,
) {
    val usable: Boolean get() = validFix && latitude.isFinite() && longitude.isFinite() && latitude in -90.0..90.0 && longitude in -180.0..180.0
}

enum class NavigationSource { PHONE_GPS, ACTISENSE }
enum class NetworkProtocol { TCP, UDP }

@Serializable
data class ActisenseSettings(
    val inputEnabled: Boolean = false,
    val outputEnabled: Boolean = false,
    val host: String = "192.168.4.1",
    val port: Int = 60001,
    val protocol: NetworkProtocol = NetworkProtocol.TCP,
    val autoConnectOutput: Boolean = false,
)

data class BearingSnapshot(
    val bearingTrue: Double,
    val distanceNm: Double,
    val speedKnots: Double?,
    val accuracyMeters: Double?,
) {
    val timeToMarkSeconds: Double? get() = speedKnots?.takeIf { it > .2 }?.let { distanceNm / it * 3600 }
}

enum class LineMode { START, FINISH }

@Serializable
enum class BearingSource { COG, HEADING }

@Serializable
data class BoatGeometrySettings(
    val bowOffsetMeters: Double = 9.4,
    val gpsOffsetStarboardMeters: Double = 0.0,
    val useBowOffset: Boolean = true,
    val bearingSource: BearingSource = BearingSource.COG,
)

enum class LineCrossingStatus {
    APPROACHING, CROSSING_AHEAD, OUTSIDE_SEGMENT, PARALLEL, MOVING_AWAY,
    NO_GPS, NO_COG, NO_SOG,
}

enum class ReferencePoint { GPS, BOW }
enum class DegradedReason { MISSING_HEADING, MISSING_GEOMETRY, DISABLED }

data class LineCrossingResult(
    val status: LineCrossingStatus,
    val distanceMeters: Double? = null,
    val secondsToLine: Double? = null,
    val referencePoint: ReferencePoint = ReferencePoint.GPS,
    val bowOffsetApplied: Boolean = false,
    val degradedReason: DegradedReason? = null,
    val bowGainToLineMeters: Double? = null,
)
