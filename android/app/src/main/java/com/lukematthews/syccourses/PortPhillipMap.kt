package com.lukematthews.syccourses

import kotlin.math.*

data class ProjectedPoint(val easting: Double, val northing: Double)

/**
 * Projects WGS84 GPS fixes into MGA zone 55 metre coordinates. Around Port Phillip Bay,
 * WGS84 and GDA2020 are close enough for a race-track display, while the metre coordinates
 * ensure north/south and east/west are drawn at the same scale.
 */
object PortPhillipProjection {
    private const val SEMI_MAJOR_AXIS = 6_378_137.0
    private const val INVERSE_FLATTENING = 298.257223563
    private const val CENTRAL_MERIDIAN_DEGREES = 147.0
    private const val SCALE_FACTOR = 0.9996
    private const val FALSE_EASTING = 500_000.0
    private const val FALSE_NORTHING = 10_000_000.0

    fun project(latitude: Double, longitude: Double): ProjectedPoint {
        val flattening = 1.0 / INVERSE_FLATTENING
        val eccentricitySquared = flattening * (2.0 - flattening)
        val secondEccentricitySquared = eccentricitySquared / (1.0 - eccentricitySquared)
        val latitudeRadians = Math.toRadians(latitude)
        val longitudeDifference = Math.toRadians(longitude - CENTRAL_MERIDIAN_DEGREES)
        val sinLatitude = sin(latitudeRadians)
        val cosLatitude = cos(latitudeRadians)
        val tangent = tan(latitudeRadians)
        val radius = SEMI_MAJOR_AXIS / sqrt(1.0 - eccentricitySquared * sinLatitude.pow(2))
        val tangentSquared = tangent.pow(2)
        val longitudeTerm = cosLatitude * longitudeDifference
        val curvature = secondEccentricitySquared * cosLatitude.pow(2)

        val e2 = eccentricitySquared
        val meridionalArc = SEMI_MAJOR_AXIS * (
            (1.0 - e2 / 4.0 - 3.0 * e2.pow(2) / 64.0 - 5.0 * e2.pow(3) / 256.0) * latitudeRadians
                - (3.0 * e2 / 8.0 + 3.0 * e2.pow(2) / 32.0 + 45.0 * e2.pow(3) / 1024.0) * sin(2.0 * latitudeRadians)
                + (15.0 * e2.pow(2) / 256.0 + 45.0 * e2.pow(3) / 1024.0) * sin(4.0 * latitudeRadians)
                - (35.0 * e2.pow(3) / 3072.0) * sin(6.0 * latitudeRadians)
            )

        val easting = FALSE_EASTING + SCALE_FACTOR * radius * (
            longitudeTerm
                + (1.0 - tangentSquared + curvature) * longitudeTerm.pow(3) / 6.0
                + (5.0 - 18.0 * tangentSquared + tangentSquared.pow(2) + 72.0 * curvature - 58.0 * secondEccentricitySquared) * longitudeTerm.pow(5) / 120.0
            )
        val northing = FALSE_NORTHING + SCALE_FACTOR * (
            meridionalArc + radius * tangent * (
                longitudeTerm.pow(2) / 2.0
                    + (5.0 - tangentSquared + 9.0 * curvature + 4.0 * curvature.pow(2)) * longitudeTerm.pow(4) / 24.0
                    + (61.0 - 58.0 * tangentSquared + tangentSquared.pow(2) + 600.0 * curvature - 330.0 * secondEccentricitySquared) * longitudeTerm.pow(6) / 720.0
                )
            )
        return ProjectedPoint(easting, northing)
    }
}
