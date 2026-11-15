"""Run in CI right after `flutter create`: adjusts the generated Android project.

- INTERNET: the update check talks to the GitHub API (release builds do not
  have this permission by default).
- WRITE_EXTERNAL_STORAGE (API <= 29): saving PNGs to the gallery on old Android.
- Human-readable app name.
- In-app update: REQUEST_INSTALL_PACKAGES, a FileProvider (UpdateFileProvider, authority
  <applicationId>.updates, folder cache/updates) and the channel "card_maker/update" that opens
  the system installer for the downloaded APK (ApkInstaller.kt).
- Lint: the release build runs Android lint ("lintVitalAnalyzeRelease"); its StopShip
  check crashes inside lint (NoSuchMethodError in JavaDocParser) with some AGP / lint
  versions and fails the whole build. Lint results are not needed for the APK, so lint
  is switched off for release builds.
- MainActivity + Mp4Encoder: a small channel "card_maker/video" that saves one frame
  of a video as a JPEG (MediaMetadataRetriever) and writes an H.264 MP4 from RGBA
  frames (MediaCodec + MediaMuxer); no extra plugin or ffmpeg needed.
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

// Video helpers for the card maker (channel "card_maker/video"):
//  frame:         saves one frame of a video as a JPEG
//  encoderStart / encoderAdd / encoderFinish / encoderCancel: writes an H.264 MP4
//                 from RGBA frames, using the phone's own encoder (MediaCodec)
class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var encoder: Mp4Encoder? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ApkInstaller.register(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "card_maker/video")
            .setMethodCallHandler { call, result ->
                worker.execute {
                    try {
                        val value: Any? = when (call.method) {
                            "frame" -> {
                                val out = call.argument<String>("out")!!
                                saveFrame(
                                    call.argument<String>("path")!!,
                                    (call.argument<Number>("timeMs") ?: 0).toLong(),
                                    out
                                )
                                out
                            }
                            "encoderStart" -> {
                                encoder?.cancel()
                                encoder = Mp4Encoder(
                                    call.argument<String>("out")!!,
                                    call.argument<Int>("width")!!,
                                    call.argument<Int>("height")!!,
                                    call.argument<Int>("fps")!!,
                                    call.argument<Int>("bitrate")!!
                                )
                                true
                            }
                            "encoderAdd" -> {
                                encoder!!.add(call.argument<ByteArray>("rgba")!!)
                                true
                            }
                            "encoderFinish" -> {
                                encoder!!.finish()
                                encoder = null
                                true
                            }
                            "encoderCancel" -> {
                                encoder?.cancel()
                                encoder = null
                                true
                            }
                            else -> NOT_IMPLEMENTED
                        }
                        mainHandler.post {
                            if (value === NOT_IMPLEMENTED) result.notImplemented() else result.success(value)
                        }
                    } catch (e: Throwable) {
                        mainHandler.post { result.error("video", e.toString(), null) }
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

    companion object {
        private val NOT_IMPLEMENTED = Any()
    }
}
"""

KOTLIN_INSTALLER = """package __PACKAGE__

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Own subclass, so the manifest does not clash with the providers of other plugins.
class UpdateFileProvider : FileProvider()

// Channel "card_maker/update": install(path) opens the system installer for the APK the app
// downloaded. Answers "started", or "permission" when Android first needs the
// "install unknown apps" permission (its settings page is opened then).
object ApkInstaller {
    fun register(activity: Activity, messenger: BinaryMessenger) {
        MethodChannel(messenger, "card_maker/update").setMethodCallHandler { call, result ->
            if (call.method != "install") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val path = call.argument<String>("path")!!
                if (Build.VERSION.SDK_INT >= 26 && !activity.packageManager.canRequestPackageInstalls()) {
                    val settings = Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:" + activity.packageName)
                    )
                    settings.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    activity.startActivity(settings)
                    result.success("permission")
                    return@setMethodCallHandler
                }
                val uri = FileProvider.getUriForFile(activity, activity.packageName + ".updates", File(path))
                val install = Intent(Intent.ACTION_VIEW)
                install.setDataAndType(uri, "application/vnd.android.package-archive")
                install.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                activity.startActivity(install)
                result.success("started")
            } catch (e: Exception) {
                result.error("install_failed", e.message, null)
            }
        }
    }
}
"""

