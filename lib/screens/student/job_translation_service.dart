import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum JobInformationField { title, description, requirements }

enum JobTranslationProgress { checkingModels, downloadingModels, translating }

typedef JobTranslationProgressCallback = void Function(
  JobTranslationProgress progress,
);

class JobTranslationRequest {
  const JobTranslationRequest({required this.originalContent});

  final Map<JobInformationField, String> originalContent;
}

class TranslatedJobContent {
  const TranslatedJobContent({required this.content});

  final Map<JobInformationField, String> content;
}

abstract interface class JobTranslationService {
  Future<TranslatedJobContent> translate(
    JobTranslationRequest request, {
    JobTranslationProgressCallback? onProgress,
  });
}

class PlatformJobTranslationService implements JobTranslationService {
  static const _channelName = 'pallijob/job_translation';
  const PlatformJobTranslationService({
    this.channel = const MethodChannel(_channelName),
    this.platform,
  });

  final MethodChannel channel;
  final TargetPlatform? platform;

  @override
  Future<TranslatedJobContent> translate(
    JobTranslationRequest request, {
    JobTranslationProgressCallback? onProgress,
  }) async {
    final platform = this.platform ?? defaultTargetPlatform;
    if (kIsWeb ||
        (platform != TargetPlatform.iOS &&
            platform != TargetPlatform.android)) {
      throw const JobTranslationUnsupportedPlatformException();
    }
    if (request.originalContent.isEmpty) {
      throw const JobTranslationContentMissingException();
    }

    onProgress?.call(JobTranslationProgress.checkingModels);
    try {
      final isSupported = await channel.invokeMethod<bool>('isSupported');
      if (isSupported != true) {
        throw const JobTranslationUnsupportedPlatformException();
      }

      final isModelDownloaded = await channel.invokeMethod<bool>(
        'isModelDownloaded',
      );
      if (isModelDownloaded != true) {
        onProgress?.call(JobTranslationProgress.downloadingModels);
      }

      onProgress?.call(JobTranslationProgress.translating);
      final result = await channel.invokeMapMethod<String, String>(
        'translate',
        request.originalContent.map(
          (field, text) => MapEntry(field.name, text),
        ),
      );
      if (result == null) {
        throw const JobTranslationIncompleteException();
      }
      return TranslatedJobContent(
        content: Map.unmodifiable({
          for (final entry in result.entries)
            if (JobInformationField.values.any(
              (field) => field.name == entry.key,
            ))
              JobInformationField.values.firstWhere(
                (field) => field.name == entry.key,
              ): entry.value,
        }),
      );
    } on PlatformException catch (error) {
      if (error.code == 'unsupported') {
        throw const JobTranslationUnsupportedPlatformException();
      }
      if (error.code == 'model_download_failed') {
        throw JobTranslationModelDownloadException(
          error.message ?? '',
          cause: error,
        );
      }
      throw JobTranslationPlatformException(error.message ?? error.code);
    }
  }
}

class UnavailableJobTranslationService implements JobTranslationService {
  const UnavailableJobTranslationService();

  @override
  Future<TranslatedJobContent> translate(
    JobTranslationRequest request, {
    JobTranslationProgressCallback? onProgress,
  }) {
    throw const JobTranslationUnavailableException();
  }
}

class JobTranslationUnavailableException implements Exception {
  const JobTranslationUnavailableException();
}

class JobTranslationIncompleteException implements Exception {
  const JobTranslationIncompleteException();
}

class JobTranslationContentMissingException implements Exception {
  const JobTranslationContentMissingException();
}

class JobTranslationUnsupportedPlatformException implements Exception {
  const JobTranslationUnsupportedPlatformException();
}

class JobTranslationModelDownloadException implements Exception {
  const JobTranslationModelDownloadException(this.languageCode, {this.cause});

  final String languageCode;
  final Object? cause;
}

class JobTranslationPlatformException implements Exception {
  const JobTranslationPlatformException(this.message);

  final String message;
}
