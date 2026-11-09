import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pallijob/screens/student/job_application_service.dart';
import 'package:pallijob/screens/student/job_translation_service.dart';
import 'package:pallijob/screens/student/student_job_listings_screen.dart';

const translationJob = StudentJobListing(
  id: 'job-translation',
  title: '카페 보조',
  description: '음료 준비와 고객 응대를 돕습니다.',
  location: '서울',
  requirements: '친절하고 성실한 분',
  employerId: 'employer-1',
  createdAt: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'uses the platform channel and reports model-download progress',
    () async {
      const channel = MethodChannel('test/job_translation');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'isSupported' => true,
              'isModelDownloaded' => false,
              'translate' => {
                'title': 'Cafe Assistant',
                'description': 'Assist at a cafe.',
                'requirements': 'Friendly.',
              },
              _ => null,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final service = PlatformJobTranslationService(
        channel: channel,
        platform: TargetPlatform.android,
      );
      final progress = <JobTranslationProgress>[];

      final result = await service.translate(
        const JobTranslationRequest(
          originalContent: {
            JobInformationField.title: '카페 보조',
            JobInformationField.description: '음료를 준비합니다.',
            JobInformationField.requirements: '친절한 분',
          },
        ),
        onProgress: progress.add,
      );

      expect(result.content[JobInformationField.title], 'Cafe Assistant');
      expect(
        result.content[JobInformationField.description],
        'Assist at a cafe.',
      );
      expect(result.content[JobInformationField.requirements], 'Friendly.');
      expect(calls.map((call) => call.method), [
        'isSupported',
        'isModelDownloaded',
        'translate',
      ]);
      expect(calls.last.arguments, {
        'title': '카페 보조',
        'description': '음료를 준비합니다.',
        'requirements': '친절한 분',
      });
      expect(progress, [
        JobTranslationProgress.checkingModels,
        JobTranslationProgress.downloadingModels,
        JobTranslationProgress.translating,
      ]);
    },
  );

  test('uses the same channel contract for Apple Translation', () async {
    const channel = MethodChannel('test/apple_translation');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return switch (call.method) {
            'isSupported' || 'isModelDownloaded' => true,
            'translate' => {'title': 'Cafe Assistant'},
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final service = PlatformJobTranslationService(
      channel: channel,
      platform: TargetPlatform.iOS,
    );
    final result = await service.translate(
      const JobTranslationRequest(
        originalContent: {JobInformationField.title: '카페 보조'},
      ),
    );

    expect(result.content, {JobInformationField.title: 'Cafe Assistant'});
  });

  test('reports unsupported device and model download errors', () async {
    const channel = MethodChannel('test/unsupported_translation');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'isSupported') return false;
          throw PlatformException(
            code: 'model_download_failed',
            message: 'No network',
          );
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final service = PlatformJobTranslationService(
      channel: channel,
      platform: TargetPlatform.iOS,
    );
    const request = JobTranslationRequest(
      originalContent: {JobInformationField.title: '카페 보조'},
    );
    await expectLater(
      service.translate(request),
      throwsA(isA<JobTranslationUnsupportedPlatformException>()),
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'isSupported') return true;
          if (call.method == 'isModelDownloaded') return false;
          throw PlatformException(
            code: 'model_download_failed',
            message: 'No network',
          );
        });
    await expectLater(
      service.translate(request),
      throwsA(isA<JobTranslationModelDownloadException>()),
    );
  });

  test('rejects unsupported platforms without a channel call', () async {
    final service = PlatformJobTranslationService(
      platform: TargetPlatform.linux,
    );
    await expectLater(
      service.translate(
        const JobTranslationRequest(
          originalContent: {JobInformationField.title: '카페 보조'},
        ),
      ),
      throwsA(isA<JobTranslationUnsupportedPlatformException>()),
    );
  });

  testWidgets('keeps original Korean text and toggles to translated content', (
    tester,
  ) async {
    final service = _FakeJobTranslationService(
      Future.value(
        const TranslatedJobContent(
          content: {
            JobInformationField.title: 'Cafe Assistant',
            JobInformationField.description:
                'Assist with drink preparation and customer service.',
            JobInformationField.requirements: 'Friendly and reliable.',
          },
        ),
      ),
    );
    await _pumpDetails(tester, translationService: service);

    expect(find.text('카페 보조'), findsOneWidget);
    expect(find.text('음료 준비와 고객 응대를 돕습니다.'), findsOneWidget);
    expect(find.text('친절하고 성실한 분'), findsOneWidget);
    expect(service.calls, 0);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Cafe Assistant'), findsOneWidget);
    expect(
      find.text('Assist with drink preparation and customer service.'),
      findsOneWidget,
    );
    expect(find.text('Friendly and reliable.'), findsOneWidget);
    expect(
      find.textContaining('original listing is unchanged'),
      findsOneWidget,
    );
    expect(service.requestedFields, {
      JobInformationField.title,
      JobInformationField.description,
      JobInformationField.requirements,
    });

    await tester.tap(find.text('Original'));
    await tester.pumpAndSettle();
    expect(find.text('카페 보조'), findsOneWidget);
    expect(find.text('음료 준비와 고객 응대를 돕습니다.'), findsOneWidget);
    expect(find.text('친절하고 성실한 분'), findsOneWidget);
    expect(service.calls, 1);
  });

  testWidgets('shows provider unavailable without claiming translation', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      translationService: const UnavailableJobTranslationService(),
    );

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('unavailable until a translation provider'),
      findsOneWidget,
    );
    expect(find.text('카페 보조'), findsOneWidget);
    expect(find.text('음료 준비와 고객 응대를 돕습니다.'), findsOneWidget);
    expect(find.text('친절하고 성실한 분'), findsOneWidget);
    expect(
      find.text('English translation. The original listing is unchanged.'),
      findsNothing,
    );
  });

  testWidgets(
    'shows the unsupported-device state and preserves original text',
    (tester) async {
      final result = Completer<TranslatedJobContent>();
      final service = _FakeJobTranslationService(result.future);
      await _pumpDetails(tester, translationService: service);

      await tester.tap(find.text('English'));
      await tester.pump();
      result.completeError(const JobTranslationUnsupportedPlatformException());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Translation unavailable on this device'),
        findsOneWidget,
      );
      expect(find.text('카페 보조'), findsOneWidget);
      expect(find.text('음료 준비와 고객 응대를 돕습니다.'), findsOneWidget);
    },
  );

  testWidgets('shows loading state during an injected translation request', (
    tester,
  ) async {
    final result = Completer<TranslatedJobContent>();
    final service = _FakeJobTranslationService(
      result.future,
      progress: JobTranslationProgress.translating,
    );
    await _pumpDetails(tester, translationService: service);

    await tester.tap(find.text('English'));
    await tester.pump();

    expect(find.text('Translating on your device...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    result.complete(
      const TranslatedJobContent(
        content: {
          JobInformationField.title: 'Cafe Assistant',
          JobInformationField.description: 'Assist at a cafe.',
          JobInformationField.requirements: 'Friendly.',
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cafe Assistant'), findsOneWidget);
  });

  testWidgets('shows first-use model download feedback and retry on failure', (
    tester,
  ) async {
    final downloadResult = Completer<TranslatedJobContent>();
    final service = _FakeJobTranslationService(
      downloadResult.future,
      progress: JobTranslationProgress.downloadingModels,
    );
    await _pumpDetails(tester, translationService: service);

    await tester.tap(find.text('English'));
    await tester.pump();
    downloadResult.completeError(
      const JobTranslationModelDownloadException('ko'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('allow language downloads'), findsOneWidget);
    expect(find.textContaining('uses device storage'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('카페 보조'), findsOneWidget);
  });

  testWidgets('does not present unchanged source as a translation', (
    tester,
  ) async {
    final service = _FakeJobTranslationService(
      Future.value(
        const TranslatedJobContent(
          content: {
            JobInformationField.title: '카페 보조',
            JobInformationField.description: 'Assist at a cafe.',
            JobInformationField.requirements: 'Friendly and reliable.',
          },
        ),
      ),
    );
    await _pumpDetails(tester, translationService: service);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('could not translate all job information'),
      findsOneWidget,
    );
    expect(find.text('카페 보조'), findsOneWidget);
    expect(
      find.text('English translation. The original listing is unchanged.'),
      findsNothing,
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('retries a failed translation and ignores repeated toggles', (
    tester,
  ) async {
    final firstAttempt = Completer<TranslatedJobContent>();
    final service = _FakeJobTranslationService.sequence([
      firstAttempt.future,
      Future.value(
        const TranslatedJobContent(
          content: {
            JobInformationField.title: 'Cafe Assistant',
            JobInformationField.description: 'Assist at a cafe.',
            JobInformationField.requirements: 'Friendly.',
          },
        ),
      ),
    ]);
    await _pumpDetails(tester, translationService: service);

    await tester.tap(find.text('English'));
    await tester.pump();
    firstAttempt.completeError(StateError('provider unavailable'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('could not translate all job information'),
      findsOneWidget,
    );
    expect(service.calls, 1);

    await tester.tap(find.text('Original'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(service.calls, 1);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    expect(find.text('Cafe Assistant'), findsOneWidget);
  });

  testWidgets('handles missing translatable content without provider call', (
    tester,
  ) async {
    const emptyJob = StudentJobListing(
      id: 'empty-job',
      title: 'Untitled job',
      description: 'Not provided',
      location: 'Seoul',
      requirements: 'Not provided',
      employerId: 'employer-1',
      createdAt: null,
    );
    final service = _FakeJobTranslationService(
      Future.value(const TranslatedJobContent(content: {})),
    );
    await _pumpDetails(tester, job: emptyJob, translationService: service);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.textContaining('There is no job title'), findsOneWidget);
    expect(find.text('Untitled job'), findsOneWidget);
    expect(find.text('Not provided'), findsNWidgets(2));
    expect(service.calls, 0);
  });
}

Future<void> _pumpDetails(
  WidgetTester tester, {
  StudentJobListing job = translationJob,
  JobTranslationService? translationService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: StudentJobDetailsScreen(
        job: job,
        applicationService: _FakeApplicationService(),
        translationService:
            translationService ?? const UnavailableJobTranslationService(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeJobTranslationService implements JobTranslationService {
  _FakeJobTranslationService(
    this.result, {
    this.progress = JobTranslationProgress.translating,
  }) : _results = [result];

  _FakeJobTranslationService.sequence(
    List<Future<TranslatedJobContent>> results,
  ) : result = results.first,
      _results = results,
      progress = JobTranslationProgress.translating;

  final Future<TranslatedJobContent> result;
  final List<Future<TranslatedJobContent>> _results;
  final JobTranslationProgress progress;
  int calls = 0;
  Set<JobInformationField> requestedFields = {};

  @override
  Future<TranslatedJobContent> translate(
    JobTranslationRequest request, {
    JobTranslationProgressCallback? onProgress,
  }) {
    requestedFields = request.originalContent.keys.toSet();
    onProgress?.call(progress);
    final index = calls++;
    return _results[index.clamp(0, _results.length - 1)];
  }
}

class _FakeApplicationService implements JobApplicationService {
  @override
  Future<JobApplicationStatus> getStatus(String jobId) async {
    return JobApplicationStatus.canApply;
  }

  @override
  Future<void> apply(String jobId) async {}
}
