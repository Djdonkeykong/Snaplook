package com.snaplook.snaplook

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.snaplook.snaplook.R
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val shareLogsChannel = "snaplook/share_extension_logs"
    private var splashOverlay: View? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareLogsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLogs" -> result.success(emptyList<String>())
                    "clearLogs" -> result.success(null)
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        addSplashOverlay()
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        intent?.let {
            Log.d("SnaplookShare", "Intent received:")
            Log.d("SnaplookShare", "Action: ${it.action}")
            Log.d("SnaplookShare", "Type: ${it.type}")
            Log.d("SnaplookShare", "Data: ${it.data}")
            Log.d("SnaplookShare", "ClipData: ${it.clipData}")
            Log.d("SnaplookShare", "Extras: ${it.extras}")

            // Log all extras
            it.extras?.let { bundle ->
                for (key in bundle.keySet()) {
                    Log.d("SnaplookShare", "Extra $key: ${bundle.get(key)}")
                }
            }

            // Log ClipData items
            it.clipData?.let { clipData ->
                Log.d("SnaplookShare", "ClipData item count: ${clipData.itemCount}")
                for (i in 0 until clipData.itemCount) {
                    val item = clipData.getItemAt(i)
                    Log.d("SnaplookShare", "ClipData item $i: uri=${item.uri}, text=${item.text}")
                }
            }
        }
    }

    private fun addSplashOverlay() {
        val rootView = findViewById<ViewGroup>(android.R.id.content)
        if (rootView != null && splashOverlay == null) {
            splashOverlay = LayoutInflater.from(this)
                .inflate(R.layout.launch_splash_overlay, rootView, false)
            rootView.addView(
                splashOverlay,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                ),
            )
        }
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        splashOverlay?.let { overlay ->
            val parent = overlay.parent as? ViewGroup
            parent?.removeView(overlay)
        }
        splashOverlay = null
    }
}
