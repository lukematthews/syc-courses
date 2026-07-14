package com.lukematthews.syccourses

import org.junit.Assert.assertEquals
import org.junit.Test

class PortPhillipProjectionTest {
    @Test
    fun centralMeridianHasStandardUtmEasting() {
        val point = PortPhillipProjection.project(-38.0, 147.0)
        assertEquals(500_000.0, point.easting, 0.001)
    }

    @Test
    fun projectedMetresMatchNavigationDistanceAroundSyc() {
        val syc = PortPhillipProjection.project(-37.946833, 144.99)
        val north = PortPhillipProjection.project(-37.936833, 144.99)
        val projectedDistance = kotlin.math.hypot(north.easting - syc.easting, north.northing - syc.northing)
        val geodesicDistance = NavigationMath.distanceMeters(-37.946833, 144.99, -37.936833, 144.99)
        // NavigationMath uses a spherical Earth while MGA uses the WGS84 ellipsoid.
        assertEquals(geodesicDistance, projectedDistance, 5.0)
    }
}
