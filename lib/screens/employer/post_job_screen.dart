import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pallijob/l10n/role_aware_strings.dart';
import 'package:pallijob/screens/student/student_job_matching.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _requirementsController = TextEditingController();

  String? _selectedWorkType;
  String? _selectedSchedule;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _requirementsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      appBar: AppBar(
        title: const Text(
          '채용 공고 등록',
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
                16,
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
                          '채용 공고 작성',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: const Color(0xFF173B27),
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '학생에게 필요한 공고 정보를 입력해 주세요.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: const Color(0xFF647369),
                                height: 1.45,
                              ),
                        ),
                        const SizedBox(height: 24),
                        _textField(
                          controller: _titleController,
                          label: '공고 제목',
                          icon: Icons.work_outline_rounded,
                        ),
                        const SizedBox(height: 16),
                        _textField(
                          controller: _descriptionController,
                          label: '상세 설명',
                          icon: Icons.subject_rounded,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 16),
                        _textField(
                          controller: _locationController,
                          label: '근무 지역',
                          icon: Icons.location_on_outlined,
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 16),
                        _textField(
                          controller: _requirementsController,
                          label: '지원 요건',
                          icon: Icons.checklist_rounded,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          key: const ValueKey('post-job-work-type'),
                          initialValue: _selectedWorkType,
                          decoration: const InputDecoration(
                            labelText: '근무 형태',
                            prefixIcon: Icon(Icons.work_outline_rounded),
                          ),
                          items: jobWorkTypes
                              .map(
                                (workType) => DropdownMenuItem<String>(
                                  value: workType,
                                  child: Text(
                                    const RoleAwareStrings(isEmployer: true)
                                        .workType(workType),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          validator: (value) =>
                              value == null ? '근무 형태를 선택해 주세요.' : null,
                          onChanged: _isLoading
                              ? null
                              : (value) =>
                                    setState(() => _selectedWorkType = value),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String?>(
                          key: const ValueKey('post-job-schedule'),
                          initialValue: _selectedSchedule,
                          decoration: const InputDecoration(
                            labelText: '근무 일정 (선택)',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('선택 안 함'),
                            ),
                            ...jobSchedules.map(
                              (schedule) => DropdownMenuItem<String?>(
                                value: schedule,
                                child: Text(
                                  const RoleAwareStrings(isEmployer: true)
                                      .schedule(schedule),
                                ),
                              ),
                            ),
                          ],
                          onChanged: _isLoading
                              ? null
                              : (value) =>
                                    setState(() => _selectedSchedule = value),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF247545),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
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
                                : const Text('공고 등록'),
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
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isLoading,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      minLines: maxLines == 1 ? 1 : maxLines,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label은 필수 입력 항목입니다.';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: maxLines > 1,
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
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      if (user == null) {
        _showMessage('고용주 계정으로 로그인해 주세요.');
        return;
      }

      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      if (!profile.exists || profile.data()?['role'] != 'employer') {
        _showMessage('인증된 고용주 계정만 채용 공고를 등록할 수 있습니다.');
        return;
      }
      if (auth.currentUser?.uid != user.uid) {
        _showMessage('로그인 세션이 만료되었습니다. 다시 로그인해 주세요.');
        return;
      }

      await FirebaseFirestore.instance.collection('jobs').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'requirements': _requirementsController.text.trim(),
        'workType': _selectedWorkType!,
        if (_selectedSchedule != null) 'schedule': _selectedSchedule,
        'employerId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();
      _requirementsController.clear();
      setState(() {
        _selectedWorkType = null;
        _selectedSchedule = null;
      });
      _showMessage('채용 공고가 등록되었습니다.', isError: false);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showMessage(_firebaseErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _firebaseErrorMessage(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' =>
        '요청이 거부되었습니다. 배포된 Firestore 규칙에서 고용주 프로필 조회와 공고 등록이 허용되는지 확인해 주세요.',
      'unavailable' || 'network-request-failed' =>
        'Firebase에 연결할 수 없습니다. 네트워크를 확인한 후 다시 시도해 주세요.',
      _ => '공고를 등록하지 못했습니다. 다시 시도해 주세요.',
    };
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFF9B2C2C) : null,
        ),
      );
  }
}
