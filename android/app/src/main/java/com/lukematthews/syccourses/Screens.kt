@file:OptIn(ExperimentalMaterial3Api::class)

package com.lukematthews.syccourses

import android.content.Intent
import android.graphics.BitmapFactory
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private val Navy = Color(0xFF102D3D)
private val Page = Color(0xFFF1F5F8)
private val Teal = Color(0xFF087F8C)

@Composable
fun SYCCoursesApp(app: AppViewModel) {
    val nav = rememberNavController()
    NavHost(nav, "home") {
        composable("home") { HomeScreen(app, nav) }
        composable("courses/{kind}") { CourseListScreen(app, nav, it.arguments?.getString("kind") == "laid") }
        composable("course/{number}") { app.repository.course(it.arguments?.getString("number")?.toIntOrNull() ?: -1)?.let { course -> CourseDetailScreen(app, nav, course) } }
        composable("quick") { QuickBearingScreen(app, nav) }
        composable("flags") { FlagsScreen(nav) }
        composable("line/{mode}") { LineAssistScreen(app, nav, if (it.arguments?.getString("mode") == "finish") LineMode.FINISH else LineMode.START) }
        composable("tracker") { RaceTrackerScreen(app, nav) }
        composable("instruments") { InstrumentsScreen(app, nav) }
    }
}

@Composable
private fun HomeScreen(app: AppViewModel, nav: NavHostController) {
    val recentNumbers by app.recents.collectAsStateWithLifecycle()
    val tracks by app.recentTracks.collectAsStateWithLifecycle()
    val activeNumber by app.activeCourse.collectAsStateWithLifecycle()
    ScreenScaffold("SYC Courses") { padding ->
        LazyColumn(Modifier.padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Sailing, null, tint = Teal, modifier = Modifier.size(52.dp))
                    Spacer(Modifier.width(12.dp)); Text("SYC Courses", fontSize = 32.sp, fontWeight = FontWeight.Bold, color = Navy)
                }
            }
            activeNumber?.let { number -> item { HighlightCard("Active race · Course $number", "Resume course or race tracking", Icons.Default.DirectionsBoat) { nav.navigate("course/$number") } } }
            item { HomeCard("Quick Bearing", "Bearing and distance to a mark", Icons.Default.NearMe) { nav.navigate("quick") } }
            item { HomeCard("Flags", "Numeral pennants 0–9", Icons.Default.Flag) { nav.navigate("flags") } }
            item { HomeCard("Fixed Mark Courses", "${app.repository.fixedCourses.size} courses", Icons.Default.FormatListNumbered) { nav.navigate("courses/fixed") } }
            item { HomeCard("Laid Courses", "${app.repository.laidCourses.size} courses", Icons.Default.ChangeHistory) { nav.navigate("courses/laid") } }
            item { HomeCard("Line Assist", "Start and finish line crossing", Icons.Default.Timer) { nav.navigate("line/start") } }
            item { HomeCard("Race Tracker", "Record and review your course", Icons.Default.Map) { nav.navigate("tracker") } }
            item { HomeCard("Instruments", "Boat communication with Actisense W2K-2", Icons.Default.SettingsInputAntenna) { nav.navigate("instruments") } }
            if (recentNumbers.isNotEmpty()) {
                item { SectionHeader("Recently viewed", "Clear", app::clearRecents) }
                items(recentNumbers.mapNotNull(app.repository::course)) { CourseRow(it) { nav.navigate("course/${it.courseNumber}") } }
            }
            if (tracks.isNotEmpty()) {
                item { SectionHeader("Recent tracks", "Clear", app::clearTracks) }
                items(tracks, key = { it.id }) { track ->
                    Card(Modifier.fillMaxWidth().clickable { app.loadTrack(track); nav.navigate("tracker") }) {
                        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Route, null, tint = Teal); Spacer(Modifier.width(12.dp))
                            Column(Modifier.weight(1f)) { Text(track.displayName, fontWeight = FontWeight.Bold); Text("${track.points.size} recorded points", color = Color.Gray) }
                            IconButton({ app.deleteTrack(track.id) }) { Icon(Icons.Default.Delete, "Delete track") }
                        }
                    }
                }
            }
        }
    }
}

