import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StudentJobListingsScreen extends StatefulWidget {
  const StudentJobListingsScreen({super.key, this.jobsStream});

  final Stream<List<StudentJobListing>>? jobsStream;

  @override
  State<StudentJobListingsScreen> createState() =>
      _StudentJobListingsScreenState();
}

class _StudentJobListingsScreenState extends State<StudentJobListingsScreen> {
  late final Stream<List<StudentJobListing>> _jobsStream =
      widget.jobsStream ?? _watchJobs();
  final _searchController = TextEditingController();

  static const _allLocations = 'All Locations';

  String _searchQuery = '';
  String _selectedLocation = _allLocations;

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
                    return matchesSearch && matchesLocation;
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
                            if (_searchQuery.trim().isNotEmpty ||
                                selectedLocation != _allLocations) ...[
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
                                message: 'Try changing or clearing your search and location filters.',
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
                            builder: (_) => StudentJobDetailsScreen(job: job),
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
    );
  }

  final String id;
  final String title;
  final String description;
  final String location;
  final String requirements;
  final String employerId;
  final DateTime? createdAt;

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

class StudentJobDetailsScreen extends StatelessWidget {
  const StudentJobDetailsScreen({super.key, required this.job});

  final StudentJobListing job;

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
                        job.title,
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
                              job.location,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: const Color(0xFF647369)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _JobDetailSection(
                        title: 'Description',
                        content: job.description,
                      ),
                      const SizedBox(height: 16),
                      _JobDetailSection(
                        title: 'Requirements',
                        content: job.requirements,
                      ),
                      const SizedBox(height: 16),
                      _JobDetailSection(
                        title: 'Employer ID',
                        content: job.employerId,
                      ),
                      const SizedBox(height: 16),
                      _JobDetailSection(
                        title: 'Posted',
                        content: _formatDate(job.createdAt),
                      ),
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
