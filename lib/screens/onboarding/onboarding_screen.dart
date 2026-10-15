import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _companyController = TextEditingController();

  void _continue() {
    final name = _nameController.text.trim();
    final jobTitle = _jobTitleController.text.trim();
    final company = _companyController.text.trim();

    if (name.isEmpty || jobTitle.isEmpty || company.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingStepTwoScreen(
          name: name,
          jobTitle: jobTitle,
          company: company,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jobTitleController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OnboardingHeader(step: 1),
              const SizedBox(height: 38),
              Text(
                'A little about you.',
                style: GoogleFonts.fraunces(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'A few details will help us make WorkLife feel more like yours.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.sub,
                ),
              ),
              const SizedBox(height: 32),
              _FieldLabel(label: 'Full name'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Your name'),
              ),
              const SizedBox(height: 20),
              _FieldLabel(label: 'Job title'),
              const SizedBox(height: 8),
              TextField(
                controller: _jobTitleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'e.g. Software Engineer',
                ),
              ),
              const SizedBox(height: 20),
              _FieldLabel(label: 'Company or organization'),
              const SizedBox(height: 8),
              TextField(
                controller: _companyController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'Where do you work?',
                ),
              ),
              const SizedBox(height: 36),
              FilledButton(onPressed: _continue, child: const Text('Continue')),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingStepTwoScreen extends StatefulWidget {
  final String name;
  final String jobTitle;
  final String company;

  const OnboardingStepTwoScreen({
    super.key,
    required this.name,
    required this.jobTitle,
    required this.company,
  });

  @override
  State<OnboardingStepTwoScreen> createState() =>
      _OnboardingStepTwoScreenState();
}

class _OnboardingStepTwoScreenState extends State<OnboardingStepTwoScreen> {
  TimeOfDay _workStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _workEndTime = const TimeOfDay(hour: 18, minute: 0);

  final Set<String> _selectedWorkdays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};

  double _commuteMinutes = 30;

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  Future<void> _selectWorkTime({required bool isStartTime}) async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _workStartTime : _workEndTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.clay,
              onPrimary: Colors.white,
              surface: AppColors.ivory,
              onSurface: AppColors.ink,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime == null) {
      return;
    }

    setState(() {
      if (isStartTime) {
        _workStartTime = selectedTime;
      } else {
        _workEndTime = selectedTime;
      }
    });
  }

  void _toggleDay(String day) {
    setState(() {
      if (_selectedWorkdays.contains(day)) {
        if (_selectedWorkdays.length == 1) {
          return;
        }

        _selectedWorkdays.remove(day);
      } else {
        _selectedWorkdays.add(day);
      }
    });
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  String _formatCommute(double value) {
    final minutes = value.round();

    if (minutes == 0) {
      return 'No commute';
    }

    if (minutes == 60) {
      return '1 hour';
    }

    if (minutes > 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;

      if (remainingMinutes == 0) {
        return '$hours hours';
      }

      return '$hours hr $remainingMinutes min';
    }

    return '$minutes min';
  }

  void _continue() {
    if (_selectedWorkdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one workday.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingStepThreeScreen(
          name: widget.name,
          jobTitle: widget.jobTitle,
          company: widget.company,
          workStartTime: _formatTime(_workStartTime),
          workEndTime: _formatTime(_workEndTime),
          workdays: _days
              .where((day) => _selectedWorkdays.contains(day))
              .toList(),
          commuteMinutes: _commuteMinutes.round(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OnboardingHeader(step: 2),
              const SizedBox(height: 38),
              Text(
                'Your work routine.',
                style: GoogleFonts.fraunces(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Share your usual hours so we can help make space for the rest of life.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.sub,
                ),
              ),
              const SizedBox(height: 32),
              _SectionLabel(label: 'WORK HOURS'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TimeCard(
                      label: 'Starts',
                      time: _formatTime(_workStartTime),
                      onTap: () => _selectWorkTime(isStartTime: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeCard(
                      label: 'Ends',
                      time: _formatTime(_workEndTime),
                      onTap: () => _selectWorkTime(isStartTime: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _SectionLabel(label: 'WORKDAYS'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _days.map((day) {
                  final isSelected = _selectedWorkdays.contains(day);

                  return _DayChip(
                    label: day,
                    selected: isSelected,
                    onTap: () => _toggleDay(day),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              _SectionLabel(label: 'DAILY COMMUTE'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: BoxDecoration(
                  color: AppColors.peach,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCommute(_commuteMinutes),
                          style: GoogleFonts.fraunces(
                            fontSize: 23,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            'each way',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.sub,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'How long does your usual one-way commute take?',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.sub,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.clay,
                        inactiveTrackColor: AppColors.clay.withValues(
                          alpha: 0.2,
                        ),
                        thumbColor: AppColors.clay,
                        overlayColor: AppColors.clay.withValues(alpha: 0.1),
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                      ),
                      child: Slider(
                        value: _commuteMinutes,
                        min: 0,
                        max: 180,
                        divisions: 36,
                        onChanged: (value) {
                          setState(() {
                            _commuteMinutes = value;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '0 min',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppColors.sub,
                            ),
                          ),
                          Text(
                            '3 hours',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppColors.sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              FilledButton(onPressed: _continue, child: const Text('Continue')),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingStepThreeScreen extends StatefulWidget {
  final String name;
  final String jobTitle;
  final String company;
  final String workStartTime;
  final String workEndTime;
  final List<String> workdays;
  final int commuteMinutes;

  const OnboardingStepThreeScreen({
    super.key,
    required this.name,
    required this.jobTitle,
    required this.company,
    required this.workStartTime,
    required this.workEndTime,
    required this.workdays,
    required this.commuteMinutes,
  });

  @override
  State<OnboardingStepThreeScreen> createState() =>
      _OnboardingStepThreeScreenState();
}

class _OnboardingStepThreeScreenState extends State<OnboardingStepThreeScreen> {
  final Set<String> _selectedHobbies = {};
  final Set<String> _selectedPersonalLife = {};
  final Set<String> _selectedSideQuests = {};

  final List<String> _customHobbies = [];
  final List<String> _customSideQuests = [];

  final _customHobbyController = TextEditingController();
  final _customSideQuestController = TextEditingController();

  final List<String> _hobbies = [
    'Gaming',
    'Reading',
    'Movies & series',
    'Music',
    'Arts & crafts',
    'Photography',
    'Cooking / baking',
    'Travel',
    'Gardening',
    'Playing an instrument',
    'Fitness / exercise',
    'Wellness / mindfulness',
    'Cafés / exploring',
    'Shopping',
    'Socializing',
    'Pets',
  ];

  final List<String> _personalLife = [
    'Household / chores',
    'Family time',
    'Relationship / dating',
    'Friends',
    'Errands',
    'Side hustle / freelance',
    'Studying / learning',
    'Caregiving',
    'Rest / doing nothing',
  ];

  final List<String> _sideQuests = [
    'Exercise more',
    'Read more',
    'Learn something new',
    'Travel',
    'Build a side hustle',
    'Take better care of myself',
    'Spend more time with loved ones',
    'Make something',
    'Start a new hobby',
  ];

  void _toggleSelection(Set<String> selection, String value) {
    setState(() {
      if (selection.contains(value)) {
        selection.remove(value);
      } else {
        selection.add(value);
      }
    });
  }

  void _addCustomHobby() {
    final value = _customHobbyController.text.trim();

    if (value.isEmpty) {
      return;
    }

    if (!_customHobbies.contains(value)) {
      setState(() {
        _customHobbies.add(value);
        _selectedHobbies.add(value);
        _customHobbyController.clear();
      });
    }
  }

  void _addCustomSideQuest() {
    final value = _customSideQuestController.text.trim();

    if (value.isEmpty) {
      return;
    }

    if (!_customSideQuests.contains(value)) {
      setState(() {
        _customSideQuests.add(value);
        _selectedSideQuests.add(value);
        _customSideQuestController.clear();
      });
    }
  }

  Future<void> _finishSetup() async {
    final authProvider = context.read<AuthProvider>();

    try {
      await authProvider.completeOnboarding(
        name: widget.name,
        jobTitle: widget.jobTitle,
        company: widget.company,
        workStartTime: widget.workStartTime,
        workEndTime: widget.workEndTime,
        workdays: widget.workdays,
        commuteMinutes: widget.commuteMinutes,
        hobbies: _selectedHobbies.toList(),
        personalLife: _selectedPersonalLife.toList(),
        sideQuests: _selectedSideQuests.toList(),
        customHobbies: _customHobbies,
        customSideQuests: _customSideQuests,
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: AppColors.ivory,
            title: Text(
              'You’re all set.',
              style: GoogleFonts.fraunces(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            content: Text(
              'Your WorkLife profile is ready. We’ll help you make space for the life outside work.',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: AppColors.sub,
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Let’s go'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We couldn’t save your profile. Please try again.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _customHobbyController.dispose();
    _customSideQuestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OnboardingHeader(step: 3),
              const SizedBox(height: 38),
              Text(
                'Your life outside work.',
                style: GoogleFonts.fraunces(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tell us what you’d like to make more room for outside of work.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.sub,
                ),
              ),
              const SizedBox(height: 30),
              _SectionLabel(label: 'HOBBIES & INTERESTS'),
              const SizedBox(height: 8),
              Text(
                'Pick anything you enjoy. You can choose more than one.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.sub),
              ),
              const SizedBox(height: 14),
              _ChoiceWrap(
                options: _hobbies,
                selected: _selectedHobbies,
                onSelected: (value) {
                  _toggleSelection(_selectedHobbies, value);
                },
              ),
              const SizedBox(height: 12),
              _CustomEntry(
                controller: _customHobbyController,
                hintText: 'Other hobby or interest',
                buttonLabel: 'Add',
                onAdd: _addCustomHobby,
              ),
              if (_customHobbies.isNotEmpty) ...[
                const SizedBox(height: 10),
                _CustomItems(
                  items: _customHobbies,
                  onRemove: (value) {
                    setState(() {
                      _customHobbies.remove(value);
                      _selectedHobbies.remove(value);
                    });
                  },
                ),
              ],
              const SizedBox(height: 30),
              _SectionLabel(label: 'PERSONAL LIFE'),
              const SizedBox(height: 8),
              Text(
                'What normally takes up your time outside work?',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.sub),
              ),
              const SizedBox(height: 14),
              _ChoiceWrap(
                options: _personalLife,
                selected: _selectedPersonalLife,
                onSelected: (value) {
                  _toggleSelection(_selectedPersonalLife, value);
                },
              ),
              const SizedBox(height: 30),
              _SectionLabel(label: 'SIDE QUESTS'),
              const SizedBox(height: 8),
              Text(
                'What would you like to make more room for?',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.sub),
              ),
              const SizedBox(height: 14),
              _ChoiceWrap(
                options: _sideQuests,
                selected: _selectedSideQuests,
                onSelected: (value) {
                  _toggleSelection(_selectedSideQuests, value);
                },
              ),
              const SizedBox(height: 12),
              _CustomEntry(
                controller: _customSideQuestController,
                hintText: 'Something else you want to make time for',
                buttonLabel: 'Add',
                onAdd: _addCustomSideQuest,
              ),
              if (_customSideQuests.isNotEmpty) ...[
                const SizedBox(height: 10),
                _CustomItems(
                  items: _customSideQuests,
                  onRemove: (value) {
                    setState(() {
                      _customSideQuests.remove(value);
                      _selectedSideQuests.remove(value);
                    });
                  },
                ),
              ],
              const SizedBox(height: 36),
              FilledButton(
                onPressed: authProvider.isLoading ? null : _finishSetup,
                child: authProvider.isLoading
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Finish setup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onSelected;

  const _ChoiceWrap({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selected.contains(option);

        return _ChoiceChip(
          label: option,
          selected: isSelected,
          onTap: () => onSelected(option),
        );
      }).toList(),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.eucalyptus : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.eucalyptus : AppColors.line,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppColors.eucalyptusDark : AppColors.sub,
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomEntry extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String buttonLabel;
  final VoidCallback onAdd;

  const _CustomEntry({
    required this.controller,
    required this.hintText,
    required this.buttonLabel,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onAdd(),
            decoration: InputDecoration(hintText: hintText),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 42,
          child: FilledButton(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              minimumSize: const Size(58, 42),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: Text(buttonLabel),
          ),
        ),
      ],
    );
  }
}

class _CustomItems extends StatelessWidget {
  final List<String> items;
  final ValueChanged<String> onRemove;

  const _CustomItems({required this.items, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
          decoration: BoxDecoration(
            color: AppColors.pistachio,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => onRemove(item),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 14, color: AppColors.sub),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  final int step;

  const _OnboardingHeader({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.eucalyptus,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.eco_outlined,
            color: AppColors.eucalyptusDark,
            size: 20,
          ),
        ),
        const Spacer(),
        Text(
          '$step of 3',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.sub,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.sub,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: AppColors.sub,
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimeCard({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.sub,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_outlined,
                    size: 17,
                    color: AppColors.clayDark,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      time,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
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
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.eucalyptus : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 47,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.eucalyptus : AppColors.line,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.eucalyptusDark : AppColors.sub,
            ),
          ),
        ),
      ),
    );
  }
}
