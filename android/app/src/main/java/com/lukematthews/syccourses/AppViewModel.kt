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
    private val _recents = MutableStateFlow(loadCourseIDs())
    private val _activeCourse = MutableStateFlow(loadActiveCourseID())
    private val _activeMark = MutableStateFlow(prefs.getString("active_mark", null))
    private val _settings = MutableStateFlow(loadSettings())
    private val _lastOutputMessage = MutableStateFlow<String?>(null)
    private val _outputCount = MutableStateFlow(0)
    private val _outputError = MutableStateFlow<String?>(null)
    private val _lastReconnectMillis = MutableStateFlow<Long?>(null)

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
    val lastOutputMessage = _lastOutputMessage.asStateFlow()
    val outputCount = _outputCount.asStateFlow()
    val outputError = _outputError.asStateFlow()
    val lastReconnectMillis = _lastReconnectMillis.asStateFlow()
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

    fun recordRecent(course: Course) {
        _recents.value = (listOf(course.id) + _recents.value.filterNot { it == course.id }).take(6)
        saveStrings("recent_course_ids", _recents.value)
    }

    fun clearRecents() { _recents.value = emptyList(); prefs.edit().remove("recent_course_ids").remove("recent_courses").apply() }

    fun activateCourse(course: Course) {
        if (course.kind == CourseKind.laid) return
        _activeCourse.value = course.id
        _activeMark.value = course.rows.firstOrNull { it.mark.normalizedMarkName() !in setOf("start", "total") }?.mark
        prefs.edit().putString("active_course_id", course.id).remove("active_course").putString("active_mark", _activeMark.value).apply()
    }

    fun setActiveMark(name: String) { _activeMark.value = name; prefs.edit().putString("active_mark", name).apply() }
    fun clearActiveCourse() { _activeCourse.value = null; _activeMark.value = null; prefs.edit().remove("active_course_id").remove("active_course").remove("active_mark").apply() }

    fun activeCourseMarks(): List<Mark> = _activeCourse.value?.let(repository::course)?.rows
        ?.filterNot { it.mark.normalizedMarkName() in setOf("start", "finish", "total", "sub-total", "subtotal") || it.side.equals("Pass", true) }
        ?.mapNotNull { repository.mark(it.mark) }
        .orEmpty()

    fun activeCourseLineMarks(): List<Mark> {
        val course = _activeCourse.value?.let(repository::course) ?: return emptyList()
        val result = mutableListOf<Mark>()
        repository.startFinishMark()?.let(result::add)
        course.rows.filterNot { it.mark.normalizedMarkName() in setOf("total", "sub-total", "subtotal") || it.side.equals("Pass", true) }
            .mapNotNull { repository.mark(it.mark) }
            .forEach { if (result.lastOrNull()?.id != it.id) result += it }
        return result
    }

    fun advanceActiveMark() {
        val marks = activeCourseMarks()
        val index = marks.indexOfFirst { it.name == _activeMark.value || it.id == _activeMark.value }
        marks.getOrNull((index + 1).coerceAtMost(marks.lastIndex))?.let { setActiveMark(it.name) }
    }

    fun retreatActiveMark() {
        val marks = activeCourseMarks()
        val index = marks.indexOfFirst { it.name == _activeMark.value || it.id == _activeMark.value }
        marks.getOrNull((index - 1).coerceAtLeast(0))?.let { setActiveMark(it.name) }
    }

    fun startRecording() {
        if (_currentTrack.value == null) _currentTrack.value = SavedRaceTrack()
        _recording.value = true
        ContextCompat.startForegroundService(getApplication(), android.content.Intent(getApplication(), RaceTrackingService::class.java))
        startLocation()
    }

    fun stopRecording() {
        _recording.value = false
        getApplication<Application>().stopService(android.content.Intent(getApplication(), RaceTrackingService::class.java))
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
    fun renameTrack(id: String, name: String) {
        val trimmed = name.trim().takeIf { it.isNotEmpty() }
        _recentTracks.value = _recentTracks.value.map { if (it.id == id) it.copy(name = trimmed) else it }
        _currentTrack.value = _currentTrack.value?.let { if (it.id == id) it.copy(name = trimmed) else it }
        saveTracks()
    }

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
        _lastReconnectMillis.value = System.currentTimeMillis()
        val client = ActisenseClient(_settings.value, { _networkStatus.value = it }, { _actisenseFix.value = it })
        actisense = client
        viewModelScope.launch { client.connect() }
    }

    fun disconnectActisense() { actisense?.disconnect(); _networkStatus.value = "Disconnected" }

    suspend fun sendWaypoint(mark: Mark): Result<Unit> {
        val fix = activeFix ?: return Result.failure(IllegalStateException("No valid position"))
        val sentences = NmeaEncoder.waypoint(fix, mark)
        val result = actisense?.send(sentences) ?: Result.failure(IllegalStateException("Not connected"))
        if (result.isSuccess) { _lastOutputMessage.value = sentences.lastOrNull(); _outputCount.value += sentences.size; _outputError.value = null }
        else _outputError.value = result.exceptionOrNull()?.localizedMessage
        return result
    }

    private fun loadSettings() = prefs.getString("actisense", null)?.let { runCatching { json.decodeFromString<ActisenseSettings>(it) }.getOrNull() } ?: ActisenseSettings()
    private fun loadTracks() = prefs.getString("race_tracks", null)?.let { runCatching { json.decodeFromString<List<SavedRaceTrack>>(it) }.getOrNull() } ?: emptyList()
    private fun saveTracks() = prefs.edit().putString("race_tracks", json.encodeToString(_recentTracks.value)).apply()
    private fun loadCourseIDs(): List<String> {
        val stored = loadStrings("recent_course_ids")
        if (stored.isNotEmpty()) return stored
        val migrated = prefs.getString("recent_courses", "").orEmpty().split(',')
            .mapNotNull(String::toIntOrNull).mapNotNull(repository::course).map(Course::id)
        if (migrated.isNotEmpty()) {
            saveStrings("recent_course_ids", migrated)
            prefs.edit().remove("recent_courses").apply()
        }
        return migrated
    }

    private fun loadActiveCourseID(): String? {
        prefs.getString("active_course_id", null)?.let { return it.takeIf { id -> repository.course(id) != null } }
        val legacyNumber = prefs.getInt("active_course", -1)
        return repository.course(legacyNumber)?.id?.also {
            prefs.edit().putString("active_course_id", it).remove("active_course").apply()
        }
    }

    private fun loadStrings(key: String) = prefs.getString(key, "").orEmpty().split(',').filter(String::isNotBlank)
    private fun saveStrings(key: String, values: List<String>) = prefs.edit().putString(key, values.joinToString(",")).apply()

    override fun onCleared() { actisense?.disconnect(); locationManager.removeUpdates(this) }
}