@Composable private fun HomeCard(title: String, subtitle: String, icon: ImageVector, action: () -> Unit) = Card(Modifier.fillMaxWidth().clickable(onClick = action)) { Row(Modifier.padding(18.dp), verticalAlignment = Alignment.CenterVertically) { Icon(icon, null, tint = Teal, modifier = Modifier.size(30.dp)); Spacer(Modifier.width(16.dp)); Column(Modifier.weight(1f)) { Text(title, fontWeight = FontWeight.Bold, fontSize = 18.sp); Text(subtitle, color = Color.Gray) }; Icon(Icons.Default.ChevronRight, null) } }
@Composable private fun HighlightCard(title: String, subtitle: String, icon: ImageVector, action: () -> Unit) = Card(colors = CardDefaults.cardColors(containerColor = Navy), modifier = Modifier.fillMaxWidth().clickable(onClick = action)) { Row(Modifier.padding(18.dp), verticalAlignment = Alignment.CenterVertically) { Icon(icon, null, tint = Color(0xFFFFC65C)); Spacer(Modifier.width(14.dp)); Column { Text(title, color = Color.White, fontWeight = FontWeight.Bold); Text(subtitle, color = Color(0xFFBFD3DD)) } } }
@Composable private fun SectionHeader(title: String, actionName: String, action: () -> Unit) = Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) { Text(title, Modifier.weight(1f), fontWeight = FontWeight.Bold, color = Navy); TextButton(action) { Text(actionName) } }

@Composable
private fun CourseListScreen(app: AppViewModel, nav: NavHostController, laid: Boolean) {
    val courses = if (laid) app.repository.laidCourses else app.repository.fixedCourses
    var query by remember { mutableStateOf("") }
    val filtered = courses.filter { query.isBlank() || it.courseNumber.toString().contains(query) || it.route?.contains(query, true) == true }
    ScreenScaffold(if (laid) "Laid Courses" else "Fixed Mark Courses", { nav.popBackStack() }) { padding ->
        LazyColumn(Modifier.padding(padding).padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item { OutlinedTextField(query, { query = it }, Modifier.fillMaxWidth(), label = { Text("Find a course") }, leadingIcon = { Icon(Icons.Default.Search, null) }, singleLine = true) }
            items(filtered) { CourseRow(it) { app.recordRecent(it.courseNumber); nav.navigate("course/${it.courseNumber}") } }
            item { Spacer(Modifier.height(16.dp)) }
        }
    }
}

@Composable private fun CourseRow(course: Course, action: () -> Unit) = Card(Modifier.fillMaxWidth().clickable(onClick = action)) { Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) { Surface(shape = RoundedCornerShape(10.dp), color = Navy) { Text(course.courseNumber.toString(), Modifier.padding(horizontal = 15.dp, vertical = 12.dp), color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold) }; Spacer(Modifier.width(14.dp)); Column(Modifier.weight(1f)) { Text(course.route ?: "Course ${course.courseNumber}", fontWeight = FontWeight.SemiBold); Text("${course.totalDistance} nm", color = Color.Gray) }; Icon(Icons.Default.ChevronRight, null) } }

