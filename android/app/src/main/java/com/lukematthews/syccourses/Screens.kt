@file:OptIn(ExperimentalMaterial3Api::class)

package com.lukematthews.syccourses

import android.content.Intent
import android.graphics.BitmapFactory
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTransformGestures
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
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.TextStyle
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
        composable("mark/{id}") { entry -> app.repository.markById(entry.arguments?.getString("id").orEmpty())?.let { MarkDetailScreen(app, nav, it) } }
        composable("flags") { FlagsScreen(app, nav) }
        composable("line/{mode}") { LineAssistScreen(app, nav, if (it.arguments?.getString("mode") == "finish") LineMode.FINISH else LineMode.START) }
        composable("finish") { FinishOptionsScreen(app, nav) }
        composable("tracker") { RaceTrackerScreen(app, nav) }
        composable("instruments") { InstrumentsScreen(app, nav) }
    }
}

@Composable
private fun HomeScreen(app: AppViewModel, nav: NavHostController) {
    val recentNumbers by app.recents.collectAsStateWithLifecycle()
    val tracks by app.recentTracks.collectAsStateWithLifecycle()
    val activeNumber by app.activeCourse.collectAsStateWithLifecycle()
    var renameTrack by remember { mutableStateOf<SavedRaceTrack?>(null) }
    var renameText by remember { mutableStateOf("") }
    ScreenScaffold("SYC Courses") { padding ->
        LazyColumn(Modifier.padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Image(painterResource(R.drawable.app_icon), "SYC Courses", modifier = Modifier.size(54.dp), contentScale = ContentScale.Fit)
                    Spacer(Modifier.width(12.dp)); Text("SYC Courses", fontSize = 32.sp, fontWeight = FontWeight.Bold, color = Navy)
                }
            }
            activeNumber?.let { item { ActiveRaceHomePanel(app, nav) } }
            item { HomeCard("Quick Bearing", "Bearing and distance to a mark", Icons.Default.NearMe) { nav.navigate("quick") } }
            item { HomeCard("Flags", "Numeral pennants 0–9", Icons.Default.Flag) { nav.navigate("flags") } }
            item { HomeCard("Fixed Mark Courses", "${app.repository.fixedCourses.size} courses", Icons.Default.FormatListNumbered) { nav.navigate("courses/fixed") } }
            item { HomeCard("Laid Courses", "${app.repository.laidCourses.size} courses", Icons.Default.ChangeHistory) { nav.navigate("courses/laid") } }
            item { HomeCard("Line Assist", "Start and finish line crossing", Icons.Default.Timer) { nav.navigate("line/start") } }
            item { HomeCard("Race Tracker", "Record and review your course", Icons.Default.Map) { nav.navigate("tracker") } }
            item { HomeCard("Instruments", "Boat communication with Actisense W2K-2", Icons.Default.SettingsInputAntenna) { nav.navigate("instruments") } }
            if (recentNumbers.isNotEmpty()) {
                item { SectionHeader("Recently Viewed", "Clear…", app::clearRecents) }
                items(recentNumbers.mapNotNull(app.repository::course)) { CourseRow(it) { nav.navigate("course/${it.courseNumber}") } }
            }
            if (tracks.isNotEmpty()) {
                item { SectionHeader("Recent Tracks", "Clear…", app::clearTracks) }
                items(tracks, key = { it.id }) { track ->
                    Card(Modifier.fillMaxWidth().clickable { app.loadTrack(track); nav.navigate("tracker") }) {
                        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Map, null, tint = Teal); Spacer(Modifier.width(12.dp))
                            Column(Modifier.weight(1f)) { Text(track.displayName, fontWeight = FontWeight.Bold); Text(formatDuration(trackDuration(track.points)), color = Color.Gray) }
                            IconButton({ renameTrack = track; renameText = track.name.orEmpty() }) { Icon(Icons.Default.Edit, "Rename track") }
                            IconButton({ app.deleteTrack(track.id) }) { Icon(Icons.Default.Delete, "Delete track") }
                        }
                    }
                }
            }
        }
    }
    renameTrack?.let { track -> AlertDialog(onDismissRequest = { renameTrack = null }, title = { Text("Rename Track") }, text = { OutlinedTextField(renameText, { renameText = it }, label = { Text("Track name") }) }, confirmButton = { TextButton({ app.renameTrack(track.id, renameText); renameTrack = null }) { Text("Done") } }, dismissButton = { TextButton({ renameTrack = null }) { Text("Cancel") } }) }
}

@Composable
private fun ActiveRaceHomePanel(app: AppViewModel, nav: NavHostController) {
    val number by app.activeCourse.collectAsStateWithLifecycle(); val activeName by app.activeMark.collectAsStateWithLifecycle()
    val marks = app.activeCourseMarks(); val index = marks.indexOfFirst { it.name == activeName || it.id == activeName }
    number ?: return
    OutlinedCard(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row { Column(Modifier.weight(1f)) { Text("Course $number", fontWeight = FontWeight.Bold, fontSize = 18.sp); Text("Going to: ${marks.getOrNull(index)?.name ?: "--"}", color = Color.Gray) }; CoursePennantHoist(number!!, 58, 22) }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) { OutlinedButton(app::retreatActiveMark, enabled = index > 0) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Previous mark") }; Button(app::advanceActiveMark, enabled = index >= 0 && index < marks.lastIndex) { Text("Next Mark"); Icon(Icons.Default.ChevronRight, null) }; Spacer(Modifier.weight(1f)); IconButton({ nav.navigate("tracker") }) { Icon(Icons.Default.Map, "Race Tracker") }; IconButton({ nav.navigate("course/$number") }) { Icon(Icons.Default.FormatListNumbered, "Course") } }
        }
    }
}

@Composable private fun HomeCard(title: String, subtitle: String, icon: ImageVector, action: () -> Unit) = HomeCard(title, subtitle, icon, Modifier.fillMaxWidth(), action)
@Composable private fun HomeCard(title: String, subtitle: String, icon: ImageVector, modifier: Modifier, action: () -> Unit) = Card(modifier.clickable(onClick = action)) { Row(Modifier.padding(18.dp), verticalAlignment = Alignment.CenterVertically) { Icon(icon, null, tint = Teal, modifier = Modifier.size(30.dp)); Spacer(Modifier.width(16.dp)); Column(Modifier.weight(1f)) { Text(title, fontWeight = FontWeight.Bold, fontSize = 18.sp); Text(subtitle, color = Color.Gray) }; Icon(Icons.Default.ChevronRight, null) } }
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
private fun CoursePennantHoist(number: Int, flagWidth: Int = 76, flagHeight: Int = 29) {
    Row(
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Box(
            Modifier
                .width(2.dp)
                .height((number.toString().length * (flagHeight + 5) - 5).dp)
                .background(Color.Gray.copy(alpha = .35f)),
        )
        Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
            number.toString().forEach { digit ->
                AssetImage(
                    path = "pennants/numeral-$digit.png",
                    modifier = Modifier.width(flagWidth.dp).height(flagHeight.dp),
                    description = "Numeral pennant $digit",
                )
            }
        }
    }
}

