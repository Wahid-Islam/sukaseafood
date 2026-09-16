import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/ui_kit.dart';

/// First-run landing. The artwork is the page; hotspots open signup/login.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const String landingAsset = 'assets/images/auth/signup_landing.png';
  static const double imageAspect = 853 / 1782;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: ContentWidth(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth;
            final double imageHeight = width / imageAspect;
            final double pageHeight = math.max(
              imageHeight,
              constraints.maxHeight,
            );
            return SingleChildScrollView(
              child: SizedBox(
                width: width,
                height: pageHeight,
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: imageHeight,
                      child: const ExcludeSemantics(
                        child: Image(
                          image: AssetImage(landingAsset),
                          fit: BoxFit.fill,
                          alignment: Alignment.topCenter,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                    _Hotspot(
                      key: const Key('onboarding-signup'),
                      label: 'Create an account with email',
                      left: width * 0.06,
                      right: width * 0.06,
                      top: imageHeight * 0.726,
                      height: math.max(52, imageHeight * 0.058),
                      onTap: () => context.go('/signup'),
                    ),
                    _Hotspot(
                      key: const Key('onboarding-signin'),
                      label: 'Sign in',
                      left: width * 0.18,
                      right: width * 0.18,
                      top: imageHeight * 0.798,
                      height: math.max(44, imageHeight * 0.038),
                      onTap: () => context.go('/login'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Hotspot extends StatelessWidget {
  const _Hotspot({
    super.key,
    required this.label,
    required this.left,
    required this.right,
    required this.top,
    required this.height,
    required this.onTap,
  });

  final String label;
  final double left;
  final double right;
  final double top;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      height: height,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.white24,
            highlightColor: Colors.white10,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
