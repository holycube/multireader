package com.novelreader.multireader

import com.chaquo.python.PyException
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val chunkerChannel = "com.novelreader/chunker"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            chunkerChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getChunkBoundaries" -> {
                    val text = call.argument<String>("text") ?: ""
                    try {
                        val py = Python.getInstance()
                        val module = py.getModule("chunker")
                        val json = module.callAttr("get_chunk_boundaries", text).toString()
                        result.success(json)
                    } catch (e: PyException) {
                        result.error("PYTHON_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
