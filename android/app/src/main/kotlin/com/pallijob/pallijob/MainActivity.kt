package com.pallijob.pallijob

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.TranslateRemoteModel
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.Translator
import com.google.mlkit.nl.translate.TranslatorOptions

class MainActivity : FlutterActivity() {
    private val translationChannelName = "pallijob/job_translation"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            translationChannelName,
        ).setMethodCallHandler(::handleTranslationCall)
    }

    private fun handleTranslationCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(true)
            "isModelDownloaded" -> checkModelsDownloaded(result)
            "translate" -> translate(call, result)
            else -> result.notImplemented()
        }
    }

    private fun checkModelsDownloaded(result: MethodChannel.Result) {
        val manager = RemoteModelManager.getInstance()
        val korean = TranslateRemoteModel.Builder(TranslateLanguage.KOREAN).build()
        val english = TranslateRemoteModel.Builder(TranslateLanguage.ENGLISH).build()
        manager.isModelDownloaded(korean)
            .addOnSuccessListener { koreanDownloaded ->
                if (!koreanDownloaded) {
                    result.success(false)
                } else {
                    manager.isModelDownloaded(english)
                        .addOnSuccessListener { result.success(it) }
                        .addOnFailureListener {
                            result.error("model_check_failed", it.localizedMessage, null)
                        }
                }
            }
            .addOnFailureListener {
                result.error("model_check_failed", it.localizedMessage, null)
            }
    }

    private fun translate(call: MethodCall, result: MethodChannel.Result) {
        val content = call.arguments as? Map<*, *>
        if (content == null || content.isEmpty()) {
            result.error("invalid_arguments", "No job text was provided.", null)
            return
        }

        val options = TranslatorOptions.Builder()
            .setSourceLanguage(TranslateLanguage.KOREAN)
            .setTargetLanguage(TranslateLanguage.ENGLISH)
            .build()
        val translator = Translation.getClient(options)
        val conditions = DownloadConditions.Builder().requireWifi().build()

        translator.downloadModelIfNeeded(conditions)
            .addOnSuccessListener {
                translateFields(content.entries.toList(), 0, mutableMapOf(), translator, result)
            }
            .addOnFailureListener {
                translator.close()
                result.error("model_download_failed", it.localizedMessage, null)
            }
    }

    private fun translateFields(
        entries: List<Map.Entry<*, *>>,
        index: Int,
        translated: MutableMap<String, String>,
        translator: Translator,
        result: MethodChannel.Result,
    ) {
        if (index >= entries.size) {
            translator.close()
            result.success(translated)
            return
        }

        val entry = entries[index]
        val key = entry.key as? String
        val text = entry.value as? String
        if (key == null || text == null) {
            translator.close()
            result.error("invalid_arguments", "Job text must be string fields.", null)
            return
        }

        translator.translate(text)
            .addOnSuccessListener { value ->
                translated[key] = value
                translateFields(entries, index + 1, translated, translator, result)
            }
            .addOnFailureListener {
                translator.close()
                result.error("translation_failed", it.localizedMessage, null)
            }
    }
}
