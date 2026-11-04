import 'package:flutter/material.dart';
import 'package:pallijob/screens/auth/auth_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 360 ? 20.0 : 28.0;

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Container(
                    width: 480,
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _BrandHeader(),
                        const SizedBox(height: 32),
                        const _WelcomeArtwork(),
                        const SizedBox(height: 28),
                        Text(
                          'Good work starts here.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: const Color(0xFF173B27),
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Find the right part-time job in Korea.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: const Color(0xFF647369),
                                height: 1.5,
                              ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: FilledButton.icon(
                            onPressed: () =>
                                _openAuth(context, role: 'Student'),
                            icon: const Icon(Icons.school_outlined),
                            label: const Text('Continue as Student'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF247545),
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _openAuth(context, role: 'Employer'),
                            icon: const Icon(Icons.business_outlined),
                            label: const Text('Continue as Employer'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF247545),
                              side: const BorderSide(color: Color(0xFFB8D7C2)),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
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

  void _openAuth(BuildContext context, {required String role}) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => AuthScreen(role: role)));
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF247545),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.work_outline_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'PalliJob',
          style: TextStyle(
            color: Color(0xFF173B27),
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
        ),
      ],
    );
  }
}

class _WelcomeArtwork extends StatelessWidget {
  const _WelcomeArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFEDF6EF),
                borderRadius: BorderRadius.circular(32),
              ),
            ),
          ),
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              color: const Color(0xFF247545),
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF247545).withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.work_outline_rounded,
              color: Colors.white,
              size: 58,
            ),
          ),
          Positioned(
            top: 28,
            right: 34,
            child: _ArtworkBadge(
              icon: Icons.location_on_outlined,
              color: Color(0xFF247545),
            ),
          ),
          Positioned(
            bottom: 26,
            left: 22,
            child: _ArtworkBadge(
              icon: Icons.check_circle_outline_rounded,
              color: Color(0xFF4F8B62),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtworkBadge extends StatelessWidget {
  const _ArtworkBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF173B27).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 25),
    );
  }
}
