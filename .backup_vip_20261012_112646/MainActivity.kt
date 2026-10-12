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
import java.util.zip.ZipInputStream

class MainActivity: FlutterActivity() {
    private val REC_CHANNEL = "kugou/recorder"
    private val BACKEND_CHANNEL = "kugou/backend"
    private var recorder: MediaRecorder? = null
    private var outputPath: String? = null
    private var nodeProc: Process? = null

    private fun crashLogFile(): File = File(cacheDir, "backend_crash.log")
    private fun npmLogFile(): File = File(cacheDir, "npm.log")

    private fun logCrash(tag: String, e: Throwable) {
        try {
            crashLogFile().appendText(
                "[${System.currentTimeMillis()}] $tag: " +
                "${e.javaClass.simpleName}: ${e.message}\n" +
                e.stackTraceToString() + "\n---\n")
        } catch (_: Throwable) {}
    }

    private fun readFully(input: InputStream, buf: ByteArray, len: Int): Int {
        var total = 0
        while (total < len) {
            val n = input.read(buf, total, len - total)
            if (n <= 0) break
            total += n
        }
        return total
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
                        "extractSourceZip" -> {
                            val zipPath = call.argument<String>("zip")
                            val destRel = call.argument<String>("dest") ?: "backend_runtime/backend"
                            if (zipPath == null) {
                                safeReply { result.error("NO_ZIP", "缺少 zip", null) }
                                return@setMethodCallHandler
                            }
                            Thread {
                                try {
                                    val zipFile = File(zipPath)
                                    if (!zipFile.exists()) throw Exception("zip 不存在")
                                    val dest = File(filesDir, destRel)
                                    if (dest.exists()) dest.deleteRecursively()
                                    dest.mkdirs()

                                    ZipInputStream(zipFile.inputStream()).use { zis ->
                                        var entry = zis.nextEntry
                                        while (entry != null) {
                                            val name = entry.name
                                            val parts = name.split("/", limit = 2)
                                            val rel = if (parts.size > 1) parts[1] else ""
                                            if (rel.isNotEmpty()) {
                                                val outFile = File(dest, rel)
                                                if (entry.isDirectory) {
                                                    outFile.mkdirs()
                                                } else {
                                                    outFile.parentFile?.mkdirs()
                                                    FileOutputStream(outFile).use { fos ->
                                                        val buf = ByteArray(65536)
                                                        var n: Int
                                                        while (zis.read(buf).also { n = it } > 0) {
                                                            fos.write(buf, 0, n)
                                                        }
                                                    }
                                                }
                                            }
                                            zis.closeEntry()
                                            entry = zis.nextEntry
                                        }
                                    }
                                    safeReply { result.success(true) }
                                } catch (e: Throwable) {
                                    logCrash("extractZip", e)
                                    safeReply { result.error("EXTRACT_FAIL", e.message ?: "", null) }
                                }
                            }.start()
                        }
                        "runNpmInstall" -> {
                            Thread {
                                try {
                                    val root = File(filesDir, "backend_runtime")
                                    val node = File(root, "node/bin/node")
                                    val npmCli = File(root, "node/lib/node_modules/npm/bin/npm-cli.js")
                                    val backend = File(root, "backend")

                                    if (!node.exists()) throw Exception("node 不存在")
                                    if (!npmCli.exists()) throw Exception("npm 缺失（tar 里没有）")
                                    if (!File(backend, "package.json").exists()) throw Exception("package.json 不存在")

                                    npmLogFile().writeText("=== npm install ===\n")

                                    val pb = ProcessBuilder(
                                        node.absolutePath, "--jitless",
                                        npmCli.absolutePath, "install",
                                        "--production", "--no-audit", "--no-fund"
                                    )
                                    pb.directory(backend)
                                    pb.redirectErrorStream(true)
                                    val env = pb.environment()
                                    env["LD_LIBRARY_PATH"] = File(root, "node/lib").absolutePath
                                    env["PATH"] = "${File(root, "node/bin").absolutePath}:/system/bin"
                                    env["HOME"] = filesDir.absolutePath
                                    env["TMPDIR"] = cacheDir.absolutePath
                                    env["OPENSSL_CONF"] = "/dev/null"
                                    env["SSL_CERT_FILE"] = "/system/etc/security/cacerts"
                                    env["npm_config_prefix"] = File(root, "node").absolutePath
                                    env["npm_config_cache"] = File(cacheDir, "npm-cache").absolutePath
                                    env["npm_config_registry"] = "https://registry.npmmirror.com"

                                    val proc = pb.start()
                                    val reader = proc.inputStream.bufferedReader()
                                    val fos = FileOutputStream(npmLogFile(), true)
                                    try {
                                        var line: String?
                                        while (reader.readLine().also { line = it } != null) {
                                            fos.write((line + "\n").toByteArray())
                                            fos.flush()
                                        }
                                    } finally {
                                        fos.close()
                                    }
                                    val exit = proc.waitFor()
                                    if (exit == 0) {
                                        safeReply { result.success(true) }
                                    } else {
                                        safeReply { result.error("NPM_FAIL", "退出码=$exit", null) }
                                    }
                                } catch (e: Throwable) {
                                    logCrash("npm", e)
                                    safeReply { result.error("NPM_ERR", e.message ?: "未知", null) }
                                }
                            }.start()
                        }
                        "getNpmLog" -> {
                            try {
                                val f = npmLogFile()
                                if (!f.exists()) { result.success(""); return@setMethodCallHandler }
                                val txt = f.readText()
                                val lines = txt.split("\n")
                                val tail = if (lines.size > 80) lines.takeLast(80).joinToString("\n") else txt
                                result.success(tail)
                            } catch (_: Throwable) {
                                result.success("")
                            }
                        }
                        "clearBackend" -> {
                            try {
                                val backendDir = File(filesDir, "backend_runtime/backend")
                                if (backendDir.exists()) backendDir.deleteRecursively()
                                safeReply { result.success(true) }
                            } catch (e: Throwable) {
                                logCrash("clearBackend", e)
                                safeReply { result.success(false) }
                            }
                        }
                        "clear" -> {
                            try {
                                nodeProc?.destroy(); nodeProc = null
                                File(filesDir, "backend_runtime").deleteRecursively()
                                crashLogFile().delete()
                                npmLogFile().delete()
                            } catch (_: Throwable) {}
                            safeReply { result.success(true) }
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

    private fun unpackTarGz(tarGz: File, dest: File) {
        if (!tarGz.exists()) throw Exception("源文件不存在")
        if (tarGz.length() < 100) throw Exception("源文件太小")
        dest.mkdirs()
        GZIPInputStream(BufferedInputStream(tarGz.inputStream(), 65536)).use { gz ->
            untar(gz, dest)
        }
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
                                    val n = readFully(input, buf, toRead)
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
                                val n = readFully(input, buf, minOf(rem, 8192L).toInt())
                                if (n <= 0) break
                                rem -= n
                            }
                        }
                    }
                    else -> {
                        var rem = size
                        val buf = ByteArray(8192)
                        while (rem > 0) {
                            val n = readFully(input, buf, minOf(rem, 8192L).toInt())
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

    private fun startNode(): Boolean {
        val root = File(filesDir, "backend_runtime")
        val node = File(root, "node/bin/node")
        val app = File(root, "backend/app.js")
        if (!node.exists()) throw Exception("node 不存在")
        if (!app.exists()) throw Exception("app.js 不存在")

        nodeProc?.destroy(); nodeProc = null

        val pb = ProcessBuilder(node.absolutePath, "--jitless", app.absolutePath)
        pb.directory(File(root, "backend"))
        pb.redirectErrorStream(true)
        val env = pb.environment()
        env["LD_LIBRARY_PATH"] = File(root, "node/lib").absolutePath
        env["PATH"] = "${File(root, "node/bin").absolutePath}:/system/bin"
        env["PORT"] = "3000"
        env["NODE_ENV"] = "production"
        env["HOME"] = root.absolutePath
        env["TMPDIR"] = cacheDir.absolutePath
        env["OPENSSL_CONF"] = "/dev/null"
        env["SSL_CERT_FILE"] = "/system/etc/security/cacerts"
        env["SSL_CERT_DIR"] = "/system/etc/security/cacerts"

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

        Thread.sleep(2000)
        if (nodeProc?.isAlive != true) {
            throw Exception("node 立即退出 (code=${nodeProc?.exitValue()})")
        }
        return true
    }

    override fun onDestroy() {
        try { nodeProc?.destroy(); nodeProc = null } catch (_: Throwable) {}
        super.onDestroy()
    }
}
