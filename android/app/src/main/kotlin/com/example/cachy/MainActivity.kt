package com.example.cachy

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {

    private val CHANNEL = "gemma"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            if (call.method == "generate") {

                val prompt = call.argument<String>("prompt") ?: ""

                // TEMPORARY RESPONSE
                val modelPath =
                    "/storage/emulated/0/Download/gemma-4-E2B-it.litertlm"

                val exists = java.io.File(modelPath).exists()

                if (exists) {
                    result.success("Model found!\nPrompt: $prompt")
                } else {
                    result.success("Model NOT found")
                }

            } else {
                result.notImplemented()
            }
        }
    }
}