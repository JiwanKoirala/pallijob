import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pallijob/screens/student/job_translation_service.dart';

import 'chat_translation_service.dart';

const int maxChatMessageLength = 2000;

typedef _ChatTranslationKey = ({String messageId, String content});

enum ChatParticipantRole { student, employer }

class ChatConversation {
  const ChatConversation({
    required this.applicationId,
    required this.jobTitle,
    required this.studentId,
    required this.employerId,
    required this.currentUserId,
    required this.currentRole,
  });

  final String applicationId;
  final String jobTitle;
  final String studentId;
  final String employerId;
  final String currentUserId;
  final ChatParticipantRole currentRole;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime? timestamp;
}

abstract interface class ApplicationChatService {
  Future<ChatConversation> loadConversation(String applicationId);

  Stream<List<ChatMessage>> watchMessages(String applicationId);

  Future<void> sendMessage(String applicationId, String content);
}

class FirestoreApplicationChatService implements ApplicationChatService {
  const FirestoreApplicationChatService();

  @override
  Future<ChatConversation> loadConversation(String applicationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const ChatAccessException('Sign in to access this chat.');
    }

    final firestore = FirebaseFirestore.instance;
    final profile = await firestore.collection('users').doc(user.uid).get();
    final role = profile.data()?['role'];
    if (role != 'student' && role != 'employer') {
      throw const ChatAccessException(
        'Only student applicants and employers can access this chat.',
      );
    }

    final application = await firestore
        .collection('applications')
        .doc(applicationId)
        .get();
    final applicationData = application.data();
    if (applicationData == null) {
      throw const ChatAccessException(
        'This application is no longer available.',
      );
    }

    final jobId = applicationData['jobId'];
    final studentId = applicationData['studentId'];
    if (jobId is! String ||
        jobId.trim().isEmpty ||
        studentId is! String ||
        studentId.trim().isEmpty) {
      throw const ChatAccessException(
        'This application does not have valid chat participants.',
      );
    }

    final job = await firestore.collection('jobs').doc(jobId).get();
    final jobData = job.data();
    final employerId = jobData?['employerId'];
    if (jobData == null ||
        employerId is! String ||
        employerId.trim().isEmpty ||
        studentId == employerId) {
      throw const ChatAccessException(
        'The job owner for this application could not be verified.',
      );
    }

    if (applicationData.containsKey('employerId') &&
        applicationData['employerId'] != employerId) {
      throw const ChatAccessException(
        'The application and job ownership information do not match.',
      );
    }

    final currentRole = switch (role) {
      'student' when user.uid == studentId => ChatParticipantRole.student,
      'employer' when user.uid == employerId => ChatParticipantRole.employer,
      _ => null,
    };
    if (currentRole == null ||
        FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw const ChatAccessException(
        'You are not a participant in this application chat.',
      );
    }

