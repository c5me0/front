package com.cameo.cameo

import android.os.Bundle
import android.os.SystemClock
import android.view.View
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private var keyboardVisible = false
    private var hideAllowedAt = 0L
    private val hideNavigationBar = Runnable {
        if (hasWindowFocus() && !keyboardVisible) {
            // Use insets APIs so this also works with Android 16's edge-to-edge layout.
            WindowCompat.getInsetsController(window, window.decorView).apply {
                systemBarsBehavior =
                    WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                hide(WindowInsetsCompat.Type.navigationBars())
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Observe the container and leave FlutterView's own inset handling intact.
        ViewCompat.setOnApplyWindowInsetsListener(findViewById(android.R.id.content)) { _, insets ->
            val visible = insets.isVisible(WindowInsetsCompat.Type.ime())
            if (keyboardVisible != visible) {
                keyboardVisible = visible
                if (!visible) {
                    // Android temporarily blocks hiding system bars after the keyboard closes.
                    hideAllowedAt = SystemClock.uptimeMillis() + 1100L
                }
                scheduleNavigationBarHide()
            }
            insets
        }
    }

    override fun onPostResume() {
        super.onPostResume()
        // Flutter restores its system UI here; apply our navigation policy afterwards.
        scheduleNavigationBarHide()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            scheduleNavigationBarHide()
        } else {
            window.decorView.removeCallbacks(hideNavigationBar)
        }
    }

    private fun scheduleNavigationBarHide() {
        val decorView = window.decorView
        decorView.removeCallbacks(hideNavigationBar)
        if (!keyboardVisible) {
            decorView.postDelayed(
                hideNavigationBar,
                (hideAllowedAt - SystemClock.uptimeMillis()).coerceAtLeast(0L),
            )
        }
    }

    override fun onDestroy() {
        window.decorView.removeCallbacks(hideNavigationBar)
        ViewCompat.setOnApplyWindowInsetsListener(findViewById<View>(android.R.id.content), null)
        super.onDestroy()
    }
}