@Composable
private fun CourseDetailScreen(app: AppViewModel, nav: NavHostController, course: Course) {
    val scope = rememberCoroutineScope(); val context = LocalContext.current
    var showActions by remember { mutableStateOf(false) }
    Scaffold(
        containerColor = Page,
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton({ nav.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                },
                title = {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(end = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            "Course ${course.courseNumber}",
                            modifier = Modifier.weight(1f),
                            fontSize = 22.sp,
                            fontWeight = FontWeight.Bold,
                        )
                        CoursePennantHoist(course.courseNumber, flagWidth = 58, flagHeight = 22)
                    }
                },
                actions = { IconButton({ showActions = true }) { Icon(Icons.Default.MoreVert, "Course actions") } },
            )
        },
    ) { padding ->
        LazyColumn(Modifier.padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    course.route?.let { Text(it, fontSize = 24.sp, fontWeight = FontWeight.Bold, color = Navy) }
                    Text(course.totalDistance, color = Color.Gray)
                    Text(
                        buildString {
                            append(course.passInstruction)
                            course.comparableCourseNote?.takeIf { it.isNotBlank() }?.let { append(", "); append(it) }
                        },
                        color = Color.Gray,
                        fontSize = 14.sp,
                    )
                }
            }
            if (course.courseNumber >= 80) {
                item { LaidCourseInfo(course) }
                if (course.chartImage.isNotBlank()) item { AssetImage(course.chartImage.removePrefix("/")) }
                item { LaidCourseSequence(course) }
            } else {
                item { ActiveCourseControls(app, course) }
                item { Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) { HomeCard("Start", "Line Assist", Icons.Default.Timer, Modifier.weight(1f)) { nav.navigate("line/start") }; HomeCard("Finish", "Options", Icons.Default.Flag, Modifier.weight(1f)) { nav.navigate("finish") } } }
                item { FixedCourseTable(app, nav, course) }
                if (course.chartImage.isNotBlank()) item { AssetImage(course.chartImage.removePrefix("/")) }
                item { NavigationOutputPanel(app, course) }
            }
        }
    }
    if (showActions) {
        ModalBottomSheet(onDismissRequest = { showActions = false }) {
            Column(Modifier.padding(20.dp).padding(bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Course Actions", fontSize = 22.sp, fontWeight = FontWeight.Bold)
                Text("Course ${course.courseNumber}", fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Text(listOf(course.totalDistance, course.passInstruction, course.comparableCourseNote).filterNotNull().filter { it.isNotBlank() }.joinToString(" · "), color = Color.Gray)
                Button({ showActions = false; shareGpx(context, app, course) }, Modifier.fillMaxWidth()) { Icon(Icons.Default.Share, null); Text(" Share GPX Route") }
                Text("Export this course as a GPX route for other navigation apps.", color = Color.Gray)
            }
        }
    }
}

@Composable
private fun ActiveCourseControls(app: AppViewModel, course: Course) {
    val activeNumber by app.activeCourse.collectAsStateWithLifecycle(); val activeName by app.activeMark.collectAsStateWithLifecycle()
    val isActive = activeNumber == course.courseNumber
    val marks = if (isActive) app.activeCourseMarks() else emptyList()
    val index = marks.indexOfFirst { it.name == activeName || it.id == activeName }
    OutlinedCard(Modifier.fillMaxWidth(), shape = RoundedCornerShape(8.dp)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) { Icon(if (isActive) Icons.Default.CheckCircle else Icons.Default.GpsFixed, null, tint = if (isActive) Color(0xFF2E7D32) else Teal); Spacer(Modifier.width(8.dp)); Text(if (isActive) "Active course" else "Set active course", Modifier.weight(1f), fontWeight = FontWeight.Bold); if (isActive) TextButton(app::clearActiveCourse) { Text("Clear") } }
            if (!isActive) Button({ app.activateCourse(course) }, Modifier.fillMaxWidth()) { Text("Set Active Course") }
            else {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { OutlinedButton(app::retreatActiveMark, enabled = index > 0) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Previous") }; Button(app::advanceActiveMark, Modifier.weight(1f), enabled = index >= 0 && index < marks.lastIndex) { Text("Next Mark"); Icon(Icons.Default.ChevronRight, null) } }
                Text("Current: ${marks.getOrNull(index)?.name ?: "--"}", color = Color.Gray)
            }
        }
    }
}

private data class DisplayLeg(val leg: CourseLeg, val mark: Mark?, val bearing: String, val distance: String)

private fun calculatedLegs(app: AppViewModel, course: Course): List<DisplayLeg> {
    var previous = app.repository.mark("SYC 4")
    return course.rows.map { leg ->
        if (leg.mark.normalizedMarkName() in setOf("total", "sub-total", "subtotal")) DisplayLeg(leg, null, "", leg.distance)
        else {
            val mark = app.repository.mark(leg.mark)
            val pass = leg.side.equals("Pass", true) || leg.bearing.equals("NA", true)
            val bearing = if (!pass && previous != null && mark != null) "%03.0f".format((NavigationMath.bearing(previous!!.latitude, previous!!.longitude, mark.latitude, mark.longitude) - 12 + 360) % 360) else leg.bearing
            val distance = if (!pass && previous != null && mark != null) "%.2f".format(NavigationMath.distanceNm(previous!!.latitude, previous!!.longitude, mark.latitude, mark.longitude)) else leg.distance
            if (!pass && mark != null) previous = mark
            DisplayLeg(leg, mark, bearing, distance)
        }
    }
}

