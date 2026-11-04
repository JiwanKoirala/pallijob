import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pallijob/screens/student/student_dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.role})
    : assert(role == 'Student' || role == 'Employer');

  final String role;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isRegistering = true;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _isRepairingProfile = false;

  bool get _isStudent => widget.role == 'Student';

  @override
  void dispose() {
    _fullNameController.dispose();
    _businessNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      appBar: AppBar(
        title: const Text(
          'PalliJob',
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 360 ? 20.0 : 28.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
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
                          _isRepairingProfile
                              ? 'Complete your profile'
                              : _isRegistering
                              ? 'Create your ${widget.role.toLowerCase()} account'
                              : 'Welcome back',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: const Color(0xFF173B27),
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isRepairingProfile
                              ? 'Your account is signed in. Add the details below to finish setting it up.'
                              : _isRegistering
                              ? 'A few details and you’re ready to get started.'
                              : 'Log in to continue to PalliJob.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: const Color(0xFF647369),
                                height: 1.45,
                              ),
                        ),
                        const SizedBox(height: 24),
                        if (!_isRepairingProfile) ...[
                          _ModeSelector(
                            isRegistering: _isRegistering,
                            isEnabled: !_isLoading,
                            onChanged: _setMode,
                          ),
                          const SizedBox(height: 24),
                        ],
                        if ((_isRegistering || _isRepairingProfile) &&
                            _isStudent)
                          _textField(
                            controller: _fullNameController,
                            label: 'Full name',
                            icon: Icons.person_outline,
                            textCapitalization: TextCapitalization.words,
                            validator: (value) => _required(value, 'Full name'),
                          ),
                        if ((_isRegistering || _isRepairingProfile) &&
                            !_isStudent) ...[
                          _textField(
                            controller: _businessNameController,
                            label: 'Business name',
                            icon: Icons.business_outlined,
                            textCapitalization: TextCapitalization.words,
                            validator: (value) =>
                                _required(value, 'Business name'),
                          ),
                          const SizedBox(height: 16),
                          _textField(
                            controller: _fullNameController,
                            label: 'Employer full name',
                            icon: Icons.person_outline,
                            textCapitalization: TextCapitalization.words,
                            validator: (value) =>
                                _required(value, 'Employer full name'),
                          ),
                        ],
                        if (!_isRepairingProfile) ...[
                          if (_isRegistering) const SizedBox(height: 16),
                          _textField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            textCapitalization: TextCapitalization.none,
                            autofillHints: const [AutofillHints.email],
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 16),
                          _textField(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_outline,
                            obscureText: !_isPasswordVisible,
                            autofillHints: [
                              _isRegistering
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            suffixIcon: IconButton(
                              tooltip: _isPasswordVisible
                                  ? 'Hide password'
                                  : 'Show password',
                              onPressed: () => setState(
                                () => _isPasswordVisible = !_isPasswordVisible,
                              ),
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                            validator: _validatePassword,
                          ),
                          if (_isRegistering) ...[
                            const SizedBox(height: 16),
                            _textField(
                              controller: _confirmPasswordController,
                              label: 'Confirm password',
                              icon: Icons.lock_outline,
                              obscureText: !_isConfirmPasswordVisible,
                              autofillHints: const [AutofillHints.newPassword],
                              suffixIcon: IconButton(
                                tooltip: _isConfirmPasswordVisible
                                    ? 'Hide password'
                                    : 'Show password',
                                onPressed: () => setState(
                                  () => _isConfirmPasswordVisible =
                                      !_isConfirmPasswordVisible,
                                ),
                                icon: Icon(
                                  _isConfirmPasswordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                              validator: _validateConfirmPassword,
                            ),
                          ],
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 56,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF247545),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF8DAF98),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isRegistering
                                        ? _isRepairingProfile
                                              ? 'Save profile'
                                              : 'Create account'
                                        : 'Log in',
                                  ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _isRepairingProfile
                              ? 'Your account is safe. You can retry saving your profile.'
                              : _isRegistering
                              ? 'By creating an account, you agree to use PalliJob responsibly.'
                              : 'Use the email address linked to your account.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF738078),
                                height: 1.4,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    List<String>? autofillHints,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isLoading,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      autofillHints: autofillHints,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF64816D)),
        suffixIcon: suffixIcon,
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
      ),
    );
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final requiredError = _required(value, 'Email');
    if (requiredError != null) return requiredError;

    final email = value!.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final requiredError = _required(value, 'Password');
    if (requiredError != null) return requiredError;
    if (_isRegistering && value!.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final requiredError = _required(value, 'Confirm password');
    if (requiredError != null) return requiredError;
    if (value != _passwordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  void _setMode(bool isRegistering) {
    if (_isLoading || _isRegistering == isRegistering) return;
    setState(() {
      _isRegistering = isRegistering;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final auth = FirebaseAuth.instance;
      final email = _emailController.text.trim().toLowerCase();

      if (_isRepairingProfile) {
        final user = auth.currentUser;
        if (user == null) {
          setState(() {
            _isRepairingProfile = false;
            _isRegistering = false;
          });
          _showMessage(
            'Your session expired. Log in to continue profile setup.',
          );
          return;
        }
        await _saveProfile(
          uid: user.uid,
          email: (user.email ?? email).trim().toLowerCase(),
          isNewProfile: false,
        );
        if (!mounted) return;
        _showSuccess(isRegistration: true, isProfileRepair: true);
        return;
      }

      if (_isRegistering) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: _passwordController.text,
        );
        final user = credential.user;
        if (user == null) {
          _showMessage(
            'Your account was created, but could not be loaded. Log in to finish setting up your profile.',
          );
          return;
        }

        try {
          await _saveProfile(uid: user.uid, email: email, isNewProfile: true);
        } on FirebaseException {
          if (!mounted) return;
          setState(() => _isRepairingProfile = true);
          _showMessage(
            'Your account was created, but its profile was not saved. You’re signed in; save your profile below to finish setup.',
          );
          return;
        }

        if (!mounted) return;
        _showSuccess(isRegistration: true);
        return;
      }

      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );
      final user = credential.user;
      if (user == null) {
        _showMessage('We could not load your account. Please log in again.');
        return;
      }

      DocumentSnapshot<Map<String, dynamic>> profile;
      try {
        profile = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
      } on FirebaseException {
        await auth.signOut();
        _showMessage(
          'We could not verify your account role. You have been logged out; please try again later.',
        );
        return;
      }

      if (!profile.exists) {
        setState(() {
          _isRegistering = true;
          _isRepairingProfile = true;
        });
        _showMessage(
          'You’re logged in, but your profile is incomplete. Add your details below to finish setup.',
        );
        return;
      }

      final expectedRole = _isStudent ? 'student' : 'employer';
      final savedRole = profile.data()?['role'];
      if (savedRole != expectedRole) {
        await auth.signOut();
        final selectedRole = _isStudent ? 'Student' : 'Employer';
        final savedRoleName = switch (savedRole) {
          'student' => 'Student',
          'employer' => 'Employer',
          _ => null,
        };
        _showMessage(
          savedRoleName == null
              ? 'This account has no valid role saved. You have been logged out; please contact support.'
              : 'This account is registered as a $savedRoleName. You have been logged out; log in using the $savedRoleName option instead of $selectedRole.',
        );
        return;
      }

      if (!mounted) return;
      _showSuccess(isRegistration: false);
    } on FirebaseAuthException catch (error) {
      _showMessage(_authErrorMessage(error));
    } on FirebaseException {
      _showMessage(
        _isRepairingProfile
            ? 'We could not save your profile. Your account is still available; check your connection and try again.'
            : 'We could not complete your request. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile({
    required String uid,
    required String email,
    required bool isNewProfile,
  }) async {
    final profile = <String, Object>{
      'role': _isStudent ? 'student' : 'employer',
      'fullName': _fullNameController.text.trim(),
      'email': email,
    };
    if (isNewProfile) {
      profile['createdAt'] = FieldValue.serverTimestamp();
    }
    if (!_isStudent) {
      profile['businessName'] = _businessNameController.text.trim();
    }
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set(profile, SetOptions(merge: true));
  }

  void _showSuccess({
    required bool isRegistration,
    bool isProfileRepair = false,
  }) {
    if (_isStudent) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const StudentDashboardScreen(),
        ),
        (_) => false,
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => _AuthSuccessScreen(
          role: widget.role,
          isRegistration: isRegistration,
          isProfileRepair: isProfileRepair,
        ),
      ),
    );
  }

  String _authErrorMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'email-already-in-use' => 'An account with this email already exists.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' =>
        'Choose a stronger password with at least 6 characters.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'The email or password is incorrect.',
      'network-request-failed' =>
        'Check your internet connection and try again.',
      'too-many-requests' => 'Too many attempts. Please wait and try again.',
      _ =>
        'We could not ${_isRegistering ? 'create your account' : 'log you in'}. Please try again.',
    };
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.isRegistering,
    required this.isEnabled,
    required this.onChanged,
  });

  final bool isRegistering;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF4EF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [_modeButton('Login', false), _modeButton('Register', true)],
      ),
    );
  }

  Widget _modeButton(String label, bool registerMode) {
    final selected = isRegistering == registerMode;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: TextButton(
            onPressed: isEnabled ? () => onChanged(registerMode) : null,
            style: TextButton.styleFrom(
              backgroundColor: selected ? Colors.white : Colors.transparent,
              foregroundColor: selected
                  ? const Color(0xFF247545)
                  : const Color(0xFF647369),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _AuthSuccessScreen extends StatelessWidget {
  const _AuthSuccessScreen({
    required this.role,
    required this.isRegistration,
    this.isProfileRepair = false,
  });

  final String role;
  final bool isRegistration;
  final bool isProfileRepair;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5F2E9),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF247545),
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isProfileRepair
                        ? 'Profile completed!'
                        : isRegistration
                        ? 'Account created!'
                        : 'You’re logged in!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF173B27),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your $role account is ready. More features are coming soon.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: const Color(0xFF647369), height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF247545),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