@Composable
private fun CourseDetailScreen(app: AppViewModel, nav: NavHostController, course: Course) {
    val scope = rememberCoroutineScope(); val context = LocalContext.current
    ScreenScaffold("Course ${course.courseNumber}", { nav.popBackStack() }) { padding ->
        LazyColumn(Modifier.padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item { Text(course.route ?: "Course ${course.courseNumber}", fontSize = 24.sp, fontWeight = FontWeight.Bold, color = Navy); Text("Total distance ${course.totalDistance} nm", color = Color.Gray) }
            item { Row(Modifier.fillMaxWidth().background(Navy, RoundedCornerShape(10.dp)).padding(10.dp)) { listOf("Mark", "Side", "Bearing", "NM").forEachIndexed { i, text -> Text(text, Modifier.weight(if (i == 0) 1.6f else 1f), color = Color.White, fontWeight = FontWeight.Bold) } } }
            items(course.rows) { leg ->
                Row(Modifier.fillMaxWidth().clickable { if (app.repository.mark(leg.mark) != null) nav.navigate("quick") }.padding(vertical = 8.dp)) {
                    Text(leg.mark, Modifier.weight(1.6f), fontWeight = FontWeight.SemiBold); Text(leg.side, Modifier.weight(1f)); Text(leg.bearing, Modifier.weight(1f)); Text(leg.distance, Modifier.weight(1f))
                }; HorizontalDivider()
            }
            if (course.chartImage.isNotBlank()) item { AssetImage("course-charts/${course.chartImage}") }
            item { Button({ app.activateCourse(course) }, Modifier.fillMaxWidth()) { Icon(Icons.Default.PlayArrow, null); Text(" Start Course") } }
            item { OutlinedButton({ shareGpx(context, app, course) }, Modifier.fillMaxWidth()) { Icon(Icons.Default.Share, null); Text(" Share GPX") } }
            item { OutlinedButton({ nav.navigate("line/finish") }, Modifier.fillMaxWidth()) { Text("Finish options") } }
            item { Button({ val mark = course.rows.mapNotNull { app.repository.mark(it.mark) }.firstOrNull(); if (mark != null) scope.launch { app.sendWaypoint(mark) } }, Modifier.fillMaxWidth()) { Text("Send to Boat") } }
        }
    }
}

@Composable private fun AssetImage(path: String) { val context = LocalContext.current; val bitmap = remember(path) { runCatching { context.assets.open(path).use(BitmapFactory::decodeStream) }.getOrNull() }; bitmap?.let { Image(it.asImageBitmap(), null, Modifier.fillMaxWidth(), contentScale = ContentScale.FillWidth) } }

@Composable
private fun QuickBearingScreen(app: AppViewModel, nav: NavHostController) {
    val phone by app.phoneFix.collectAsStateWithLifecycle(); val boat by app.actisenseFix.collectAsStateWithLifecycle()
    var selected by remember { mutableStateOf<Mark?>(null) }; val fix = app.activeFix
    ScreenScaffold("Quick Bearing", { nav.popBackStack() }) { padding ->
        LazyColumn(Modifier.padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item { Text(if (fix?.source == NavigationSource.ACTISENSE) "Source: NMEA2000" else if (fix != null) "Source: iPhone GPS" else "No valid position", color = if (fix == null) Color.Red else Teal) }
            items(app.repository.marks) { mark -> Card(Modifier.fillMaxWidth().clickable { selected = mark }) { Row(Modifier.padding(15.dp)) { Text(mark.name, Modifier.weight(1f), fontWeight = FontWeight.SemiBold); Icon(Icons.Default.NearMe, null) } } }
        }
        selected?.let { mark -> val snapshot = fix?.let { NavigationMath.snapshot(it, mark) }; AlertDialog(onDismissRequest = { selected = null }, confirmButton = { TextButton({ selected = null }) { Text("Done") } }, title = { Text(mark.name) }, text = { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) { if (snapshot == null) Text("Waiting for a valid position.") else { Text("%03.0f° T".format(snapshot.bearingTrue), fontSize = 38.sp, fontWeight = FontWeight.Bold); Text("%.2f nm".format(snapshot.distanceNm)); snapshot.timeToMarkSeconds?.let { Text("Time to mark ${formatDuration(it)}") } } } }) }
    }
    LaunchedEffect(Unit) { app.startLocation() }
}

