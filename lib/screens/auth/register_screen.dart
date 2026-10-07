import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final pageContext = context;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(
          content: Text('Please complete all fields.'),
        ),
      );
      return;
    }

    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address.'),
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.'),
        ),
      );
      return;
    }

    final authProvider = pageContext.read<AuthProvider>();

    try {
      await authProvider.register(
        name: name,
        email: email,
        password: password,
      );

      final user = authProvider.user;

      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }

      if (!pageContext.mounted) return;

      await showDialog<void>(
        context: pageContext,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: AppColors.ivory,
            title: Text(
              'Check your email',
              style: GoogleFonts.fraunces(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            content: Text(
              'We sent a verification link to $email. '
              'Please verify your email before logging in.',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: AppColors.sub,
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);

                  if (pageContext.mounted) {
                    Navigator.pop(pageContext);
                  }
                },
                child: const Text('Back to login'),
              ),
            ],
          );
        },
      );
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'REGISTER ERROR: ${e.code} - ${e.message}',
      );

      if (!pageContext.mounted) return;

      if (e.code == 'email-already-in-use') {
        await showDialog<void>(
          context: pageContext,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: AppColors.ivory,
              title: Text(
                'Email already registered',
                style: GoogleFonts.fraunces(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              content: Text(
                'An account already exists with $email. '
                'Please log in instead.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.sub,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.sub,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);

                    if (!pageContext.mounted) return;

                    Navigator.pushReplacement(
                      pageContext,
                      MaterialPageRoute(
                        builder: (_) => LoginScreen(
                          initialEmail: email,
                        ),
                      ),
                    );
                  },
                  child: const Text('Log in'),
                ),
              ],
            );
          },
        );

        return;
      }

      String message;

      switch (e.code) {
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          message = 'Password is too weak. Use at least 6 characters.';
          break;
        case 'network-request-failed':
          message = 'Check your internet connection and try again.';
          break;
        default:
          message = 'Something went wrong. Please try again.';
      }

      ScaffoldMessenger.of(pageContext).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (_) {
      if (!pageContext.mounted) return;

      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    return emailRegex.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CREATE ACCOUNT',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: AppColors.sub,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Create your account',
                style: GoogleFonts.fraunces(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Set up your WorkLife account to get started.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  color: AppColors.sub,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'Name',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.sub,
                ),
              ),
              const SizedBox(height: 7),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.ink,
                ),
                decoration: const InputDecoration(
                  hintText: 'Your name',
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Email',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.sub,
                ),
              ),
              const SizedBox(height: 7),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.ink,
                ),
                decoration: const InputDecoration(
                  hintText: 'name@email.com',
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Password',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.sub,
                ),
              ),
              const SizedBox(height: 7),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.ink,
                ),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 19,
                      color: AppColors.eucalyptusDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.clay,
                      Color(0xFFC48E5C),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.clay.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: isLoading ? null : _register,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isLoading
                        ? 'Creating account...'
                        : 'Create account',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.sub,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Already have an account? ',
                        ),
                        TextSpan(
                          text: 'Log in',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.eucalyptusDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}