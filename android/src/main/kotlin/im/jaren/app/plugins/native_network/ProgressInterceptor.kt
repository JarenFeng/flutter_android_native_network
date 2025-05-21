package im.jaren.app.plugins.native_network

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import okhttp3.Interceptor
import okhttp3.MediaType
import okhttp3.Response
import okhttp3.ResponseBody
import okio.Buffer
import okio.BufferedSource
import okio.ForwardingSource
import okio.IOException
import okio.buffer

class ProgressInterceptor(
    private val requestId: String,
    private val eventSink: EventChannel.EventSink?
) : Interceptor {

    private var lastEmitTime = 0L
    private val emitInterval = 500 // 毫秒

    override fun intercept(chain: Interceptor.Chain): Response {
        val originalResponse = chain.proceed(chain.request())
        return originalResponse.newBuilder()
            .body(ProgressResponseBody(originalResponse.body, requestId, eventSink))
            .build()
    }

    inner class ProgressResponseBody(
        private val originalBody: ResponseBody?,
        private val requestId: String,
        private val eventSink: EventChannel.EventSink?
    ) : ResponseBody() {

        override fun contentType(): MediaType? = originalBody?.contentType()
        override fun contentLength(): Long = originalBody?.contentLength() ?: -1L

        override fun source(): BufferedSource {
            return originalBody?.source()?.let { source ->
                object : ForwardingSource(source) {
                    var bytesRead = 0L

                    override fun read(sink: Buffer, byteCount: Long): Long {
                        val read = super.read(sink, byteCount)
                        bytesRead += if (read != -1L) read else 0
                        // 节流控制
                        val now = System.currentTimeMillis()
                        if (now - lastEmitTime > emitInterval || read == -1L) {
                            emitProgress(bytesRead, contentLength(), read == -1L)
                            lastEmitTime = now
                        }
                        return read
                    }
                }.buffer()
            } ?: throw IOException("No source available")
        }


        private fun emitProgress(bytesRead: Long, contentLength: Long, done: Boolean) {
            Handler(Looper.getMainLooper()).post {
                eventSink?.success(
                    mapOf(
                        "type" to "d-p",
                        "requestId" to requestId,
                        "transferred" to bytesRead,
                        "total" to contentLength
                    )
                )
            }
        }
    }
}