@Composable
private fun FixedCourseTable(app: AppViewModel, nav: NavHostController, course: Course) {
    val activeNumber by app.activeCourse.collectAsStateWithLifecycle(); val activeName by app.activeMark.collectAsStateWithLifecycle()
    val rows = remember(course) { calculatedLegs(app, course) }
    OutlinedCard(Modifier.fillMaxWidth(), shape = RoundedCornerShape(8.dp)) {
        Column {
            Row(Modifier.background(Color.Gray.copy(alpha = .12f)).padding(vertical = 10.dp)) { listOf("Mark", "Side", "Bearing", "Dist").forEach { Text(it, Modifier.weight(1f).padding(horizontal = 10.dp), color = Color.Gray, fontSize = 12.sp, fontWeight = FontWeight.Bold) } }
            rows.forEach { row ->
                val tappable = row.mark != null && row.leg.mark.normalizedMarkName() !in setOf("start", "finish")
                Row(Modifier.fillMaxWidth().background(if (activeNumber == course.courseNumber && (activeName == row.mark?.name || activeName == row.mark?.id)) Teal.copy(alpha = .14f) else Color.Transparent).clickable(enabled = tappable) { row.mark?.let { nav.navigate("mark/${it.id}") } }.padding(horizontal = 10.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(row.leg.mark, Modifier.weight(1f), fontWeight = FontWeight.Bold); Text(row.leg.side, Modifier.weight(1f)); Text(row.bearing, Modifier.weight(1f)); Row(Modifier.weight(1f)) { Text(row.distance); if (tappable) Icon(Icons.Default.ChevronRight, null, Modifier.size(16.dp), tint = Color.Gray) }
                }
                HorizontalDivider()
            }
        }
    }
}

@Composable
private fun NavigationOutputPanel(app: AppViewModel, course: Course) {
    val status by app.networkStatus.collectAsStateWithLifecycle(); val settings by app.settings.collectAsStateWithLifecycle()
    val activeNumber by app.activeCourse.collectAsStateWithLifecycle(); val activeName by app.activeMark.collectAsStateWithLifecycle()
    val target = if (activeNumber == course.courseNumber) activeName?.let(app.repository::mark) else course.rows.mapNotNull { app.repository.mark(it.mark) }.firstOrNull()
    val fix = app.activeFix; val scope = rememberCoroutineScope(); var message by remember { mutableStateOf<String?>(null) }
    val connected = status in setOf("Connected", "Receiving")
    OutlinedCard(Modifier.fillMaxWidth(), shape = RoundedCornerShape(8.dp)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row { Icon(if (connected) Icons.Default.SettingsInputAntenna else Icons.Default.PortableWifiOff, null, tint = if (connected) Color(0xFF2E7D32) else Color.Gray); Spacer(Modifier.width(8.dp)); Text(if (connected) "Navigation output connected" else if (!settings.outputEnabled) "Navigation output disabled" else "Navigation output unavailable", fontWeight = FontWeight.SemiBold) }
            Text(target?.let { "Active waypoint: ${it.name}" } ?: "No fixed mark waypoint is available for this course.", color = Color.Gray)
            if (target != null) Text(if (fix == null) "Current GPS position is needed before output can be sent." else if (fix.source == NavigationSource.ACTISENSE) "Source: NMEA2000" else "Source: Android GPS", color = Color.Gray)
            message?.let { Text(it, color = if (it.startsWith("Sent")) Teal else Color.Red) }
            Button({ target?.let { mark -> scope.launch { val result = app.sendWaypoint(mark); message = if (result.isSuccess) "Sent to W2K-2" else result.exceptionOrNull()?.localizedMessage } } }, Modifier.fillMaxWidth(), enabled = connected && target != null && fix != null) { Icon(Icons.AutoMirrored.Filled.Send, null); Text(" Send to Boat") }
        }
    }
}

@Composable
private fun LaidCourseInfo(course: Course) {
    val hasGate = course.rows.any { it.mark.normalizedMarkName() == "gate" }
    OutlinedCard(Modifier.fillMaxWidth(), shape = RoundedCornerShape(8.dp)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Flag, null, tint = Teal)
                Spacer(Modifier.width(10.dp))
                Text("Race Committee Boat start and finish", fontWeight = FontWeight.Bold)
            }
            if (hasGate && course.courseNumber != 96) Text("Pass through the gate to start the next leg.", color = Color.Gray)
            if (course.courseNumber == 96) Text("Gate is not a mark of the course.", color = Color.Gray)
        }
    }
}

@Composable
private fun LaidCourseSequence(course: Course) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("Course Sequence", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = Navy)
        OutlinedCard(Modifier.fillMaxWidth(), shape = RoundedCornerShape(8.dp)) {
            Column {
                course.rows.forEachIndexed { index, row ->
                    Column(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 12.dp)) {
                        Text(row.mark, fontWeight = FontWeight.Black, fontSize = 20.sp)
                        val action = when (row.mark.normalizedMarkName()) {
                            "start", "finish" -> null
                            "gate" -> "Pass through to start the next leg"
                            else -> "Leave to ${row.side.lowercase()}"
                        }
                        action?.let { Text(it, color = Color.Gray, fontSize = 14.sp) }
                    }
                    if (index < course.rows.lastIndex) HorizontalDivider()
                }
            }
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
    val activeCourse by app.activeCourse.collectAsStateWithLifecycle()
    val activeMarkName by app.activeMark.collectAsStateWithLifecycle()
    val fix = app.activeFix
    val activeMarks = remember(activeCourse, activeMarkName) { app.activeCourseMarks() }
    val activeMark = activeMarks.firstOrNull { it.name == activeMarkName || it.id == activeMarkName }
    ScreenScaffold("Quick Bearing", { nav.popBackStack() }, actions = { IconButton(app::startLocation) { Icon(Icons.Default.Refresh, "Refresh position") } }) { padding ->
        LazyColumn(Modifier.padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item { Text(if (fix?.source == NavigationSource.ACTISENSE) "Source: NMEA2000" else if (fix != null) "Source: Android GPS" else "No valid position", color = if (fix == null) Color.Red else Teal) }
            item {
                Text("Approximate Mark Locations", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = Navy)
                Spacer(Modifier.height(8.dp))
                MarkLocationChart(app = app, onSelect = { nav.navigate("mark/${it.id}") })
            }
            if (activeMark != null) {
                item { Text("Active Mark", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = Navy) }
                item { MarkSelectionCard(activeMark, true, true) { nav.navigate("mark/${activeMark.id}") } }
            }
            item { Text("Select Mark", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = Navy) }
            items(app.repository.marks) { mark ->
                MarkSelectionCard(mark, mark in activeMarks, mark == activeMark) { nav.navigate("mark/${mark.id}") }
            }
        }
    }
    LaunchedEffect(Unit) { app.startLocation() }
}

