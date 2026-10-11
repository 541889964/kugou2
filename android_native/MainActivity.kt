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
import java.util.concurrent.atomic.AtomicBoolean
import java.util.zip.GZIPInputStream

class MainActivity: FlutterActivity() {
    private val REC_CHANNEL = "kugou/recorder"
    private val BACKEND_CHANNEL = "kugou/backend"
    private var recorder: MediaRecorder? = null
    private var outputPath: String? = null
    private var nodeProc: Process? = null
    private val crashLog = File(cacheDir, "backend_crash.log")

    private fun logCrash(tag: String, e: Throwable) {
        try {
            crashLog.appendText("[${System.currentTimeMillis()}] $tag: ${e.javaClass.simpleName}: ${e.message}\n")
            crashLog.appendText(e.stackTraceToString())
            crashLog.appendText("\n---\n")
        } catch (_: Exception) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REC_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "start" -> {
                            val path = call.argument<String>("path")
                            if (path == null) { result.error("NO_PATH", "缺少路径", null); return@setMethodCallHandler }
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
                        }
                        "stop" -> {
                            recorder?.stop(); recorder?.release(); recorder = null
                            result.success(outputPath)
                        }
                        "hasPermission" -> result.success(true)
                        else -> result.notImplemented()
                    }
                } catch (e: Throwable) {
                    logCrash("recorder", e)
                    try { result.error("REC_FAIL", e.message ?: "录音失败", null) } catch (_: Exception) {}
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKEND_CHANNEL)
            .setMethodCallHandler { call, result ->
                val replied = AtomicBoolean(false)
                fun safeReply(block: () -> Unit) {
                    if (replied.compareAndSet(false, true)) {
                        try { block() } catch (e: Throwable) { logCrash("safeReply", e) }
                    }
                }
                try {
                    when (call.method) {
                        "unpackNode" -> {
                            val src = call.argument<String>("src")
                            if (src == null) { safeReply { result.error("NO_SRC", "缺少源", null) }; return@setMethodCallHandler }
                            Thread {
                                try {
                                    unpackTarGzSafely(File(src), File(filesDir, "backend_runtime"))
                                    val binDir = File(filesDir, "backend_runtime/node/bin")
                                    binDir.listFiles()?.forEach { it.setExecutable(true, false) }
                                    File(filesDir, "backend_runtime/node/lib").listFiles()?.forEach {
                                        if (it.isFile) it.setExecutable(true, false)
                                    }
                                    safeReply { result.success(true) }
                                } catch (e: Throwable) {
                                    logCrash("unpackNode", e)
                                    safeReply { result.error("UNPACK_NODE_FAIL", e.message ?: "解压失败", null) }
                                }
                            }.start()
                        }
                        "unpackBackend" -> {
                            val src = call.argument<String>("src")
                            if (src == null) { safeReply { result.error("NO_SRC", "缺少源", null) }; return@setMethodCallHandler }
                            Thread {
                                try {
                                    val dest = File(filesDir, "backend_runtime/backend")
                                    dest.mkdirs()
                                    unpackTarGzSafely(File(src), dest)
                                    safeReply { result.success(true) }
                                } catch (e: Throwable) {
                                    logCrash("unpackBackend", e)
                                    safeReply { result.error("UNPACK_BACKEND_FAIL", e.message ?: "解压失败", null) }
                                }
                            }.start()
                        }
                        "unpacked" -> {
                            val node = File(filesDir, "backend_runtime/node/bin/node")
                            val app = File(filesDir, "backend_runtime/backend/app.js")
                            safeReply { result.success(node.exists() && app.exists()) }
                        }
                        "start" -> {
                            val ok = try { startNodeSafely() } catch (e: Throwable) { logCrash("startNode", e); false }
                            safeReply { result.success(ok) }
                        }
                        "stop" -> {
                            try { nodeProc?.destroy(); nodeProc = null } catch (_: Throwable) {}
                            safeReply { result.success(true) }
                        }
                        "running" -> safeReply { result.success(nodeProc?.isAlive == true) }
                        "clear" -> {
                            try {
                                nodeProc?.destroy(); nodeProc = null
                                File(filesDir, "backend_runtime").deleteRecursively()
                                crashLog.delete()
                            } catch (_: Throwable) {}
                            safeReply { result.success(true) }
                        }
                        "crashLog" -> {
                            val txt = try {
                                if (crashLog.exists()) crashLog.readText() else ""
                            } catch (_: Throwable) { "" }
                            safeReply { result.success(txt) }
                        }
                        else -> safeReply { result.notImplemented() }
                    }
                } catch (e: Throwable) {
                    logCrash("channel", e)
                    safeReply { result.error("CHANNEL_FAIL", e.message ?: "通道失败", null) }
                }
            }
    }

    private fun unpackTarGzSafely(tarGz: File, dest: File) {
        if (!tarGz.exists()) throw Exception("源文件不存在: ${tarGz.absolutePath}")
        if (tarGz.length() < 100) throw Exception("源文件太小: ${tarGz.length()}")
        dest.mkdirs()
        GZIPInputStream(BufferedInputStream(tarGz.inputStream(), 65536)).use { gz ->
            untar(gz, dest)
        }
    }

    private fun untar(input: InputStream, dest: File) {
        val header = ByteArray(512)
        var longName: String? = null
        var files = 0
        while (true) {
            val read = input.readNBytes(header, 0, 512)
            if (read < 512) break
            if (header.all { it == 0.toByte() }) break

            val name = String(header, 0, 100, Charsets.UTF_8).trimEnd('\u0000', ' ')
            if (name.isEmpty()) break

            val sizeStr = String(header, 124, 12, Charsets.UTF_8).trimEnd('\u0000', ' ', ' ')
            val size = try { if (sizeStr.isEmpty()) 0L else sizeStr.toLong(8) } catch (_: Exception) { 0L }

            val type = header[156].toInt().toChar()
            val prefix = String(header, 345, 155, Charsets.UTF_8).trimEnd('\u0000', ' ')

            if (type == 'L') {
                val data = ByteArray(size.toInt().coerceAtMost(4096))
                var r = 0
                while (r < data.size) {
                    val n = input.read(data, r, data.size - r)
                    if (n <= 0) break
                    r += n
                }
                longName = String(data, Charsets.UTF_8).trimEnd('\u0000', ' ')
                val padding = ((512 - (size % 512)) % 512).toInt()
                if (padding > 0) input.skip(padding.toLong())
                continue
            }

            val baseName = longName ?: (if (prefix.isEmpty()) name else "$prefix/$name")
            longName = null

            // 防路径穿越
            val safeName = baseName.replace("\\", "/").split("/").filter {
                it != ".." && it.isNotEmpty()
            }.joinToString("/")
            if (safeName.isEmpty()) {
                val padding = ((512 - (size % 512)) % 512).toInt()
                if (padding > 0) input.skip(padding.toLong())
                continue
            }

            val outFile = File(dest, safeName)
            when (type) {
                '5' -> { try { outFile.mkdirs() } catch (_: Throwable) {} }
                '0', '\u0000', '7' -> {
                    try {
                        outFile.parentFile?.mkdirs()
                        FileOutputStream(outFile).use { fos ->
                            var remaining = size
                            val buf = ByteArray(65536)
                            while (remaining > 0) {
                                val toRead = minOf(remaining, 65536L).toInt()
                                val n = input.read(buf, 0, toRead)
                                if (n <= 0) break
                                fos.write(buf, 0, n)
                                remaining -= n
                            }
                            fos.flush()
                        }
                        files++
                    } catch (e: Throwable) {
                        logCrash("untar-write:$safeName", e)
                        // 跳过这个文件的数据
                        var remaining = size
                        val buf = ByteArray(8192)
                        while (remaining > 0) {
                            val toRead = minOf(remaining, 8192L).toInt()
                            val n = input.read(buf, 0, toRead)
                            if (n <= 0) break
                            remaining -= n
                        }
                    }
                }
                else -> {
                    // 其他类型跳过
                    var remaining = size
                    val buf = ByteArray(8192)
                    while (remaining > 0) {
                        val toRead = minOf(remaining, 8192L).toInt()
                        val n = input.read(buf, 0, toRead)
                        if (n <= 0) break
                        remaining -= n
                    }
                }
            }
            val padding = ((512 - (size % 512)) % 512).toInt()
            if (padding > 0) input.skip(padding.toLong())
        }
        android.util.Log.i("KuGou", "untar done: $files files")
    }

    private fun startNodeSafely(): Boolean {
        val root = File(filesDir, "backend_runtime")
        val node = File(root, "node/bin/node")
        val app = File(root, "backend/app.js")
        if (!node.exists()) throw Exception("node 不存在: ${node.absolutePath}")
        if (!app.exists()) throw Exception("app.js 不存在: ${app.absolutePath}")

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
        env["TMPDIR"] = cacheDir.absolutePath

        nodeProc = pb.start()

        Thread {
            try {
                val r = nodeProc?.inputStream?.bufferedReader() ?: return@Thread
                while (true) {
                    val line = r.readLine() ?: break
                    android.util.Log.i("KuGou-Node", line)
                }
            } catch (_: Throwable) {}
        }.start()

        // 等 1 秒看进程是否已死
        Thread.sleep(1000)
        if (nodeProc?.isAlive != true) {
            val exit = nodeProc?.exitValue()
            throw Exception("node 进程立即退出 (code=$exit)，可能是不兼容 arm64")
        }
        return true
    }

    override fun onDestroy() {
        try { nodeProc?.destroy(); nodeProc = null } catch (_: Throwable) {}
        super.onDestroy()
    }
}
