package com.downloads.app

import android.content.Intent
import android.os.Bundle
import android.util.Log
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import com.yausername.youtubedl_android.mapper.VideoFormat
import com.yausername.youtubedl_android.mapper.VideoInfo
import com.yausername.ffmpeg.FFmpeg
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {
    private val SHARE_CHANNEL = "com.downloads.app/share"
    private val YTDLP_CHANNEL = "com.downloads.app/ytdlp"
    private var initialSharedText: String? = null
    private val scope = CoroutineScope(Dispatchers.Main)
    private var isYtDlpInitialized = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initYtDlpAsync()
    }

    private fun initYtDlpAsync() {
        scope.launch(Dispatchers.IO) {
            try {
                YoutubeDL.getInstance().init(applicationContext)
                try {
                    FFmpeg.getInstance().init(applicationContext)
                } catch (e: Exception) {
                    Log.w("MainActivity", "FFmpeg init: ${e.message}")
                }
                isYtDlpInitialized = true
                Log.d("MainActivity", "YoutubeDL initialized successfully")
            } catch (e: Exception) {
                Log.e("MainActivity", "Failed to init YoutubeDL", e)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Share Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedText" -> {
                    val text = initialSharedText ?: getSharedTextFromIntent(intent)
                    initialSharedText = null
                    result.success(text)
                }
                else -> result.notImplemented()
            }
        }

        // yt-dlp Native Channel
        val ytdlpChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, YTDLP_CHANNEL)
        ytdlpChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> {
                    result.success(true)
                }
                "extractInfo" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.error("INVALID_URL", "URL cannot be empty", null)
                        return@setMethodCallHandler
                    }
                    scope.launch(Dispatchers.IO) {
                        try {
                            if (!isYtDlpInitialized) {
                                YoutubeDL.getInstance().init(applicationContext)
                                isYtDlpInitialized = true
                            }
                            val request = YoutubeDLRequest(url)
                            val info: VideoInfo = YoutubeDL.getInstance().getInfo(request)

                            val formatsList = mutableListOf<Map<String, Any?>>()
                            val formats = info.formats
                            if (formats != null) {
                                for (f: VideoFormat in formats) {
                                    val fId = f.formatId ?: ""
                                    val ext = f.ext ?: "mp4"
                                    val note = f.formatNote ?: f.format ?: ""
                                    val size = f.fileSize
                                    val streamUrl = f.url ?: ""
                                    val vcodec = f.vcodec ?: ""
                                    val acodec = f.acodec ?: ""
                                    val width = f.width
                                    val height = f.height

                                    formatsList.add(mapOf(
                                        "formatId" to fId,
                                        "ext" to ext,
                                        "formatNote" to note,
                                        "fileSize" to size,
                                        "url" to streamUrl,
                                        "vcodec" to vcodec,
                                        "acodec" to acodec,
                                        "width" to width,
                                        "height" to height
                                    ))
                                }
                            }

                            val resMap = mapOf(
                                "id" to (info.id ?: ""),
                                "title" to (info.title ?: "Video"),
                                "duration" to info.duration,
                                "thumbnail" to (info.thumbnail ?: ""),
                                "uploader" to (info.uploaderId ?: ""),
                                "ext" to "mp4",
                                "url" to (info.url ?: ""),
                                "formats" to formatsList
                            )
                            withContext(Dispatchers.Main) {
                                result.success(resMap)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("EXTRACTION_FAILED", e.message ?: "Failed to extract media", null)
                            }
                        }
                    }
                }
                "downloadWithYtDlp" -> {
                    val url = call.argument<String>("url")
                    val outputPath = call.argument<String>("outputPath")
                    val format = call.argument<String>("format")
                    val taskId = call.argument<String>("taskId") ?: "task"

                    if (url.isNullOrBlank() || outputPath.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "Missing url or outputPath", null)
                        return@setMethodCallHandler
                    }

                    scope.launch(Dispatchers.IO) {
                        try {
                            if (!isYtDlpInitialized) {
                                YoutubeDL.getInstance().init(applicationContext)
                                isYtDlpInitialized = true
                            }
                            val request = YoutubeDLRequest(url)
                            request.addOption("-o", outputPath)
                            if (!format.isNullOrBlank()) {
                                request.addOption("-f", format)
                            }
                            request.addOption("--no-mtime")

                            YoutubeDL.getInstance().execute(request, taskId) { progress: Float, etaInSeconds: Long, line: String ->
                                scope.launch(Dispatchers.Main) {
                                    ytdlpChannel.invokeMethod("onDownloadProgress", mapOf(
                                        "taskId" to taskId,
                                        "progress" to progress.toDouble(),
                                        "eta" to etaInSeconds,
                                        "line" to line
                                    ))
                                }
                            }
                            withContext(Dispatchers.Main) {
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("DOWNLOAD_FAILED", e.message ?: "Download failed", null)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val text = getSharedTextFromIntent(intent)
        if (text != null && flutterEngine != null) {
            MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, SHARE_CHANNEL).invokeMethod("onSharedText", text)
        }
    }

    private fun getSharedTextFromIntent(intent: Intent?): String? {
        if (intent == null) return null
        if (Intent.ACTION_SEND == intent.action && intent.type == "text/plain") {
            return intent.getStringExtra(Intent.EXTRA_TEXT)
        }
        return null
    }
}
