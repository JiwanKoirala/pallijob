import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pallijob/screens/chat/chat_translation_service.dart';
import 'package:pallijob/screens/student/job_translation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'translates one chat message through the existing native channel',
    () async {
      const channel = MethodChannel('test/chat_translation');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'isSupported' || 'isModelDownloaded' => true,
              'translate' => {'title': 'Please prepare the drinks.'},
              _ => null,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      const original = '음료를 준비해 주세요.';
      final service = PlatformChatTranslationService(
        jobTranslationService: PlatformJobTranslationService(
          channel: channel,
          platform: TargetPlatform.android,
        ),
      );

      final translation = await service.translate(original);

      expect(translation, 'Please prepare the drinks.');
      expect(original, '음료를 준비해 주세요.');
      expect(calls.map((call) => call.method), [
        'isSupported',
        'isModelDownloaded',
        'translate',
      ]);
      expect(calls.last.arguments, {'title': original});
    },
  );

  test(
    'reports native translation failures without returning a result',
    () async {
      const channel = MethodChannel('test/chat_translation_error');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'isSupported') return true;
            if (call.method == 'isModelDownloaded') return true;
            throw PlatformException(
              code: 'translation_failed',
              message: 'Translation failed.',
            );
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final service = PlatformChatTranslationService(
        jobTranslationService: PlatformJobTranslationService(
          channel: channel,
          platform: TargetPlatform.android,
        ),
      );

      await expectLater(
        service.translate('감사합니다.'),
        throwsA(isA<JobTranslationPlatformException>()),
      );
    },
  );

  test(
    'reports unsupported platforms without invoking a native channel',
    () async {
      final service = PlatformChatTranslationService(
        jobTranslationService: PlatformJobTranslationService(
          platform: TargetPlatform.linux,
        ),
      );

      await expectLater(
        service.translate('감사합니다.'),
        throwsA(isA<JobTranslationUnsupportedPlatformException>()),
      );
    },
  );

  test('rejects empty translations returned by the native channel', () async {
    const channel = MethodChannel('test/chat_translation_incomplete');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return switch (call.method) {
            'isSupported' || 'isModelDownloaded' => true,
            'translate' => <String, String>{},
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final service = PlatformChatTranslationService(
      jobTranslationService: PlatformJobTranslationService(
        channel: channel,
        platform: TargetPlatform.android,
      ),
    );

    await expectLater(
      service.translate('감사합니다.'),
      throwsA(isA<JobTranslationIncompleteException>()),
    );
  });
}
