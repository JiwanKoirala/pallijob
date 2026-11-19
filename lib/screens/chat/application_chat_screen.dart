import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pallijob/l10n/role_aware_strings.dart';
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
    this.jobTitleIsFallback = false,
  });

  final String applicationId;
  final String jobTitle;
  final String studentId;
  final String employerId;
  final String currentUserId;
  final ChatParticipantRole currentRole;
  final bool jobTitleIsFallback;

  String notificationTitleForRecipient(ChatParticipantRole role) {
    if (jobTitleIsFallback && role == ChatParticipantRole.employer) {
      return '지원서';
    }
    return jobTitle;
  }
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
      throw const ChatAccessException(
        'Sign in to access this chat.',
        koreanMessage: '채팅을 이용하려면 로그인해 주세요.',
      );
    }

    final firestore = FirebaseFirestore.instance;
    final profile = await firestore.collection('users').doc(user.uid).get();
    final role = profile.data()?['role'];
    if (role != 'student' && role != 'employer') {
      throw const ChatAccessException(
        'Only student applicants and employers can access this chat.',
        koreanMessage: '학생 지원자와 해당 고용주만 이 채팅을 이용할 수 있습니다.',
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
        koreanMessage: '이 지원서는 더 이상 이용할 수 없습니다.',
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
        koreanMessage: '지원서의 채팅 참여자 정보가 올바르지 않습니다.',
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
        koreanMessage: '이 지원서의 공고 소유자를 확인할 수 없습니다.',
      );
    }

    if (applicationData.containsKey('employerId') &&
        applicationData['employerId'] != employerId) {
      throw const ChatAccessException(
        'The application and job ownership information do not match.',
        koreanMessage: '지원서와 공고의 소유자 정보가 일치하지 않습니다.',
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
        koreanMessage: '이 지원서의 채팅 참여자가 아닙니다.',
      );
    }

    final title = jobData['title'];
    final hasJobTitle = title is String && title.trim().isNotEmpty;
    return ChatConversation(
      applicationId: applicationId,
      jobTitle: hasJobTitle ? title.trim() : 'Job application',
      jobTitleIsFallback: !hasJobTitle,
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
      throw const ChatValidationException(
        'Enter a message before sending.',
        koreanMessage: '메시지를 입력해 주세요.',
      );
    }
    if (text.length > maxChatMessageLength) {
      throw const ChatValidationException(
        'Messages must be 2,000 characters or fewer.',
        koreanMessage: '메시지는 2,000자 이하로 입력해 주세요.',
      );
    }

    final conversation = await loadConversation(applicationId);
    final receiverId = conversation.currentRole == ChatParticipantRole.student
        ? conversation.employerId
        : conversation.studentId;
    final receiverRole = conversation.currentRole == ChatParticipantRole.student
        ? ChatParticipantRole.employer
        : ChatParticipantRole.student;
    final firestore = FirebaseFirestore.instance;
    final message = _messagesReference(applicationId).doc();
    final notification = firestore
        .collection('users')
        .doc(receiverId)
        .collection('notifications')
        .doc('${applicationId}__${message.id}');
    final batch = firestore.batch();
    batch.set(message, {
      'senderId': conversation.currentUserId,
      'receiverId': receiverId,
      'content': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
    batch.set(notification, {
      'type': 'new_message',
      'applicationId': applicationId,
      'jobTitle': conversation.notificationTitleForRecipient(receiverRole),
      'messageId': message.id,
      'createdAt': FieldValue.serverTimestamp(),
      'readAt': null,
    });
    await batch.commit();
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
}

class ChatAccessException implements Exception {
  const ChatAccessException(this.message, {required this.koreanMessage});

  final String message;
  final String koreanMessage;

  @override
  String toString() => message;
}

class ChatValidationException implements Exception {
  const ChatValidationException(this.message, {required this.koreanMessage});

  final String message;
  final String koreanMessage;

  @override
  String toString() => message;
}

class ApplicationChatScreen extends StatefulWidget {
  const ApplicationChatScreen({
    required this.applicationId,
    this.chatService = const FirestoreApplicationChatService(),
    this.translationService = const PlatformChatTranslationService(),
    this.uiRole,
    super.key,
  });

  final String applicationId;
  final ApplicationChatService chatService;
  final ChatTranslationService translationService;
  final ChatParticipantRole? uiRole;

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

  RoleAwareStrings get _strings => RoleAwareStrings(
    isEmployer: widget.uiRole == ChatParticipantRole.employer,
  );

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
    final strings = _strings;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      appBar: AppBar(
        title: Text(
          strings.text(english: 'Chat', korean: '채팅'),
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
              title: strings.text(
                english: 'Could not open chat',
                korean: '채팅을 열지 못했습니다',
              ),
              message: _accessErrorMessage(conversationSnapshot.error, strings),
              action: TextButton(
                onPressed: () => setState(
                  () => _conversationFuture = widget.chatService
                      .loadConversation(widget.applicationId),
                ),
                child: Text(strings.text(english: 'Retry', korean: '다시 시도')),
              ),
            );
          }
          if (!conversationSnapshot.hasData) {
            return _ChatState(
              loading: true,
              title: strings.text(
                english: 'Loading chat',
                korean: '채팅을 불러오는 중',
              ),
              message: strings.text(
                english: 'Verifying application participants.',
                korean: '지원서 참여자를 확인하고 있습니다.',
              ),
            );
          }

          final conversation = conversationSnapshot.data!;
          final conversationStrings = RoleAwareStrings(
            isEmployer:
                conversation.currentRole == ChatParticipantRole.employer,
          );
          return Column(
            children: [
              Expanded(child: _messageList(conversation, conversationStrings)),
              _messageComposer(conversationStrings),
            ],
          );
        },
      ),
    );
  }

  Widget _messageList(ChatConversation conversation, RoleAwareStrings strings) {
    return StreamBuilder<List<ChatMessage>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ChatState(
            title: strings.text(
              english: 'Could not load messages',
              korean: '메시지를 불러오지 못했습니다',
            ),
            message: _streamErrorMessage(snapshot.error, strings),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _ChatState(
            loading: true,
            title: strings.text(
              english: 'Loading messages',
              korean: '메시지를 불러오는 중',
            ),
            message: strings.text(
              english: 'Please wait while we load this conversation.',
              korean: '대화 내용을 불러오고 있습니다.',
            ),
          );
        }

        final messages = snapshot.data ?? const <ChatMessage>[];
        if (messages.isEmpty) {
          return _ChatState(
            title: strings.text(
              english: 'No messages yet',
              korean: '메시지가 없습니다',
            ),
            message: strings.text(
              english: 'Send a message to start this conversation.',
              korean: '메시지를 보내 대화를 시작해 보세요.',
            ),
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
              strings: strings,
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

  Widget _messageComposer(RoleAwareStrings strings) {
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
                      decoration: InputDecoration(
                        hintText: strings.text(
                          english: 'Write a message',
                          korean: '메시지를 입력하세요',
                        ),
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
                    tooltip: strings.text(
                      english: 'Send message',
                      korean: '메시지 보내기',
                    ),
                    onPressed: _isSending ? null : () => _sendMessage(strings),
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

  Future<void> _sendMessage(RoleAwareStrings strings) async {
    if (_isSending) return;
    final content = _messageController.text.trim();
    if (content.isEmpty) {
      setState(() {
        _validationError = strings.text(
          english: 'Enter a message before sending.',
          korean: '메시지를 입력해 주세요.',
        );
        _sendError = null;
      });
      return;
    }
    if (content.length > maxChatMessageLength) {
      setState(() {
        _validationError = strings.text(
          english: 'Messages must be 2,000 characters or fewer.',
          korean: '메시지는 2,000자 이하로 입력해 주세요.',
        );
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
      if (mounted) {
        setState(() => _sendError = _sendErrorMessage(error, strings));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.conversation,
    required this.strings,
    required this.translation,
    required this.translationError,
    required this.isTranslationVisible,
    required this.isTranslating,
    required this.isTranslationDisabled,
    required this.onTranslationPressed,
  });

  final ChatMessage message;
  final ChatConversation conversation;
  final RoleAwareStrings strings;
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
        ? strings.text(english: 'Student', korean: '학생')
        : strings.text(english: 'Employer', korean: '고용주');
    final localTimestamp = message.timestamp?.toLocal();
    final timeLabel = localTimestamp == null
        ? strings.text(english: 'Sending…', korean: '전송 중…')
        : '${strings.mediumDate(context, localTimestamp)} · '
              '${strings.timeOfDay(context, localTimestamp)}';

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
                  isMine
                      ? '${strings.text(english: 'You', korean: '나')} · $roleLabel'
                      : roleLabel,
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
                    strings.text(
                      english: 'English translation',
                      korean: '영어 번역',
                    ),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          strings.text(
                            english: 'Translating on your device…',
                            korean: '기기에서 번역 중…',
                          ),
                        ),
                      ),
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
                          ? strings.text(english: 'Try again', korean: '다시 시도')
                          : translation == null
                          ? strings.text(
                              english: 'Translate to English',
                              korean: '영어로 번역',
                            )
                          : isTranslationVisible
                          ? strings.text(
                              english: 'Hide translation',
                              korean: '번역 숨기기',
                            )
                          : strings.text(
                              english: 'Show translation',
                              korean: '번역 보기',
                            ),
                    ),
                  ),
                  if (translationError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        _chatTranslationErrorMessage(
                          translationError!,
                          strings,
                        ),
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

String _chatTranslationErrorMessage(Object error, RoleAwareStrings strings) {
  if (error is JobTranslationUnsupportedPlatformException) {
    return strings.text(
      english: 'On-device Korean-to-English translation is not supported on this device. The original message is unchanged.',
      korean: '이 기기에서는 한국어 메시지를 영어로 번역할 수 없습니다. 원본 메시지는 변경되지 않았습니다.',
    );
  }
  if (error is JobTranslationUnavailableException) {
    return strings.text(
      english: 'Translation is unavailable on this device. The original message is unchanged.',
      korean: '이 기기에서는 번역을 사용할 수 없습니다. 원본 메시지는 변경되지 않았습니다.',
    );
  }
  if (error is JobTranslationModelDownloadException) {
    return strings.text(
      english: 'Could not prepare the language resources. Check your connection and try again.',
      korean: '번역 리소스를 준비하지 못했습니다. 네트워크를 확인한 후 다시 시도해 주세요.',
    );
  }
  return strings.text(
    english: 'Could not translate this message. The original message is unchanged. Please try again.',
    korean: '메시지를 번역하지 못했습니다. 원본 메시지는 변경되지 않았습니다. 다시 시도해 주세요.',
  );
}

String _accessErrorMessage(Object? error, RoleAwareStrings strings) {
  if (error is ChatAccessException) {
    return strings.text(english: error.message, korean: error.koreanMessage);
  }
  if (error is FirebaseException && error.code == 'permission-denied') {
    return strings.text(
      english: 'You do not have permission to access this application chat.',
      korean: '이 지원서 채팅에 접근할 권한이 없습니다.',
    );
  }
  if (error is FirebaseException) {
    return strings.text(
      english:
          'A Firebase error occurred while opening chat. Please try again.',
      korean: '채팅을 여는 중 Firebase 오류가 발생했습니다. 다시 시도해 주세요.',
    );
  }
  return strings.text(
    english: 'Could not verify this application chat. Please try again.',
    korean: '지원서 채팅을 확인하지 못했습니다. 다시 시도해 주세요.',
  );
}

String _streamErrorMessage(Object? error, RoleAwareStrings strings) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return strings.text(
      english: 'You do not have permission to read these messages.',
      korean: '메시지를 읽을 권한이 없습니다.',
    );
  }
  if (error is FirebaseException) {
    return strings.text(
      english:
          'A Firebase error occurred while loading messages. Please try again.',
      korean: '메시지를 불러오는 중 Firebase 오류가 발생했습니다. 다시 시도해 주세요.',
    );
  }
  return strings.text(
    english: 'Could not load messages. Please try again.',
    korean: '메시지를 불러오지 못했습니다. 다시 시도해 주세요.',
  );
}

String _sendErrorMessage(Object error, RoleAwareStrings strings) {
  if (error is ChatValidationException) {
    return strings.text(english: error.message, korean: error.koreanMessage);
  }
  if (error is ChatAccessException) {
    return strings.text(english: error.message, korean: error.koreanMessage);
  }
  if (error is FirebaseException && error.code == 'permission-denied') {
    return strings.text(
      english: 'You do not have permission to send messages in this chat.',
      korean: '이 채팅에서 메시지를 보낼 권한이 없습니다.',
    );
  }
  if (error is FirebaseException) {
    return strings.text(
      english:
          'Could not send message. Please check your connection and try again.',
      korean: '메시지를 보내지 못했습니다. 네트워크를 확인한 후 다시 시도해 주세요.',
    );
  }
  return strings.text(
    english: 'Could not send message. Please try again.',
    korean: '메시지를 보내지 못했습니다. 다시 시도해 주세요.',
  );
}
