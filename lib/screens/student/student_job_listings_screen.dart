import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pallijob/screens/student/job_application_service.dart';
import 'package:pallijob/screens/student/job_translation_service.dart';
import 'package:pallijob/screens/student/student_visa_eligibility_screen.dart';

const jobWorkTypes = <String>['Part-time', 'Full-time', 'Temporary/Contract'];
const jobSchedules = <String>['Weekdays', 'Weekends', 'Flexible'];

class StudentJobListingsScreen extends StatefulWidget {
  const StudentJobListingsScreen({
    super.key,
    this.jobsStream,
    this.applicationService = const FirestoreJobApplicationService(),
  });

  final Stream<List<StudentJobListing>>? jobsStream;
  final JobApplicationService applicationService;

  @override
  State<StudentJobListingsScreen> createState() =>
      _StudentJobListingsScreenState();
}

class _StudentJobListingsScreenState extends State<StudentJobListingsScreen> {
  late final Stream<List<StudentJobListing>> _jobsStream =
      widget.jobsStream ?? _watchJobs();
  final _searchController = TextEditingController();

  static const _allLocations = 'All Locations';
  static const _allWorkTypes = 'All Types';
  static const _allSchedules = 'All Schedules';

  String _searchQuery = '';
  String _selectedLocation = _allLocations;
  String _selectedWorkType = _allWorkTypes;
  String _selectedSchedule = _allSchedules;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<StudentJobListing>> _watchJobs() {
    return FirebaseFirestore.instance
        .collection('jobs')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(StudentJobListing.fromDocument)
              .toList(growable: false),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      appBar: AppBar(
        title: const Text(
          'Search Jobs',
          style: TextStyle(
            color: Color(0xFF173B27),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: const Color(0xFFF8FBF8),
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<List<StudentJobListing>>(
        stream: _jobsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ListingsState(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load jobs',
              message: _errorMessage(snapshot.error),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _ListingsState(
              loading: true,
              title: 'Loading jobs',
              message: 'Please wait while we load available listings.',
            );
          }

          final jobs = snapshot.data ?? const <StudentJobListing>[];
          if (jobs.isEmpty) {
            return const _ListingsState(
              icon: Icons.work_outline_rounded,
              title: 'No jobs available yet',
              message: 'Please check back later for new opportunities.',
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth < 360
                  ? 20.0
                  : 28.0;
              final locations = _locationsFor(jobs);
              final selectedLocation = locations.contains(_selectedLocation)
                  ? _selectedLocation
                  : _allLocations;
              final selectedWorkType =
                  _selectedWorkType == _allWorkTypes ||
                      jobWorkTypes.contains(_selectedWorkType)
                  ? _selectedWorkType
                  : _allWorkTypes;
              final selectedSchedule =
                  _selectedSchedule == _allSchedules ||
                      jobSchedules.contains(_selectedSchedule)
                  ? _selectedSchedule
                  : _allSchedules;
              final normalizedQuery = _searchQuery.trim().toLowerCase();
              final filteredJobs = jobs
                  .where((job) {
                    final matchesSearch =
                        normalizedQuery.isEmpty ||
                        job.title.toLowerCase().contains(normalizedQuery) ||
                        job.location.toLowerCase().contains(normalizedQuery);
                    final matchesLocation =
                        selectedLocation == _allLocations ||
                        job.location.trim().toLowerCase() ==
                            selectedLocation.toLowerCase();
                    final matchesWorkType =
                        selectedWorkType == _allWorkTypes ||
                        job.workType == selectedWorkType;
                    final matchesSchedule =
                        selectedSchedule == _allSchedules ||
                        job.schedule == selectedSchedule;
                    return matchesSearch &&
                        matchesLocation &&
                        matchesWorkType &&
                        matchesSchedule;
                  })
                  .toList(growable: false);

              return ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  20,
                  horizontalPadding,
                  32,
                ),
                itemCount: filteredJobs.isEmpty ? 1 : filteredJobs.length + 1,
                separatorBuilder: (_, index) =>
                    SizedBox(height: index == 0 ? 16 : 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Available jobs',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: const Color(0xFF173B27),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const ValueKey('job-search-field'),
                              controller: _searchController,
                              textInputAction: TextInputAction.search,
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value),
                              decoration: InputDecoration(
                                labelText: 'Search by title or location',
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: Color(0xFF64816D),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFDCE8DF),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFDCE8DF),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF247545),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: const ValueKey('job-location-filter'),
                              initialValue: selectedLocation,
                              decoration: InputDecoration(
                                labelText: 'Location',
                                prefixIcon: const Icon(
                                  Icons.location_on_outlined,
                                  color: Color(0xFF64816D),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFDCE8DF),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFDCE8DF),
                                  ),
                                ),
                              ),
                              items: [_allLocations, ...locations]
                                  .map((location) {
                                    return DropdownMenuItem(
                                      value: location,
                                      child: Text(location),
                                    );
                                  })
                                  .toList(growable: false),
                              onChanged: (location) {
                                if (location != null) {
                                  setState(() => _selectedLocation = location);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: const ValueKey('job-work-type-filter'),
                              initialValue: selectedWorkType,
                              decoration: InputDecoration(
                                labelText: 'Work type',
                                prefixIcon: const Icon(
                                  Icons.work_outline_rounded,
                                  color: Color(0xFF64816D),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFDCE8DF),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFDCE8DF),
                                  ),
                                ),
                              ),
                              items: [_allWorkTypes, ...jobWorkTypes]
                                  .map(
                                    (workType) => DropdownMenuItem(
                                      value: workType,
                                      child: Text(workType),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (workType) {
                                if (workType != null) {
                                  setState(() => _selectedWorkType = workType);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: const ValueKey('job-schedule-filter'),
                              initialValue: selectedSchedule,
                              decoration: InputDecoration(
                                labelText: 'Schedule',
                                prefixIcon: const Icon(
                                  Icons.calendar_today_outlined,
                                  color: Color(0xFF64816D),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFDCE8DF),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFDCE8DF),
                                  ),
                                ),
                              ),
                              items: [_allSchedules, ...jobSchedules]
                                  .map(
                                    (schedule) => DropdownMenuItem(
                                      value: schedule,
                                      child: Text(schedule),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (schedule) {
                                if (schedule != null) {
                                  setState(() => _selectedSchedule = schedule);
                                }
                              },
                            ),
                            if (_searchQuery.trim().isNotEmpty ||
                                selectedLocation != _allLocations ||
                                selectedWorkType != _allWorkTypes ||
                                selectedSchedule != _allSchedules) ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  key: const ValueKey('clear-job-filters'),
                                  onPressed: _clearFilters,
                                  icon: const Icon(Icons.clear_all_rounded),
                                  label: const Text('Clear filters'),
                                ),
                              ),
                            ],
                            if (filteredJobs.isEmpty) ...[
                              const SizedBox(height: 32),
                              const _ListingsState(
                                icon: Icons.search_off_rounded,
                                title: 'No matching jobs',
                                message: 'Try changing or clearing your search and filters.',
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  final job = filteredJobs[index - 1];
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: _JobCard(
                        job: job,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StudentJobDetailsScreen(
                              job: job,
                              applicationService: widget.applicationService,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  List<String> _locationsFor(List<StudentJobListing> jobs) {
    final locationsByKey = <String, String>{};
    for (final job in jobs) {
      final location = job.location.trim();
      if (location.isEmpty || location == 'Not provided') continue;
      locationsByKey.putIfAbsent(location.toLowerCase(), () => location);
    }

    final locations = locationsByKey.values.toList()..sort();
    return locations;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedLocation = _allLocations;
      _selectedWorkType = _allWorkTypes;
      _selectedSchedule = _allSchedules;
    });
  }

  String _errorMessage(Object? error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'You do not have permission to view job listings. Sign in with a valid account and make sure the Firestore job read rules are deployed.';
    }
    if (error is FirebaseException &&
        (error.code == 'unavailable' ||
            error.code == 'network-request-failed')) {
      return 'Check your internet connection and try again.';
    }
    return 'Something went wrong while loading jobs. Please try again later.';
  }
}

