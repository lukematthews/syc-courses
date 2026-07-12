package com.lukematthews.syccourses

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.isActive
import kotlinx.coroutines.withContext
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.time.LocalDate
import java.time.ZoneOffset
import kotlin.coroutines.coroutineContext

class ActisenseClient(
    private val settings: ActisenseSettings,
    private val onStatus: (String) -> Unit,
    private val onFix: (NavigationFix) -> Unit,
) {
    private var tcp: Socket? = null
    private var udp: DatagramSocket? = null
    private var lastFix: NavigationFix? = null

    suspend fun connect() = withContext(Dispatchers.IO) {
        runCatching {
            onStatus("Connecting")
            when (settings.protocol) {
                NetworkProtocol.TCP -> {
                    val socket = Socket().apply { connect(InetSocketAddress(settings.host, settings.port), 5000) }
                    tcp = socket
                    onStatus("Connected")
                    if (settings.inputEnabled) socket.getInputStream().bufferedReader(Charsets.US_ASCII).useLines { lines ->
                        lines.takeWhile { coroutineContext.isActive }.forEach(::ingest)
                    }
                }
                NetworkProtocol.UDP -> {
                    val socket = DatagramSocket().apply { connect(InetAddress.getByName(settings.host), settings.port) }
                    udp = socket
                    onStatus("Connected")
                    if (settings.inputEnabled) {
                        val bytes = ByteArray(4096)
                        while (coroutineContext.isActive && !socket.isClosed) {
                            val packet = DatagramPacket(bytes, bytes.size)
                            socket.receive(packet)
                            String(packet.data, 0, packet.length, Charsets.US_ASCII).lineSequence().forEach(::ingest)
                        }
                    }
                }
            }
        }.onFailure { onStatus("Error: ${it.localizedMessage}") }
    }

    suspend fun send(sentences: List<String>): Result<Unit> = withContext(Dispatchers.IO) {
        runCatching {
            val bytes = sentences.joinToString("") { "$it\r\n" }.toByteArray(Charsets.US_ASCII)
            when (settings.protocol) {
                NetworkProtocol.TCP -> tcp?.getOutputStream()?.apply { write(bytes); flush() } ?: error("Not connected")
                NetworkProtocol.UDP -> udp?.send(DatagramPacket(bytes, bytes.size)) ?: error("Not connected")
            }
            Unit
        }
    }

    fun disconnect() { tcp?.close(); udp?.close(); tcp = null; udp = null }

    private fun ingest(raw: String) {
        NmeaParser.parse(raw.trim(), lastFix)?.let { fix ->
            lastFix = fix
            onFix(fix)
            onStatus(if (fix.validFix) "Receiving" else "Invalid fix")
        }
    }
}

object NmeaParser {
    fun parse(raw: String, previous: NavigationFix?): NavigationFix? {
        if (!raw.startsWith('$')) return null
        val body = raw.substringBefore('*')
        val fields = body.split(',')
        return when (fields.firstOrNull()?.takeLast(3)) {
            "RMC" -> parseRmc(fields, previous)
            "GGA" -> parseGga(fields, previous)
            "VTG" -> previous?.copy(cogDegrees = fields.getOrNull(1)?.toDoubleOrNull(), sogKnots = fields.getOrNull(5)?.toDoubleOrNull(), timestampMillis = System.currentTimeMillis())
            "HDT", "HDM", "HDG" -> previous?.copy(headingDegrees = fields.getOrNull(1)?.toDoubleOrNull(), timestampMillis = System.currentTimeMillis())
            else -> null
        }
    }

    private fun parseRmc(f: List<String>, old: NavigationFix?): NavigationFix? {
        val lat = coordinate(f.getOrNull(3), f.getOrNull(4)) ?: return null
        val lon = coordinate(f.getOrNull(5), f.getOrNull(6)) ?: return null
        return NavigationFix(lat, lon, f.getOrNull(7)?.toDoubleOrNull(), f.getOrNull(8)?.toDoubleOrNull(), old?.headingDegrees, source = NavigationSource.ACTISENSE, validFix = f.getOrNull(2) == "A")
    }

    private fun parseGga(f: List<String>, old: NavigationFix?): NavigationFix? {
        val lat = coordinate(f.getOrNull(2), f.getOrNull(3)) ?: return null
        val lon = coordinate(f.getOrNull(4), f.getOrNull(5)) ?: return null
        return NavigationFix(lat, lon, old?.sogKnots, old?.cogDegrees, old?.headingDegrees, source = NavigationSource.ACTISENSE, hdop = f.getOrNull(8)?.toDoubleOrNull(), validFix = (f.getOrNull(6)?.toIntOrNull() ?: 0) > 0)
    }

    private fun coordinate(value: String?, hemisphere: String?): Double? {
        val number = value?.toDoubleOrNull() ?: return null
        val degrees = (number / 100).toInt()
        val result = degrees + (number - degrees * 100) / 60
        return if (hemisphere == "S" || hemisphere == "W") -result else result
    }
}

object NmeaEncoder {
    fun waypoint(fix: NavigationFix, mark: Mark): List<String> {
        val bearing = NavigationMath.bearing(fix.latitude, fix.longitude, mark.latitude, mark.longitude)
        val distance = NavigationMath.distanceNm(fix.latitude, fix.longitude, mark.latitude, mark.longitude)
        val name = mark.name.filter { it.isLetterOrDigit() }.take(8).ifBlank { "WAYPOINT" }
        val bwc = listOf("GPBWC", utcTime(), coordinate(mark.latitude, true), hemi(mark.latitude, true), coordinate(mark.longitude, false), hemi(mark.longitude, false), one(bearing), "T", one(bearing), "M", two(distance), "N", name)
        val rmb = listOf("GPRMB", "A", "0.00", "R", "ORIGIN", name, coordinate(mark.latitude, true), hemi(mark.latitude, true), coordinate(mark.longitude, false), hemi(mark.longitude, false), two(distance), one(bearing), one(fix.sogKnots ?: 0.0), "A")
        return listOf(sentence(bwc), sentence(rmb))
    }

    private fun sentence(fields: List<String>): String {
        val body = fields.joinToString(",")
        val checksum = body.fold(0) { value, char -> value xor char.code }
        return "$$body*${checksum.toString(16).uppercase().padStart(2, '0')}"
    }
    private fun coordinate(value: Double, latitude: Boolean): String { val absolute = kotlin.math.abs(value); val degrees = absolute.toInt(); return if (latitude) "%02d%07.4f".format(degrees, (absolute - degrees) * 60) else "%03d%07.4f".format(degrees, (absolute - degrees) * 60) }
    private fun hemi(value: Double, latitude: Boolean) = if (latitude) if (value >= 0) "N" else "S" else if (value >= 0) "E" else "W"
    private fun utcTime(): String { val now = java.time.Instant.now().atOffset(ZoneOffset.UTC); return "%02d%02d%02d".format(now.hour, now.minute, now.second) }
    private fun one(v: Double) = "%.1f".format(v)
    private fun two(v: Double) = "%.2f".format(v)
}
