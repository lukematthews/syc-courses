package com.lukematthews.syccourses

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun ClubAccessScreen(working: Boolean, message: String?, activate: (String) -> Unit) {
    var invitation by remember { mutableStateOf("") }
    Box(Modifier.fillMaxSize().background(Color(0xFFF1F5F8)).padding(24.dp), contentAlignment = Alignment.Center) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 8.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Image(painterResource(R.drawable.app_icon), null, Modifier.size(96.dp))
            Text("Club access", fontSize = 32.sp, fontWeight = FontWeight.Bold, color = Color(0xFF102D3D))
            Text("Enter the invitation code supplied by your sailing club. No member account, payment or email address is required.", textAlign = TextAlign.Center, color = Color.Gray)
            Card(Modifier.fillMaxWidth(), shape = RoundedCornerShape(14.dp), colors = CardDefaults.cardColors(containerColor = Color.White)) {
                Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    OutlinedTextField(
                        value = invitation,
                        onValueChange = { invitation = it.uppercase() },
                        label = { Text("Invitation code") },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters, keyboardType = KeyboardType.Ascii),
                        modifier = Modifier.fillMaxWidth(),
                    )
                    message?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                    Button(
                        onClick = { activate(invitation.trim()) },
                        enabled = !working && invitation.isNotBlank(),
                        modifier = Modifier.fillMaxWidth().height(52.dp),
                    ) {
                        if (working) CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp, color = Color.White)
                        else Text("Activate club")
                    }
                }
            }
            Spacer(Modifier.height(12.dp))
        }
    }
}
