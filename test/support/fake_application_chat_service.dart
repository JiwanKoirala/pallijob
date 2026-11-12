import 'package:pallijob/screens/chat/application_chat_screen.dart';

class FakeApplicationChatService implements ApplicationChatService {
  FakeApplicationChatService({
    Future<ChatConversation>? conversation,
    Stream<List<ChatMessage>>? messages,
    this.onSend,
  }) : conversation = conversation ?? Future.value(testChatConversation),
       messages = messages ?? Stream.value(const []);

  static const testChatConversation = ChatConversation(
    applicationId: 'job-1_student-1',
    jobTitle: 'Cafe Assistant',
    studentId: 'student-1',
    employerId: 'employer-1',
    currentUserId: 'student-1',
    currentRole: ChatParticipantRole.student,
  );

  final Future<ChatConversation> conversation;
  final Stream<List<ChatMessage>> messages;
  final Future<void> Function(String applicationId, String content)? onSend;
  final List<(String, String)> sentMessages = [];

  @override
  Future<ChatConversation> loadConversation(String applicationId) =>
      conversation;

  @override
  Stream<List<ChatMessage>> watchMessages(String applicationId) => messages;

  @override
  Future<void> sendMessage(String applicationId, String content) async {
    sentMessages.add((applicationId, content));
    await onSend?.call(applicationId, content);
  }
}