@Composable private fun FlagsScreen(nav: NavHostController) { ScreenScaffold("Numeral Pennants", { nav.popBackStack() }) { padding -> LazyColumn(Modifier.padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) { items((0..9).toList()) { number -> Card(Modifier.fillMaxWidth()) { Row(Modifier.padding(20.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Default.Flag, null, tint = if (number % 2 == 0) Color.Red else Teal, modifier = Modifier.size(48.dp)); Spacer(Modifier.width(20.dp)); Text(number.toString(), fontSize = 34.sp, fontWeight = FontWeight.Bold) } } } } } }

@Composable
private fun LineAssistScreen(app: AppViewModel, nav: NavHostController, initialMode: LineMode) {
    var mode by remember { mutableStateOf(initialMode) }; var gunOffset by remember { mutableIntStateOf(5) }; var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) { app.startLocation(); while (true) { now = System.currentTimeMillis(); delay(1000) } }
    val fix = app.activeFix; val tower = app.repository.mark("SYC Tower"); val mark4 = app.repository.mark("SYC 4"); val result = if (fix != null && tower != null && mark4 != null) NavigationMath.lineCrossing(fix, tower, mark4) else LineCrossingResult("Waiting for position")
    ScreenScaffold("Line Assist", { nav.popBackStack() }) { padding -> Column(Modifier.padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) { LineMode.entries.forEachIndexed { index, value -> SegmentedButton(mode == value, { mode = value }, SegmentedButtonDefaults.itemShape(index, 2)) { Text(value.name.lowercase().replaceFirstChar(Char::uppercase)) } } }
        Card(colors = CardDefaults.cardColors(containerColor = Navy), modifier = Modifier.fillMaxWidth()) { Column(Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) { Text(result.status, color = Color.White); Text(result.secondsToLine?.let(::formatDuration) ?: "—", color = Color(0xFFFFC65C), fontSize = 48.sp, fontWeight = FontWeight.Bold); Text(result.distanceMeters?.let { "%.0f m to line".format(it) } ?: "Course, speed and position required", color = Color.White) } }
        Text("Start offset", fontWeight = FontWeight.Bold); Slider(gunOffset.toFloat(), { gunOffset = it.toInt() }, valueRange = 0f..15f, steps = 14); Text("Gun time +$gunOffset minutes")
        Text("Uses the SYC Tower ↔ SYC 4 ${mode.name.lowercase()} line and your current COG/SOG.", color = Color.Gray)
    } }
}

@Composable
private fun RaceTrackerScreen(app: AppViewModel, nav: NavHostController) {
    val track by app.currentTrack.collectAsStateWithLifecycle(); val recording by app.recording.collectAsStateWithLifecycle()
    ScreenScaffold("Race Tracker", { nav.popBackStack() }) { padding -> Column(Modifier.padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        TrackCanvas(track?.points.orEmpty(), Modifier.fillMaxWidth().weight(1f).background(Color(0xFFDCEAF0), RoundedCornerShape(16.dp)))
        Text("${track?.points?.size ?: 0} points", fontWeight = FontWeight.Bold)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { Button(if (recording) app::stopRecording else app::startRecording, Modifier.weight(1f)) { Icon(if (recording) Icons.Default.Stop else Icons.Default.FiberManualRecord, null); Text(if (recording) " Stop" else " Record") }; OutlinedButton(app::resetTrack, Modifier.weight(1f)) { Text("Reset") } }
    } }
}

@Composable
private fun TrackCanvas(points: List<TrackPoint>, modifier: Modifier) {
    Canvas(modifier.padding(18.dp)) {
        if (points.size < 2) return@Canvas
        val minLat = points.minOf { it.latitude }
        val maxLat = points.maxOf { it.latitude }
        val minLon = points.minOf { it.longitude }
        val maxLon = points.maxOf { it.longitude }
        val pointOffset: (TrackPoint) -> Offset = { point ->
            Offset(
                (((point.longitude - minLon) / (maxLon - minLon).coerceAtLeast(1e-8)) * size.width).toFloat(),
                (size.height - ((point.latitude - minLat) / (maxLat - minLat).coerceAtLeast(1e-8)) * size.height).toFloat(),
            )
        }
        points.zipWithNext().forEach { pair -> drawLine(Teal, pointOffset(pair.first), pointOffset(pair.second), 6f) }
        drawCircle(Color.Red, 9f, pointOffset(points.last()))
    }
}

