import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pallijob/screens/chat/application_chat_screen.dart';

import '../../support/fake_application_chat_service.dart';

void main() {
  testWidgets('shows a loading state while verifying the conversation', (
    tester,
  ) async {
    final conversation = Completer<ChatConversation>();
    await tester.pumpWidget(
      MaterialApp(
        home: ApplicationChatScreen(
          applicationId: 'job-1_student-1',
          chatService: FakeApplicationChatService(
            conversation: conversation.future,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Loading chat'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    conversation.complete(FakeApplicationChatService.testChatConversation);
    await tester.pumpAndSettle();
    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no messages', (
    tester,
  ) async {
    await _pumpChat(tester, FakeApplicationChatService());

    expect(find.text('No messages yet'), findsOneWidget);
    expect(
      find.text('Send a message to start this conversation.'),
      findsOneWidget,
    );
  });

  testWidgets('renders messages in order with participant roles and times', (
    tester,
  ) async {
    final service = FakeApplicationChatService(
      messages: Stream.value([
        ChatMessage(
          id: 'first',
          senderId: 'student-1',
          receiverId: 'employer-1',
          content: 'First message',
          timestamp: DateTime(2026, 11, 1, 9),
        ),
        ChatMessage(
          id: 'second',
          senderId: 'employer-1',
          receiverId: 'student-1',
          content: 'Second message',
          timestamp: DateTime(2026, 11, 1, 10),
        ),
      ]),
    );
    await _pumpChat(tester, service);

    expect(find.text('You · Student'), findsOneWidget);
    expect(find.text('Employer'), findsOneWidget);
    expect(find.textContaining('Nov'), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('First message')).dy,
      lessThan(tester.getTopLeft(find.text('Second message')).dy),
    );
  });

  testWidgets('shows newly received messages from the live service stream', (
    tester,
  ) async {
    final snapshots = StreamController<List<ChatMessage>>.broadcast(sync: true);
    final service = FakeApplicationChatService(
      messages: snapshots.stream,
      onSend: (_, _) async {
        snapshots.add([
          ChatMessage(
            id: 'received',
            senderId: 'employer-1',
            receiverId: 'student-1',
            content: 'Received in real time',
            timestamp: DateTime(2026, 11, 1, 10),
          ),
        ]);
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ApplicationChatScreen(
          applicationId: 'job-1_student-1',
          chatService: service,
        ),
      ),
    );
    await tester.pump();
    snapshots.add(const []);
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Send a reply');
    await tester.tap(find.byKey(const ValueKey('send-chat-message')));
    await tester.pumpAndSettle();

    expect(service.sentMessages, [('job-1_student-1', 'Send a reply')]);
    expect(find.text('Received in real time'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await snapshots.close();
  });

  testWidgets('trims input and prevents duplicate sends while submitting', (
    tester,
  ) async {
    final sending = Completer<void>();
    final service = FakeApplicationChatService(
      onSend: (_, _) => sending.future,
    );
    await _pumpChat(tester, service);

    await tester.enterText(find.byType(TextField), '  hello chat  ');
    await tester.tap(find.byKey(const ValueKey('send-chat-message')));
    await tester.pump();

    expect(service.sentMessages, [('job-1_student-1', 'hello chat')]);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('send-chat-message')))
          .onPressed,
      isNull,
    );

    sending.complete();
    await tester.pumpAndSettle();
    expect(find.text('hello chat'), findsNothing);
  });

  testWidgets('rejects whitespace-only input and enforces the length limit', (
    tester,
  ) async {
    final service = FakeApplicationChatService();
    await _pumpChat(tester, service);

    await tester.enterText(find.byType(TextField), '   \n ');
    await tester.tap(find.byKey(const ValueKey('send-chat-message')));
    await tester.pump();
    expect(find.text('Enter a message before sending.'), findsOneWidget);
    expect(service.sentMessages, isEmpty);

    await tester.enterText(find.byType(TextField), 'x' * 2001);
    expect(tester.widget<TextField>(find.byType(TextField)).maxLength, 2000);
    await tester.tap(find.byKey(const ValueKey('send-chat-message')));
    await tester.pumpAndSettle();
    expect(service.sentMessages.single.$2, hasLength(2000));
  });

  testWidgets('shows send failures and keeps the draft for retry', (
    tester,
  ) async {
    final service = FakeApplicationChatService(
      onSend: (_, _) async => throw StateError('offline'),
    );
    await _pumpChat(tester, service);

    await tester.enterText(find.byType(TextField), 'keep this draft');
    await tester.tap(find.byKey(const ValueKey('send-chat-message')));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not send message. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('keep this draft'), findsOneWidget);
  });

  testWidgets('shows permission-denied state when message access is denied', (
    tester,
  ) async {
    await _pumpChat(
      tester,
      FakeApplicationChatService(
        messages: Stream.error(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
      ),
    );

    expect(
      find.text('You do not have permission to read these messages.'),
      findsOneWidget,
    );
  });

  testWidgets('shows denied conversation access and offers retry', (
    tester,
  ) async {
    final conversation = Completer<ChatConversation>();
    await tester.pumpWidget(
      MaterialApp(
        home: ApplicationChatScreen(
          applicationId: 'job-1_student-1',
          chatService: FakeApplicationChatService(
            conversation: conversation.future,
          ),
        ),
      ),
    );
    await tester.pump();
    conversation.completeError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not open chat'), findsOneWidget);
    expect(
      find.text('You do not have permission to access this application chat.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });
}

Future<void> _pumpChat(
  WidgetTester tester,
  ApplicationChatService service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ApplicationChatScreen(
        applicationId: 'job-1_student-1',
        chatService: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