class StudentJobListing {
  const StudentJobListing({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.requirements,
    required this.employerId,
    required this.createdAt,
    this.workType,
    this.schedule,
  });

  factory StudentJobListing.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return StudentJobListing(
      id: document.id,
      title: _readText(data, 'title', fallback: 'Untitled job'),
      description: _readText(data, 'description'),
      location: _readText(data, 'location'),
      requirements: _readText(data, 'requirements'),
      employerId: _readText(data, 'employerId'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      workType: _readOptionalText(data, 'workType'),
      schedule: _readOptionalText(data, 'schedule'),
    );
  }

  final String id;
  final String title;
  final String description;
  final String location;
  final String requirements;
  final String employerId;
  final DateTime? createdAt;
  final String? workType;
  final String? schedule;

  static String? _readOptionalText(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static String _readText(
    Map<String, dynamic> data,
    String key, {
    String fallback = 'Not provided',
  }) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) return fallback;
    return value;
  }
}

class StudentJobDetailsScreen extends StatefulWidget {
  const StudentJobDetailsScreen({
    super.key,
    required this.job,
    this.applicationService = const FirestoreJobApplicationService(),
    this.visaGuidanceService = const FirestoreStudentVisaGuidanceService(),
    this.translationService = const PlatformJobTranslationService(),
  });

