import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart' as app_auth;
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../goals/goals_screen.dart';
import '../home/home_screen.dart';
import '../insights/insights_screen.dart';
import '../landing/landing_screen.dart';
import '../schedule/schedule_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _firestoreService.userDocument(user.uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Unable to load your profile. Please try again.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: AppColors.sub,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }

            final data = snapshot.data?.data() ?? <String, dynamic>{};

            final storedName = data['name'] as String?;
            final name = storedName?.trim().isNotEmpty == true
                ? storedName!.trim()
                : 'Your name';

            final email = user.email ?? 'No email available';
            final storedJobTitle = data['jobTitle'] as String?;
            final storedCompany = data['company'] as String?;

            final jobTitle = storedJobTitle?.isNotEmpty == true
                ? storedJobTitle!
                : 'Add your role';

            final company = storedCompany?.isNotEmpty == true
                ? storedCompany!
                : 'Add your company';

            final photoUrl = data['photoUrl'] as String? ?? '';

            final startTime = data['workStartTime'] as String? ?? '09:00 AM';

            final endTime = data['workEndTime'] as String? ?? '05:00 PM';

            final workdays = List<String>.from(
              data['workdays'] as List? ?? const [],
            );

            final commuteMinutes =
                (data['commuteMinutes'] as num?)?.toInt() ?? 0;
            final sleepHours = (data['sleepHours'] as num?)?.toDouble();
            final restHours = (data['restHours'] as num?)?.toDouble();

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR SPACE',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: AppColors.sub,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your profile',
                          style: GoogleFonts.fraunces(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'A little space for the details and routines that make WorkLife yours.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.45,
                            color: AppColors.sub,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _ProfileHeader(
                          name: name,
                          email: email,
                          photoUrl: photoUrl,
                        ),
                        const SizedBox(height: 24),
                        _ProfileInfoCard(
                          title: 'Personal information',
                          trailing: IconButton(
                            tooltip: 'Edit profile',
                            onPressed: () {
                              showDialog<void>(
                                context: context,
                                builder: (_) => _EditProfileDialog(
                                  userId: user.uid,
                                  name: name == 'Your name' ? '' : name,
                                  jobTitle: jobTitle == 'Add your role'
                                      ? ''
                                      : jobTitle,
                                  company: company == 'Add your company'
                                      ? ''
                                      : company,
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 19,
                              color: AppColors.eucalyptusDark,
                            ),
                          ),
                          children: [
                            _ProfileInfoRow(
                              icon: Icons.person_outline,
                              label: 'Full name',
                              value: name,
                            ),
                            const _ProfileDivider(),
                            _ProfileInfoRow(
                              icon: Icons.email_outlined,
                              label: 'Email address',
                              value: email,
                            ),
                            const _ProfileDivider(),
                            _ProfileInfoRow(
                              icon: Icons.work_outline,
                              label: 'Job title',
                              value: jobTitle,
                            ),
                            const _ProfileDivider(),
                            _ProfileInfoRow(
                              icon: Icons.business_outlined,
                              label: 'Company',
                              value: company,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _ProfileInfoCard(
                          title: 'Work routine',
                          trailing: IconButton(
                            tooltip: 'Edit work routine',
                            onPressed: () {
                              showDialog<void>(
                                context: context,
                                builder: (_) => _EditRoutineDialog(
                                  userId: user.uid,
                                  startTime: startTime,
                                  endTime: endTime,
                                  workdays: workdays,
                                  commuteMinutes: commuteMinutes,
                                  sleepHours: sleepHours,
                                  restHours: restHours,
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 19,
                              color: AppColors.eucalyptusDark,
                            ),
                          ),
                          children: [
                            _ProfileInfoRow(
                              icon: Icons.schedule_outlined,
                              label: 'Working hours',
                              value: '$startTime – $endTime',
                            ),
                            const _ProfileDivider(),
                            _ProfileInfoRow(
                              icon: Icons.calendar_month_outlined,
                              label: 'Workdays',
                              value: workdays.isEmpty
                                  ? 'Not set'
                                  : workdays.join(', '),
                            ),
                            const _ProfileDivider(),
                            _ProfileInfoRow(
                              icon: Icons.directions_bus_outlined,
                              label: 'One-way commute',
                              value: commuteMinutes == 0
                                  ? 'Not set'
                                  : '$commuteMinutes minutes',
                            ),
                            const _ProfileDivider(),
                            _ProfileInfoRow(
                              icon: Icons.bedtime_outlined,
                              label: 'Sleep target',
                              value: sleepHours == null
                                  ? 'Not set'
                                  : '${sleepHours.toStringAsFixed(sleepHours % 1 == 0 ? 0 : 1)} hours per day',
                            ),
                            const _ProfileDivider(),
                            _ProfileInfoRow(
                              icon: Icons.self_improvement_outlined,
                              label: 'Rest target',
                              value: restHours == null
                                  ? 'Not set'
                                  : '${restHours.toStringAsFixed(restHours % 1 == 0 ? 0 : 1)} hours per day',
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _ProfileInfoCard(
                          title: 'Account',
                          children: [
                            _ProfileInfoRow(
                              icon: Icons.verified_user_outlined,
                              label: 'Email verification',
                              value: user.emailVerified
                                  ? 'Verified'
                                  : 'Not verified',
                            ),
                            const _ProfileDivider(),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.logout_outlined,
                                color: AppColors.clayDark,
                              ),
                              title: Text(
                                'Log out',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.clayDark,
                                ),
                              ),
                              subtitle: Text(
                                'Sign out of your WorkLife account',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.sub,
                                ),
                              ),
                              onTap: _confirmLogout,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const _ProfileNavigationBar(),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.ivory,
          title: Text(
            'Log out?',
            style: GoogleFonts.fraunces(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          content: Text(
            'Are you sure you want to log out of WorkLife?',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: AppColors.sub,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) return;

    try {
      await context.read<app_auth.AuthProvider>().logout();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LandingScreen()),
        (route) => false,
      );
    } catch (error) {
      debugPrint('LOGOUT ERROR: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to log out. Please try again.')),
      );
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.photoUrl,
  });

  final String name;
  final String email;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final trimmedName = name.trim();
    final initials = trimmedName.isEmpty
        ? '?'
        : trimmedName
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();

    return Row(
      children: [
        CircleAvatar(
          radius: 39,
          backgroundColor: AppColors.eucalyptus,
          backgroundImage: photoUrl.isEmpty ? null : NetworkImage(photoUrl),
          onBackgroundImageError: photoUrl.isEmpty
              ? null
              : (error, stackTrace) {
                  debugPrint('PROFILE PHOTO DISPLAY ERROR: $error');
                },
          child: photoUrl.isEmpty
              ? Text(
                  initials,
                  style: GoogleFonts.fraunces(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.fraunces(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.sub),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(17, 13, 17, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.fraunces(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 5),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.eucalyptusDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.sub),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDivider extends StatelessWidget {
  const _ProfileDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 0.7, color: AppColors.line);
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.userId,
    required this.name,
    required this.jobTitle,
    required this.company,
  });

  final String userId;
  final String name;
  final String jobTitle;
  final String company;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _jobTitleController;
  late final TextEditingController _companyController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _jobTitleController = TextEditingController(text: widget.jobTitle);
    _companyController = TextEditingController(text: widget.company);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jobTitleController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final jobTitle = _jobTitleController.text.trim();
    final company = _companyController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your name.')));
      return;
    }

    setState(() => _saving = true);

    try {
      await FirestoreService().updateBasicProfile(
        userId: widget.userId,
        name: name,
        jobTitle: jobTitle,
        company: company,
      );

      try {
        await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
      } catch (error) {
        debugPrint('AUTH DISPLAY NAME UPDATE ERROR: $error');
      }

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (error) {
      debugPrint('UPDATE PROFILE ERROR: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save your profile. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.ivory,
      title: Text(
        'Edit profile',
        style: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProfileTextField(
              controller: _nameController,
              label: 'Name',
              hint: 'Your name',
            ),
            const SizedBox(height: 14),
            _ProfileTextField(
              controller: _jobTitleController,
              label: 'Job title',
              hint: 'Your role',
            ),
            const SizedBox(height: 14),
            _ProfileTextField(
              controller: _companyController,
              label: 'Company',
              hint: 'Your company',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save changes'),
        ),
      ],
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.sub,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.ink),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

class _EditRoutineDialog extends StatefulWidget {
  const _EditRoutineDialog({
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.workdays,
    required this.commuteMinutes,
    required this.sleepHours,
    required this.restHours,
  });

  final String userId;
  final String startTime;
  final String endTime;
  final List<String> workdays;
  final int commuteMinutes;
  final double? sleepHours;
  final double? restHours;

  @override
  State<_EditRoutineDialog> createState() => _EditRoutineDialogState();
}

class _EditRoutineDialogState extends State<_EditRoutineDialog> {
  static const List<String> _days = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  late TimeOfDay _start;
  late TimeOfDay _end;
  late Set<String> _workdays;
  late final TextEditingController _commuteController;
  late final TextEditingController _sleepController;
  late final TextEditingController _restController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _start =
        _parseTime(widget.startTime) ?? const TimeOfDay(hour: 9, minute: 0);

    _end = _parseTime(widget.endTime) ?? const TimeOfDay(hour: 17, minute: 0);

    _workdays = widget.workdays.toSet();

    _commuteController = TextEditingController(
      text: widget.commuteMinutes == 0 ? '' : widget.commuteMinutes.toString(),
    );
    _sleepController = TextEditingController(
      text: widget.sleepHours?.toString() ?? '',
    );
    _restController = TextEditingController(
      text: widget.restHours?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _commuteController.dispose();
    _sleepController.dispose();
    _restController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value.trim());

    if (match == null) return null;

    var hour = int.tryParse(match.group(1)!) ?? 0;
    final minute = int.tryParse(match.group(2)!) ?? 0;
    final period = match.group(3)!.toUpperCase();

    if (hour < 1 || hour > 12 || minute < 0 || minute > 59) {
      return null;
    }

    if (period == 'AM') {
      if (hour == 12) hour = 0;
    } else if (hour != 12) {
      hour += 12;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  Future<void> _selectTime({required bool isStart}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );

    if (selected == null || !mounted) return;

    setState(() {
      if (isStart) {
        _start = selected;
      } else {
        _end = selected;
      }
    });
  }

  Future<void> _save() async {
    final commuteText = _commuteController.text.trim();
    final commute = commuteText.isEmpty ? 0 : int.tryParse(commuteText);
    final sleepText = _sleepController.text.trim();
    final restText = _restController.text.trim();
    final sleep = sleepText.isEmpty ? null : double.tryParse(sleepText);
    final rest = restText.isEmpty ? null : double.tryParse(restText);

    if (commute == null || commute < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid commute time in minutes.')),
      );
      return;
    }

    if ((sleepText.isNotEmpty && (sleep == null || sleep < 0 || sleep > 24)) ||
        (restText.isNotEmpty && (rest == null || rest < 0 || rest > 24))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sleep and rest targets must be 0–24 hours.'),
        ),
      );
      return;
    }

    if (_workdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one workday.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await FirestoreService().userDocument(widget.userId).update({
        'workStartTime': _formatTime(_start),
        'workEndTime': _formatTime(_end),
        'workdays': _days.where(_workdays.contains).toList(),
        'commuteMinutes': commute,
        'sleepHours': sleep ?? FieldValue.delete(),
        'restHours': rest ?? FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Work routine updated.')));
    } catch (error) {
      debugPrint('UPDATE ROUTINE ERROR: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save your work routine. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.ivory,
      title: Text(
        'Edit work routine',
        style: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Working hours',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.sub,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => _selectTime(isStart: true),
                    child: Text(_formatTime(_start)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => _selectTime(isStart: false),
                    child: Text(_formatTime(_end)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Workdays',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.sub,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _days.map((day) {
                final selected = _workdays.contains(day);

                return FilterChip(
                  label: Text(day),
                  selected: selected,
                  onSelected: _saving
                      ? null
                      : (value) {
                          setState(() {
                            if (value) {
                              _workdays.add(day);
                            } else {
                              _workdays.remove(day);
                            }
                          });
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            Text(
              'One-way commute (minutes)',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.sub,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commuteController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.ink),
              decoration: const InputDecoration(hintText: 'e.g. 30'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _sleepController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Sleep target',
                hintText: 'e.g. 8',
                suffixText: 'hours per day',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _restController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Rest target',
                hintText: 'e.g. 2',
                suffixText: 'hours per day',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save routine'),
        ),
      ],
    );
  }
}

class _ProfileNavigationBar extends StatelessWidget {
  const _ProfileNavigationBar();

  @override
  Widget build(BuildContext context) {
    final destinations = <_NavigationDestinationData>[
      _NavigationDestinationData(
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        screen: const HomeScreen(),
      ),
      _NavigationDestinationData(
        label: 'Schedule',
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month_rounded,
        screen: const ScheduleScreen(),
      ),
      _NavigationDestinationData(
        label: 'Goals',
        icon: Icons.flag_outlined,
        selectedIcon: Icons.flag_rounded,
        screen: const GoalsScreen(),
      ),
      _NavigationDestinationData(
        label: 'Insights',
        icon: Icons.insights_outlined,
        selectedIcon: Icons.insights_rounded,
        screen: const InsightsScreen(),
      ),
      _NavigationDestinationData(
        label: 'Profile',
        icon: Icons.person_outline,
        selectedIcon: Icons.person_rounded,
        screen: const ProfileScreen(),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line, width: 0.7)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
          child: Row(
            children: destinations.map((destination) {
              final selected = destination.label == 'Profile';

              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: selected
                      ? null
                      : () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) => destination.screen,
                            ),
                          );
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected
                              ? destination.selectedIcon
                              : destination.icon,
                          size: 21,
                          color: selected
                              ? AppColors.eucalyptusDark
                              : AppColors.sub,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          destination.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selected
                                ? AppColors.eucalyptusDark
                                : AppColors.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavigationDestinationData {
  const _NavigationDestinationData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.screen,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;
}
