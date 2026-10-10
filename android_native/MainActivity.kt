package com.kugou.kugou

import android.media.MediaRecorder
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.util.zip.GZIPInputStream

class MainActivity: FlutterActivity() {
    private val REC_CHANNEL = "kugou/recorder"
    private val BACKEND_CHANNEL = "kugou/backend"
    private var recorder: MediaRecorder? = null
    private var outputPath: String? = null
    private var nodeProc: Process? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REC_CHANNEL)
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKEND_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "unpackNode" -> {
                        val src = call.argument<String>("src")
                        if (src == null) {
                            result.error("NO_SRC", "缺少源文件", null); return@setMethodCallHandler
                        }
                        try {
                            unpackTarGz(File(src), File(filesDir, "backend_runtime"))
                            val binDir = File(filesDir, "backend_runtime/node/bin")
                            binDir.listFiles()?.forEach { it.setExecutable(true, false) }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("UNPACK_NODE_FAIL", e.message ?: "解压失败", null)
                        }
                    }
                    "unpackBackend" -> {
                        val src = call.argument<String>("src")
                        if (src == null) {
                            result.error("NO_SRC", "缺少源文件", null); return@setMethodCallHandler
                        }
                        try {
                            val dest = File(filesDir, "backend_runtime/backend")
                            dest.mkdirs()
                            unpackTarGz(File(src), dest)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("UNPACK_BACKEND_FAIL", e.message ?: "解压失败", null)
                        }
                    }
                    "unpacked" -> {
                        val node = File(filesDir, "backend_runtime/node/bin/node")
                        val app = File(filesDir, "backend_runtime/backend/app.js")
                        result.success(node.exists() && app.exists())
                    }
                    "start" -> {
                        try { result.success(startNode()) }
                        catch (e: Exception) {
                            result.error("START_NODE_FAIL", e.message ?: "启动失败", null)
                        }
                    }
                    "stop" -> {
                        try { nodeProc?.destroy(); nodeProc = null; result.success(true) }
                        catch (e: Exception) {
                            result.error("STOP_NODE_FAIL", e.message ?: "停止失败", null)
                        }
                    }
                    "running" -> result.success(nodeProc?.isAlive == true)
                    "clear" -> {
                        try {
                            nodeProc?.destroy(); nodeProc = null
                            File(filesDir, "backend_runtime").deleteRecursively()
                            result.success(true)
                        } catch (e: Exception) { result.success(false) }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun unpackTarGz(tarGz: File, dest: File) {
        dest.mkdirs()
        GZIPInputStream(BufferedInputStream(tarGz.inputStream())).use { gz -> untar(gz, dest) }
    }

    private fun untar(input: InputStream, dest: File) {
        val buf = ByteArray(512)
        var longName: String? = null
        while (true) {
            val read = input.readNBytes(buf, 0, 512)
            if (read < 512) break
            if (buf.all { it == 0.toByte() }) break

            val name = String(buf, 0, 100, Charsets.UTF_8).trimEnd('\u0000', ' ')
            if (name.isEmpty()) break

            val sizeStr = String(buf, 124, 12, Charsets.UTF_8).trimEnd('\u0000', ' ')
            val size = if (sizeStr.isEmpty()) 0L
                else try { sizeStr.toLong(8) } catch (_: Exception) { 0L }

            val type = buf[156].toInt().toChar()
            val prefix = String(buf, 345, 155, Charsets.UTF_8).trimEnd('\u0000', ' ')

            if (type == 'L') {
                val data = ByteArray(size.toInt())
                var r = 0
                while (r < size) { val n = input.read(data, r, size.toInt() - r); if (n <= 0) break; r += n }
                longName = String(data, Charsets.UTF_8).trimEnd('\u0000', ' ')
                val padding = ((512 - (size % 512)) % 512).toInt()
                if (padding > 0) input.skip(padding.toLong())
                continue
            }

            var fullName = longName ?: (if (prefix.isEmpty()) name else "$prefix/$name")
            longName = null

            val outFile = File(dest, fullName)
            when (type) {
                '5' -> outFile.mkdirs()
                '0', '\u0000', '7' -> {
                    outFile.parentFile?.mkdirs()
                    FileOutputStream(outFile).use { fos ->
                        var remaining = size
                        while (remaining > 0) {
                            val toRead = minOf(remaining, 8192L).toInt()
                            val n = input.readNBytes(buf, 0, toRead)
                            if (n <= 0) break
                            fos.write(buf, 0, n)
                            remaining -= n
                        }
                    }
                }
            }
            val padding = ((512 - (size % 512)) % 512).toInt()
            if (padding > 0) input.skip(padding.toLong())
        }
    }

    private fun startNode(): Boolean {
        val root = File(filesDir, "backend_runtime")
        val node = File(root, "node/bin/node")
        val app = File(root, "backend/app.js")
        if (!node.exists() || !app.exists()) return false

        nodeProc?.destroy(); nodeProc = null

        val pb = ProcessBuilder(node.absolutePath, app.absolutePath)
        pb.directory(File(root, "backend"))
        pb.redirectErrorStream(true)
        val env = pb.environment()
        env["LD_LIBRARY_PATH"] = File(root, "node/lib").absolutePath
        env["PATH"] = "${File(root, "node/bin").absolutePath}:/system/bin"
        env["PORT"] = "3000"
        env["NODE_ENV"] = "production"
        env["HOME"] = root.absolutePath

        nodeProc = pb.start()
        Thread {
            try {
                val r = nodeProc?.inputStream?.bufferedReader()
                while (r?.readLine() != null) { }
            } catch (_: Exception) { }
        }.start()
        return true
    }

    override fun onDestroy() {
        nodeProc?.destroy(); nodeProc = null
        super.onDestroy()
    }
}
