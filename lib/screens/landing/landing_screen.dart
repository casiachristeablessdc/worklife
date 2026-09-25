import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8EBCF),
              Color(0xFFF5EEDB),
              AppColors.ivory,
            ],
            stops: [0.0, 0.38, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      22,
                      16,
                      22,
                      18,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _WorkLifeBrand(),

                        const SizedBox(height: 12),

                        const _LandingIllustration(),

                        const SizedBox(height: 8),

                        Text(
                          'Make space for\nthe life outside work.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.fraunces(
                            fontSize: 31,
                            height: 1.02,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                          ),
                          child: Text(
                            'Plan your time, understand your routines, '
                            'and make room for what matters beyond work.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              height: 1.5,
                              color: AppColors.sub,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        _PrimaryButton(
                          label: 'Continue with Google',
                          icon: Icons.g_mobiledata_rounded,
                          onPressed: () {},
                        ),

                        const SizedBox(height: 10),

                        _SecondaryButton(
                          label: 'Use email instead',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 18),

                        Row(
                          children: [
                            const Expanded(
                              child: Divider(
                                color: AppColors.line,
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'or continue with',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.sub,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(
                                color: AppColors.line,
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _SocialButton(
                              icon: Icons.apple,
                              onPressed: () {},
                            ),
                            const SizedBox(width: 12),
                            _SocialButton(
                              icon: Icons.facebook_rounded,
                              onPressed: () {},
                            ),
                            const SizedBox(width: 12),
                            _SocialButton(
                              icon: Icons.close_rounded,
                              onPressed: () {},
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.sub,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'Log in',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.eucalyptusDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WorkLifeBrand extends StatelessWidget {
  const _WorkLifeBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.eucalyptusDark,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.eco_rounded,
            color: AppColors.ivory,
            size: 18,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'WorkLife',
          style: GoogleFonts.fraunces(
            fontSize: 21,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _LandingIllustration extends StatelessWidget {
  const _LandingIllustration();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 280,
      width: double.infinity,
      child: CustomPaint(
        painter: _BotanicalIllustrationPainter(),
      ),
    );
  }
}

class _BotanicalIllustrationPainter extends CustomPainter {
  const _BotanicalIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;

    final peachPaint = Paint()
      ..color = const Color(0xFFF2D8B7)
      ..style = PaintingStyle.fill;

    final eucalyptusPaint = Paint()
      ..color = const Color(0xFFCBD4B1)
      ..style = PaintingStyle.fill;

    final pistachioPaint = Paint()
      ..color = const Color(0xFFE8ECC9)
      ..style = PaintingStyle.fill;

    final darkGreenPaint = Paint()
      ..color = const Color(0xFF4E5A3A)
      ..style = PaintingStyle.fill;

    final clayPaint = Paint()
      ..color = const Color(0xFFD6A574)
      ..style = PaintingStyle.fill;

    final stemPaint = Paint()
      ..color = const Color(0xFF68734E)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Large soft botanical background shapes.
    canvas.drawCircle(
      Offset(centerX - 75, 108),
      74,
      pistachioPaint,
    );

    canvas.drawCircle(
      Offset(centerX + 72, 100),
      82,
      eucalyptusPaint,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, 98),
        width: 185,
        height: 150,
      ),
      peachPaint,
    );

    // Main stem.
    final stemPath = Path()
      ..moveTo(centerX, 245)
      ..cubicTo(
        centerX - 2,
        205,
        centerX + 4,
        165,
        centerX + 1,
        110,
      );

    canvas.drawPath(stemPath, stemPaint);

    // Left branch.
    final leftBranch = Path()
      ..moveTo(centerX, 185)
      ..cubicTo(
        centerX - 18,
        168,
        centerX - 34,
        150,
        centerX - 47,
        126,
      );

    canvas.drawPath(leftBranch, stemPaint);

    // Right branch.
    final rightBranch = Path()
      ..moveTo(centerX + 2, 165)
      ..cubicTo(
        centerX + 22,
        147,
        centerX + 38,
        130,
        centerX + 48,
        105,
      );

    canvas.drawPath(rightBranch, stemPaint);

    // Large central leaf.
    final centerLeaf = Path()
      ..moveTo(centerX, 155)
      ..cubicTo(
        centerX - 38,
        135,
        centerX - 42,
        98,
        centerX - 4,
        74,
      )
      ..cubicTo(
        centerX + 30,
        96,
        centerX + 29,
        130,
        centerX,
        155,
      )
      ..close();

    canvas.drawPath(centerLeaf, darkGreenPaint);

    // Left leaf.
    final leftLeaf = Path()
      ..moveTo(centerX - 36, 139)
      ..cubicTo(
        centerX - 70,
        141,
        centerX - 88,
        122,
        centerX - 89,
        94,
      )
      ..cubicTo(
        centerX - 57,
        93,
        centerX - 39,
        110,
        centerX - 36,
        139,
      )
      ..close();

    canvas.drawPath(leftLeaf, darkGreenPaint);

    // Right leaf.
    final rightLeaf = Path()
      ..moveTo(centerX + 35, 130)
      ..cubicTo(
        centerX + 67,
        128,
        centerX + 83,
        108,
        centerX + 80,
        82,
      )
      ..cubicTo(
        centerX + 49,
        84,
        centerX + 34,
        101,
        centerX + 35,
        130,
      )
      ..close();

    canvas.drawPath(rightLeaf, darkGreenPaint);

    // Lower left leaf.
    final lowerLeftLeaf = Path()
      ..moveTo(centerX - 8, 205)
      ..cubicTo(
        centerX - 43,
        208,
        centerX - 60,
        190,
        centerX - 58,
        168,
      )
      ..cubicTo(
        centerX - 30,
        169,
        centerX - 11,
        183,
        centerX - 8,
        205,
      )
      ..close();

    canvas.drawPath(lowerLeftLeaf, eucalyptusPaint);

    // Lower right leaf.
    final lowerRightLeaf = Path()
      ..moveTo(centerX + 7, 202)
      ..cubicTo(
        centerX + 39,
        202,
        centerX + 57,
        184,
        centerX + 58,
        161,
      )
      ..cubicTo(
        centerX + 29,
        165,
        centerX + 10,
        181,
        centerX + 7,
        202,
      )
      ..close();

    canvas.drawPath(lowerRightLeaf, eucalyptusPaint);

    // Decorative circles.
    canvas.drawCircle(
      Offset(centerX - 112, 180),
      15,
      clayPaint,
    );

    canvas.drawCircle(
      Offset(centerX + 112, 194),
      12,
      pistachioPaint,
    );

    canvas.drawCircle(
      Offset(centerX + 98, 63),
      10,
      clayPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AppColors.clay,
              Color(0xFFC48E5C),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.clay.withValues(alpha: 0.24),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 21,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SecondaryButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.eucalyptusDark,
          side: const BorderSide(
            color: AppColors.eucalyptus,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(23),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.white.withValues(alpha: 0.72),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Icon(
            icon,
            size: 20,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}