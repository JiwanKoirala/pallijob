import 'package:pallijob/screens/student/job_translation_service.dart';

abstract interface class ChatTranslationService {
  Future<String> translate(String content);
}

class PlatformChatTranslationService implements ChatTranslationService {
  const PlatformChatTranslationService({
    this.jobTranslationService = const PlatformJobTranslationService(),
  });

  final JobTranslationService jobTranslationService;

  @override
  Future<String> translate(String content) async {
    final translated = await jobTranslationService.translate(
      JobTranslationRequest(
        originalContent: {JobInformationField.title: content},
      ),
    );
    final result = translated.content[JobInformationField.title];
    if (result == null || result.trim().isEmpty) {
      throw const JobTranslationIncompleteException();
    }
    return result;
  }
}
