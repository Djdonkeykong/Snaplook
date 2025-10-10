package com.snaplook.snaplook

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
}