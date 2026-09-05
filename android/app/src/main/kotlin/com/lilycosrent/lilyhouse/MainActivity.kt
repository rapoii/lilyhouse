package com.lilycosrent.lilyhouse

import android.os.Build
import android.os.Bundle
import android.view.Display
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        unlockUltraHighRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        unlockUltraHighRefreshRate()
    }

    private fun unlockUltraHighRefreshRate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+ (API 30+): Set preferred display mode to the highest available refresh rate (120Hz, 144Hz, 165Hz, 240Hz+)
            try {
                val display = display ?: return
                val supportedModes = display.supportedModes
                if (supportedModes != null && supportedModes.isNotEmpty()) {
                    var maxRateMode: Display.Mode? = null
                    var maxRate = 0f
                    for (mode in supportedModes) {
                        if (mode.refreshRate > maxRate) {
                            maxRate = mode.refreshRate
                            maxRateMode = mode
                        }
                    }
                    if (maxRateMode != null) {
                        val params = window.attributes
                        params.preferredDisplayModeId = maxRateMode.modeId
                        // Use reflection for Android 12+ (API 31+) preferredMin/MaxDisplayRefreshRate to ensure backward/forward compile compatibility
                        try {
                            val minField = params.javaClass.getField("preferredMinDisplayRefreshRate")
                            val maxField = params.javaClass.getField("preferredMaxDisplayRefreshRate")
                            minField.setFloat(params, maxRate)
                            maxField.setFloat(params, maxRate)
                        } catch (_: Exception) {
                            // Property not available on this compile SDK version
                        }
                        window.attributes = params
                    }
                }
            } catch (e: Exception) {
                // Fallback gracefully on low-end / unsupported vendor firmware
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            // Android 6 - 10 (API 23-29): Legacy display mode selection
            try {
                @Suppress("DEPRECATION")
                val windowManager = getSystemService(WINDOW_SERVICE) as? WindowManager
                @Suppress("DEPRECATION")
                val display = windowManager?.defaultDisplay ?: return
                @Suppress("DEPRECATION")
                val supportedModes = display.supportedModes
                if (supportedModes != null && supportedModes.isNotEmpty()) {
                    var maxRateMode: Display.Mode? = null
                    var maxRate = 0f
                    for (mode in supportedModes) {
                        if (mode.refreshRate > maxRate) {
                            maxRate = mode.refreshRate
                            maxRateMode = mode
                        }
                    }
                    if (maxRateMode != null) {
                        val params = window.attributes
                        params.preferredDisplayModeId = maxRateMode.modeId
                        window.attributes = params
                    }
                }
            } catch (e: Exception) {
                // Fallback gracefully
            }
        }
    }
}
