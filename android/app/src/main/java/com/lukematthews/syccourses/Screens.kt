@file:OptIn(ExperimentalMaterial3Api::class)

package com.lukematthews.syccourses

import android.content.Intent
import android.graphics.BitmapFactory
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.shape.CircleShape
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
        composable("flags") { FlagsScreen(app, nav) }
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
    ScreenScaffold(if (laid) "Laid Courses" else "Fixed Mark Courses", { nav.popBackStack() }) { padding ->
        LazyColumn(Modifier.padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            items(courses) { CourseRow(it) { app.recordRecent(it.courseNumber); nav.navigate("course/${it.courseNumber}") } }
            item { Spacer(Modifier.height(16.dp)) }
        }
    }
}

@Composable
private fun CourseRow(course: Course, action: () -> Unit) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth().clickable(onClick = action),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = Color.White),
        border = CardDefaults.outlinedCardBorder().copy(width = 1.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                "Course ${course.courseNumber}",
                modifier = Modifier.weight(1f),
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF1C1B1F),
                maxLines = 1,
            )
            CoursePennantHoist(course.courseNumber)
        }
    }
}

@Composable
private fun CoursePennantHoist(number: Int) {
    Row(
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Box(
            Modifier
                .width(2.dp)
                .height((number.toString().length * 34).dp)
                .background(Color.Gray.copy(alpha = .35f)),
        )
        Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
            number.toString().forEach { digit ->
                AssetImage(
                    path = "pennants/numeral-$digit.png",
                    modifier = Modifier.width(76.dp).height(29.dp),
                    description = "Numeral pennant $digit",
                )
            }
        }
    }
}

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
            if (course.chartImage.isNotBlank()) item { AssetImage(course.chartImage.removePrefix("/")) }
            item { Button({ app.activateCourse(course) }, Modifier.fillMaxWidth()) { Icon(Icons.Default.PlayArrow, null); Text(" Start Course") } }
            item { OutlinedButton({ shareGpx(context, app, course) }, Modifier.fillMaxWidth()) { Icon(Icons.Default.Share, null); Text(" Share GPX") } }
            item { OutlinedButton({ nav.navigate("line/finish") }, Modifier.fillMaxWidth()) { Text("Finish options") } }
            item { Button({ val mark = course.rows.mapNotNull { app.repository.mark(it.mark) }.firstOrNull(); if (mark != null) scope.launch { app.sendWaypoint(mark) } }, Modifier.fillMaxWidth()) { Text("Send to Boat") } }
        }
    }
}

@Composable
private fun AssetImage(path: String, modifier: Modifier = Modifier.fillMaxWidth(), description: String? = null) {
    val context = LocalContext.current
    val bitmap = remember(path) {
        runCatching { context.assets.open(path).use(BitmapFactory::decodeStream) }.getOrNull()
    }
    bitmap?.let { Image(it.asImageBitmap(), description, modifier, contentScale = ContentScale.Fit) }
}

@Composable
private fun QuickBearingScreen(app: AppViewModel, nav: NavHostController) {
    val phone by app.phoneFix.collectAsStateWithLifecycle(); val boat by app.actisenseFix.collectAsStateWithLifecycle()
    var selected by remember { mutableStateOf<Mark?>(null) }; val fix = app.activeFix
    ScreenScaffold("Quick Bearing", { nav.popBackStack() }) { padding ->
        LazyColumn(Modifier.padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item { Text(if (fix?.source == NavigationSource.ACTISENSE) "Source: NMEA2000" else if (fix != null) "Source: iPhone GPS" else "No valid position", color = if (fix == null) Color.Red else Teal) }
            item {
                Text("Approximate Mark Locations", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = Navy)
                Spacer(Modifier.height(8.dp))
                MarkLocationChart(app = app, onSelect = { selected = it })
            }
            item { Text("Select Mark", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = Navy) }
            items(app.repository.marks) { mark -> Card(Modifier.fillMaxWidth().clickable { selected = mark }) { Row(Modifier.padding(15.dp)) { Text(mark.name, Modifier.weight(1f), fontWeight = FontWeight.SemiBold); Icon(Icons.Default.NearMe, null) } } }
        }
        selected?.let { mark -> val snapshot = fix?.let { NavigationMath.snapshot(it, mark) }; AlertDialog(onDismissRequest = { selected = null }, confirmButton = { TextButton({ selected = null }) { Text("Done") } }, title = { Text(mark.name) }, text = { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) { if (snapshot == null) Text("Waiting for a valid position.") else { Text("%03.0f° T".format(snapshot.bearingTrue), fontSize = 38.sp, fontWeight = FontWeight.Bold); Text("%.2f nm".format(snapshot.distanceNm)); snapshot.timeToMarkSeconds?.let { Text("Time to mark ${formatDuration(it)}") } } } }) }
    }
    LaunchedEffect(Unit) { app.startLocation() }
}

