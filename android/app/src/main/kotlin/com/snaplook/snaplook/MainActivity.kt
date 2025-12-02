package com.snaplook.snaplook

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.content.res.ResourcesCompat
import android.graphics.BitmapFactory
import android.app.PictureInPictureParams

class MainActivity: FlutterActivity() {
    private val launchLogTag = "SnaplookLaunch"
    private val shareLogsChannel = "snaplook/share_extension_logs"
    private val shareStatusChannelName = "com.snaplook.snaplook/share_status"
    private val authChannelName = "snaplook/auth"
    private val pipTutorialChannel = "pip_tutorial"
    private val shareStatusPrefs by lazy {
        getSharedPreferences("snaplook_share_status", MODE_PRIVATE)
    }

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareStatusChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "configureShareExtension" -> result.success(null)
                    "updateShareProcessingStatus" -> {
                        val status = (call.arguments as? Map<*, *>)?.get("status") as? String
                        if (status != null) {
                            shareStatusPrefs.edit().putString("processing_status", status).apply()
                        }
                        result.success(null)
                    }
                    "markShareProcessingComplete" -> {
                        shareStatusPrefs.edit().putString("processing_status", "completed").apply()
                        result.success(null)
                    }
                    "getShareProcessingSession" -> {
                        val status = shareStatusPrefs.getString("processing_status", null)
                        result.success(mapOf("sessionId" to null, "status" to status))
                    }
                    "getPendingSearchId" -> {
                        result.success(null)
                    }
                    "getPendingPlatformType" -> {
                        val platform = shareStatusPrefs.getString("pending_platform_type", null)
                        if (platform != null) {
                            shareStatusPrefs.edit().remove("pending_platform_type").apply()
                        }
                        result.success(platform)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, authChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setAuthFlag" -> {
                        val args = call.arguments as? Map<*, *>
                        val isAuthenticated = args?.get("isAuthenticated") as? Boolean
                        if (isAuthenticated == null) {
                            result.error("INVALID_ARGS", "isAuthenticated missing", null)
                            return@setMethodCallHandler
                        }
                        val userId = args["userId"] as? String
                        shareStatusPrefs.edit()
                            .putBoolean("user_authenticated", isAuthenticated)
                            .apply()
                        if (userId != null) {
                            shareStatusPrefs.edit()
                                .putString("supabase_user_id", userId)
                                .apply()
                        } else {
                            shareStatusPrefs.edit()
                                .remove("supabase_user_id")
                                .apply()
                        }
                        Log.d("SnaplookAuth", "setAuthFlag -> authenticated=$isAuthenticated userId=${userId ?: "null"}")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pipTutorialChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val args = call.arguments as? Map<*, *>
                        val target = args?.get("target") as? String
                        val video = args?.get("video") as? String
                            ?: if (target == "instagram") {
                                "assets/videos/instagram-tutorial.mp4"
                            } else {
                                "assets/videos/pip-test.mp4"
                            }
                        if (target == null) {
                            result.error("INVALID_ARGS", "Missing target", null)
                            return@setMethodCallHandler
                        }
                        val intent = Intent(this, TutorialPipActivity::class.java).apply {
                            putExtra("assetKey", video)
                            putExtra("target", target)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        logSplashResourceState()
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

            storeBrowserPlatform(it)
        }
    }

    private fun storeBrowserPlatform(intent: Intent) {
        val packageName = detectReferrerPackage(intent) ?: return
        val platformType = when (packageName.lowercase()) {
            "com.android.chrome", "com.chrome.beta", "com.chrome.dev", "com.chrome.canary" -> "chrome"
            "org.mozilla.firefox", "org.mozilla.firefox_beta", "org.mozilla.focus", "org.mozilla.klar" -> "firefox"
            "com.brave.browser", "com.brave.browser_beta" -> "brave"
            else -> null
        } ?: return

        shareStatusPrefs.edit().putString("pending_platform_type", platformType).apply()
        Log.d("SnaplookShare", "Detected browser source: $platformType (package=$packageName)")
    }

    private fun detectReferrerPackage(intent: Intent): String? {
        var packageName: String? = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            val parcelableReferrer: Uri? = intent.getParcelableExtra(Intent.EXTRA_REFERRER)
                ?: intent.getStringExtra(Intent.EXTRA_REFERRER_NAME)?.let { Uri.parse(it) }
                ?: referrer

            parcelableReferrer?.let { uri ->
                when {
                    uri.scheme == "android-app" -> packageName = uri.host
                    uri.scheme == "https" && uri.host == "android-app" && uri.pathSegments.isNotEmpty() -> {
                        packageName = uri.pathSegments.last()
                    }
                }
            }
        }

        if (packageName.isNullOrEmpty()) {
            val referrerName = intent.getStringExtra(Intent.EXTRA_REFERRER_NAME)
            if (!referrerName.isNullOrEmpty()) {
                packageName = referrerName.removePrefix("android-app://")
            }
        }

        return packageName
    }

    private fun logSplashResourceState() {
        val splashId = resources.getIdentifier("transparent_splash_icon", "drawable", packageName)
        if (splashId != 0) {
            val bmp = BitmapFactory.decodeResource(resources, splashId)
            Log.d(
                launchLogTag,
                "transparent_splash_icon -> resId=$splashId size=${bmp.width}x${bmp.height}"
            )
        } else {
            Log.w(launchLogTag, "transparent_splash_icon drawable not found at runtime")
        }
        val bgColorId = resources.getIdentifier("splash_background", "color", packageName)
        if (bgColorId != 0) {
            val color = ResourcesCompat.getColor(resources, bgColorId, theme)
            Log.d(launchLogTag, "splash_background -> color=#${Integer.toHexString(color)}")
        } else {
            Log.w(launchLogTag, "splash_background color not found at runtime")
        }
    }
}
