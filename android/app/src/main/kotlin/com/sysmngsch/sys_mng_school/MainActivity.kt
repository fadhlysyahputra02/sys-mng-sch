package com.sysmngsch.sys_mng_school

import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.sysmngsch.sys_mng_school/feedback"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "playBeep") {
                try {
                    val toneGen = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
                    toneGen.startTone(ToneGenerator.TONE_CDMA_PIP, 150)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("ERR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}

