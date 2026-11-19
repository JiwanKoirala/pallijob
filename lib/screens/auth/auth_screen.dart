import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pallijob/l10n/role_aware_strings.dart';
import 'package:pallijob/screens/employer/employer_dashboard_screen.dart';
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
  RoleAwareStrings get _strings => RoleAwareStrings(isEmployer: !_isStudent);

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
    final strings = RoleAwareStrings(isEmployer: !_isStudent);
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
                          strings.text(
                            english: _isRepairingProfile
                                ? 'Complete your profile'
                                : _isRegistering
                                ? 'Create your ${widget.role.toLowerCase()} account'
                                : 'Welcome back',
                            korean: _isRepairingProfile
                                ? '프로필을 완성해 주세요'
                                : _isRegistering
                                ? '고용주 계정 만들기'
                                : '다시 오신 것을 환영합니다',
                          ),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: const Color(0xFF173B27),
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.text(
                            english: _isRepairingProfile
                                ? 'Your account is signed in. Add the details below to finish setting it up.'
                                : _isRegistering
                                ? 'A few details and you’re ready to get started.'
                                : 'Log in to continue to PalliJob.',
                            korean: _isRepairingProfile
                                ? '아래 정보를 입력해 계정 설정을 완료해 주세요.'
                                : _isRegistering
                                ? '몇 가지 정보를 입력하고 PalliJob을 시작해 보세요.'
                                : '로그인하여 PalliJob을 이용해 주세요.',
                          ),
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
                            loginLabel: strings.text(
                              english: 'Login',
                              korean: '로그인',
                            ),
                            registerLabel: strings.text(
                              english: 'Register',
                              korean: '회원가입',
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if ((_isRegistering || _isRepairingProfile) &&
                            _isStudent)
                          _textField(
                            controller: _fullNameController,
                            label: strings.text(
                              english: 'Full name',
                              korean: '성함',
                            ),
                            icon: Icons.person_outline,
                            textCapitalization: TextCapitalization.words,
                            validator: (value) => _required(
                              value,
                              strings.text(english: 'Full name', korean: '성함'),
                            ),
                          ),
                        if ((_isRegistering || _isRepairingProfile) &&
                            !_isStudent) ...[
                          _textField(
                            controller: _businessNameController,
                            label: strings.text(
                              english: 'Business name',
                              korean: '회사명',
                            ),
                            icon: Icons.business_outlined,
                            textCapitalization: TextCapitalization.words,
                            validator: (value) => _required(
                              value,
                              strings.text(
                                english: 'Business name',
                                korean: '회사명',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _textField(
                            controller: _fullNameController,
                            label: strings.text(
                              english: 'Employer full name',
                              korean: '담당자 성함',
                            ),
                            icon: Icons.person_outline,
                            textCapitalization: TextCapitalization.words,
                            validator: (value) => _required(
                              value,
                              strings.text(
                                english: 'Employer full name',
                                korean: '담당자 성함',
                              ),
                            ),
                          ),
                        ],
                        if (!_isRepairingProfile) ...[
                          if (_isRegistering) const SizedBox(height: 16),
                          _textField(
                            controller: _emailController,
                            label: strings.text(
                              english: 'Email',
                              korean: '이메일',
                            ),
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            textCapitalization: TextCapitalization.none,
                            autofillHints: const [AutofillHints.email],
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 16),
                          _textField(
                            controller: _passwordController,
                            label: strings.text(
                              english: 'Password',
                              korean: '비밀번호',
                            ),
                            icon: Icons.lock_outline,
                            obscureText: !_isPasswordVisible,
                            autofillHints: [
                              _isRegistering
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            suffixIcon: IconButton(
                              tooltip: _isPasswordVisible
                                  ? strings.text(
                                      english: 'Hide password',
                                      korean: '비밀번호 숨기기',
                                    )
                                  : strings.text(
                                      english: 'Show password',
                                      korean: '비밀번호 표시',
                                    ),
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
                              label: strings.text(
                                english: 'Confirm password',
                                korean: '비밀번호 확인',
                              ),
                              icon: Icons.lock_outline,
                              obscureText: !_isConfirmPasswordVisible,
                              autofillHints: const [AutofillHints.newPassword],
                              suffixIcon: IconButton(
                                tooltip: _isConfirmPasswordVisible
                                    ? strings.text(
                                        english: 'Hide password',
                                        korean: '비밀번호 숨기기',
                                      )
                                    : strings.text(
                                        english: 'Show password',
                                        korean: '비밀번호 표시',
                                      ),
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
                                              ? strings.text(
                                                  english: 'Save profile',
                                                  korean: '프로필 저장',
                                                )
                                              : strings.text(
                                                  english: 'Create account',
                                                  korean: '계정 만들기',
                                                )
                                        : strings.text(
                                            english: 'Log in',
                                            korean: '로그인',
                                          ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          strings.text(
                            english: _isRepairingProfile
                                ? 'Your account is safe. You can retry saving your profile.'
                                : _isRegistering
                                ? 'By creating an account, you agree to use PalliJob responsibly.'
                                : 'Use the email address linked to your account.',
                            korean: _isRepairingProfile
                                ? '계정은 안전합니다. 프로필 저장을 다시 시도할 수 있습니다.'
                                : _isRegistering
                                ? '계정을 만들면 PalliJob을 책임감 있게 이용하는 데 동의하게 됩니다.'
                                : '계정에 등록된 이메일 주소를 입력해 주세요.',
                          ),
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
      final lastCharacter = label.runes.last;
      final hasFinalConsonant =
          lastCharacter >= 0xAC00 &&
          lastCharacter <= 0xD7A3 &&
          (lastCharacter - 0xAC00) % 28 != 0;
      return _strings.text(
        english: '$label is required.',
        korean: '$label${hasFinalConsonant ? '은' : '는'} 필수 입력 항목입니다.',
      );
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final requiredError = _required(
      value,
      _strings.text(english: 'Email', korean: '이메일'),
    );
    if (requiredError != null) return requiredError;

    final email = value!.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return _strings.text(
        english: 'Enter a valid email address.',
        korean: '올바른 이메일 주소를 입력해 주세요.',
      );
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final requiredError = _required(
      value,
      _strings.text(english: 'Password', korean: '비밀번호'),
    );
    if (requiredError != null) return requiredError;
    if (_isRegistering && value!.length < 6) {
      return _strings.text(
        english: 'Password must be at least 6 characters.',
        korean: '비밀번호는 6자 이상이어야 합니다.',
      );
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final requiredError = _required(
      value,
      _strings.text(english: 'Confirm password', korean: '비밀번호 확인'),
    );
    if (requiredError != null) return requiredError;
    if (value != _passwordController.text) {
      return _strings.text(
        english: 'Passwords do not match.',
        korean: '비밀번호가 일치하지 않습니다.',
      );
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
            _strings.text(
              english:
                  'Your session expired. Log in to continue profile setup.',
              korean: '로그인 세션이 만료되었습니다. 다시 로그인하여 프로필 설정을 완료해 주세요.',
            ),
          );
          return;
        }
        await _saveProfile(
          uid: user.uid,
          email: (user.email ?? email).trim().toLowerCase(),
          isNewProfile: false,
        );
        if (!mounted) return;
        _showSuccess();
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
            _strings.text(
              english: 'Your account was created, but could not be loaded. Log in to finish setting up your profile.',
              korean: '계정이 생성되었지만 계정 정보를 불러오지 못했습니다. 다시 로그인하여 프로필 설정을 완료해 주세요.',
            ),
          );
          return;
        }

        try {
          await _saveProfile(uid: user.uid, email: email, isNewProfile: true);
        } on FirebaseException {
          if (!mounted) return;
          setState(() => _isRepairingProfile = true);
          _showMessage(
            _strings.text(
              english: 'Your account was created, but its profile was not saved. You’re signed in; save your profile below to finish setup.',
              korean: '계정은 생성되었지만 프로필을 저장하지 못했습니다. 로그인된 상태이므로 아래에서 프로필을 저장해 설정을 완료해 주세요.',
            ),
          );
          return;
        }

        if (!mounted) return;
        _showSuccess();
        return;
      }

      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );
      final user = credential.user;
      if (user == null) {
        _showMessage(
          _strings.text(
            english: 'We could not load your account. Please log in again.',
            korean: '계정 정보를 불러오지 못했습니다. 다시 로그인해 주세요.',
          ),
        );
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
          _strings.text(
            english: 'We could not verify your account role. You have been logged out; please try again later.',
            korean: '계정 유형을 확인하지 못해 로그아웃되었습니다. 잠시 후 다시 시도해 주세요.',
          ),
        );
        return;
      }

      if (!profile.exists) {
        setState(() {
          _isRegistering = true;
          _isRepairingProfile = true;
        });
        _showMessage(
          _strings.text(
            english: 'You’re logged in, but your profile is incomplete. Add your details below to finish setup.',
            korean: '로그인되었지만 프로필 설정이 완료되지 않았습니다. 아래 정보를 입력해 설정을 마무리해 주세요.',
          ),
        );
        return;
      }

      final expectedRole = _isStudent ? 'student' : 'employer';
      final savedRole = profile.data()?['role'];
      if (savedRole != expectedRole) {
        await auth.signOut();
        final selectedRole = _strings.text(
          english: _isStudent ? 'Student' : 'Employer',
          korean: _isStudent ? 'Student' : '고용주',
        );
        final savedRoleName = switch (savedRole) {
          'student' => _strings.text(english: 'Student', korean: '학생'),
          'employer' => _strings.text(english: 'Employer', korean: '고용주'),
          _ => null,
        };
        _showMessage(
          savedRoleName == null
              ? _strings.text(
                  english: 'This account has no valid role saved. You have been logged out; please contact support.',
                  korean: '계정 유형이 올바르지 않아 로그아웃되었습니다. 고객 지원에 문의해 주세요.',
                )
              : _strings.text(
                  english:
                      'This account is registered as a $savedRoleName. You have been logged out; log in using the $savedRoleName option instead of $selectedRole.',
                  korean:
                      '이 계정은 $savedRoleName 계정입니다. 로그아웃되었습니다. $selectedRole 옵션이 아닌 $savedRoleName 옵션으로 로그인해 주세요.',
                ),
        );
        return;
      }

      if (!mounted) return;
      _showSuccess();
    } on FirebaseAuthException catch (error) {
      _showMessage(_authErrorMessage(error));
    } on FirebaseException {
      _showMessage(
        _strings.text(
          english: _isRepairingProfile
              ? 'We could not save your profile. Your account is still available; check your connection and try again.'
              : 'We could not complete your request. Please try again.',
          korean: _isRepairingProfile
              ? '프로필을 저장하지 못했지만 계정은 사용할 수 있습니다. 네트워크를 확인한 후 다시 시도해 주세요.'
              : '요청을 완료하지 못했습니다. 다시 시도해 주세요.',
        ),
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

  void _showSuccess() {
    if (_isStudent) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const StudentDashboardScreen()),
        (_) => false,
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const EmployerDashboardScreen()),
      (_) => false,
    );
  }

  String _authErrorMessage(FirebaseAuthException error) {
    final english = switch (error.code) {
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
    final korean = switch (error.code) {
      'email-already-in-use' => '이미 사용 중인 이메일 주소입니다.',
      'invalid-email' => '올바른 이메일 주소를 입력해 주세요.',
      'weak-password' => '6자 이상의 안전한 비밀번호를 설정해 주세요.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => '이메일 또는 비밀번호가 올바르지 않습니다.',
      'network-request-failed' => '네트워크에 연결할 수 없습니다. 연결 상태를 확인해 주세요.',
      'too-many-requests' => '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.',
      _ =>
        _isRegistering
            ? '계정을 만들지 못했습니다. 다시 시도해 주세요.'
            : '로그인하지 못했습니다. 다시 시도해 주세요.',
    };
    return _strings.text(english: english, korean: korean);
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
    required this.loginLabel,
    required this.registerLabel,
  });

  final bool isRegistering;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;
  final String loginLabel;
  final String registerLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF4EF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _modeButton(loginLabel, false),
          _modeButton(registerLabel, true),
        ],
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
