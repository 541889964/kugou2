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

    // ✅ 修复：延迟获取，避免在构造函数里调 cacheDir 导致 NPE
    private fun crashLogFile(): File = File(cacheDir, "backend_crash.log")

    private fun logCrash(tag: String, e: Throwable) {
        try {
            crashLogFile().appendText(
                "[${System.currentTimeMillis()}] $tag: " +
                "${e.javaClass.simpleName}: ${e.message}\n" +
                e.stackTraceToString() + "\n---\n")
        } catch (_: Throwable) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ---------- 录音通道 ----------
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REC_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "start" -> {
                            val path = call.argument<String>("path")
                            if (path == null) {
                                result.error("NO_PATH", "缺少路径", null)
                                return@setMethodCallHandler
                            }
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
                    try { result.error("REC_FAIL", e.message ?: "失败", null) } catch (_: Throwable) {}
                }
            }

        // ---------- 后端通道 ----------
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
                            val src = call.argument<String>("src") ?: run {
                                safeReply { result.error("NO_SRC", "缺少源", null) }
                                return@setMethodCallHandler
                            }
                            Thread {
                                try {
                                    unpackTarGz(File(src), File(filesDir, "backend_runtime"))
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
                            val src = call.argument<String>("src") ?: run {
                                safeReply { result.error("NO_SRC", "缺少源", null) }
                                return@setMethodCallHandler
                            }
                            Thread {
                                try {
                                    val dest = File(filesDir, "backend_runtime/backend")
                                    dest.mkdirs()
                                    unpackTarGz(File(src), dest)
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
                            val ok = try { startNode() } catch (e: Throwable) { logCrash("startNode", e); false }
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
                                crashLogFile().delete()
                            } catch (_: Throwable) {}
                            safeReply { result.success(true) }
                        }
                        "listDir" -> {
                            try {
                                val root = File(filesDir, "backend_runtime")
                                val txt = listTree(root, 4)
                                safeReply { result.success(txt) }
                            } catch (e: Throwable) {
                                safeReply { result.success("listDir 失败: ${e.message}") }
                            }
                        }
                        "crashLog" -> {
                            val txt = try {
                                if (crashLogFile().exists()) crashLogFile().readText() else ""
                            } catch (_: Throwable) { "" }
                            safeReply { result.success(txt) }
                        }
                        else -> safeReply { result.notImplemented() }
                    }
                } catch (e: Throwable) {
                    logCrash("channel", e)
                    safeReply { result.error("CHANNEL_FAIL", e.message ?: "失败", null) }
                }
            }
    }

    /// Android 8 兼容：手写 readFully 替代 InputStream.readNBytes
    private fun readFully(input: InputStream, buf: ByteArray, len: Int): Int {
        var total = 0
        while (total < len) {
            val n = input.read(buf, total, len - total)
            if (n <= 0) break
            total += n
        }
        return total
    }

    private fun unpackTarGz(tarGz: File, dest: File) {
        if (!tarGz.exists()) throw Exception("源文件不存在: ${tarGz.absolutePath}")
        if (tarGz.length() < 100) throw Exception("源文件太小")
        dest.mkdirs()
        GZIPInputStream(BufferedInputStream(tarGz.inputStream(), 65536)).use { gz -> untar(gz, dest) }
    }

    private fun untar(input: InputStream, dest: File) {
        val header = ByteArray(512)
        var longName: String? = null
        while (true) {
            val read = readFully(input, header, 512)
            if (read < 512) break
            if (header.all { it == 0.toByte() }) break

            val name = String(header, 0, 100, Charsets.UTF_8).trimEnd('\u0000', ' ')
            if (name.isEmpty()) break
            val sizeStr = String(header, 124, 12, Charsets.UTF_8).trimEnd('\u0000', ' ')
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
                val pad = ((512 - (size % 512)) % 512).toInt()
                if (pad > 0) input.skip(pad.toLong())
                continue
            }

            val baseName = longName ?: (if (prefix.isEmpty()) name else "$prefix/$name")
            longName = null
            val safeName = baseName.replace("\\", "/").split("/")
                .filter { it != ".." && it.isNotEmpty() }.joinToString("/")

            if (safeName.isNotEmpty()) {
                val outFile = File(dest, safeName)
                when (type) {
                    '5' -> { try { outFile.mkdirs() } catch (_: Throwable) {} }
                    '0', '\u0000', '7' -> {
                        try {
                            outFile.parentFile?.mkdirs()
                            FileOutputStream(outFile).use { fos ->
                                var rem = size
                                val buf = ByteArray(65536)
                                while (rem > 0) {
                                    val toRead = minOf(rem, 65536L).toInt()
                                    val n = input.read(buf, 0, toRead)
                                    if (n <= 0) break
                                    fos.write(buf, 0, n)
                                    rem -= n
                                }
                            }
                        } catch (e: Throwable) {
                            logCrash("untar:$safeName", e)
                            var rem = size
                            val buf = ByteArray(8192)
                            while (rem > 0) {
                                val n = input.read(buf, 0, minOf(rem, 8192L).toInt())
                                if (n <= 0) break
                                rem -= n
                            }
                        }
                    }
                    else -> {
                        var rem = size
                        val buf = ByteArray(8192)
                        while (rem > 0) {
                            val n = input.read(buf, 0, minOf(rem, 8192L).toInt())
                            if (n <= 0) break
                            rem -= n
                        }
                    }
                }
            }
            val pad = ((512 - (size % 512)) % 512).toInt()
            if (pad > 0) input.skip(pad.toLong())
        }
    }

    private fun findNodeBin(root: File): File? {
        val candidates = listOf(
            File(root, "node/bin/node"),
            File(root, "node/node"),
            File(root, "bin/node"),
            File(root, "node/bin/node.exe"),
        )
        for (c in candidates) if (c.exists()) return c
        // 递归找名叫 node 的可执行文件
        val found = root.walkTopDown().maxDepth(3)
            .firstOrNull { it.isFile && it.name == "node" }
        return found
    }

    private fun findAppJs(root: File): File? {
        val candidates = listOf(
            File(root, "backend/app.js"),
            File(root, "backend/backend/app.js"),
            File(root, "app.js"),
        )
        for (c in candidates) if (c.exists()) return c
        return root.walkTopDown().maxDepth(4)
            .firstOrNull { it.isFile && it.name == "app.js" }
    }

    /// 递归列目录，返回文本树
    private fun listTree(root: File, maxDepth: Int = 3): String {
        if (!root.exists()) return "(目录不存在)"
        val sb = StringBuilder()
        fun walk(f: File, prefix: String, depth: Int) {
            if (depth > maxDepth) return
            val children = f.listFiles() ?: return
            for ((i, c) in children.withIndex()) {
                val last = i == children.size - 1
                sb.append(prefix).append(if (last) "└─ " else "├─ ")
                sb.append(c.name)
                if (c.isDirectory) sb.append("/")
                else sb.append(" (").append(c.length() / 1024).append(" KB)")
                sb.append("\n")
                if (c.isDirectory) {
                    walk(c, prefix + if (last) "   " else "│  ", depth + 1)
                }
            }
        }
        walk(root, "", 0)
        return sb.toString()
    }

    private fun startNode(): Boolean {
        val root = File(filesDir, "backend_runtime")
        val node = findNodeBin(root)
        val app = findAppJs(root)
        if (node == null) {
            throw Exception("找不到 node 二进制\n" +
              "backend_runtime 结构:\n" + listTree(root))
        }
        if (app == null) {
            throw Exception("找不到 app.js\n" +
              "backend_runtime 结构:\n" + listTree(root))
        }

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

        Thread.sleep(1000)
        if (nodeProc?.isAlive != true) {
            throw Exception("node 进程立即退出 (code=${nodeProc?.exitValue()})")
        }
        return true
    }

    override fun onDestroy() {
        try { nodeProc?.destroy(); nodeProc = null } catch (_: Throwable) {}
        super.onDestroy()
    }
}
