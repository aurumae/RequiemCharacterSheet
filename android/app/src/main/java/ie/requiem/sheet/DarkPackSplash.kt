package ie.requiem.sheet

import android.os.SystemClock
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay

@Composable
internal fun LaunchWithDarkPack(content: @Composable () -> Unit) {
    // A monotonic deadline avoids restarting the five seconds on rotation.
    val deadline = rememberSaveable { SystemClock.elapsedRealtime() + 5_000L }
    var dismissed by rememberSaveable { mutableStateOf(false) }
    if (dismissed) {
        content()
    } else {
        LaunchedEffect(deadline) {
            delay((deadline - SystemClock.elapsedRealtime()).coerceIn(0, 5_000L))
            dismissed = true
        }
        Box(Modifier.fillMaxSize().background(Color.White).testTag("dark-pack-splash")
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null,
                role = androidx.compose.ui.semantics.Role.Button, onClickLabel = "Continue to app") { dismissed = true }) {
            Column(Modifier.fillMaxSize().safeDrawingPadding().verticalScroll(rememberScrollState()).padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                Image(painterResource(R.drawable.dark_pack), "Dark Pack", Modifier.size(150.dp))
                Spacer(Modifier.height(28.dp))
                SheetText(stringResource(R.string.dark_pack_copyright), textAlign = TextAlign.Center,
                    style = MaterialTheme.typography.bodySmall)
                Spacer(Modifier.height(20.dp))
                SheetText(stringResource(R.string.dark_pack_disclaimer), textAlign = TextAlign.Center,
                    style = MaterialTheme.typography.bodySmall)
                Spacer(Modifier.height(28.dp))
                SheetText("Tap anywhere to continue", color = SheetColors.muted, textAlign = TextAlign.Center,
                    style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}
