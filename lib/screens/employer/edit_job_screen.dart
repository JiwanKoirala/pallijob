import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
          'Edit Job',
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
                          'Update job listing',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: const Color(0xFF173B27),
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Edit the details students see in your listing.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: const Color(0xFF647369),
                                height: 1.45,
                              ),
                        ),
                        const SizedBox(height: 24),
                        _textField(
                          controller: _titleController,
                          label: 'Job title',
                          icon: Icons.work_outline_rounded,
                        ),
                        const SizedBox(height: 16),
                        _textField(
                          controller: _descriptionController,
                          label: 'Description',
                          icon: Icons.subject_rounded,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 16),
                        _textField(
                          controller: _locationController,
                          label: 'Location',
                          icon: Icons.location_on_outlined,
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 16),
                        _textField(
                          controller: _requirementsController,
                          label: 'Requirements',
                          icon: Icons.checklist_rounded,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String?>(
                          key: const ValueKey('edit-job-work-type'),
                          initialValue: _selectedWorkType,
                          decoration: const InputDecoration(
                            labelText: 'Work type',
                            prefixIcon: Icon(Icons.work_outline_rounded),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Not specified'),
                            ),
                            ...jobWorkTypes.map(
                              (workType) => DropdownMenuItem<String?>(
                                value: workType,
                                child: Text(workType),
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
                            labelText: 'Schedule (optional)',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Not specified'),
                            ),
                            ...jobSchedules.map(
                              (schedule) => DropdownMenuItem<String?>(
                                value: schedule,
                                child: Text(schedule),
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
                                : const Text('Save Changes'),
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
          return '$label is required.';
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
        _showMessage(
          'You must be signed in as the job owner to edit this job.',
        );
        return;
      }

      final jobReference = FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.job.id);
      final jobSnapshot = await jobReference.get();
      if (!mounted) return;
      if (!jobSnapshot.exists) {
        _showMessage('This job no longer exists.');
        return;
      }
      if (jobSnapshot.data()?['employerId'] != user.uid ||
          widget.job.employerId != user.uid) {
        _showMessage('You can only edit jobs posted by your account.');
        return;
      }
      if (auth.currentUser?.uid != user.uid) {
        _showMessage('Your session expired. Please sign in again.');
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
        ..showSnackBar(
          const SnackBar(content: Text('Job updated successfully.')),
        );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showMessage(_firebaseErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _firebaseErrorMessage(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' => 'Firestore denied this update. Make sure the job belongs to your employer account and the edit rules are deployed.',
      'not-found' => 'This job no longer exists.',
      'unavailable' || 'network-request-failed' =>
        'Could not reach Firebase. Check your connection and try again.',
      _ =>
        'Could not update the job${error.message == null ? '.' : ': ${error.message}'}',
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
