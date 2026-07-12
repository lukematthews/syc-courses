package com.lukematthews.syccourses

import android.Manifest
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.lifecycle.viewmodel.compose.viewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val app: AppViewModel = viewModel()
            val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
                app.startLocation()
            }
            LaunchedEffect(Unit) {
                permission.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
            }
            MaterialTheme(
                colorScheme = MaterialTheme.colorScheme.copy(
                    primary = Color(0xFF087F8C),
                    secondary = Color(0xFFE6A33A),
                    background = Color(0xFFF1F5F8),
                    surface = Color.White,
                )
            ) {
                Surface(Modifier.fillMaxSize().background(Color(0xFFF1F5F8))) { SYCCoursesApp(app) }
            }
        }
    }
}