@Composable
private fun MarkSelectionCard(mark: Mark, inActiveCourse: Boolean, isActive: Boolean, action: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = action),
        colors = CardDefaults.cardColors(containerColor = if (isActive) Teal.copy(alpha = .14f) else if (inActiveCourse) Color.Gray.copy(alpha = .08f) else Color.White),
    ) {
        Row(Modifier.fillMaxWidth().padding(15.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(mark.name, fontWeight = FontWeight.SemiBold)
                mark.description?.let { Text(it, color = Color.Gray, fontSize = 14.sp) }
                if (isActive) Text("Active mark", color = Teal, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                else if (inActiveCourse) Text("In active course", color = Color.Gray, fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }
            if (isActive) Icon(Icons.Default.GpsFixed, "Active mark", tint = Teal)
        }
    }
}

@Composable
private fun MarkDetailScreen(app: AppViewModel, nav: NavHostController, mark: Mark) {
    val phone by app.phoneFix.collectAsStateWithLifecycle(); val boat by app.actisenseFix.collectAsStateWithLifecycle()
    val activeCourse by app.activeCourse.collectAsStateWithLifecycle(); val activeMarkName by app.activeMark.collectAsStateWithLifecycle()
    val fix = app.activeFix
    val snapshot = fix?.let { NavigationMath.snapshot(it, mark) }
    val inCourse = remember(activeCourse) { mark in app.activeCourseMarks() }
    val isActive = activeMarkName == mark.name || activeMarkName == mark.id
    ScreenScaffold(mark.name, { nav.popBackStack() }) { padding ->
        LazyColumn(Modifier.padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            mark.description?.let { item { Text(it, color = Color.Gray) } }
            item { Text(if (fix?.source == NavigationSource.ACTISENSE) "Source: NMEA2000" else if (fix != null) "Source: Android GPS" else "No valid position", color = if (fix == null) Color.Red else Teal, fontWeight = FontWeight.SemiBold) }
            if (snapshot != null) {
                if (snapshot.distanceNm > 100) item { Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFFFE0B2))) { Column(Modifier.padding(16.dp)) { Text("Location looks far from SYC", fontWeight = FontWeight.Bold); Text("Current location: %.5f, %.5f".format(fix.latitude, fix.longitude)); Text("Set the emulator or device location near Sandringham for race-day distances.", color = Color.Gray) } } }
                item { MetricCard("Bearing", "%03.0f° T".format(snapshot.bearingTrue)) }
                item { MetricCard("Distance", "%.2f nm".format(snapshot.distanceNm)) }
                item { Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) { MetricCard("SOG", snapshot.speedKnots?.let { "%.1f kt".format(it) } ?: "--", Modifier.weight(1f)); MetricCard("Time", snapshot.timeToMarkSeconds?.let(::formatDuration) ?: "--", Modifier.weight(1f)) } }
                item { Text("GPS accuracy: ${snapshot.accuracyMeters?.let { "${it.toInt()} m" } ?: "--"}\nUpdated: ${formatClock(fix.timestampMillis)}", color = Color.Gray) }
            } else item { Card { Column(Modifier.padding(16.dp)) { Text("Waiting for GPS", fontWeight = FontWeight.Bold); Text("Allow location access and move into open sky if positioning is slow.", color = Color.Gray) } } }
            if (inCourse) item { Button({ app.setActiveMark(mark.name) }, Modifier.fillMaxWidth(), enabled = !isActive) { Icon(Icons.Default.GpsFixed, null); Text(if (isActive) " Going To" else " Go To") } }
            item { Button(app::startLocation, Modifier.fillMaxWidth()) { Icon(Icons.Default.Refresh, null); Text(" Refresh Position") } }
        }
    }
    LaunchedEffect(Unit) { app.startLocation() }
}

@Composable private fun MetricCard(title: String, value: String, modifier: Modifier = Modifier) = OutlinedCard(modifier, shape = RoundedCornerShape(8.dp)) { Column(Modifier.fillMaxWidth().padding(16.dp)) { Text(title.uppercase(), color = Color.Gray, fontSize = 12.sp, fontWeight = FontWeight.Bold); Text(value, fontSize = 32.sp, fontWeight = FontWeight.Bold) } }

