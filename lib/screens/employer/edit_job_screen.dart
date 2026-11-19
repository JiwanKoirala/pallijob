import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pallijob/l10n/role_aware_strings.dart';
import 'package:pallijob/screens/student/student_job_matching.dart';
import 'package:pallijob/screens/student/student_job_listings_screen.dart';

class EditJobScreen extends StatefulWidget {
  const EditJobScreen({super.key, required this.job});

  final StudentJobListing job;

  @override
  State<EditJobScreen> createState() => _EditJobScreenState();
}

class _EditJobScreenState extends State<EditJobScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(text: widget.job.title);
  late final _descriptionController = TextEditingController(
    text: widget.job.description,
  );
  late final _locationController = TextEditingController(
    text: widget.job.location,
  );
  late final _requirementsController = TextEditingController(
    text: widget.job.requirements,
  );

  late String? _selectedWorkType = jobWorkTypes.contains(widget.job.workType)
      ? widget.job.workType
      : null;
  late String? _selectedSchedule = jobSchedules.contains(widget.job.schedule)
      ? widget.job.schedule
      : null;
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
          '공고 수정',
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
                          '채용 공고 수정',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: const Color(0xFF173B27),
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '학생에게 표시되는 공고 정보를 수정합니다.',
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
                        DropdownButtonFormField<String?>(
                          key: const ValueKey('edit-job-work-type'),
                          initialValue: _selectedWorkType,
                          decoration: const InputDecoration(
                            labelText: '근무 형태',
                            prefixIcon: Icon(Icons.work_outline_rounded),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('선택 안 함'),
                            ),
                            ...jobWorkTypes.map(
                              (workType) => DropdownMenuItem<String?>(
                                value: workType,
                                child: Text(
                                  const RoleAwareStrings(isEmployer: true)
                                      .workType(workType),
                                ),
                              ),
                            ),
                          ],
                          onChanged: _isLoading
                              ? null
                              : (value) =>
                                    setState(() => _selectedWorkType = value),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String?>(
                          key: const ValueKey('edit-job-schedule'),
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
                                : const Text('변경 사항 저장'),
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
      key: ValueKey('edit-job-${label.toLowerCase().replaceAll(' ', '-')}'),
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
        _showMessage('공고 소유자 계정으로 로그인해 주세요.');
        return;
      }

      final jobReference = FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.job.id);
      final jobSnapshot = await jobReference.get();
      if (!mounted) return;
      if (!jobSnapshot.exists) {
        _showMessage('이 채용 공고는 더 이상 존재하지 않습니다.');
        return;
      }
      if (jobSnapshot.data()?['employerId'] != user.uid ||
          widget.job.employerId != user.uid) {
        _showMessage('내 계정으로 등록한 공고만 수정할 수 있습니다.');
        return;
      }
      if (auth.currentUser?.uid != user.uid) {
        _showMessage('로그인 세션이 만료되었습니다. 다시 로그인해 주세요.');
        return;
      }

      await jobReference.update({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'requirements': _requirementsController.text.trim(),
        'workType': _selectedWorkType ?? FieldValue.delete(),
        'schedule': _selectedSchedule ?? FieldValue.delete(),
      });

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('채용 공고가 수정되었습니다.')));
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
        '수정 권한이 없습니다. 내 계정으로 등록한 공고인지, 공고 수정 규칙이 배포되었는지 확인해 주세요.',
      'not-found' => '이 채용 공고는 더 이상 존재하지 않습니다.',
      'unavailable' || 'network-request-failed' =>
        'Firebase에 연결할 수 없습니다. 네트워크를 확인한 후 다시 시도해 주세요.',
      _ => '공고를 수정하지 못했습니다. 다시 시도해 주세요.',
    };
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF9B2C2C),
        ),
      );
  }
}
