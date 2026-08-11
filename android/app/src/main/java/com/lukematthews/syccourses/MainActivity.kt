package com.lukematthews.syccourses

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.lifecycle.viewmodel.compose.viewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val app: AppViewModel = viewModel()
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
