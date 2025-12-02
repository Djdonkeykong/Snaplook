package com.snaplook.snaplook

import android.app.PictureInPictureParams
import android.content.Intent
import android.content.res.Configuration
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.Rational
import android.widget.FrameLayout
import android.widget.VideoView
import androidx.appcompat.app.AppCompatActivity
import io.flutter.FlutterInjector
import java.io.File
import java.lang.ref.WeakReference
import android.media.AudioAttributes

class TutorialPipActivity : AppCompatActivity() {
  private var videoView: VideoView? = null
  private var hasStartedPip = false
  private fun stopAndFinish() {
    hasStartedPip = false
    try {
      videoView?.stopPlayback()
    } catch (_: Exception) {
      // ignore stop errors
    }
    if (!isFinishing) {
      finishAndRemoveTask()
    }
  }

  companion object {
    private var currentInstance: WeakReference<TutorialPipActivity>? = null

    fun stopActive() {
      currentInstance?.get()?.let { activity ->
        activity.runOnUiThread {
          activity.stopAndFinish()
        }
      }
    }
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    currentInstance = WeakReference(this)

    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
      finish()
      return
    }

        val container = FrameLayout(this)
        videoView = VideoView(this)
        container.addView(
            videoView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )
        setContentView(container)

        val assetKey = intent.getStringExtra("assetKey") ?: run {
            finish()
            return
        }
        Log.d("TutorialPip", "assetKey=$assetKey")
        val target = intent.getStringExtra("target") ?: ""

        val videoFile = copyAssetToCache(assetKey)
        if (videoFile == null) {
            finish()
            return
        }

        videoView?.setVideoURI(Uri.fromFile(videoFile))
        videoView?.setOnPreparedListener { mp: MediaPlayer ->
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
                    .build()
            )
            mp.isLooping = true
            mp.setVolume(0f, 0f)
            videoView?.start()
            enterPipAndLaunch(target, mp.videoWidth, mp.videoHeight)
        }
        videoView?.setOnErrorListener { _, _, _ ->
            finish()
            true
        }
    }

    private fun copyAssetToCache(assetKey: String): File? {
        return try {
            val lookup = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetKey)
            val input = assets.open(lookup)
            val outFile = File(cacheDir, "pip_tutorial_${System.currentTimeMillis()}.mp4")
            outFile.outputStream().use { output ->
                input.copyTo(output)
            }
            outFile
        } catch (e: Exception) {
            Log.e("TutorialPip", "copyAssetToCache failed: ${e.message}")
            null
        }
    }

    private fun enterPipAndLaunch(target: String, videoWidth: Int?, videoHeight: Int?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val builder = PictureInPictureParams.Builder()
            val width = videoWidth ?: 9
            val height = videoHeight ?: 16
            if (width > 0 && height > 0) {
                builder.setAspectRatio(Rational(width, height))
            }
            val params = builder.build()
            enterPictureInPictureMode(params)
            hasStartedPip = true
        }
        openTarget(target)
    }

    private fun openTarget(target: String) {
        val intent = when (target) {
            "instagram" -> packageIntent("com.instagram.android", "https://instagram.com")
            "pinterest" -> packageIntent("com.pinterest", "https://www.pinterest.com")
            "tiktok" -> packageIntent("com.zhiliaoapp.musically", "https://www.tiktok.com")
            "photos" -> packageIntent("com.google.android.apps.photos", "https://photos.google.com")
            "facebook" -> packageIntent("com.facebook.katana", "https://www.facebook.com")
            "imdb" -> packageIntent("com.imdb.mobile", "https://www.imdb.com")
            "safari" -> packageIntent(null, "https://www.google.com")
            "x" -> packageIntent("com.twitter.android", "https://twitter.com")
            else -> null
        }
        if (intent != null) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                startActivity(intent)
            } catch (_: Exception) {
                // ignore
            }
        }
    }

    private fun packageIntent(packageName: String?, fallbackUrl: String): Intent {
        return if (packageName != null) {
            Intent(Intent.ACTION_VIEW).setPackage(packageName).setData(Uri.parse(fallbackUrl))
        } else {
            Intent(Intent.ACTION_VIEW, Uri.parse(fallbackUrl))
        }
    }

  override fun onPictureInPictureModeChanged(
    isInPictureInPictureMode: Boolean,
    newConfig: Configuration
  ) {
    super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
    if (!isInPictureInPictureMode && hasStartedPip) {
      stopAndFinish()
    }
  }

  override fun onResume() {
    super.onResume()
    if (hasStartedPip && !isInPictureInPictureMode) {
      stopAndFinish()
    }
  }

  override fun onDestroy() {
    super.onDestroy()
    if (currentInstance?.get() === this) {
      currentInstance = null
    }
  }
}
