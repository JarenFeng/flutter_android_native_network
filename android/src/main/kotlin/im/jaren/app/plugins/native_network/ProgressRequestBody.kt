package im.jaren.app.plugins.native_network

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import okhttp3.MediaType
import okhttp3.RequestBody
import okio.BufferedSink
import java.io.File
import java.io.FileInputStream

class ProgressRequestBody(
    private val file: File,
    private val contentType: MediaType?,
    private val requestId: String,
    private val eventSink: EventChannel.EventSink?
) : RequestBody() {

    private var lastEmitTime = 0L
    private val emitInterval = 500 // 毫秒

    override fun contentType(): MediaType? = contentType

    override fun contentLength(): Long = file.length()

    override fun writeTo(sink: BufferedSink) {
//        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        val buffer = ByteArray(64 * 1024)
        var uploaded = 0L
        FileInputStream(file).use { inputStream ->
            var read: Int
            while (inputStream.read(buffer).also { read = it } != -1) {
                uploaded += read
                sink.write(buffer, 0, read)

                // 节流控制
                val now = System.currentTimeMillis()
                if (now - lastEmitTime > emitInterval) {
                    emitProgress(uploaded, contentLength())
                    lastEmitTime = now
                }
            }
        }
        emitProgress(uploaded, contentLength())
    }

    private fun emitProgress(uploaded: Long, total: Long) {
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(
                mapOf(
                    "type" to "u-p",
                    "requestId" to requestId,
                    "transferred" to uploaded,
                    "total" to total
                )
            )
        }
    }
}