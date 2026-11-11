package dev.cyclescope.cyclescope

import android.graphics.Bitmap
import android.graphics.Matrix
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/**
 * Decodes single video frames ahead of time for instant frame stepping
 * (channel `dev.cyclescope/frames`, Dart side: `ChannelFrameSource`).
 *
 * Needs API 28 (`getFramesAtIndex`, frame count); on older devices `open`
 * returns null and the app steps with player seeks only.
 */
class FrameDecoder : MethodChannel.MethodCallHandler {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var retriever: MediaMetadataRetriever? = null
    private var rotation = 0
    private var codedLandscape = true

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> run(result) { open(call.argument<String>("path")!!) }
            "frames" -> run(result) {
                frames(
                    call.argument<Int>("first")!!,
                    call.argument<Int>("count")!!,
                    call.argument<Int>("maxSize") ?: 1280,
                )
            }
            "close" -> run(result) { release(); null }
            else -> result.notImplemented()
        }
    }

    /** Runs [block] on the worker thread (in order) and replies on main. */
    private fun run(result: MethodChannel.Result, block: () -> Any?) {
        worker.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("frames", e.message, null) }
            }
        }
    }

    private fun open(path: String): Map<String, Any>? {
        release()
        if (Build.VERSION.SDK_INT < 28) return null
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(path)
        } catch (e: Exception) {
            r.release()
            return null
        }
        fun meta(key: Int) = r.extractMetadata(key)?.toLongOrNull()
        val count = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_FRAME_COUNT) ?: 0L
        val durationMs = meta(MediaMetadataRetriever.METADATA_KEY_DURATION) ?: 0L
        if (count <= 0 || durationMs <= 0) {
            r.release()
            return null
        }
        rotation = (meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION) ?: 0L).toInt()
        val w = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH) ?: 0L
        val h = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT) ?: 0L
        codedLandscape = w >= h
        retriever = r
        return mapOf(
            "fps" to count * 1000.0 / durationMs,
            "frameCount" to count.toInt(),
        )
    }

    private fun frames(first: Int, count: Int, maxSize: Int): List<ByteArray> {
        val r = retriever ?: return emptyList()
        if (Build.VERSION.SDK_INT < 28 || count <= 0) return emptyList()
        return r.getFramesAtIndex(first, count).map { encode(upright(it), maxSize) }
    }

    /** Applies the video rotation if the decoder returned the coded picture. */
    private fun upright(bitmap: Bitmap): Bitmap {
        val quarter = rotation == 90 || rotation == 270
        val stillCoded = (bitmap.width >= bitmap.height) == codedLandscape
        if (rotation == 0 || (quarter && !stillCoded)) return bitmap
        val m = Matrix().apply { postRotate(rotation.toFloat()) }
        val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, m, true)
        if (rotated !== bitmap) bitmap.recycle()
        return rotated
    }

    private fun encode(bitmap: Bitmap, maxSize: Int): ByteArray {
        val longest = maxOf(bitmap.width, bitmap.height)
        val scaled = if (longest > maxSize) {
            val f = maxSize.toFloat() / longest
            Bitmap.createScaledBitmap(
                bitmap, (bitmap.width * f).toInt(), (bitmap.height * f).toInt(), true,
            ).also { bitmap.recycle() }
        } else {
            bitmap
        }
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, 85, out)
        scaled.recycle()
        return out.toByteArray()
    }

    private fun release() {
        retriever?.release()
        retriever = null
    }

    fun dispose() {
        worker.execute { release() }
        worker.shutdown()
    }
}