private data class MarkHotspot(val markId: String, val x: Float, val y: Float)

private val markHotspots = listOf(
    MarkHotspot("rmys-g", .596f, .135f),
    MarkHotspot("r3", .592f, .308f),
    MarkHotspot("r2", .575f, .432f),
    MarkHotspot("syc-7", .817f, .535f),
    MarkHotspot("syc-3", .840f, .567f),
    MarkHotspot("syc-6", .642f, .604f),
    MarkHotspot("syc-2", .721f, .604f),
    MarkHotspot("syc-4", .831f, .617f),
    MarkHotspot("syc-1", .802f, .703f),
    MarkHotspot("syc-5", .751f, .789f),
    MarkHotspot("spoil-ground", .286f, .833f),
    MarkHotspot("t2", .485f, .867f),
    MarkHotspot("t1", .509f, .867f),
    MarkHotspot("centre-m1", .265f, .940f),
    MarkHotspot("carrum-no2", .922f, .935f),
)

@Composable
private fun MarkLocationChart(app: AppViewModel, onSelect: (Mark) -> Unit) {
    val context = LocalContext.current
    val image = remember {
        runCatching { context.assets.open("mark-locations.png").use(BitmapFactory::decodeStream) }.getOrNull()
    }
    val activeCourseNumber by app.activeCourse.collectAsStateWithLifecycle()
    val activeMarkName by app.activeMark.collectAsStateWithLifecycle()
    val activeCourseMarkIds = remember(activeCourseNumber) {
        app.repository.course(activeCourseNumber ?: -1)?.rows
            ?.mapNotNull { app.repository.mark(it.mark)?.id }
            ?.toSet().orEmpty()
    }
    val activeMarkId = remember(activeMarkName) { activeMarkName?.let { app.repository.mark(it)?.id } }

    if (image == null) {
        Text("Mark map unavailable", color = Color.Gray)
        return
    }

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(1215f / 1680f)
            .background(Color.White, RoundedCornerShape(8.dp))
            .border(1.dp, Color(0xFFD7DEE3), RoundedCornerShape(8.dp)),
    ) {
        Image(
            bitmap = image.asImageBitmap(),
            contentDescription = "Approximate SYC mark locations",
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.FillBounds,
        )
        markHotspots.forEach { hotspot ->
            val mark = app.repository.marks.firstOrNull { it.id == hotspot.markId } ?: return@forEach
            val isActive = mark.id == activeMarkId
            val isInCourse = mark.id in activeCourseMarkIds
            Box(
                modifier = Modifier
                    .offset(x = maxWidth * hotspot.x - 22.dp, y = maxHeight * hotspot.y - 22.dp)
                    .size(44.dp)
                    .clickable { onSelect(mark) },
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    Modifier
                        .size(if (isActive) 24.dp else 18.dp)
                        .background(Color.White.copy(alpha = if (isActive) .95f else .8f), CircleShape)
                        .border(
                            width = if (isActive) 4.dp else 3.dp,
                            color = if (isActive) Color(0xFFFF9800) else Teal.copy(alpha = if (isInCourse) 1f else .7f),
                            shape = CircleShape,
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Box(Modifier.size(7.dp).background(Color.Gray, CircleShape))
                }
            }
        }
    }
}

