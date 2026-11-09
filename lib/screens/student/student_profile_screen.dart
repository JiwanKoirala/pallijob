import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StudentProfile {
  const StudentProfile({
    required this.fullName,
    required this.email,
    required this.visaStatus,
    required this.languages,
  });

  final String? fullName;
  final String? email;
  final String visaStatus;
  final List<String> languages;
}

abstract interface class StudentProfileService {
  Future<StudentProfile> loadProfile();

  Future<void> saveProfile({
    required String visaStatus,
    required List<String> languages,
  });
}

class FirestoreStudentProfileService implements StudentProfileService {
  const FirestoreStudentProfileService();

  @override
  Future<StudentProfile> loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const StudentProfileException(
        'Sign in with a student account to view your profile.',
      );
    }

    final profile = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (profile.data()?['role'] != 'student') {
      throw const StudentProfileException(
        'Only student accounts can view this profile.',
      );
    }
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw const StudentProfileException(
        'Your session changed. Please sign in again.',
      );
    }

    final data = profile.data()!;
    final languagesValue = data['languages'];
    return StudentProfile(
      fullName: _optionalString(data['fullName']),
      email: _optionalString(data['email']),
      visaStatus: _stringValue(data['visaStatus']),
      languages: languagesValue is List
          ? languagesValue
                .whereType<String>()
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList()
          : const [],
    );
  }

  @override
  Future<void> saveProfile({
    required String visaStatus,
    required List<String> languages,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const StudentProfileException(
        'Sign in with a student account to save your profile.',
      );
    }

    final profileReference = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final profile = await profileReference.get();
    if (profile.data()?['role'] != 'student') {
      throw const StudentProfileException(
        'Only student accounts can edit this profile.',
      );
    }
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw const StudentProfileException(
        'Your session changed. Please sign in again.',
      );
    }

    await profileReference.update({
      'visaStatus': visaStatus,
      'languages': languages,
    });
  }

  static String _stringValue(Object? value) {
    return value is String ? value.trim() : '';
  }

  static String? _optionalString(Object? value) {
    final text = _stringValue(value);
    return text.isEmpty ? null : text;
  }
}

class StudentProfileException implements Exception {
  const StudentProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({
    super.key,
    this.profileService = const FirestoreStudentProfileService(),
  });

  final StudentProfileService profileService;

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _visaStatusController = TextEditingController();
  final _languagesController = TextEditingController();

  StudentProfile? _profile;
  String? _loadError;
  String? _saveError;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _visaStatusController.dispose();
    _languagesController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final profile = await widget.profileService.loadProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _visaStatusController.text = profile.visaStatus;
        _languagesController.text = profile.languages.join(', ');
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = _errorMessage(error, loading: true);
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final languages = _parseLanguages(_languagesController.text);
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await widget.profileService.saveProfile(
        visaStatus: _visaStatusController.text.trim(),
        languages: languages,
      );
      if (!mounted) return;
      setState(() {
        _profile = StudentProfile(
          fullName: _profile?.fullName,
          email: _profile?.email,
          visaStatus: _visaStatusController.text.trim(),
          languages: languages,
        );
        _isSaving = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Profile updated successfully.')),
        );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saveError = _errorMessage(error, loading: false);
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Color(0xFF173B27),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: const Color(0xFFF8FBF8),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const _ProfileState(
                loading: true,
                title: 'Loading profile',
                message: 'Please wait while we load your student profile.',
              )
            : _loadError != null
            ? _ProfileState(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load profile',
                message: _loadError!,
                action: TextButton(
                  onPressed: _loadProfile,
                  child: const Text('Retry'),
                ),
              )
            : _buildProfile(),
      ),
    );
  }

  Widget _buildProfile() {
    final profile = _profile!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 360 ? 20.0 : 28.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Your student details',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: const Color(0xFF173B27),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Review your account information and keep your profile up to date.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF647369),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _readOnlyCard(
                      context,
                      icon: Icons.person_outline_rounded,
                      label: 'Full name',
                      value: profile.fullName ?? 'Not provided',
                    ),
                    const SizedBox(height: 10),
                    _readOnlyCard(
                      context,
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: profile.email ?? 'Not provided',
                    ),
                    const SizedBox(height: 10),
                    _readOnlyCard(
                      context,
                      icon: Icons.verified_user_outlined,
                      label: 'Account type',
                      value: 'Student',
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      key: const ValueKey('student-visa-status'),
                      controller: _visaStatusController,
                      enabled: !_isSaving,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Visa status is required.'
                          : null,
                      onChanged: (_) => _clearSaveError(),
                      decoration: _inputDecoration(
                        label: 'Visa status',
                        hint: 'Enter your current visa status',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('student-languages'),
                      controller: _languagesController,
                      enabled: !_isSaving,
                      minLines: 2,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.words,
                      validator: _validateLanguages,
                      onChanged: (_) => _clearSaveError(),
                      decoration: _inputDecoration(
                        label: 'Languages',
                        hint: 'For example: English, Korean',
                        icon: Icons.language_rounded,
                        helperText: 'Separate each language with a comma.',
                      ),
                    ),
                    if (_saveError != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBanner(message: _saveError!),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      key: const ValueKey('save-student-profile'),
                      onPressed: _isSaving ? null : _saveProfile,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF247545),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _clearSaveError() {
    if (_saveError != null) setState(() => _saveError = null);
  }

  static String? _validateLanguages(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'At least one language is required.';
    }
    if (_parseLanguages(value).any((language) => language.isEmpty)) {
      return 'Enter a language for each comma-separated value.';
    }
    return null;
  }

  static List<String> _parseLanguages(String value) {
    return value.split(',').map((language) => language.trim()).toList();
  }

  static InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      prefixIcon: Icon(icon, color: const Color(0xFF64816D)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDCE8DF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDCE8DF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF247545), width: 1.5),
      ),
      errorMaxLines: 2,
    );
  }

  static Widget _readOnlyCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5EEE7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF247545)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: const Color(0xFF647369)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF173B27),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.lock_outline, color: Color(0xFF738078), size: 18),
          ],
        ),
      ),
    );
  }

  static String _errorMessage(Object error, {required bool loading}) {
    if (error is StudentProfileException) return error.message;
    if (error is FirebaseException && error.code == 'permission-denied') {
      return loading
          ? 'Firestore denied access to this profile. Confirm you are signed in as its owner.'
          : 'Firestore denied this update. Check that the rules allow student profile fields.';
    }
    return loading
        ? 'We could not load your profile. Check your connection and try again.'
        : 'We could not save your profile. Check your connection and try again.';
  }
}

class _ProfileState extends StatelessWidget {
  const _ProfileState({
    required this.title,
    required this.message,
    this.loading = false,
    this.icon,
    this.action,
  });

  final String title;
  final String message;
  final bool loading;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const CircularProgressIndicator(color: Color(0xFF247545))
              else
                Icon(
                  icon ?? Icons.info_outline_rounded,
                  color: const Color(0xFF247545),
                  size: 36,
                ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF173B27),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: const Color(0xFF647369), height: 1.45),
              ),
              if (action != null) ...[const SizedBox(height: 12), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF2C8BE)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: const Color(0xFF8A3020)),
      ),
    );
  }
}
