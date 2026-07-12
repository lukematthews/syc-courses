package com.lukematthews.syccourses

import kotlin.math.*

object NavigationMath {
    private const val EARTH_RADIUS_METERS = 6_371_000.0
    private const val METERS_PER_NM = 1852.0

    fun bearing(fromLat: Double, fromLon: Double, toLat: Double, toLon: Double): Double {
        val phi1 = Math.toRadians(fromLat)
        val phi2 = Math.toRadians(toLat)
        val delta = Math.toRadians(toLon - fromLon)
        val y = sin(delta) * cos(phi2)
        val x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(delta)
        return (Math.toDegrees(atan2(y, x)) + 360) % 360
    }

    fun distanceNm(fromLat: Double, fromLon: Double, toLat: Double, toLon: Double): Double =
        distanceMeters(fromLat, fromLon, toLat, toLon) / METERS_PER_NM

    fun distanceMeters(fromLat: Double, fromLon: Double, toLat: Double, toLon: Double): Double {
        val dLat = Math.toRadians(toLat - fromLat)
        val dLon = Math.toRadians(toLon - fromLon)
        val p1 = Math.toRadians(fromLat)
        val p2 = Math.toRadians(toLat)
        val a = sin(dLat / 2).pow(2) + cos(p1) * cos(p2) * sin(dLon / 2).pow(2)
        return EARTH_RADIUS_METERS * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    fun snapshot(fix: NavigationFix, mark: Mark) = BearingSnapshot(
        bearingTrue = bearing(fix.latitude, fix.longitude, mark.latitude, mark.longitude),
        distanceNm = distanceNm(fix.latitude, fix.longitude, mark.latitude, mark.longitude),
        speedKnots = fix.sogKnots,
        accuracyMeters = fix.horizontalAccuracyMeters ?: fix.hdop?.times(5),
    )

    fun lineCrossing(fix: NavigationFix, a: Mark, b: Mark): LineCrossingResult {
        val cog = fix.cogDegrees ?: return LineCrossingResult("Course over ground unavailable")
        val speed = fix.sogKnots?.takeIf { it > .2 } ?: return LineCrossingResult("Speed unavailable")
        val latScale = 111_320.0
        val lonScale = latScale * cos(Math.toRadians(fix.latitude))
        fun xy(mark: Mark) = Pair((mark.longitude - fix.longitude) * lonScale, (mark.latitude - fix.latitude) * latScale)
        val p1 = xy(a); val p2 = xy(b)
        val directionX = sin(Math.toRadians(cog)); val directionY = cos(Math.toRadians(cog))
        val lineX = p2.first - p1.first; val lineY = p2.second - p1.second
        val denominator = directionX * lineY - directionY * lineX
        if (abs(denominator) < 1e-8) return LineCrossingResult("Moving parallel to line")
        val t = (p1.first * lineY - p1.second * lineX) / denominator
        val u = (p1.first * directionY - p1.second * directionX) / denominator
        if (t < 0) return LineCrossingResult("Moving away from line")
        val seconds = t / (speed * .514444)
        return LineCrossingResult(if (u in 0.0..1.0) "Crossing ahead" else "Crossing outside line", t, seconds)
    }
}
