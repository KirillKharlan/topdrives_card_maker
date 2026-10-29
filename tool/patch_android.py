"""Run in CI right after `flutter create`: adjusts the generated Android project.

- INTERNET: the update check talks to the GitHub API (release builds do not
  have this permission by default).
- WRITE_EXTERNAL_STORAGE (API <= 29): saving PNGs to the gallery on old Android.
- Human-readable app name.
- MainActivity: a small channel "card_maker/video" that saves one frame of a
  video as a JPEG (Android's MediaMetadataRetriever); no extra plugin needed.
"""
import glob
import pathlib
import re

KOTLIN = """package __PACKAGE__

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "card_maker/video")
            .setMethodCallHandler { call, result ->
                if (call.method != "frame") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                val out = call.argument<String>("out")
                val timeMs = (call.argument<Number>("timeMs") ?: 0).toLong()
                if (path == null || out == null) {
                    result.error("args", "path and out are required", null)
                    return@setMethodCallHandler
                }
                worker.execute {
                    try {
                        saveFrame(path, timeMs, out)
                        mainHandler.post { result.success(out) }
                    } catch (e: Exception) {
                        mainHandler.post { result.error("frame", e.message, null) }
                    }
                }
            }
    }

    private fun saveFrame(path: String, timeMs: Long, out: String) {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            val bitmap = retriever.getFrameAtTime(
                timeMs * 1000, MediaMetadataRetriever.OPTION_CLOSEST
            ) ?: throw IllegalStateException("No frame at " + timeMs + " ms")
            FileOutputStream(File(out)).use { bitmap.compress(Bitmap.CompressFormat.JPEG, 95, it) }
            bitmap.recycle()
        } finally {
            retriever.release()
        }
    }
}
"""

manifest = pathlib.Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text(encoding="utf-8")

permissions = [
    ("android.permission.INTERNET", '<uses-permission android:name="android.permission.INTERNET"/>'),
    (
        "android.permission.WRITE_EXTERNAL_STORAGE",
        '<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29"/>',
    ),
]
block = "".join(f"    {tag}\n" for name, tag in permissions if name not in text)
if block:
    index = text.index("<application")
    text = text[:index] + block.lstrip() + "    " + text[index:]

text = re.sub(r'android:label="[^"]*"', 'android:label="Card Maker"', text, count=1)

manifest.write_text(text, encoding="utf-8")
print("AndroidManifest.xml patched")

activities = glob.glob("android/app/src/main/kotlin/**/MainActivity.kt", recursive=True)
if not activities:
    raise SystemExit("MainActivity.kt not found: the video frame channel cannot be added")
activity = pathlib.Path(activities[0])
package = re.search(r"^package\s+([\w.]+)", activity.read_text(encoding="utf-8"), re.M).group(1)
activity.write_text(KOTLIN.replace("__PACKAGE__", package), encoding="utf-8")
print("MainActivity.kt patched (" + package + ")")