    return ChatConversation(
      applicationId: applicationId,
      jobTitle: _readText(jobData['title'], fallback: 'Job application'),
      studentId: studentId,
      employerId: employerId,
      currentUserId: user.uid,
      currentRole: currentRole,
    );
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String applicationId) {
    return _messagesReference(applicationId)
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_messageFromDocument).toList());
  }

  @override
  Future<void> sendMessage(String applicationId, String content) async {
    final text = content.trim();
    if (text.isEmpty) {
      throw const ChatValidationException('Enter a message before sending.');
    }
    if (text.length > maxChatMessageLength) {
      throw const ChatValidationException(
        'Messages must be 2,000 characters or fewer.',
      );
    }

    final conversation = await loadConversation(applicationId);
    final receiverId = conversation.currentRole == ChatParticipantRole.student
        ? conversation.employerId
        : conversation.studentId;
    await _messagesReference(applicationId).add({
      'senderId': conversation.currentUserId,
      'receiverId': receiverId,
      'content': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  CollectionReference<Map<String, dynamic>> _messagesReference(
    String applicationId,
  ) {
    return FirebaseFirestore.instance
        .collection('applications')
        .doc(applicationId)
        .collection('messages');
  }

  ChatMessage _messageFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final senderId = data['senderId'];
    final receiverId = data['receiverId'];
    final content = data['content'];
    final timestamp = data['timestamp'];
    if (senderId is! String ||
        receiverId is! String ||
        content is! String ||
        (timestamp != null && timestamp is! Timestamp)) {
      throw const FormatException('A chat message has invalid fields.');
    }

    return ChatMessage(
      id: document.id,
      senderId: senderId,
      receiverId: receiverId,
      content: content,
      timestamp: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }

  static String _readText(Object? value, {required String fallback}) {
    return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  }
}

class ChatAccessException implements Exception {
  const ChatAccessException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ChatValidationException implements Exception {
  const ChatValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApplicationChatScreen extends StatefulWidget {
  const ApplicationChatScreen({
    required this.applicationId,
    this.chatService = const FirestoreApplicationChatService(),
    this.translationService = const PlatformChatTranslationService(),
    super.key,
  });

  final String applicationId;
  final ApplicationChatService chatService;
  final ChatTranslationService translationService;

  @override
  State<ApplicationChatScreen> createState() => _ApplicationChatScreenState();
}

class _ApplicationChatScreenState extends State<ApplicationChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  late final Stream<List<ChatMessage>> _messagesStream = widget.chatService
      .watchMessages(widget.applicationId);
  late Future<ChatConversation> _conversationFuture;
  bool _isSending = false;
  String? _sendError;
  String? _validationError;
  final Map<_ChatTranslationKey, String> _translations = {};
  final Map<_ChatTranslationKey, Object> _translationErrors = {};
  final Set<_ChatTranslationKey> _visibleTranslations = {};
  _ChatTranslationKey? _activeTranslationKey;

  @override
  void initState() {
    super.initState();
    _conversationFuture = widget.chatService.loadConversation(
      widget.applicationId,
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      appBar: AppBar(
        title: const Text(
          'Chat',
          style: TextStyle(
            color: Color(0xFF173B27),
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: const Color(0xFFF8FBF8),
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<ChatConversation>(
        future: _conversationFuture,
        builder: (context, conversationSnapshot) {
          if (conversationSnapshot.hasError) {
            return _ChatState(
              title: 'Could not open chat',
              message: _accessErrorMessage(conversationSnapshot.error),
              action: TextButton(
                onPressed: () => setState(
                  () => _conversationFuture = widget.chatService
                      .loadConversation(widget.applicationId),
                ),
                child: const Text('Retry'),
              ),
            );
          }
          if (!conversationSnapshot.hasData) {
            return const _ChatState(
              loading: true,
              title: 'Loading chat',
              message: 'Verifying application participants.',
            );
          }

          final conversation = conversationSnapshot.data!;
          return Column(
            children: [
              Expanded(child: _messageList(conversation)),
              _messageComposer(),
            ],
          );
        },
      ),
    );
  }

  Widget _messageList(ChatConversation conversation) {
    return StreamBuilder<List<ChatMessage>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ChatState(
            title: 'Could not load messages',
            message: _streamErrorMessage(snapshot.error),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ChatState(
            loading: true,
            title: 'Loading messages',
            message: 'Please wait while we load this conversation.',
          );
        }

        final messages = snapshot.data ?? const <ChatMessage>[];
        if (messages.isEmpty) {
          return const _ChatState(
            title: 'No messages yet',
            message: 'Send a message to start this conversation.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          itemCount: messages.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final message = messages[index];
            final translationKey = (
              messageId: message.id,
              content: message.content,
            );
            return _MessageBubble(
              message: message,
              conversation: conversation,
              translation: _translations[translationKey],
              translationError: _translationErrors[translationKey],
              isTranslationVisible: _visibleTranslations.contains(
                translationKey,
              ),
              isTranslating: _activeTranslationKey == translationKey,
              isTranslationDisabled:
                  _activeTranslationKey != null &&
                  _activeTranslationKey != translationKey,
              onTranslationPressed: () => _toggleTranslation(message),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleTranslation(ChatMessage message) async {
    final key = (messageId: message.id, content: message.content);
    if (_activeTranslationKey != null) return;

    if (_translations.containsKey(key)) {
      setState(() {
        if (!_visibleTranslations.remove(key)) {
          _visibleTranslations.add(key);
        }
      });
      return;
    }

    setState(() {
      _activeTranslationKey = key;
      _translationErrors.remove(key);
    });
    try {
      final translation = await widget.translationService.translate(
        message.content,
      );
      if (mounted) {
        setState(() {
          _translations[key] = translation;
          _visibleTranslations.add(key);
        });
      }
    } catch (error) {
      if (mounted) setState(() => _translationErrors[key] = error);
    } finally {
      if (mounted) setState(() => _activeTranslationKey = null);
    }
  }

  Widget _messageComposer() {
    return SafeArea(
      top: false,
      child: Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_sendError != null || _validationError != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Text(
                      _validationError ?? _sendError!,
                      key: const ValueKey('chat-send-error'),
                      style: const TextStyle(
                        color: Color(0xFF9B2C2C),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: maxChatMessageLength,
                      onChanged: (_) => setState(() {
                        _validationError = null;
                        _sendError = null;
                      }),
                      decoration: const InputDecoration(
                        hintText: 'Write a message',
                        border: OutlineInputBorder(),
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const ValueKey('send-chat-message'),
                    tooltip: 'Send message',
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;
    final content = _messageController.text.trim();
    if (content.isEmpty) {
      setState(() {
        _validationError = 'Enter a message before sending.';
        _sendError = null;
      });
      return;
    }
    if (content.length > maxChatMessageLength) {
      setState(() {
        _validationError = 'Messages must be 2,000 characters or fewer.';
        _sendError = null;
      });
      return;
    }

    setState(() {
      _isSending = true;
      _sendError = null;
      _validationError = null;
    });
    try {
      await widget.chatService.sendMessage(widget.applicationId, content);
      if (mounted) _messageController.clear();
    } catch (error) {
      if (mounted) setState(() => _sendError = _sendErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.conversation,
    required this.translation,
    required this.translationError,
    required this.isTranslationVisible,
    required this.isTranslating,
    required this.isTranslationDisabled,
    required this.onTranslationPressed,
  });

  final ChatMessage message;
  final ChatConversation conversation;
  final String? translation;
  final Object? translationError;
  final bool isTranslationVisible;
  final bool isTranslating;
  final bool isTranslationDisabled;
  final VoidCallback onTranslationPressed;

  @override
  Widget build(BuildContext context) {
    final isMine = message.senderId == conversation.currentUserId;
    final role = isMine
        ? conversation.currentRole
        : conversation.currentRole == ChatParticipantRole.student
        ? ChatParticipantRole.employer
        : ChatParticipantRole.student;
    final roleLabel = role == ChatParticipantRole.student
        ? 'Student'
        : 'Employer';
    final timeLabel = message.timestamp == null
        ? 'Sending…'
        : '${MaterialLocalizations.of(context).formatMediumDate(message.timestamp!.toLocal())} · '
              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(message.timestamp!.toLocal()))}';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isMine ? const Color(0xFFEAF4ED) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5EEE7)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMine ? 'You · $roleLabel' : roleLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF247545),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message.content),
                if (translation != null && isTranslationVisible) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFDCE8DF)),
                  const SizedBox(height: 8),
                  Text(
                    'English translation',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF247545),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    translation!,
                    key: ValueKey('translation-${message.id}'),
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  timeLabel,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: const Color(0xFF647369)),
                ),
                if (isTranslating) ...[
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Flexible(child: Text('Translating on your device…')),
                    ],
                  ),
                ] else ...[
                  TextButton.icon(
                    key: ValueKey('translate-message-${message.id}'),
                    onPressed: isTranslationDisabled
                        ? null
                        : onTranslationPressed,
                    icon: Icon(
                      translation == null
                          ? Icons.translate_rounded
                          : isTranslationVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                    ),
                    label: Text(
                      translationError != null
                          ? 'Try again'
                          : translation == null
                          ? 'Translate to English'
                          : isTranslationVisible
                          ? 'Hide translation'
                          : 'Show translation',
                    ),
                  ),
                  if (translationError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        _chatTranslationErrorMessage(translationError!),
                        key: ValueKey('translation-error-${message.id}'),
                        style: const TextStyle(
                          color: Color(0xFF9B2C2C),
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatState extends StatelessWidget {
  const _ChatState({
    required this.title,
    required this.message,
    this.loading = false,
    this.action,
  });

  final String title;
  final String message;
  final bool loading;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const CircularProgressIndicator(color: Color(0xFF247545))
            else
              const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Color(0xFF247545),
                size: 42,
              ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFF173B27),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

String _chatTranslationErrorMessage(Object error) {
  if (error is JobTranslationUnsupportedPlatformException) {
    return 'On-device Korean-to-English translation is not supported on this device. The original message is unchanged.';
  }
  if (error is JobTranslationUnavailableException) {
    return 'Translation is unavailable on this device. The original message is unchanged.';
  }
  if (error is JobTranslationModelDownloadException) {
    return 'Could not prepare the language resources. Check your connection and try again.';
  }
  return 'Could not translate this message. The original message is unchanged. Please try again.';
}

String _accessErrorMessage(Object? error) {
  if (error is ChatAccessException) return error.message;
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'You do not have permission to access this application chat.';
  }
  if (error is FirebaseException) {
    return 'A Firebase error occurred while opening chat. Please try again.';
  }
  return 'Could not verify this application chat. Please try again.';
}

String _streamErrorMessage(Object? error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'You do not have permission to read these messages.';
  }
  if (error is FirebaseException) {
    return 'A Firebase error occurred while loading messages. Please try again.';
  }
  return 'Could not load messages. Please try again.';
}

String _sendErrorMessage(Object error) {
  if (error is ChatValidationException) return error.message;
  if (error is ChatAccessException) return error.message;
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'You do not have permission to send messages in this chat.';
  }
  if (error is FirebaseException) {
    return 'Could not send message. Please check your connection and try again.';
  }
  return 'Could not send message. Please try again.';
}
