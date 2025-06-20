package im.jaren.app.plugins.native_network

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import android.util.Log

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.Response
import okhttp3.internal.headersContentLength
import okio.IOException
import java.io.File
import java.io.FileOutputStream
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.util.concurrent.TimeUnit
import javax.net.ssl.SSLHandshakeException

/** NativeNetworkPlugin */
class NativeNetworkPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel

    private var eventSink: EventChannel.EventSink? = null
    private lateinit var context: Context

    companion object {
        const val TAG = "NativeNetworkPlugin"
        var boundNetwork: Network? = null
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext

        channel = MethodChannel(binding.binaryMessenger, "native_network/method")
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "native_network/event")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }

            "bindToWiFiNetwork" -> {
                val ssid = call.argument<String>("ssid")
                if (ssid == null) {
                    result.error("MISSING_SSID", "SSID is required", null)
                    return
                }
                bindToNetworkBySsid(ssid, result)
            }

            "httpRequest" -> {
                handleHttpRequest(call.arguments as Map<String, Any>, result)
            }

            "openSocket" -> {
                handleHttpRequest(call.arguments as Map<String, Any>, result)
            }

            else -> result.notImplemented()
        }
    }

    private fun bindToNetworkBySsid(ssid: String, result: MethodChannel.Result) {
        val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        for (network in connectivityManager.allNetworks) {
            val info = connectivityManager.getNetworkInfo(network)
            if (info != null && info.type == ConnectivityManager.TYPE_WIFI && info.isConnected) {
                val currentSsid = getSsidFromWifiManager()
                if (currentSsid == ssid) {
                    boundNetwork = network
                    Log.d("NativeNetwork", "Bound to network for SSID: $ssid")
                    flutterSuccess(result, network.networkHandle)
                    return
                }
            }
        }
        flutterError(result, "NETWORK_NOT_FOUND", "No matching Wi-Fi network found for SSID: $ssid")
    }

    private fun getSsidFromWifiManager(): String? {
        val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val info = wifiManager.connectionInfo
        return info?.ssid?.replace("\"", "")  // 去除双引号
    }

    private fun handleHttpRequest(args: Map<String, Any>, result: MethodChannel.Result) {
        val requestId = args["requestId"] as String
        val url = args["url"] as String
        val method = (args["method"] as String).uppercase()
        val headers = args["headers"] as? Map<String, String> ?: emptyMap()
        val body = args["body"] as? String
        val filePath = args["filePath"] as? String

        val connectTimeout = args["connectTimeout"] as? Long ?: 10000L
        val readTimeout = args["readTimeout"] as? Long ?: 10000L
        val writeTimeout = args["writeTimeout"] as? Long ?: 10000L

        val client = OkHttpClient.Builder().apply {
            boundNetwork?.let { socketFactory(it.socketFactory) }
            if (filePath != null && method == "GET") {
                addNetworkInterceptor(ProgressInterceptor(requestId, eventSink))
            }
            this.connectTimeout(connectTimeout, TimeUnit.MILLISECONDS)
            this.readTimeout(readTimeout, TimeUnit.MILLISECONDS)
            this.writeTimeout(writeTimeout, TimeUnit.MILLISECONDS)
        }.build()

        val requestBuilder = Request.Builder().url(url)
        headers.forEach { (k, v) -> requestBuilder.addHeader(k, v) }

        val mediaType = headers["Content-Type"]?.toMediaTypeOrNull()

        when (method) {
            "GET" -> {
                val request = requestBuilder.get().build()
                client.newCall(request).enqueue(object : Callback {
                    override fun onFailure(call: Call, e: IOException) {
                        handleHttpFailure(e, result)
                    }

                    override fun onResponse(call: Call, response: Response) {
                        response.use {
                            if (filePath != null) {
                                handleDownload(response, filePath, result)
                            } else {
                                val bodyBytes = response.body?.bytes() ?: ByteArray(0)

                                val resultMap = HashMap<String, Any>()
                                resultMap["statusCode"] = response.code
                                resultMap["body"] = bodyBytes
                                resultMap["contentLength"] = response.headersContentLength()

                                val headersMap = mutableMapOf<String, String>()
                                for ((name, value) in response.headers) {
                                    headersMap[name] = value
                                }
                                resultMap["headers"] = headersMap

                                flutterSuccess(result, resultMap)
                            }
                        }
                    }
                })
            }

            "POST", "PUT" -> {
                val requestBody = when {
                    filePath != null -> {
                        val file = File(filePath)
                        ProgressRequestBody(file, mediaType, requestId, eventSink)
                    }

                    body != null -> RequestBody.create(mediaType, body)
                    else -> RequestBody.create(null, ByteArray(0))
                }

                if (method == "POST") requestBuilder.post(requestBody)
                else requestBuilder.put(requestBody)

                val request = requestBuilder.build()
                client.newCall(request).enqueue(object : Callback {
                    override fun onFailure(call: Call, e: IOException) {
                        handleHttpFailure(e, result)
                    }

                    override fun onResponse(call: Call, response: Response) {
                        response.use {
                            val bodyBytes = response.body?.bytes() ?: ByteArray(0)

                            val resultMap = HashMap<String, Any>()
                            resultMap["statusCode"] = response.code
                            resultMap["body"] = bodyBytes
                            resultMap["contentLength"] = response.headersContentLength()
                            val headersMap = mutableMapOf<String, String>()
                            for ((name, value) in response.headers) {
                                headersMap[name] = value
                            }
                            resultMap["headers"] = headersMap

                            flutterSuccess(result, resultMap)
                        }
                    }
                })
            }

            "DELETE" -> {
                val request = requestBuilder.delete(RequestBody.create(null, ByteArray(0))).build()
                client.newCall(request).enqueue(object : Callback {
                    override fun onFailure(call: Call, e: IOException) {
                        handleHttpFailure(e, result)
                    }

                    override fun onResponse(call: Call, response: Response) {
                        response.use {
                            val bodyBytes = response.body?.bytes() ?: ByteArray(0)

                            val resultMap = HashMap<String, Any>()
                            resultMap["statusCode"] = response.code
                            resultMap["body"] = bodyBytes
                            resultMap["contentLength"] = response.headersContentLength()
                            val headersMap = mutableMapOf<String, String>()
                            for ((name, value) in response.headers) {
                                headersMap[name] = value
                            }
                            resultMap["headers"] = headersMap

                            flutterSuccess(result, resultMap)
                        }
                    }
                })
            }

            "MOVE" -> {
                val request = requestBuilder
                    .method("MOVE", RequestBody.create(null, ByteArray(0)))
                    .build()

                client.newCall(request).enqueue(object : Callback {
                    override fun onFailure(call: Call, e: IOException) {
                        handleHttpFailure(e, result)
                    }

                    override fun onResponse(call: Call, response: Response) {
                        response.use {
                            val bodyBytes = response.body?.bytes() ?: ByteArray(0)

                            val resultMap = HashMap<String, Any>()
                            resultMap["statusCode"] = response.code
                            resultMap["body"] = bodyBytes
                            resultMap["contentLength"] = response.headersContentLength()
                            val headersMap = mutableMapOf<String, String>()
                            for ((name, value) in response.headers) {
                                headersMap[name] = value
                            }
                            resultMap["headers"] = headersMap

                            flutterSuccess(result, resultMap)
                        }
                    }
                })
            }

            else -> flutterError(result, "UNSUPPORTED_METHOD", "HTTP method $method is not supported")
        }
    }

    private fun handleDownload(response: Response, filePath: String, result: MethodChannel.Result) {
        try {
            val inputStream = response.body?.byteStream() ?: throw IOException("No input stream")
            val file = File(filePath)
            val outputStream = FileOutputStream(file)

            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            var read: Int

            inputStream.use { input ->
                outputStream.use { output ->
                    while (input.read(buffer).also { read = it } != -1) {
                        output.write(buffer, 0, read)
                    }
                }
            }
            val headersMap = mutableMapOf<String, String>()
            for ((name, value) in response.headers) {
                headersMap[name] = value
            }
            flutterSuccess(
                result, mapOf(
                    "statusCode" to response.code,
                    "body" to ByteArray(0),
                    "contentLength" to response.headersContentLength(),
                    "headers" to headersMap,
                    "filePath" to filePath
                )
            )

        } catch (e: Exception) {
            result.error("DOWNLOAD_ERROR", e.message, null)

        }
    }

    private fun handleHttpFailure(e: IOException, result: MethodChannel.Result) {
        val errorCode = when (e) {
            is SocketTimeoutException -> "timeout"
            is ConnectException -> "connect_error"
            is UnknownHostException -> "dns_error"
            is SSLHandshakeException -> "ssl_error"
            else -> "network_error"
        }
        val errorDetails = mapOf(
            "exception" to e::class.java.simpleName,
            "message" to (e.message ?: "unknown")
        )
        flutterError(result, errorCode, e.message, errorDetails)
    }

    private fun handleOpenSocket(args: Map<String, Any>, result: MethodChannel.Result) {
        val requestId = args["requestId"] as String
        val url = args["url"] as String
    }


    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        Log.d(TAG, "event sink onListen: $eventSink")
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        Log.d(TAG, "event sink onCancel")

    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private fun flutterSuccess(result: MethodChannel.Result, value: Any?) {
        mainHandler.post {
            result.success(value)
        }
    }

    private fun flutterError(
        result: MethodChannel.Result,
        errorCode: String,
        errorMessage: String?,
        errorDetails: Any? = null
    ) {
        mainHandler.post {
            result.error(errorCode, errorMessage, errorDetails)
        }
    }


}