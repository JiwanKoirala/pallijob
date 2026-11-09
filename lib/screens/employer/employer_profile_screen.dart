import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmployerProfile {
  const EmployerProfile({
    required this.fullName,
    required this.email,
    required this.companyName,
    required this.contactInfo,
  });

  final String? fullName;
  final String? email;
  final String companyName;
  final String contactInfo;
}

abstract interface class EmployerProfileService {
  Future<EmployerProfile> loadProfile();

  Future<void> saveProfile({
    required String companyName,
    required String contactInfo,
  });
}

class FirestoreEmployerProfileService implements EmployerProfileService {
  const FirestoreEmployerProfileService();

  @override
  Future<EmployerProfile> loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const EmployerProfileException(
        'Sign in with an employer account to view your profile.',
      );
    }

    final profile = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (profile.data()?['role'] != 'employer') {
      throw const EmployerProfileException(
        'Only employer accounts can view this profile.',
      );
    }
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw const EmployerProfileException(
        'Your session changed. Please sign in again.',
      );
    }

    final data = profile.data()!;
    return EmployerProfile(
      fullName: _optionalString(data['fullName']),
      email: _optionalString(data['email']),
      companyName: _stringValue(data['companyName']).isNotEmpty
          ? _stringValue(data['companyName'])
          : _stringValue(data['businessName']),
      contactInfo: _stringValue(data['contactInfo']),
    );
  }

  @override
  Future<void> saveProfile({
    required String companyName,
    required String contactInfo,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const EmployerProfileException(
        'Sign in with an employer account to save your profile.',
      );
    }

    final profileReference = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final profile = await profileReference.get();
    if (profile.data()?['role'] != 'employer') {
      throw const EmployerProfileException(
        'Only employer accounts can edit this profile.',
      );
    }
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw const EmployerProfileException(
        'Your session changed. Please sign in again.',
      );
    }

    await profileReference.update({
      'companyName': companyName,
      'contactInfo': contactInfo,
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

class EmployerProfileException implements Exception {
  const EmployerProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EmployerProfileScreen extends StatefulWidget {
  const EmployerProfileScreen({
    super.key,
    this.profileService = const FirestoreEmployerProfileService(),
  });

  final EmployerProfileService profileService;

  @override
  State<EmployerProfileScreen> createState() => _EmployerProfileScreenState();
}

class _EmployerProfileScreenState extends State<EmployerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _contactInfoController = TextEditingController();

  EmployerProfile? _profile;
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
    _companyNameController.dispose();
    _contactInfoController.dispose();
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
        _companyNameController.text = profile.companyName;
        _contactInfoController.text = profile.contactInfo;
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

    final companyName = _companyNameController.text.trim();
    final contactInfo = _contactInfoController.text.trim();
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await widget.profileService.saveProfile(
        companyName: companyName,
        contactInfo: contactInfo,
      );
      if (!mounted) return;
      setState(() {
        _profile = EmployerProfile(
          fullName: _profile?.fullName,
          email: _profile?.email,
          companyName: companyName,
          contactInfo: contactInfo,
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
            ? const _EmployerProfileState(
                loading: true,
                title: 'Loading profile',
                message: 'Please wait while we load your employer profile.',
              )
            : _loadError != null
            ? _EmployerProfileState(
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
                      'Your employer details',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: const Color(0xFF173B27),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Review your account information and keep your company profile up to date.',
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
                      value: 'Employer',
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      key: const ValueKey('employer-company-name'),
                      controller: _companyNameController,
                      enabled: !_isSaving,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Company name is required.'
                          : null,
                      onChanged: (_) => _clearSaveError(),
                      decoration: _inputDecoration(
                        label: 'Company name',
                        hint: 'Enter your company name',
                        icon: Icons.business_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('employer-contact-info'),
                      controller: _contactInfoController,
                      enabled: !_isSaving,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 2,
                      maxLines: 3,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Contact information is required.'
                          : null,
                      onChanged: (_) => _clearSaveError(),
                      decoration: _inputDecoration(
                        label: 'Contact information',
                        hint: 'Enter a contact email or phone number',
                        icon: Icons.contact_mail_outlined,
                        helperText: 'Provide a way for applicants to contact your company.',
                      ),
                    ),
                    if (_saveError != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBanner(message: _saveError!),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      key: const ValueKey('save-employer-profile'),
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
    if (error is EmployerProfileException) return error.message;
    if (error is FirebaseException && error.code == 'permission-denied') {
      return loading
          ? 'Firestore denied access to this profile. Confirm you are signed in as its owner.'
          : 'Firestore denied this update. Check that the rules allow employer profile fields.';
    }
    return loading
        ? 'We could not load your profile. Check your connection and try again.'
        : 'We could not save your profile. Check your connection and try again.';
  }
}

class _EmployerProfileState extends StatelessWidget {
  const _EmployerProfileState({
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
