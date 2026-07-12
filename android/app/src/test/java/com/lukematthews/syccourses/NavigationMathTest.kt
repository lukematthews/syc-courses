package com.lukematthews.syccourses

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class NavigationMathTest {
    @Test
    fun bearingDueNorthIsZero() {
        assertEquals(0.0, NavigationMath.bearing(-37.9, 145.0, -37.8, 145.0), 0.001)
    }

    @Test
    fun oneMinuteLatitudeIsApproximatelyOneNauticalMile() {
        assertEquals(1.0, NavigationMath.distanceNm(-38.0, 145.0, -37.983333333, 145.0), 0.01)
    }

    @Test
    fun parserReadsValidRmcFix() {
        val fix = NmeaParser.parse("\$GPRMC,092751.000,A,3751.6500,S,14459.5000,E,5.5,123.4,120726,,,A*00", null)
        assertNotNull(fix)
        assertEquals(-37.860833, fix!!.latitude, 0.00001)
        assertEquals(144.991667, fix.longitude, 0.00001)
        assertEquals(5.5, fix.sogKnots!!, 0.001)
        assertEquals(NavigationSource.ACTISENSE, fix.source)
    }

    @Test
    fun encodedWaypointHasValidChecksums() {
        val fix = NavigationFix(-37.9, 145.0, 6.2, 90.0, source = NavigationSource.PHONE_GPS)
        val mark = Mark("m", "SYC 4", latitude = -37.89, longitude = 145.01)
        NmeaEncoder.waypoint(fix, mark).forEach { sentence ->
            val body = sentence.substring(1).substringBefore('*')
            val expected = body.fold(0) { value, char -> value xor char.code }
            assertEquals(expected.toString(16).uppercase().padStart(2, '0'), sentence.substringAfter('*'))
        }
    }
}