@Composable
private fun FinishOptionsScreen(app: AppViewModel, nav: NavHostController) {
    val finish = app.repository.mark("SYC 4")!!
    ScreenScaffold("Finish", { nav.popBackStack() }) { padding ->
        Column(Modifier.padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            HomeCard("Line Crossing", "Predict crossing the SYC Tower ↔ SYC 4 finish line", Icons.Default.Timer) { nav.navigate("line/finish") }
            HomeCard("Bearing to SYC 4", "Bearing, distance, and time to the finish mark", Icons.Default.NearMe) { nav.navigate("mark/${finish.id}") }
        }
    }
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
    val activeLineIds = remember(activeCourseNumber) { app.activeCourseLineMarks().map { it.id } }
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
        Canvas(Modifier.fillMaxSize()) {
            val linePoints = activeLineIds.mapNotNull { id -> markHotspots.firstOrNull { it.markId == id } }
            linePoints.zipWithNext().forEach { (a, b) ->
                drawLine(
                    color = Color.Cyan.copy(alpha = .45f),
                    start = Offset(a.x * size.width, a.y * size.height),
                    end = Offset(b.x * size.width, b.y * size.height),
                    strokeWidth = 4.dp.toPx(),
                    pathEffect = PathEffect.dashPathEffect(floatArrayOf(7.dp.toPx(), 6.dp.toPx())),
                )
            }
        }
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
    ScreenScaffold("Flags", { nav.popBackStack() }) { padding ->
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
    var offsetText by remember { mutableStateOf(offsetMinutes.toString()) }
    var gunTimeMillis by remember {
        mutableLongStateOf(prefs.getLong("line_gun_time", nextWholeMinute(System.currentTimeMillis())))
    }
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    var showOffsetMenu by remember { mutableStateOf(false) }
    val haptics = LocalHapticFeedback.current
    val firedHaptics = remember { mutableSetOf<Int>() }
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
        while (true) {
            now = System.currentTimeMillis()
            val seconds = kotlin.math.round((startTime - now) / 1000.0).toInt()
            if (seconds in setOf(60, 30, 10, 0) && firedHaptics.add(seconds)) haptics.performHapticFeedback(HapticFeedbackType.LongPress)
            delay(1000)
        }
    }
    DisposableEffect(Unit) {
        val activity = context as? android.app.Activity
        activity?.window?.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        onDispose { activity?.window?.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) }
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
                        firedHaptics.clear()
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
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                OutlinedTextField(
                                    value = offsetText,
                                    onValueChange = { value ->
                                        offsetText = value
                                        value.toIntOrNull()?.coerceIn(-5, 25)?.let { parsed -> offsetMinutes = parsed; prefs.edit().putInt("line_offset", parsed).apply() }
                                    },
                                    modifier = Modifier.width(92.dp),
                                    suffix = { Text("min") },
                                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                    singleLine = true,
                                    textStyle = LocalTextStyle.current.copy(color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold),
                                )
                                IconButton({ showOffsetMenu = true }) { Icon(Icons.Default.ExpandMore, "Choose offset", tint = Color.White) }
                            }
                            DropdownMenu(showOffsetMenu, { showOffsetMenu = false }) {
                                (-5..25).forEach { value -> DropdownMenuItem({ Text("$value min") }, {
                                    offsetMinutes = value; offsetText = value.toString(); showOffsetMenu = false
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
    val activeNumber by app.activeCourse.collectAsStateWithLifecycle(); val activeName by app.activeMark.collectAsStateWithLifecycle()
    val phone by app.phoneFix.collectAsStateWithLifecycle(); val boat by app.actisenseFix.collectAsStateWithLifecycle()
    val points = track?.points.orEmpty(); val duration = trackDuration(points)
    var scrubSeconds by remember(track?.id) { mutableFloatStateOf(duration.toFloat()) }
    var hasScrubbed by remember { mutableStateOf(false) }
    LaunchedEffect(points.size, recording) { if (!hasScrubbed || !recording) scrubSeconds = duration.toFloat() }
    val avatar = interpolateTrack(points, scrubSeconds.toDouble())
    val courseMarks = remember(activeNumber, activeName) { app.activeCourseMarks() }
    val lineMarks = remember(activeNumber) { app.activeCourseLineMarks() }
    val activeMark = courseMarks.firstOrNull { it.name == activeName || it.id == activeName }
    val snapshot = activeMark?.let { mark -> app.activeFix?.let { NavigationMath.snapshot(it, mark) } }
    ScreenScaffold("Race Tracker", { nav.popBackStack() }) { padding ->
        Column(Modifier.padding(padding)) {
            RaceMap(points, lineMarks, courseMarks, app.repository.marks, app.repository.portPhillipCoastline, activeMark, avatar, app.activeFix, Modifier.fillMaxWidth().weight(1f))
            HorizontalDivider()
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (activeNumber != null) OutlinedCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row { Column(Modifier.weight(1f)) { Text("ACTIVE COURSE", color = Color.Gray, fontSize = 11.sp, fontWeight = FontWeight.Bold); Text("Course $activeNumber", fontWeight = FontWeight.Bold); Text(activeMark?.let { "Active mark: ${it.name}" } ?: "No active mark", color = Color.Gray) }; Column(horizontalAlignment = Alignment.End) { Text("BTW", color = Color.Gray, fontSize = 11.sp); Text(snapshot?.let { "%03.0f° T".format(it.bearingTrue) } ?: "--", fontWeight = FontWeight.Bold); Text("DTW", color = Color.Gray, fontSize = 11.sp); Text(snapshot?.let { "%.2f nm".format(it.distanceNm) } ?: "--", fontWeight = FontWeight.Bold) } }
                        val index = courseMarks.indexOf(activeMark)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { OutlinedButton(app::retreatActiveMark, enabled = index > 0) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Previous mark") }; Button(app::advanceActiveMark, enabled = index >= 0 && index < courseMarks.lastIndex) { Text("Next Mark"); Icon(Icons.Default.ChevronRight, null) } }
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button({ app.startRecording(); hasScrubbed = false }, enabled = !recording) { Icon(Icons.Default.PlayArrow, null); Text("Start") }
                    OutlinedButton(app::stopRecording, enabled = recording) { Icon(Icons.Default.Stop, null); Text("Stop") }
                    OutlinedButton({ app.resetTrack(); scrubSeconds = 0f; hasScrubbed = false }, enabled = points.isNotEmpty() || recording) { Icon(Icons.Default.Refresh, null); Text("Reset") }
                }
                Slider(scrubSeconds, { scrubSeconds = it; hasScrubbed = true }, valueRange = 0f..duration.coerceAtLeast(1.0).toFloat(), enabled = duration > 0)
                Row { Text(formatDuration(scrubSeconds.toDouble()), color = Color.Gray, fontSize = 12.sp); Spacer(Modifier.weight(1f)); Text(formatDuration(duration), color = Color.Gray, fontSize = 12.sp) }
                Row { Icon(if (recording) Icons.Default.FiberManualRecord else Icons.Default.PauseCircle, null, tint = if (recording) Color.Red else Color.Gray); Spacer(Modifier.width(6.dp)); Text(if (recording) "Recording" else if (points.isEmpty()) "Ready" else "Stopped", color = Color.Gray, fontSize = 12.sp) }
            }
        }
    }
    LaunchedEffect(Unit) { app.startLocation() }
}

private fun trackDuration(points: List<TrackPoint>): Double = if (points.size < 2) 0.0 else (points.last().timestampMillis - points.first().timestampMillis) / 1000.0
private fun interpolateTrack(points: List<TrackPoint>, seconds: Double): TrackPoint? {
    if (points.isEmpty()) return null
    val target = points.first().timestampMillis + (seconds * 1000).toLong()
    val after = points.indexOfFirst { it.timestampMillis >= target }
    if (after <= 0) return points.first()
    if (after < 0) return points.last()
    val a = points[after - 1]; val b = points[after]; val ratio = (target - a.timestampMillis).toDouble() / (b.timestampMillis - a.timestampMillis).coerceAtLeast(1)
    return TrackPoint(a.latitude + (b.latitude - a.latitude) * ratio, a.longitude + (b.longitude - a.longitude) * ratio, target)
}

@Composable
private fun RaceMap(points: List<TrackPoint>, courseLine: List<Mark>, courseMarks: List<Mark>, referenceMarks: List<Mark>, coastline: CoastlineData, activeMark: Mark?, avatar: TrackPoint?, fix: NavigationFix?, modifier: Modifier) {
    var zoom by remember { mutableFloatStateOf(1f) }
    var pan by remember { mutableStateOf(Offset.Zero) }
    val textMeasurer = rememberTextMeasurer()
    val projectedCoastline = remember(coastline) {
        coastline.paths.mapNotNull { path ->
            path.mapNotNull { coordinate ->
                if (coordinate.size < 2) null else PortPhillipProjection.project(coordinate[1], coordinate[0])
            }.takeIf { it.size >= 2 }?.let(::ProjectedMapPath)
        }
    }
    val projectedLand = remember(coastline) {
        coastline.landPolygons.map { polygon ->
            polygon.map { ring ->
                ring.mapNotNull { coordinate ->
                    if (coordinate.size < 2) null else PortPhillipProjection.project(coordinate[1], coordinate[0])
                }
            }.filter { it.size >= 3 }
        }.filter { it.isNotEmpty() }
    }
    Box(modifier.background(Color(0xFFEAF5F8))) {
        Canvas(
            Modifier
                .fillMaxSize()
                .pointerInput(Unit) {
                    detectTransformGestures { centroid, panChange, zoomChange, _ ->
                        val previousZoom = zoom
                        val nextZoom = (previousZoom * zoomChange).coerceIn(.125f, 12f)
                        val ratio = nextZoom / previousZoom
                        val centre = Offset(size.width / 2f, size.height / 2f)
                        pan = Offset(
                            centroid.x - centre.x - (centroid.x - centre.x - pan.x) * ratio + panChange.x,
                            centroid.y - centre.y - (centroid.y - centre.y - pan.y) * ratio + panChange.y,
                        )
                        zoom = nextZoom
                    }
                },
        ) {
            val focus = buildList {
                courseMarks.forEach { add(PortPhillipProjection.project(it.latitude, it.longitude)) }
                courseLine.forEach { add(PortPhillipProjection.project(it.latitude, it.longitude)) }
                points.forEach { add(PortPhillipProjection.project(it.latitude, it.longitude)) }
                avatar?.let { add(PortPhillipProjection.project(it.latitude, it.longitude)) }
                fix?.let { add(PortPhillipProjection.project(it.latitude, it.longitude)) }
            }
            val viewport = mapViewport(focus, size.width.toDouble() / size.height.toDouble())
            fun transform(position: Offset): Offset {
                val centreX = size.width / 2f
                val centreY = size.height / 2f
                return Offset(
                    centreX + (position.x - centreX) * zoom + pan.x,
                    centreY + (position.y - centreY) * zoom + pan.y,
                )
            }
            fun position(latitude: Double, longitude: Double): Offset {
                val projected = PortPhillipProjection.project(latitude, longitude)
                return transform(viewport.position(projected, size.width, size.height))
            }
            projectedLand.forEach { polygon ->
                val land = Path().apply {
                    fillType = PathFillType.EvenOdd
                    polygon.forEach { ring ->
                        val first = transform(viewport.position(ring.first(), size.width, size.height))
                        moveTo(first.x, first.y)
                        ring.drop(1).forEach { point ->
                            val transformed = transform(viewport.position(point, size.width, size.height))
                            lineTo(transformed.x, transformed.y)
                        }
                        close()
                    }
                }
                drawPath(land, Color(0xFFF3E4A6))
            }
            projectedCoastline.forEach { path ->
                path.points.zipWithNext().forEach { (a, b) ->
                    drawLine(
                        Color(0xFF58717D),
                        transform(viewport.position(a, size.width, size.height)),
                        transform(viewport.position(b, size.width, size.height)),
                        1.5.dp.toPx(),
                    )
                }
            }
            courseLine.zipWithNext().forEach { (a, b) ->
                drawLine(Color(0xFF00A7B5).copy(alpha = .65f), position(a.latitude, a.longitude), position(b.latitude, b.longitude), 5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(12.dp.toPx(), 8.dp.toPx())))
            }
            points.zipWithNext().forEach { (a, b) -> drawLine(Color(0xFF1976D2), position(a.latitude, a.longitude), position(b.latitude, b.longitude), 6.dp.toPx()) }
            referenceMarks.forEach { mark ->
                val center = position(mark.latitude, mark.longitude)
                drawCircle(Color.White, 5.dp.toPx(), center)
                drawCircle(Color(0xFF314A57), 2.8.dp.toPx(), center)
            }
            val courseIds = courseMarks.mapTo(mutableSetOf()) { it.id }
            val occupied = mutableListOf(
                Rect(0f, 0f, 170.dp.toPx(), 65.dp.toPx()),
                Rect(size.width - 55.dp.toPx(), 0f, size.width, 55.dp.toPx()),
                Rect(0f, size.height - 22.dp.toPx(), 225.dp.toPx(), size.height),
            )
            referenceMarks.forEach { mark ->
                val center = position(mark.latitude, mark.longitude)
                if (center.x in 0f..size.width && center.y in 0f..size.height) {
                    val radius = when { mark.id == activeMark?.id -> 12.dp.toPx(); mark.id in courseIds -> 9.dp.toPx(); else -> 6.dp.toPx() }
                    occupied += Rect(center.x - radius, center.y - radius, center.x + radius, center.y + radius)
                }
            }
            referenceMarks.sortedBy { mark -> when { mark.id == activeMark?.id -> 0; mark.id in courseIds -> 1; else -> 2 } }.forEach { mark ->
                val center = position(mark.latitude, mark.longitude)
                if (center.x !in 0f..size.width || center.y !in 0f..size.height) return@forEach
                val isActive = mark.id == activeMark?.id
                val isInCourse = mark.id in courseIds
                val style = TextStyle(
                    color = when { isActive -> Color(0xFFB45309); isInCourse -> Color(0xFF006A73); else -> Navy },
                    fontSize = (8.5f + zoom.coerceIn(.125f, 1f) * 1.5f).sp,
                    fontWeight = if (isActive || isInCourse) FontWeight.Bold else FontWeight.SemiBold,
                )
                val layout = textMeasurer.measure(mark.name, style = style)
                val labelWidth = layout.size.width.toFloat()
                val labelHeight = layout.size.height.toFloat()
                val minimumGap = if (isActive) 12.dp.toPx() else 7.dp.toPx()
                val candidates = listOf(0f, 15.dp.toPx(), 30.dp.toPx(), 45.dp.toPx()).flatMap { extra ->
                    val gap = minimumGap + extra
                    listOf(
                        Offset(center.x + gap, center.y - labelHeight / 2f),
                        Offset(center.x - labelWidth - gap, center.y - labelHeight / 2f),
                        Offset(center.x - labelWidth / 2f, center.y - labelHeight - gap),
                        Offset(center.x - labelWidth / 2f, center.y + gap),
                        Offset(center.x + gap, center.y - labelHeight - gap),
                        Offset(center.x - labelWidth - gap, center.y - labelHeight - gap),
                        Offset(center.x + gap, center.y + gap),
                        Offset(center.x - labelWidth - gap, center.y + gap),
                    )
                }
                fun labelRect(topLeft: Offset) = Rect(
                    topLeft.x - 2.dp.toPx(), topLeft.y - 1.dp.toPx(),
                    topLeft.x + labelWidth + 2.dp.toPx(), topLeft.y + labelHeight + 1.dp.toPx(),
                )
                fun overlapArea(a: Rect, b: Rect): Float {
                    val width = (minOf(a.right, b.right) - maxOf(a.left, b.left)).coerceAtLeast(0f)
                    val height = (minOf(a.bottom, b.bottom) - maxOf(a.top, b.top)).coerceAtLeast(0f)
                    return width * height
                }
                val topLeft = candidates.minBy { candidate ->
                    val rect = labelRect(candidate)
                    occupied.sumOf { overlapArea(rect, it).toDouble() } +
                        (if (rect.left < 0f || rect.top < 0f || rect.right > size.width || rect.bottom > size.height) 1_000_000.0 else 0.0) +
                        kotlin.math.hypot((rect.left + rect.right) / 2f - center.x, (rect.top + rect.bottom) / 2f - center.y) * .01
                }
                val rect = labelRect(topLeft)
                occupied += rect
                val leaderEnd = Offset(
                    center.x.coerceIn(rect.left, rect.right),
                    center.y.coerceIn(rect.top, rect.bottom),
                )
                if (kotlin.math.hypot(leaderEnd.x - center.x, leaderEnd.y - center.y) > minimumGap * 1.5f) {
                    drawLine(Color(0xFF526B76).copy(alpha = .55f), center, leaderEnd, 1.dp.toPx())
                }
                drawRoundRect(
                    Color.White.copy(alpha = .86f),
                    Offset(rect.left, rect.top),
                    androidx.compose.ui.geometry.Size(rect.width, rect.height),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(2.dp.toPx()),
                )
                drawText(textMeasurer, mark.name, topLeft = topLeft, style = style)
            }
            courseMarks.forEach { mark ->
                val center = position(mark.latitude, mark.longitude)
                drawCircle(Color.White, if (mark.id == activeMark?.id) 10.dp.toPx() else 7.dp.toPx(), center)
                drawCircle(if (mark.id == activeMark?.id) Color(0xFFFF9800) else Color(0xFF00A7B5), if (mark.id == activeMark?.id) 6.dp.toPx() else 4.dp.toPx(), center)
            }
            avatar?.let { drawCircle(Color(0xFFFF9800), 8.dp.toPx(), position(it.latitude, it.longitude)) }
            fix?.let { drawCircle(Color(0xFF1976D2), 7.dp.toPx(), position(it.latitude, it.longitude)) }
        }
        Text("N ↑", Modifier.align(Alignment.TopEnd).padding(10.dp), color = Navy, fontWeight = FontWeight.Black)
        Surface(
            Modifier.align(Alignment.TopStart).padding(10.dp),
            shape = RoundedCornerShape(24.dp),
            color = Color.White.copy(alpha = .92f),
            tonalElevation = 3.dp,
        ) {
            Row {
                IconButton({ zoom = (zoom / 1.5f).coerceAtLeast(.125f) }, enabled = zoom > .125f) { Icon(Icons.Default.ZoomOut, "Zoom out") }
                IconButton({ zoom = (zoom * 1.5f).coerceAtMost(12f) }, enabled = zoom < 12f) { Icon(Icons.Default.ZoomIn, "Zoom in") }
                IconButton({ zoom = 1f; pan = Offset.Zero }, enabled = zoom != 1f || pan != Offset.Zero) { Icon(Icons.Default.CenterFocusStrong, "Re-centre map") }
            }
        }
        Text(
            "${coastline.attribution} · Not for navigation",
            Modifier.align(Alignment.BottomStart).background(Color.White.copy(alpha = .82f)).padding(horizontal = 6.dp, vertical = 3.dp),
            color = Color(0xFF455A64),
            fontSize = 9.sp,
        )
    }
}

private data class ProjectedMapPath(val points: List<ProjectedPoint>) {
}

private data class MapViewport(val left: Double, val right: Double, val bottom: Double, val top: Double) {
    fun position(point: ProjectedPoint, width: Float, height: Float) = Offset(
        ((point.easting - left) / (right - left) * width).toFloat(),
        ((top - point.northing) / (top - bottom) * height).toFloat(),
    )
}

private fun mapViewport(focus: List<ProjectedPoint>, canvasAspect: Double): MapViewport {
    val relevant = focus.takeIf { it.isNotEmpty() } ?: listOf(
        PortPhillipProjection.project(-38.45, 144.4),
        PortPhillipProjection.project(-37.75, 145.15),
    )
    val centreEasting = (relevant.minOf { it.easting } + relevant.maxOf { it.easting }) / 2.0
    val centreNorthing = (relevant.minOf { it.northing } + relevant.maxOf { it.northing }) / 2.0
    var width = (relevant.maxOf { it.easting } - relevant.minOf { it.easting }).coerceAtLeast(8_000.0) * 1.3
    var height = (relevant.maxOf { it.northing } - relevant.minOf { it.northing }).coerceAtLeast(8_000.0) * 1.3
    if (width / height < canvasAspect) width = height * canvasAspect else height = width / canvasAspect
    return MapViewport(
        centreEasting - width / 2.0,
        centreEasting + width / 2.0,
        centreNorthing - height / 2.0,
        centreNorthing + height / 2.0,
    )
}

@Composable
private fun InstrumentsScreen(app: AppViewModel, nav: NavHostController) {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("syc_courses", android.content.Context.MODE_PRIVATE) }
    var settings by remember { mutableStateOf(app.settings.value) }; val status by app.networkStatus.collectAsStateWithLifecycle()
    val lastMessage by app.lastOutputMessage.collectAsStateWithLifecycle(); val outputCount by app.outputCount.collectAsStateWithLifecycle(); val outputError by app.outputError.collectAsStateWithLifecycle(); val lastReconnect by app.lastReconnectMillis.collectAsStateWithLifecycle()
    var discoveryMessage by remember { mutableStateOf<String?>(null) }; var discovering by remember { mutableStateOf(false) }; var showGeometry by remember { mutableStateOf(false) }; var showDiagnostics by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    var useBow by remember { mutableStateOf(prefs.getBoolean("line_use_bow", true)) }
    var bowOffset by remember { mutableStateOf(prefs.getFloat("line_bow_offset", 9.4f).toString()) }
    var sidewaysOffset by remember { mutableStateOf(prefs.getFloat("line_gps_sideways", 0f).toString()) }
    var bearingSource by remember { mutableStateOf(runCatching { BearingSource.valueOf(prefs.getString("line_bearing_source", "COG")!!) }.getOrDefault(BearingSource.COG)) }
    fun persist(value: ActisenseSettings) { settings = value; app.updateSettings(value) }
    ScreenScaffold("Instruments", { nav.popBackStack() }) { padding -> LazyColumn(Modifier.padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { Text("Configure one Actisense W2K-2, then choose input, output, or both.", color = Color.Gray) }
        item { Text("Instrument display depends on W2K-2 configuration and downstream support.", color = Color.Gray, fontSize = 12.sp) }
        item { Text("Actisense W2K-2", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = Navy) }
        item { OutlinedTextField(settings.host, { persist(settings.copy(host = it)) }, Modifier.fillMaxWidth(), label = { Text("IP address") }) }
        item { OutlinedTextField(settings.port.toString(), { it.toIntOrNull()?.let { port -> persist(settings.copy(port = port)) } }, Modifier.fillMaxWidth(), label = { Text("Data server port") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)) }
        item { Row { FilterChip(settings.protocol == NetworkProtocol.TCP, { persist(settings.copy(protocol = NetworkProtocol.TCP)) }, { Text("TCP") }); Spacer(Modifier.width(8.dp)); FilterChip(settings.protocol == NetworkProtocol.UDP, { persist(settings.copy(protocol = NetworkProtocol.UDP)) }, { Text("UDP") }) } }
        item { OutlinedButton({ scope.launch { discovering = true; discoveryMessage = "Scanning likely W2K-2 addresses and ports…"; val found = discoverActisense(settings.host, settings.port); discovering = false; if (found != null) { persist(settings.copy(host = found.first, port = found.second)); discoveryMessage = "Found Actisense at ${found.first}:${found.second}." } else discoveryMessage = "No Actisense data server found. Check Wi-Fi, IP address, and port." } }, enabled = !discovering) { Icon(Icons.Default.Search, null); Text(if (discovering) " Finding Actisense" else " Find Actisense") } }
        discoveryMessage?.let { item { Text(it, color = if (it.startsWith("No")) Color.Red else Color.Gray, fontSize = 12.sp) } }
        item { SettingSwitch("Use for boat data input", settings.inputEnabled) { persist(settings.copy(inputEnabled = it)) } }
        item { SettingSwitch("Send output to instruments", settings.outputEnabled) { persist(settings.copy(outputEnabled = it)) } }
        if (settings.outputEnabled) item { SettingSwitch("Auto-connect output", settings.autoConnectOutput) { persist(settings.copy(autoConnectOutput = it)) } }
        item { Text("The data server port is the TCP/UDP port configured for NMEA 0183 streaming. Common setups use 60001.", color = Color.Gray, fontSize = 12.sp) }
        item { Text("Quick Bearing and Line Assist prefer fresh Actisense position/SOG and fall back to Android GPS when it is stale.", color = Color.Gray, fontSize = 12.sp) }
        item { HorizontalDivider(); Text("Actisense Status", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = Navy) }
        item { Row { Text("Input", Modifier.weight(1f)); Text(if (settings.inputEnabled) status else "Disabled", fontWeight = FontWeight.SemiBold) } }
        item { Row { Text("Output", Modifier.weight(1f)); Text(if (settings.outputEnabled) status else "Disabled", fontWeight = FontWeight.SemiBold) } }
        if (status.startsWith("Error")) item { Text(status, color = Color.Red, fontSize = 12.sp) }
        item { Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { Button({ app.connectActisense() }, Modifier.weight(1f), enabled = settings.host.isNotBlank() && settings.port in 1..65535) { Text("Test Connection") }; OutlinedButton(app::disconnectActisense, Modifier.weight(1f), enabled = status != "Disconnected") { Text("Disconnect") } } }
        item { OutlinedButton({ app.repository.mark("SYC 4")?.let { mark -> scope.launch { app.sendWaypoint(mark) } } }, enabled = settings.outputEnabled && status in setOf("Connected", "Receiving") && app.activeFix != null) { Text("Test Output") } }
        item { HorizontalDivider(); TextButton({ showGeometry = !showGeometry }) { Text("Line Assist · Boat Geometry"); Icon(if (showGeometry) Icons.Default.ExpandLess else Icons.Default.ExpandMore, null) } }
        if (showGeometry) item { SettingSwitch("Use bow position for Line Assist", useBow) { useBow = it; prefs.edit().putBoolean("line_use_bow", it).apply() } }
        if (showGeometry) item { OutlinedTextField(bowOffset, { value -> bowOffset = value; value.toFloatOrNull()?.let { prefs.edit().putFloat("line_bow_offset", it.coerceIn(0f, 30f)).apply() } }, Modifier.fillMaxWidth(), label = { Text("GPS to bow distance (m)") }, supportingText = { Text("Measured forward from the GPS/compass sensor to the bow.") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)) }
        if (showGeometry) item { OutlinedTextField(sidewaysOffset, { value -> sidewaysOffset = value; value.toFloatOrNull()?.let { prefs.edit().putFloat("line_gps_sideways", it.coerceIn(-10f, 10f)).apply() } }, Modifier.fillMaxWidth(), label = { Text("GPS sideways offset (m)") }, supportingText = { Text("Positive is starboard; negative is port.") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)) }
        if (showGeometry) item {
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
        if (showGeometry) item { Text("Course over ground is the default. Heading projection is available when filtered heading data is reliable. Line Assist uses the bow because the boat starts or finishes when the bow crosses the line.", color = Color.Gray, fontSize = 12.sp) }
        item { HorizontalDivider(); TextButton({ showDiagnostics = !showDiagnostics }) { Text("Diagnostics / Advanced"); Icon(if (showDiagnostics) Icons.Default.ExpandLess else Icons.Default.ExpandMore, null) } }
        if (showDiagnostics) {
            item { DiagnosticRow("Device / host", if (settings.host.isBlank()) "Not configured" else "${settings.host}:${settings.port}") }
            item { DiagnosticRow("Connection", status) }
            item { DiagnosticRow("Last message sent", lastMessage ?: "None") }
            item { DiagnosticRow("Message count", outputCount.toString()) }
            item { DiagnosticRow("Last error", outputError ?: "None") }
            item { DiagnosticRow("Last reconnect", lastReconnect?.let(::formatClock) ?: "Never") }
        }
    } }
    LaunchedEffect(Unit) { if ((settings.inputEnabled || settings.autoConnectOutput) && status == "Disconnected") app.connectActisense() }
}

@Composable private fun DiagnosticRow(label: String, value: String) = Row(Modifier.fillMaxWidth()) { Text(label, Modifier.weight(1f)); Text(value, color = Color.Gray) }

private suspend fun discoverActisense(currentHost: String, currentPort: Int): Pair<String, Int>? = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
    val hosts = listOf(currentHost, "192.168.4.1", "192.168.1.1", "192.168.0.1", "10.0.0.1").filter { it.isNotBlank() }.distinct()
    val ports = listOf(currentPort, 60001, 60002, 60003).filter { it in 1..65535 }.distinct()
    for (host in hosts) for (port in ports) runCatching { java.net.Socket().use { it.connect(java.net.InetSocketAddress(host, port), 750) } }.onSuccess { return@withContext host to port }
    null
}