  final StudentJobListing job;
  final JobApplicationService applicationService;
  final StudentVisaGuidanceService visaGuidanceService;
  final JobTranslationService translationService;

  @override
  State<StudentJobDetailsScreen> createState() =>
      _StudentJobDetailsScreenState();
}

class _StudentJobDetailsScreenState extends State<StudentJobDetailsScreen> {
  late Future<JobApplicationStatus> _applicationStatus;
  bool _isSubmitting = false;
  bool _showEnglish = false;
  bool _isTranslating = false;
  bool _translationRequested = false;
  TranslatedJobContent? _translatedContent;
  Object? _translationError;
  JobTranslationProgress _translationProgress =
      JobTranslationProgress.checkingModels;

  @override
  void initState() {
    super.initState();
    _applicationStatus = widget.applicationService.getStatus(widget.job.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      appBar: AppBar(
        title: const Text(
          'Job Details',
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
                20,
                horizontalPadding,
                32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _displayContent(
                          JobInformationField.title,
                          widget.job.title,
                        ),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: const Color(0xFF173B27),
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF247545),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.job.location,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: const Color(0xFF647369)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _JobDetailSection(
                        title: 'Work type',
                        content: widget.job.workType ?? 'Not specified',
                      ),
                      const SizedBox(height: 12),
                      _JobDetailSection(
                        title: 'Schedule',
                        content: widget.job.schedule ?? 'Not specified',
                      ),
                      const SizedBox(height: 24),
                      SegmentedButton<bool>(
                        key: const ValueKey('job-language-toggle'),
                        segments: const [
                          ButtonSegment<bool>(
                            value: false,
                            label: Text('Original'),
                            icon: Icon(Icons.article_outlined),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            label: Text('English'),
                            icon: Icon(Icons.translate_rounded),
                          ),
                        ],
                        selected: {_showEnglish},
                        onSelectionChanged: (selection) {
                          final showEnglish = selection.first;
                          setState(() => _showEnglish = showEnglish);
                          if (showEnglish) _requestTranslation();
                        },
                      ),
                      if (_showEnglish) ...[
                        const SizedBox(height: 12),
                        _translationStatus(),
                      ],
                      const SizedBox(height: 18),
                      _JobDetailSection(
                        title: 'Description',
                        content: _displayContent(
                          JobInformationField.description,
                          widget.job.description,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _JobDetailSection(
                        title: 'Requirements',
                        content: _displayContent(
                          JobInformationField.requirements,
                          widget.job.requirements,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _JobDetailSection(
                        title: 'Employer ID',
                        content: widget.job.employerId,
                      ),
                      const SizedBox(height: 16),
                      _JobDetailSection(
                        title: 'Posted',
                        content: _formatDate(widget.job.createdAt),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        key: const ValueKey('check-visa-eligibility'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StudentVisaEligibilityScreen(
                              jobId: widget.job.id,
                              guidanceService: widget.visaGuidanceService,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.info_outline_rounded),
                        label: const Text('Check Visa Eligibility'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF247545),
                          side: const BorderSide(color: Color(0xFF247545)),
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _applyButton(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _requestTranslation({bool retry = false}) async {
    if (_isTranslating || (_translationRequested && !retry)) return;

    final content = <JobInformationField, String>{};
    for (final entry in {
      JobInformationField.title: widget.job.title,
      JobInformationField.description: widget.job.description,
      JobInformationField.requirements: widget.job.requirements,
    }.entries) {
      final value = entry.value.trim();
      if (value.isNotEmpty &&
          value != 'Not provided' &&
          value != 'Untitled job') {
        content[entry.key] = value;
      }
    }

    setState(() {
      _translationRequested = true;
      _isTranslating = true;
      _translationProgress = JobTranslationProgress.checkingModels;
      _translationError = content.isEmpty
          ? const JobTranslationContentMissingException()
          : null;
      _translatedContent = null;
    });
    if (content.isEmpty) {
      setState(() => _isTranslating = false);
      return;
    }

    try {
      final result = await widget.translationService.translate(
        JobTranslationRequest(originalContent: Map.unmodifiable(content)),
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _translationProgress = progress);
        },
      );
      for (final entry in content.entries) {
        final translated = result.content[entry.key]?.trim();
        if (translated == null ||
            translated.isEmpty ||
            (translated == entry.value && _containsKorean(entry.value))) {
          throw const JobTranslationIncompleteException();
        }
      }
      if (!mounted) return;
      setState(() {
        _translatedContent = result;
        _isTranslating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _translationError = error;
        _isTranslating = false;
      });
    }
  }

  String _displayContent(JobInformationField field, String original) {
    if (!_showEnglish || _isTranslating || _translationError != null) {
      return original;
    }
    return _translatedContent?.content[field]?.trim() ?? original;
  }

  Widget _translationStatus() {
    if (_isTranslating) {
      final message = switch (_translationProgress) {
        JobTranslationProgress.checkingModels =>
          'Checking for downloaded Korean and English models...',
        JobTranslationProgress.downloadingModels => 'Preparing language models. Internet may be required the first time; models use device storage.',
        JobTranslationProgress.translating => 'Translating on your device...',
      };
      return Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF247545),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      );
    }

    final error = _translationError;
    if (error is JobTranslationUnavailableException) {
      return _TranslationMessage(
        message: 'English translation is unavailable until a translation provider is selected and securely integrated. Original job information is shown below.',
      );
    }
    if (error is JobTranslationUnsupportedPlatformException) {
      return const _TranslationMessage(
        message: 'Translation unavailable on this device. Apple Translation requires a supported iOS version and device; Android uses on-device translation. Original information is shown below.',
      );
    }
    if (error is JobTranslationModelDownloadException) {
      return _TranslationMessage(
        message: 'Could not prepare the Korean and English translation resources. Check your internet connection and allow language downloads, then try again. First setup may need internet and uses device storage; downloaded resources are reused later.',
        action: TextButton(
          onPressed: () => _requestTranslation(retry: true),
          child: const Text('Try again'),
        ),
      );
    }
    if (error is JobTranslationContentMissingException) {
      return const _TranslationMessage(
        message: 'There is no job title, description, or requirements content available to translate. Original information is shown below.',
      );
    }
    if (error != null) {
      return _TranslationMessage(
        message: 'We could not translate all job information. Original information is shown below.',
        action: TextButton(
          onPressed: () => _requestTranslation(retry: true),
          child: const Text('Try again'),
        ),
      );
    }
    if (_translatedContent != null) {
      return const _TranslationMessage(
        message: 'English translation. The original listing is unchanged. Language resources are stored on this device and may be reused offline.',
      );
    }
    return const SizedBox.shrink();
  }

  @override
  void didUpdateWidget(covariant StudentJobDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.job.id != widget.job.id) {
      _showEnglish = false;
      _isTranslating = false;
      _translationRequested = false;
      _translatedContent = null;
      _translationError = null;
      _translationProgress = JobTranslationProgress.checkingModels;
      _applicationStatus = widget.applicationService.getStatus(widget.job.id);
    }
  }

  static bool _containsKorean(String value) {
    return RegExp(r'[\u1100-\u11FF\u3130-\u318F\uAC00-\uD7AF]').hasMatch(value);
  }

  Widget _applyButton() {
    return FutureBuilder<JobApplicationStatus>(
      future: _applicationStatus,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _applicationStatusError(snapshot.error),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: const Color(0xFF9B2C2C)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _applicationStatus = widget.applicationService.getStatus(
                      widget.job.id,
                    );
                  });
                },
                child: const Text('Retry'),
              ),
            ],
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF247545)),
          );
        }

        final status = snapshot.data!;
        if (status == JobApplicationStatus.alreadyApplied) {
          return FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Applied'),
          );
        }
        if (status == JobApplicationStatus.unauthenticated ||
            status == JobApplicationStatus.studentRoleRequired) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                status == JobApplicationStatus.unauthenticated
                    ? 'Sign in with a student account to apply.'
                    : 'Only student accounts can apply for jobs.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: const Color(0xFF647369)),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: null, child: const Text('Apply for Job')),
            ],
          );
        }

        return SizedBox(
          height: 54,
          child: FilledButton.icon(
            key: const ValueKey('apply-for-job'),
            onPressed: _isSubmitting ? null : _confirmApplication,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF247545),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_isSubmitting ? 'Applying…' : 'Apply for Job'),
          ),
        );
      },
    );
  }

  String _applicationStatusError(Object? error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Could not verify your application status. Check that you are signed in as a student and application read rules are deployed.';
    }
    return 'Could not verify your application status. Please check your connection and try again.';
  }

  Future<void> _confirmApplication() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apply for this job?'),
        content: Text('Submit an application for "${widget.job.title}"?'),
        actions: [
          TextButton(
            key: const ValueKey('cancel-job-application'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-job-application'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.applicationService.apply(widget.job.id);
      if (!mounted) return;
      setState(() {
        _applicationStatus = Future.value(JobApplicationStatus.alreadyApplied);
      });
      _showApplicationMessage('Application submitted successfully.');
    } on JobApplicationException catch (error) {
      if (!mounted) return;
      _showApplicationMessage(error.message, isError: true);
      if (error is JobAlreadyAppliedException) {
        setState(() {
          _applicationStatus = Future.value(
            JobApplicationStatus.alreadyApplied,
          );
        });
      }
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showApplicationMessage(_firebaseApplicationError(error), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _firebaseApplicationError(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' => 'Your application was denied. Sign in with a student account and make sure the application Firestore rules are deployed.',
      'already-exists' => 'You have already applied for this job.',
      'unavailable' || 'network-request-failed' =>
        'Could not reach Firebase. Check your connection and try again.',
      _ =>
        'Could not submit your application${error.message == null ? '.' : ': ${error.message}'}',
    };
  }

  void _showApplicationMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFF9B2C2C) : null,
        ),
      );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not available';
    final local = date.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onTap});

  final StudentJobListing job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5EEE7)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF173B27),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                job.workType ?? 'Work type not specified',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF536359),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Schedule: ${job.schedule ?? 'Not specified'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF536359),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFF247545),
                    size: 17,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job.location,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: const Color(0xFF647369)),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF247545),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                job.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: const Color(0xFF647369), height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobDetailSection extends StatelessWidget {
  const _JobDetailSection({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5EEE7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: const Color(0xFF247545),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              content,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: const Color(0xFF173B27), height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranslationMessage extends StatelessWidget {
  const _TranslationMessage({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF4EF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE8DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: const Color(0xFF173B27), height: 1.4),
          ),
          if (action != null) ...[const SizedBox(height: 4), action!],
        ],
      ),
    );
  }
}

class _ListingsState extends StatelessWidget {
  const _ListingsState({
    required this.title,
    required this.message,
    this.icon,
    this.loading = false,
  });

  final String title;
  final String message;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const CircularProgressIndicator(color: Color(0xFF247545))
              else
                Icon(icon, color: const Color(0xFF247545), size: 42),
              const SizedBox(height: 20),
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
            ],
          ),
        ),
      ),
    );
  }
}
