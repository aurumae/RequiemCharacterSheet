package ie.forsaken.sheet

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import ie.chronicles.ui.DarkPackSplash

@Composable
internal fun LaunchWithDarkPack(content: @Composable () -> Unit) = DarkPackSplash(
    R.drawable.dark_pack, stringResource(R.string.dark_pack_copyright), stringResource(R.string.dark_pack_disclaimer), content)