@Composable private fun SettingSwitch(label: String, checked: Boolean, change: (Boolean) -> Unit) = Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) { Text(label, Modifier.weight(1f)); Switch(checked, change) }

@Composable private fun ScreenScaffold(title: String, back: (() -> Unit)? = null, actions: @Composable RowScope.() -> Unit = {}, content: @Composable (PaddingValues) -> Unit) { Scaffold(containerColor = Page, topBar = { if (back != null) TopAppBar(title = { Text(title, fontWeight = FontWeight.Bold) }, navigationIcon = { IconButton(back) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back") } }, actions = actions) }, content = content) }

private fun formatDuration(seconds: Double): String { val value = seconds.coerceAtLeast(0.0).toInt(); return "%d:%02d".format(value / 60, value % 60) }

private fun shareGpx(context: android.content.Context, app: AppViewModel, course: Course) {
    val marks = course.rows.mapNotNull { leg -> app.repository.mark(leg.mark)?.let { leg.mark to it } }
    val xml = buildString { append("<?xml version=\"1.0\" encoding=\"UTF-8\"?><gpx version=\"1.1\" creator=\"SYC Courses\" xmlns=\"http://www.topografix.com/GPX/1/1\"><rte><name>SYC Course ${course.courseNumber}</name>"); marks.forEach { (name, mark) -> append("<rtept lat=\"${mark.latitude}\" lon=\"${mark.longitude}\"><name>${name.replace("&", "&amp;").replace("<", "&lt;")}</name></rtept>") }; append("</rte></gpx>") }
    val dir = File(context.cacheDir, "shared").apply { mkdirs() }; val file = File(dir, "SYC_Course_${course.courseNumber}.gpx").apply { writeText(xml) }; val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
    context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply { type = "application/gpx+xml"; putExtra(Intent.EXTRA_STREAM, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION) }, "Share GPX"))
}