@Composable
private fun FlagsScreen(app: AppViewModel, nav: NavHostController) {
    var digits by remember { mutableStateOf("") }
    val matchedCourse = digits.toIntOrNull()?.let(app.repository::course)
    ScreenScaffold("Numeral Pennants", { nav.popBackStack() }) { padding ->
        Column(Modifier.padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            LazyVerticalGrid(
                columns = GridCells.Fixed(3),
                modifier = Modifier.fillMaxWidth().weight(1f),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items((0..9).toList()) { number ->
                    Card(
                        modifier = Modifier.fillMaxWidth().clickable {
                            if (digits.length < 2) digits += number.toString()
                        },
                    ) {
                        Column(
                            modifier = Modifier.fillMaxWidth().padding(8.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                        AssetImage(
                            path = "pennants/numeral-$number.png",
                                modifier = Modifier.fillMaxWidth().height(48.dp),
                            description = "Numeral pennant $number",
                        )
                            Text(number.toString(), fontSize = 18.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }

            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Course Lookup", Modifier.weight(1f), fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        TextButton(onClick = { digits = "" }, enabled = digits.isNotEmpty()) { Text("Clear") }
                    }
                    Text(
                        text = if (digits.isEmpty()) "Tap pennants to enter a course number." else digits,
                        fontSize = if (digits.isEmpty()) 22.sp else 44.sp,
                        fontWeight = FontWeight.Bold,
                    )
                    if (matchedCourse != null) {
                        CourseRow(matchedCourse) {
                            app.recordRecent(matchedCourse.courseNumber)
                            nav.navigate("course/${matchedCourse.courseNumber}")
                        }
                    } else if (digits.isNotEmpty()) {
                        Text("No course $digits.", color = Color.Gray)
                    }
                }
            }
        }
    }
}

@Composable
private fun LineAssistScreen(app: AppViewModel, nav: NavHostController, initialMode: LineMode) {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("syc_courses", android.content.Context.MODE_PRIVATE) }
    var mode by remember { mutableStateOf(initialMode) }
    var offsetMinutes by remember { mutableIntStateOf(prefs.getInt("line_offset", 10).coerceIn(-5, 25)) }
    var gunTimeMillis by remember {
        mutableLongStateOf(prefs.getLong("line_gun_time", nextWholeMinute(System.currentTimeMillis())))
    }
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    var showOffsetMenu by remember { mutableStateOf(false) }
    val phoneFix by app.phoneFix.collectAsStateWithLifecycle()
    val actisenseFix by app.actisenseFix.collectAsStateWithLifecycle()
    val fix = app.activeFix
    val settings = app.settings.collectAsStateWithLifecycle().value
    val geometry = remember(prefs) {
        BoatGeometrySettings(
            bowOffsetMeters = prefs.getFloat("line_bow_offset", 9.4f).toDouble(),
            gpsOffsetStarboardMeters = prefs.getFloat("line_gps_sideways", 0f).toDouble(),
            useBowOffset = prefs.getBoolean("line_use_bow", true),
            bearingSource = runCatching { BearingSource.valueOf(prefs.getString("line_bearing_source", "COG")!!) }.getOrDefault(BearingSource.COG),
        )
    }
    val tower = app.repository.mark("SYC Tower")!!
    val mark4 = app.repository.mark("SYC 4")!!
    val result = NavigationMath.lineCrossing(fix, tower, mark4, geometry)
    val startTime = gunTimeMillis + offsetMinutes * 60_000L
    val timeToStart = (startTime - now) / 1000.0
    val timeToBurn = result.secondsToLine?.let { timeToStart - it }
    val sourceText = when {
        fix?.source == NavigationSource.ACTISENSE -> "Source: NMEA2000"
        fix != null -> "Source: Android GPS"
        settings.inputEnabled && actisenseFix != null -> "Actisense stale — no valid position"
        else -> "No valid position"
    }
    val lcd = Color(0xFFADCA9B)
    val secondary = Color.White.copy(alpha = .62f)
    val statusText = when {
        result.degradedReason == DegradedReason.MISSING_HEADING -> "NO HEADING"
        result.status == LineCrossingStatus.APPROACHING -> "APPROACHING"
        result.status == LineCrossingStatus.CROSSING_AHEAD -> "CROSSING AHEAD"
        result.status == LineCrossingStatus.OUTSIDE_SEGMENT -> "OUTSIDE LINE"
        result.status == LineCrossingStatus.PARALLEL -> "PARALLEL"
        result.status == LineCrossingStatus.MOVING_AWAY -> "MOVING AWAY"
        else -> "NO DATA"
    }
    val timeToLineText = when (result.status) {
        LineCrossingStatus.NO_GPS -> "NO GPS"
        LineCrossingStatus.NO_COG -> "NO COG"
        LineCrossingStatus.NO_SOG -> "NO SOG"
        LineCrossingStatus.OUTSIDE_SEGMENT -> "OUTSIDE LINE"
        LineCrossingStatus.PARALLEL -> "PARALLEL"
        LineCrossingStatus.MOVING_AWAY -> "MOVING AWAY"
        else -> result.secondsToLine?.let(::signedDuration) ?: "--:--"
    }
    val referenceText = when (result.degradedReason) {
        DegradedReason.MISSING_HEADING -> "GPS POSITION ONLY"
        DegradedReason.MISSING_GEOMETRY -> "GPS POSITION · CHECK BOW OFFSET"
        DegradedReason.DISABLED -> "GPS POSITION · BOW OFFSET OFF"
        null -> if (result.bowOffsetApplied) "USING BOW POSITION · GPS to Bow %.1f m".format(geometry.bowOffsetMeters) else "GPS POSITION"
    }

    LaunchedEffect(Unit) {
        app.startLocation()
        if (settings.inputEnabled) app.connectActisense()
        while (true) { now = System.currentTimeMillis(); delay(1000) }
    }

    Scaffold(
        containerColor = Color.Black,
        topBar = {
            TopAppBar(
                title = {},
                navigationIcon = { IconButton({ nav.popBackStack() }) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = Color.White) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Black),
            )
        },
    ) { padding ->
        LazyColumn(
            Modifier.padding(padding).padding(horizontal = 18.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("SYC Tower ↔ SYC 4", Modifier.weight(1f), color = secondary, fontWeight = FontWeight.Bold)
                    if (mode == LineMode.START) TextButton({
                        val rounded = kotlin.math.round(timeToStart / 60.0) * 60.0
                        gunTimeMillis = now + rounded.toLong() * 1000 - offsetMinutes * 60_000L
                        prefs.edit().putLong("line_gun_time", gunTimeMillis).apply()
                    }) { Icon(Icons.Default.Timer, null); Text(" Sync", fontWeight = FontWeight.Bold) }
                }
            }
            item {
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                    LineMode.entries.forEachIndexed { index, value ->
                        SegmentedButton(mode == value, { mode = value }, SegmentedButtonDefaults.itemShape(index, 2)) {
                            Text(value.name.lowercase().replaceFirstChar(Char::uppercase))
                        }
                    }
                }
            }
            if (mode == LineMode.START) item {
                Row(horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                    Column(Modifier.weight(1f)) {
                        LineLabel("Start Time", secondary)
                        TextButton({
                            val zoned = java.time.Instant.ofEpochMilli(gunTimeMillis).atZone(java.time.ZoneId.systemDefault())
                            android.app.TimePickerDialog(context, { _, hour, minute ->
                                val selected = java.time.ZonedDateTime.now().withHour(hour).withMinute(minute).withSecond(0).withNano(0)
                                gunTimeMillis = selected.toInstant().toEpochMilli()
                                prefs.edit().putLong("line_gun_time", gunTimeMillis).apply()
                            }, zoned.hour, zoned.minute, false).show()
                        }) { Text(formatClock(gunTimeMillis), color = Color.White, fontSize = 25.sp, fontWeight = FontWeight.Bold) }
                    }
                    Column(Modifier.weight(1f)) {
                        LineLabel("Offset", secondary)
                        Box {
                            TextButton({ showOffsetMenu = true }) { Text("$offsetMinutes min  ▾", color = Color.White, fontSize = 25.sp, fontWeight = FontWeight.Bold) }
                            DropdownMenu(showOffsetMenu, { showOffsetMenu = false }) {
                                (-5..25).forEach { value -> DropdownMenuItem({ Text("$value min") }, {
                                    offsetMinutes = value; showOffsetMenu = false
                                    prefs.edit().putInt("line_offset", value).apply()
                                }) }
                            }
                        }
                    }
                }
            }
            item {
                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                    LineLabel(if (mode == LineMode.START) "Time To Start" else "Time To Finish", secondary)
                    Text(
                        if (mode == LineMode.START) signedDuration(timeToStart) else timeToLineText,
                        color = lcd, fontSize = 82.sp, fontWeight = FontWeight.Black, maxLines = 1,
                    )
                }
            }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    LineTile("Dist To Line", result.distanceMeters?.let { if (it < 1000) "%.0f m".format(it) else "%.2f km".format(it / 1000) } ?: "NO GPS", lcd, Modifier.weight(1f))
                    LineTile("SOG", fix?.sogKnots?.let { "%.1f kt".format(it.coerceAtLeast(0.0)) } ?: if (fix == null) "NO GPS" else "NO SOG", lcd, Modifier.weight(1f))
                }
            }
            if (mode == LineMode.START) item {
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    LineTile("Time To Line", timeToLineText, lcd, Modifier.weight(1f))
                    val burnText = when { timeToBurn == null -> "--:--"; kotlin.math.abs(timeToBurn) <= 5 -> "ON TIME"; timeToBurn < 0 -> "EARLY ${signedDuration(timeToBurn)}"; else -> signedDuration(timeToBurn) }
                    val burnColor = when { timeToBurn == null -> secondary; kotlin.math.abs(timeToBurn) <= 5 -> Color.Green; timeToBurn < 0 -> Color.Red; else -> lcd }
                    LineTile("Time To Burn", burnText, burnColor, Modifier.weight(1f))
                }
            }
            item {
                LineLabel("Status", secondary)
                Text(statusText, color = if (result.status in setOf(LineCrossingStatus.APPROACHING, LineCrossingStatus.CROSSING_AHEAD)) lcd else if (result.status in setOf(LineCrossingStatus.NO_GPS, LineCrossingStatus.NO_COG, LineCrossingStatus.NO_SOG)) secondary else Color(0xFFFF9800), fontSize = 34.sp, fontWeight = FontWeight.Black, maxLines = 1)
            }
            item {
                Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Row { Icon(Icons.Default.GpsFixed, null, tint = secondary); Spacer(Modifier.width(10.dp)); Text(sourceText, color = secondary, fontWeight = FontWeight.SemiBold); fix?.let { Text("  ${formatClock(it.timestampMillis)}", color = secondary) } }
                    Row { Icon(if (result.referencePoint == ReferencePoint.BOW) Icons.Default.Sailing else Icons.Default.LocationOn, null, tint = secondary); Spacer(Modifier.width(10.dp)); Text(referenceText, color = secondary, fontWeight = FontWeight.SemiBold) }
                    result.bowGainToLineMeters?.let { Text("Bow gain to line: %.1f m".format(it), color = secondary) }
                }
                Spacer(Modifier.height(16.dp))
            }
        }
    }
}

