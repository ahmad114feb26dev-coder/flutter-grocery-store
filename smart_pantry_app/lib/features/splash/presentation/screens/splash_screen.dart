import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _startTransitionTimer();
  }

  void _startTransitionTimer() {
    // Allow splash animation to play gracefully for 2.2 seconds before navigating
    _navigationTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      _proceedToNextScreen();
    });
  }

  void _proceedToNextScreen() {
    final authState = ref.read(authControllerProvider);
    final user = authState.valueOrNull;

    if (user != null) {
      context.go('/dashboard');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Ambient soft background glow shapes
          Positioned(
            top: -size.width * 0.25,
            right: -size.width * 0.25,
            child: Container(
              width: size.width * 0.75,
              height: size.width * 0.75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.12),
                    AppColors.primary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -size.width * 0.3,
            left: -size.width * 0.25,
            child: Container(
              width: size.width * 0.8,
              height: size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withOpacity(0.10),
                    AppColors.secondary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // Main Center Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Icon Badge with overlapping sparkle
                    Stack(
                      alignment: Alignment.topRight,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.40),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                              BoxShadow(
                                color: AppColors.primaryDark.withOpacity(0.20),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.kitchen_rounded,
                              color: Colors.white,
                              size: 54,
                            ),
                          ),
                        )
                            .animate()
                            .scale(
                              duration: 750.ms,
                              curve: Curves.easeOutBack,
                              begin: const Offset(0.6, 0.6),
                            )
                            .fadeIn(duration: 500.ms)
                            .shimmer(
                              delay: 900.ms,
                              duration: 1100.ms,
                              color: Colors.white.withOpacity(0.4),
                            ),

                        // Sparkle badge indicator
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFBBF24), AppColors.secondary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.secondary.withOpacity(0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                              border: Border.all(color: Colors.white, width: 2.5),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 16,
                            ),
                          )
                              .animate()
                              .scale(
                                delay: 500.ms,
                                duration: 500.ms,
                                curve: Curves.elasticOut,
                                begin: const Offset(0, 0),
                              )
                              .fadeIn(delay: 450.ms, duration: 300.ms),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // App Title
                    Text(
                      'Smart Pantry',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.8,
                          ),
                    )
                        .animate()
                        .fadeIn(delay: 350.ms, duration: 600.ms)
                        .slideY(begin: 0.35, end: 0, curve: Curves.easeOutCubic),

                    const SizedBox(height: 8),

                    // App Subtitle / Tagline
                    Text(
                      'Intelligent Kitchen & Inventory Management',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        letterSpacing: -0.2,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 500.ms, duration: 600.ms)
                        .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),

                    const SizedBox(height: 22),

                    // Feature badges pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.eco_rounded, size: 15, color: AppColors.primaryDark),
                          const SizedBox(width: 6),
                          Text(
                            'Fresh Tracking  •  Smart Recipes  •  Auto List',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 700.ms, duration: 600.ms)
                        .scale(
                          delay: 700.ms,
                          duration: 500.ms,
                          curve: Curves.easeOut,
                          begin: const Offset(0.9, 0.9),
                        ),

                    const SizedBox(height: 50),

                    // Loading indicator
                    SizedBox(
                      width: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: const LinearProgressIndicator(
                          minHeight: 4,
                          backgroundColor: Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 900.ms, duration: 400.ms),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Footer / Version Info
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Version 1.0.0  •  Fresh & Organized',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ).animate().fadeIn(delay: 1100.ms, duration: 500.ms),
          ),
        ],
      ),
    );
  }
}