@Composable
private fun InstrumentsScreen(app: AppViewModel, nav: NavHostController) {
    var settings by remember { mutableStateOf(app.settings.value) }; val status by app.networkStatus.collectAsStateWithLifecycle()
    ScreenScaffold("Instruments", { nav.popBackStack() }) { padding -> LazyColumn(Modifier.padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { Text("Configure one Actisense W2K-2, then choose input, output, or both.", color = Color.Gray) }
        item { OutlinedTextField(settings.host, { settings = settings.copy(host = it) }, Modifier.fillMaxWidth(), label = { Text("IP address") }) }
        item { OutlinedTextField(settings.port.toString(), { it.toIntOrNull()?.let { port -> settings = settings.copy(port = port) } }, Modifier.fillMaxWidth(), label = { Text("Data server port") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)) }
        item { Row { FilterChip(settings.protocol == NetworkProtocol.TCP, { settings = settings.copy(protocol = NetworkProtocol.TCP) }, { Text("TCP") }); Spacer(Modifier.width(8.dp)); FilterChip(settings.protocol == NetworkProtocol.UDP, { settings = settings.copy(protocol = NetworkProtocol.UDP) }, { Text("UDP") }) } }
        item { SettingSwitch("Use for boat data input", settings.inputEnabled) { settings = settings.copy(inputEnabled = it) } }
        item { SettingSwitch("Send output to instruments", settings.outputEnabled) { settings = settings.copy(outputEnabled = it) } }
        item { Text("Status: $status", fontWeight = FontWeight.Bold, color = if (status.startsWith("Error")) Color.Red else Teal) }
        item { Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { Button({ app.updateSettings(settings); app.connectActisense() }, Modifier.weight(1f)) { Text("Connect") }; OutlinedButton(app::disconnectActisense, Modifier.weight(1f)) { Text("Disconnect") } } }
        item { Text("The app exchanges NMEA 0183 data directly with the W2K-2 over your boat Wi-Fi. Common setups use port 60001.", color = Color.Gray) }
    } }
}

@Composable private fun SettingSwitch(label: String, checked: Boolean, change: (Boolean) -> Unit) = Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) { Text(label, Modifier.weight(1f)); Switch(checked, change) }

@Composable private fun ScreenScaffold(title: String, back: (() -> Unit)? = null, content: @Composable (PaddingValues) -> Unit) { Scaffold(containerColor = Page, topBar = { if (back != null) TopAppBar(title = { Text(title, fontWeight = FontWeight.Bold) }, navigationIcon = { IconButton(back) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back") } }) }, content = content) }

private fun formatDuration(seconds: Double): String { val value = seconds.coerceAtLeast(0.0).toInt(); return "%d:%02d".format(value / 60, value % 60) }

private fun shareGpx(context: android.content.Context, app: AppViewModel, course: Course) {
    val marks = course.rows.mapNotNull { leg -> app.repository.mark(leg.mark)?.let { leg.mark to it } }
    val xml = buildString { append("<?xml version=\"1.0\" encoding=\"UTF-8\"?><gpx version=\"1.1\" creator=\"SYC Courses\" xmlns=\"http://www.topografix.com/GPX/1/1\"><rte><name>SYC Course ${course.courseNumber}</name>"); marks.forEach { (name, mark) -> append("<rtept lat=\"${mark.latitude}\" lon=\"${mark.longitude}\"><name>${name.replace("&", "&amp;").replace("<", "&lt;")}</name></rtept>") }; append("</rte></gpx>") }
    val dir = File(context.cacheDir, "shared").apply { mkdirs() }; val file = File(dir, "SYC_Course_${course.courseNumber}.gpx").apply { writeText(xml) }; val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
    context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply { type = "application/gpx+xml"; putExtra(Intent.EXTRA_STREAM, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION) }, "Share GPX"))
}
