package com.lukematthews.syccourses

import android.Manifest
import android.app.Application
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import androidx.core.content.ContextCompat
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class AppViewModel(application: Application) : AndroidViewModel(application), LocationListener {
    val repository = DataRepository(application)
    private val prefs = application.getSharedPreferences("syc_courses", Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true }
    private val locationManager = application.getSystemService(Context.LOCATION_SERVICE) as LocationManager

    private val _phoneFix = MutableStateFlow<NavigationFix?>(null)
    private val _actisenseFix = MutableStateFlow<NavigationFix?>(null)
    private val _networkStatus = MutableStateFlow("Disconnected")
    private val _recording = MutableStateFlow(false)
    private val _currentTrack = MutableStateFlow<SavedRaceTrack?>(null)
    private val _recentTracks = MutableStateFlow(loadTracks())
    private val _recents = MutableStateFlow(loadInts("recent_courses"))
    private val _activeCourse = MutableStateFlow(prefs.getInt("active_course", -1).takeIf { it >= 0 })
    private val _activeMark = MutableStateFlow(prefs.getString("active_mark", null))
    private val _settings = MutableStateFlow(loadSettings())

    val phoneFix = _phoneFix.asStateFlow()
    val actisenseFix = _actisenseFix.asStateFlow()
    val networkStatus = _networkStatus.asStateFlow()
    val recording = _recording.asStateFlow()
    val currentTrack = _currentTrack.asStateFlow()
    val recentTracks = _recentTracks.asStateFlow()
    val recents = _recents.asStateFlow()
    val activeCourse = _activeCourse.asStateFlow()
    val activeMark = _activeMark.asStateFlow()
    val settings = _settings.asStateFlow()
    private var actisense: ActisenseClient? = null

    val activeFix: NavigationFix?
        get() = _actisenseFix.value?.takeIf {
            _settings.value.inputEnabled && it.usable && System.currentTimeMillis() - it.timestampMillis <= 5000
        } ?: _phoneFix.value?.takeIf { it.usable }

    fun startLocation() {
        val context = getApplication<Application>()
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) return
        locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000, 0f, this)
    }

    fun stopLocationIfIdle() { if (!_recording.value) locationManager.removeUpdates(this) }

    override fun onLocationChanged(location: Location) {
        val fix = NavigationFix(
            location.latitude, location.longitude,
            location.speed.takeIf { location.hasSpeed() }?.times(1.943844),
            location.bearing.takeIf { location.hasBearing() }?.toDouble(),
            timestampMillis = location.time,
            source = NavigationSource.PHONE_GPS,
            horizontalAccuracyMeters = location.accuracy.takeIf { location.hasAccuracy() }?.toDouble(),
        )
        _phoneFix.value = fix
        if (_recording.value) appendTrack(fix)
    }

    fun recordRecent(courseNumber: Int) {
        _recents.value = (listOf(courseNumber) + _recents.value.filterNot { it == courseNumber }).take(6)
        saveInts("recent_courses", _recents.value)
    }

    fun clearRecents() { _recents.value = emptyList(); prefs.edit().remove("recent_courses").apply() }

    fun activateCourse(course: Course) {
        if (course.courseNumber >= 80) return
        _activeCourse.value = course.courseNumber
        _activeMark.value = course.rows.firstOrNull { it.mark.normalizedMarkName() !in setOf("start", "total") }?.mark
        prefs.edit().putInt("active_course", course.courseNumber).putString("active_mark", _activeMark.value).apply()
    }

    fun setActiveMark(name: String) { _activeMark.value = name; prefs.edit().putString("active_mark", name).apply() }
    fun clearActiveCourse() { _activeCourse.value = null; _activeMark.value = null; prefs.edit().remove("active_course").remove("active_mark").apply() }

    fun startRecording() {
        if (_currentTrack.value == null) _currentTrack.value = SavedRaceTrack()
        _recording.value = true
        startLocation()
    }

    fun stopRecording() {
        _recording.value = false
        _currentTrack.value?.takeIf { it.points.isNotEmpty() }?.let { track ->
            _recentTracks.value = (listOf(track) + _recentTracks.value.filterNot { it.id == track.id }).take(6)
            saveTracks()
        }
        stopLocationIfIdle()
    }

    fun resetTrack() { stopRecording(); _currentTrack.value = null }
    fun loadTrack(track: SavedRaceTrack) { stopRecording(); _currentTrack.value = track }
    fun deleteTrack(id: String) { _recentTracks.value = _recentTracks.value.filterNot { it.id == id }; saveTracks() }
    fun clearTracks() { _recentTracks.value = emptyList(); saveTracks() }

    private fun appendTrack(fix: NavigationFix) {
        val track = _currentTrack.value ?: SavedRaceTrack()
        if (track.points.lastOrNull()?.timestampMillis == fix.timestampMillis) return
        _currentTrack.value = track.copy(
            endedAtMillis = fix.timestampMillis,
            points = track.points + TrackPoint(fix.latitude, fix.longitude, fix.timestampMillis),
        )
    }

    fun updateSettings(value: ActisenseSettings) {
        _settings.value = value
        prefs.edit().putString("actisense", json.encodeToString(value)).apply()
    }

    fun connectActisense() {
        actisense?.disconnect()
        val client = ActisenseClient(_settings.value, { _networkStatus.value = it }, { _actisenseFix.value = it })
        actisense = client
        viewModelScope.launch { client.connect() }
    }

    fun disconnectActisense() { actisense?.disconnect(); _networkStatus.value = "Disconnected" }

    suspend fun sendWaypoint(mark: Mark): Result<Unit> {
        val fix = activeFix ?: return Result.failure(IllegalStateException("No valid position"))
        return actisense?.send(NmeaEncoder.waypoint(fix, mark))
            ?: Result.failure(IllegalStateException("Not connected"))
    }

    private fun loadSettings() = prefs.getString("actisense", null)?.let { runCatching { json.decodeFromString<ActisenseSettings>(it) }.getOrNull() } ?: ActisenseSettings()
    private fun loadTracks() = prefs.getString("race_tracks", null)?.let { runCatching { json.decodeFromString<List<SavedRaceTrack>>(it) }.getOrNull() } ?: emptyList()
    private fun saveTracks() = prefs.edit().putString("race_tracks", json.encodeToString(_recentTracks.value)).apply()
    private fun loadInts(key: String) = prefs.getString(key, "")!!.split(',').mapNotNull(String::toIntOrNull)
    private fun saveInts(key: String, values: List<Int>) = prefs.edit().putString(key, values.joinToString(",")).apply()

    override fun onCleared() { actisense?.disconnect(); locationManager.removeUpdates(this) }
}
