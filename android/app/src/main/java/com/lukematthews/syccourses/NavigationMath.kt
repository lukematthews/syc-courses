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

    fun lineCrossing(
        fix: NavigationFix?,
        a: Mark,
        b: Mark,
        geometry: BoatGeometrySettings = BoatGeometrySettings(),
    ): LineCrossingResult {
        if (fix == null || !fix.usable) return LineCrossingResult(LineCrossingStatus.NO_GPS)
        val reference = boatReferencePoint(fix, geometry)
        val referenceFix = fix.copy(latitude = reference.latitude, longitude = reference.longitude)
        val distanceToSegment = distanceToSegment(referenceFix, a, b)
        val gpsDistance = distanceToSegment(fix, a, b)
        val bowGain = if (reference.point == ReferencePoint.BOW) gpsDistance - distanceToSegment(referenceFix, a, b) else null
        val cog = fix.cogDegrees ?: return LineCrossingResult(LineCrossingStatus.NO_COG, distanceToSegment, referencePoint = reference.point, bowOffsetApplied = reference.applied, degradedReason = reference.degraded, bowGainToLineMeters = bowGain)
        val speed = fix.sogKnots?.takeIf { it > .2 } ?: return LineCrossingResult(LineCrossingStatus.NO_SOG, distanceToSegment, referencePoint = reference.point, bowOffsetApplied = reference.applied, degradedReason = reference.degraded, bowGainToLineMeters = bowGain)
        val latScale = 111_320.0
        val lonScale = latScale * cos(Math.toRadians(referenceFix.latitude))
        fun xy(mark: Mark) = Pair((mark.longitude - referenceFix.longitude) * lonScale, (mark.latitude - referenceFix.latitude) * latScale)
        val p1 = xy(a); val p2 = xy(b)
        val directionX = sin(Math.toRadians(cog)); val directionY = cos(Math.toRadians(cog))
        val lineX = p2.first - p1.first; val lineY = p2.second - p1.second
        val denominator = directionX * lineY - directionY * lineX
        fun result(status: LineCrossingStatus, distance: Double? = distanceToSegment, seconds: Double? = null) = LineCrossingResult(status, distance, seconds, reference.point, reference.applied, reference.degraded, bowGain)
        if (abs(denominator) < 1e-8) return result(LineCrossingStatus.PARALLEL)
        val t = (p1.first * lineY - p1.second * lineX) / denominator
        val u = (p1.first * directionY - p1.second * directionX) / denominator
        if (t < 0) return result(LineCrossingStatus.MOVING_AWAY)
        if (u !in 0.0..1.0) return result(LineCrossingStatus.OUTSIDE_SEGMENT)
        val seconds = t / (speed * .514444)
        return result(if (t <= 25 || seconds <= 10) LineCrossingStatus.CROSSING_AHEAD else LineCrossingStatus.APPROACHING, t, seconds)
    }

    private data class BoatReference(val latitude: Double, val longitude: Double, val point: ReferencePoint, val applied: Boolean, val degraded: DegradedReason?)

    private fun boatReferencePoint(fix: NavigationFix, geometry: BoatGeometrySettings): BoatReference {
        if (!geometry.useBowOffset) return BoatReference(fix.latitude, fix.longitude, ReferencePoint.GPS, false, DegradedReason.DISABLED)
        if (!geometry.bowOffsetMeters.isFinite() || geometry.bowOffsetMeters <= 0) return BoatReference(fix.latitude, fix.longitude, ReferencePoint.GPS, false, DegradedReason.MISSING_GEOMETRY)
        val bearing = when (geometry.bearingSource) { BearingSource.COG -> fix.cogDegrees; BearingSource.HEADING -> fix.headingDegrees }
            ?: return BoatReference(fix.latitude, fix.longitude, ReferencePoint.GPS, false, if (geometry.bearingSource == BearingSource.HEADING) DegradedReason.MISSING_HEADING else null)
        var projected = project(fix.latitude, fix.longitude, geometry.bowOffsetMeters, bearing)
        if (geometry.gpsOffsetStarboardMeters != 0.0) {
            val sidewaysBearing = if (geometry.gpsOffsetStarboardMeters > 0) bearing - 90 else bearing + 90
            projected = project(projected.first, projected.second, abs(geometry.gpsOffsetStarboardMeters), sidewaysBearing)
        }
        return BoatReference(projected.first, projected.second, ReferencePoint.BOW, true, null)
    }

    private fun project(latitude: Double, longitude: Double, distanceMeters: Double, bearingDegrees: Double): Pair<Double, Double> {
        val angular = distanceMeters / EARTH_RADIUS_METERS
        val bearing = Math.toRadians((bearingDegrees % 360 + 360) % 360)
        val lat = Math.toRadians(latitude); val lon = Math.toRadians(longitude)
        val newLat = asin(sin(lat) * cos(angular) + cos(lat) * sin(angular) * cos(bearing))
        val newLon = lon + atan2(sin(bearing) * sin(angular) * cos(lat), cos(angular) - sin(lat) * sin(newLat))
        return Math.toDegrees(newLat) to Math.toDegrees(newLon)
    }

    private fun distanceToSegment(fix: NavigationFix, a: Mark, b: Mark): Double {
        val latScale = 111_320.0; val lonScale = latScale * cos(Math.toRadians(fix.latitude))
        val ax = (a.longitude - fix.longitude) * lonScale; val ay = (a.latitude - fix.latitude) * latScale
        val bx = (b.longitude - fix.longitude) * lonScale; val by = (b.latitude - fix.latitude) * latScale
        val dx = bx - ax; val dy = by - ay; val lengthSquared = dx * dx + dy * dy
        if (lengthSquared <= 0) return hypot(ax, ay)
        val projection = (-(ax * dx + ay * dy) / lengthSquared).coerceIn(0.0, 1.0)
        return hypot(ax + projection * dx, ay + projection * dy)
    }
}