KOTLIN_ENCODER = """package __PACKAGE__

import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import java.io.File

/** Writes RGBA frames (srcWidth x srcHeight) into an H.264 MP4 file. */
class Mp4Encoder(
    private val outPath: String,
    private val srcWidth: Int,
    private val srcHeight: Int,
    fps: Int,
    bitrate: Int
) {
    // H.264 wants even sizes: an odd last column or row is dropped.
    private val width = srcWidth and 1.inv()
    private val height = srcHeight and 1.inv()
    private val frameUs = 1_000_000L / fps
    private val codec: MediaCodec
    private val muxer: MediaMuxer
    private val info = MediaCodec.BufferInfo()
    private var track = -1
    private var muxerStarted = false
    private var frameIndex = 0L

    init {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height)
        format.setInteger(
            MediaFormat.KEY_COLOR_FORMAT,
            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible
        )
        format.setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
        format.setInteger(MediaFormat.KEY_FRAME_RATE, fps)
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        if (Build.VERSION.SDK_INT >= 24) {
            // The pixels are converted with BT.709 limited range, say so in the stream.
            format.setInteger(MediaFormat.KEY_COLOR_STANDARD, MediaFormat.COLOR_STANDARD_BT709)
            format.setInteger(MediaFormat.KEY_COLOR_RANGE, MediaFormat.COLOR_RANGE_LIMITED)
        }
        codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        codec.start()
        muxer = MediaMuxer(outPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    }

    fun add(rgba: ByteArray) {
        val index = waitForInput()
        val image = codec.getInputImage(index)
            ?: throw IllegalStateException("The encoder does not accept flexible YUV input")
        fillYuv(image, rgba)
        codec.queueInputBuffer(index, 0, width * height * 3 / 2, frameIndex * frameUs, 0)
        frameIndex++
        drain(false)
    }

    fun finish() {
        val index = waitForInput()
        codec.queueInputBuffer(index, 0, 0, frameIndex * frameUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
        drain(true)
        codec.stop()
        codec.release()
        if (muxerStarted) muxer.stop()
        muxer.release()
    }

    fun cancel() {
        try { codec.stop() } catch (e: Exception) {}
        try { codec.release() } catch (e: Exception) {}
        try { if (muxerStarted) muxer.stop() } catch (e: Exception) {}
        try { muxer.release() } catch (e: Exception) {}
        File(outPath).delete()
    }

    private fun waitForInput(): Int {
        var tries = 0
        while (true) {
            val index = codec.dequeueInputBuffer(10_000)
            if (index >= 0) return index
            drain(false)
            tries++
            if (tries > 2000) throw IllegalStateException("The encoder is stuck")
        }
    }

    private fun drain(untilEnd: Boolean) {
        var idle = 0
        while (true) {
            val i = codec.dequeueOutputBuffer(info, if (untilEnd) 10_000 else 0)
            if (i == MediaCodec.INFO_TRY_AGAIN_LATER) {
                if (!untilEnd) return
                idle++
                if (idle > 1000) throw IllegalStateException("The encoder did not finish")
            } else if (i == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                track = muxer.addTrack(codec.outputFormat)
                muxer.start()
                muxerStarted = true
            } else if (i >= 0) {
                idle = 0
                val buffer = codec.getOutputBuffer(i)!!
                if ((info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0) info.size = 0
                if (info.size > 0 && muxerStarted) {
                    buffer.position(info.offset)
                    buffer.limit(info.offset + info.size)
                    muxer.writeSampleData(track, buffer, info)
                }
                codec.releaseOutputBuffer(i, false)
                if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) return
            }
        }
    }

    private fun clamp(v: Int): Byte = (if (v < 0) 0 else if (v > 255) 255 else v).toByte()

    private fun fillYuv(image: Image, rgba: ByteArray) {
        val yPlane = image.planes[0]
        val uPlane = image.planes[1]
        val vPlane = image.planes[2]
        val yBuf = yPlane.buffer
        val uBuf = uPlane.buffer
        val vBuf = vPlane.buffer
        for (y in 0 until height) {
            val src = y * srcWidth * 4
            val yRow = y * yPlane.rowStride
            val uRow = (y shr 1) * uPlane.rowStride
            val vRow = (y shr 1) * vPlane.rowStride
            for (x in 0 until width) {
                val p = src + x * 4
                val r = rgba[p].toInt() and 0xFF
                val g = rgba[p + 1].toInt() and 0xFF
                val b = rgba[p + 2].toInt() and 0xFF
                yBuf.put(yRow + x * yPlane.pixelStride, clamp(((47 * r + 157 * g + 16 * b + 128) shr 8) + 16))
                if ((y and 1) == 0 && (x and 1) == 0) {
                    uBuf.put(uRow + (x shr 1) * uPlane.pixelStride, clamp(((-26 * r - 87 * g + 112 * b + 128) shr 8) + 128))
                    vBuf.put(vRow + (x shr 1) * vPlane.pixelStride, clamp(((112 * r - 102 * g - 10 * b + 128) shr 8) + 128))
                }
            }
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
    (
        "android.permission.REQUEST_INSTALL_PACKAGES",
        '<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>',
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
(activity.parent / "Mp4Encoder.kt").write_text(
    KOTLIN_ENCODER.replace("__PACKAGE__", package), encoding="utf-8"
)
print("MainActivity.kt and Mp4Encoder.kt written (" + package + ")")

# ---- in-app update: installer channel, FileProvider and its folder list ----
(activity.parent / "ApkInstaller.kt").write_text(
    KOTLIN_INSTALLER.replace("__PACKAGE__", package), encoding="utf-8"
)
xml_dir = pathlib.Path("android/app/src/main/res/xml")
xml_dir.mkdir(parents=True, exist_ok=True)
(xml_dir / "update_file_paths.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    "<paths>\n"
    '    <cache-path name="updates" path="updates/" />\n'
    "</paths>\n",
    encoding="utf-8",
)
provider = (
    '        <provider\n'
    '            android:name="' + package + '.UpdateFileProvider"\n'
    '            android:authorities="${applicationId}.updates"\n'
    '            android:exported="false"\n'
    '            android:grantUriPermissions="true">\n'
    '            <meta-data\n'
    '                android:name="android.support.FILE_PROVIDER_PATHS"\n'
    '                android:resource="@xml/update_file_paths" />\n'
    '        </provider>\n'
)
manifest_text = manifest.read_text(encoding="utf-8")
if "UpdateFileProvider" not in manifest_text:
    if "</application>" not in manifest_text:
        raise SystemExit("AndroidManifest.xml has no </application>: the update provider cannot be added")
    manifest_text = manifest_text.replace("    </application>", provider + "    </application>", 1)
    manifest.write_text(manifest_text, encoding="utf-8")
print("ApkInstaller.kt, update_file_paths.xml and the FileProvider added")

# ---- lint: do not let a crash inside Android lint fail the release build ----
LINT_KTS = """
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
"""
LINT_GROOVY = """
    lint {
        checkReleaseBuilds false
        abortOnError false
    }
"""
gradle_files = glob.glob("android/app/build.gradle.kts") + glob.glob("android/app/build.gradle")
if not gradle_files:
    raise SystemExit("android/app/build.gradle(.kts) not found: lint cannot be switched off")
gradle = pathlib.Path(gradle_files[0])
source = gradle.read_text(encoding="utf-8")
if "checkReleaseBuilds" not in source:
    patched, count = re.subn(
        r"^android\s*\{[ \t]*\r?\n",
        lambda m: m.group(0) + (LINT_KTS if gradle.suffix == ".kts" else LINT_GROOVY).lstrip("\n"),
        source,
        count=1,
        flags=re.M,
    )
    if count != 1:
        raise SystemExit(gradle.name + ": no `android {` block found, lint not switched off")
    gradle.write_text(patched, encoding="utf-8")
print(gradle.name + ": lint for release builds switched off")
