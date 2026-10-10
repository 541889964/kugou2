package com.kugou.kugou

import android.media.MediaRecorder
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "kugou/recorder"
    private var recorder: MediaRecorder? = null
    private var outputPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("NO_PATH", "缺少路径", null); return@setMethodCallHandler
                        }
                        try {
                            recorder?.release()
                            recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                MediaRecorder(applicationContext)
                            } else {
                                @Suppress("DEPRECATION")
                                MediaRecorder()
                            }.apply {
                                setAudioSource(MediaRecorder.AudioSource.MIC)
                                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                                setAudioSamplingRate(16000)
                                setAudioChannels(1)
                                setAudioEncodingBitRate(256000)
                                setOutputFile(path)
                                prepare()
                                start()
                            }
                            outputPath = path
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("START_FAIL", e.message ?: "启动失败", null)
                        }
                    }
                    "stop" -> {
                        try {
                            recorder?.stop(); recorder?.release(); recorder = null
                            result.success(outputPath)
                        } catch (e: Exception) {
                            result.error("STOP_FAIL", e.message ?: "停止失败", null)
                        }
                    }
                    "hasPermission" -> result.success(true)
                    else -> result.notImplemented()
                }
            }
    }
}
