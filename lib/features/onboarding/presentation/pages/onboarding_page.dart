import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  // Blur overlay removed; inline CTA is used on the last page
  late final AnimationController _txController;
  late final Animation<double> _txCurve;
  bool _playTransition = false;

  final List<OnboardingContent> _pages = [
    OnboardingContent(
      title: 'Monitor Your Car\'s Electronics',
      description:
          'Track voltage, temperature, and battery health in real-time using IoT sensors.',
      icon: Icons.directions_car,
      color: Colors.blue,
    ),
    OnboardingContent(
      title: 'Predict Component Failures',
      description:
          'Get early warnings about potential electronic failures before they happen.',
      icon: Icons.warning_amber_rounded,
      color: Colors.orange,
    ),
    OnboardingContent(
      title: 'Find E-Waste Centers',
      description:
          'Locate nearby recycling centers for proper disposal of electronic components.',
      icon: Icons.recycling,
      color: Colors.green,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmall =
                constraints.maxHeight < 700 || constraints.maxWidth < 360;
            final horizontalPadding =
                constraints.maxWidth * 0.08; // responsive side padding

            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.surface,
                        colorScheme.primary.withOpacity(0.06),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) => setState(() {
                            _currentPage = index;
                          }),
                          itemCount: _pages.length,
                          itemBuilder: (context, index) {
                            return _buildPage(
                              _pages[index],
                              isSmall,
                              horizontalPadding,
                              constraints.maxHeight,
                            );
                          },
                        ),
                      ),
                      _buildBottomSection(isSmall, horizontalPadding),
                    ],
                  ),
                ),
                // Futuristic transition overlay (plays on Get Started)
                if (_playTransition)
                  Positioned.fill(
                    child: AbsorbPointer(
                      absorbing: true,
                      child: AnimatedBuilder(
                        animation: _txController,
                        builder: (context, _) {
                          final t = _txCurve.value; // 0 → 1
                          final bgOpacity = 0.05 + 0.25 * t;
                          final ring1 = 120.0 + (220.0 - 120.0) * t;
                          final ring2 = 90.0 + (300.0 - 90.0) * t;
                          final ring3 = 50.0 + (380.0 - 50.0) * t;

                          return Container(
                            color: colorScheme.primary.withOpacity(bgOpacity),
                            child: Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  _ring(ring3, colorScheme.primary,
                                      0.18 * (1 - t)),
                                  _ring(ring2, colorScheme.primary,
                                      0.28 * (1 - (t * 0.6))),
                                  _ring(ring1, colorScheme.primary, 0.35),
                                  Transform.scale(
                                    scale: 0.98 + 0.02 * t,
                                    child: Opacity(
                                      opacity: 0.6 + 0.4 * t,
                                      child: Container(
                                        width: 4 + 120 * t,
                                        height: 1.5,
                                        color: colorScheme.onPrimary
                                            .withOpacity(0.35),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _txController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _txCurve = CurvedAnimation(
      parent: _txController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _txController.dispose();
    super.dispose();
  }

  // Draw a glowing concentric ring for the transition overlay
  Widget _ring(double diameter, Color color, double strokeOpacity) {
    final stroke = (diameter / 120).clamp(1.5, 3.0);
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(strokeOpacity * 0.18),
            Colors.transparent,
          ],
        ),
        border: Border.all(
          color: color.withOpacity(strokeOpacity),
          width: stroke,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(strokeOpacity * 0.9),
            blurRadius: diameter * 0.08,
            spreadRadius: 0.6,
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingContent content, bool isSmall,
      double horizontalPadding, double viewportHeight) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    // Minimum height target to center vertically when there is space
    final minHeight =
        (viewportHeight - media.padding.vertical) * (isSmall ? 0.70 : 0.78);

    final isLast = _pages.isNotEmpty && identical(content, _pages.last);

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, isSmall ? 16 : 32,
          horizontalPadding, isSmall ? 8 : 24),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (!isLast) {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
            );
          }
        },
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Futuristic glowing accent
                    Container(
                      width: isSmall ? 90 : 140,
                      height: isSmall ? 90 : 140,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            content.color.withOpacity(0.25),
                            Colors.transparent
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: content.color.withOpacity(0.12),
                          border: Border.all(
                              color: content.color.withOpacity(0.35)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(content.icon,
                            size: isSmall ? 44 : 64, color: content.color),
                      ),
                    ),
                    SizedBox(height: isSmall ? 24 : 40),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        content.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      content.description,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color:
                            theme.textTheme.bodyLarge?.color?.withOpacity(0.75),
                        height: 1.35,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isSmall ? 16 : 24),
                    // subtle futuristic divider
                    Container(
                      height: 1,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            colorScheme.primary.withOpacity(0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    if (isLast) ...[
                      SizedBox(height: isSmall ? 12 : 18),
                      Center(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmall ? 18 : 24,
                              vertical: isSmall ? 10 : 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            setState(() => _playTransition = true);
                            _txController.forward().whenComplete(() {
                              context.go('/dashboard');
                              // Reset for safety if user returns
                              _txController.reset();
                              setState(() => _playTransition = false);
                            });
                          },
                          icon: const Icon(Icons.rocket_launch, size: 18),
                          label: const Text('Get Started'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSection(bool isSmall, double horizontalPadding) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final isLast = _currentPage == _pages.length - 1;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          horizontalPadding, 8, horizontalPadding, isSmall ? 12 : 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 6,
            children: List.generate(_pages.length, (index) {
              final selected = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: selected ? 26 : 12,
                height: 8,
                decoration: BoxDecoration(
                  color:
                      selected ? primary : theme.dividerColor.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            }),
          ),
          SizedBox(height: isSmall ? 10 : 16),
          if (!isLast) ...[
            Text(
              'Tap or swipe to continue',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            SizedBox(height: isSmall ? 4 : 8),
          ],
        ],
      ),
    );
  }
}

class OnboardingContent {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingContent({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