@Composable private fun LineLabel(text: String, color: Color) = Text(text.uppercase(), color = color, fontSize = 13.sp, fontWeight = FontWeight.Black, letterSpacing = 1.sp)
@Composable private fun LineTile(title: String, value: String, color: Color, modifier: Modifier = Modifier) = Column(modifier.heightIn(min = 62.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) { LineLabel(title, Color.White.copy(alpha = .62f)); Text(value, color = color, fontSize = 30.sp, fontWeight = FontWeight.Black, maxLines = 1) }
private fun signedDuration(seconds: Double): String { val sign = if (seconds < 0) "−" else ""; val value = kotlin.math.abs(seconds).toInt(); return "$sign${value / 60}:${(value % 60).toString().padStart(2, '0')}" }
private fun formatClock(millis: Long): String = java.time.Instant.ofEpochMilli(millis).atZone(java.time.ZoneId.systemDefault()).format(java.time.format.DateTimeFormatter.ofPattern("h:mm a"))
private fun nextWholeMinute(now: Long): Long = ((now / 60_000L) + 1) * 60_000L

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
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("syc_courses", android.content.Context.MODE_PRIVATE) }
    var settings by remember { mutableStateOf(app.settings.value) }; val status by app.networkStatus.collectAsStateWithLifecycle()
    var useBow by remember { mutableStateOf(prefs.getBoolean("line_use_bow", true)) }
    var bowOffset by remember { mutableStateOf(prefs.getFloat("line_bow_offset", 9.4f).toString()) }
    var sidewaysOffset by remember { mutableStateOf(prefs.getFloat("line_gps_sideways", 0f).toString()) }
    var bearingSource by remember { mutableStateOf(runCatching { BearingSource.valueOf(prefs.getString("line_bearing_source", "COG")!!) }.getOrDefault(BearingSource.COG)) }
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
        item { HorizontalDivider(); Text("Line Assist · Boat Geometry", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = Navy) }
        item { SettingSwitch("Use bow position for Line Assist", useBow) { useBow = it; prefs.edit().putBoolean("line_use_bow", it).apply() } }
        item { OutlinedTextField(bowOffset, { value -> bowOffset = value; value.toFloatOrNull()?.let { prefs.edit().putFloat("line_bow_offset", it.coerceIn(0f, 30f)).apply() } }, Modifier.fillMaxWidth(), label = { Text("GPS to bow distance (m)") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)) }
        item { OutlinedTextField(sidewaysOffset, { value -> sidewaysOffset = value; value.toFloatOrNull()?.let { prefs.edit().putFloat("line_gps_sideways", it.coerceIn(-10f, 10f)).apply() } }, Modifier.fillMaxWidth(), label = { Text("GPS sideways offset (m)") }, supportingText = { Text("Positive is starboard; negative is port.") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)) }
        item {
            Text("Bow projection", fontWeight = FontWeight.SemiBold)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                BearingSource.entries.forEach { source ->
                    FilterChip(bearingSource == source, {
                        bearingSource = source
                        prefs.edit().putString("line_bearing_source", source.name).apply()
                    }, { Text(if (source == BearingSource.COG) "Course over ground" else "Heading") })
                }
            }
        }
        item { Text("Line Assist uses the projected bow position because the boat starts or finishes when the bow crosses the line.", color = Color.Gray) }
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
