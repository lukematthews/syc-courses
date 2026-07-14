package com.lukematthews.syccourses

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class NmeaWifiGatewayTest {
    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun ydwgFactoryProfileUsesNmeaServerOneDefaults() {
        val gateway = NmeaWifiGateway.YACHT_DEVICES_YDWG_02

        assertEquals("192.168.4.1", gateway.defaultHost)
        assertEquals(1456, gateway.defaultPort)
        assertEquals(NetworkProtocol.TCP, gateway.defaultProtocol)
    }

    @Test
    fun legacySettingsMigrateToActisense() {
        val legacy = """{"inputEnabled":true,"host":"10.0.0.2","port":60002,"protocol":"TCP"}"""

        val settings = json.decodeFromString<ActisenseSettings>(legacy)

        assertEquals(NmeaWifiGateway.ACTISENSE_W2K2, settings.gateway)
        assertEquals("10.0.0.2", settings.host)
        assertEquals(60002, settings.port)
    }

    @Test
    fun parserReadsYdwgRapidPositionGllSentence() {
        val fix = NmeaParser.parse("\$GPGLL,3756.8100,S,14459.4000,E,092751.000,A,A*00", null)

        assertNotNull(fix)
        assertEquals(-37.946833, fix!!.latitude, 0.00001)
        assertEquals(144.99, fix.longitude, 0.00001)
        assertEquals(true, fix.validFix)
    }
}
