[1mdiff --git a/lib/screens/home/home_screen.dart b/lib/screens/home/home_screen.dart[m
[1mindex 6b46fa1..1dae82e 100644[m
[1m--- a/lib/screens/home/home_screen.dart[m
[1m+++ b/lib/screens/home/home_screen.dart[m
[36m@@ -9,6 +9,7 @@[m [mimport '../../theme/app_theme.dart';[m
 import '../insights/insights_screen.dart';[m
 import '../profile/profile_screen.dart';[m
 import '../schedule/schedule_screen.dart';[m
[32m+[m[32mimport '../../models/activity_model.dart';[m
 [m
 class HomeScreen extends StatelessWidget {[m
   const HomeScreen({super.key});[m
[36m@@ -90,9 +91,17 @@[m [mclass HomeScreen extends StatelessWidget {[m
 [m
         return Scaffold([m
           backgroundColor: AppColors.ivory,[m
[32m+[m[32m          floatingActionButton: _HomeFab([m
[32m+[m[32m            onPressed: () {[m
[32m+[m[32m              _showActivityDialog([m
[32m+[m[32m                context,[m
[32m+[m[32m                user.uid,[m
[32m+[m[32m              );[m
[32m+[m[32m            },[m
[32m+[m[32m          ),[m
           body: SafeArea([m
             child: SingleChildScrollView([m
[31m-              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),[m
[32m+[m[32m              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),[m
               child: Column([m
                 crossAxisAlignment: CrossAxisAlignment.start,[m
                 children: [[m
[36m@@ -109,45 +118,65 @@[m [mclass HomeScreen extends StatelessWidget {[m
                       );[m
                     },[m
                   ),[m
[32m+[m[32m                  const SizedBox(height: 24),[m
[32m+[m
[32m+[m[32m                  _DailySnapshot([m
[32m+[m[32m                    userId: user.uid,[m
[32m+[m[32m                  ),[m
[32m+[m
[32m+[m[32m                  const SizedBox(height: 24),[m
[32m+[m
[32m+[m[32m                  _EnergyCheckInSection([m
[32m+[m[32m                    userId: user.uid,[m
[32m+[m[32m                  ),[m
[32m+[m
                   const SizedBox(height: 28),[m
[31m-                  const _TodayCard(),[m
[31m-                  const SizedBox(height: 28),[m
[32m+[m
                   const _SectionTitle([m
                     title: 'Today',[m
                     subtitle: 'A simple view of where your time goes.',[m
                   ),[m
                   const SizedBox(height: 14),[m
[32m+[m
                   _TimeOverview([m
                     workHours: workHours,[m
                     commuteMinutes: commuteMinutes,[m
                   ),[m
[32m+[m
                   const SizedBox(height: 28),[m
[31m-                  const _SectionTitle([m
[31m-                    title: 'Your schedule',[m
[31m-                    subtitle: 'Based on your usual workday.',[m
[32m+[m
[32m+[m[32m                  _HomeScheduleSection([m
[32m+[m[32m                    userId: user.uid,[m
                   ),[m
[31m-                  const SizedBox(height: 14),[m
[31m-                  _ScheduleCard([m
[31m-                    workStartTime: workStartTime,[m
[31m-                    workEndTime: workEndTime,[m
[32m+[m
[32m+[m[32m                  const SizedBox(height: 28),[m
[32m+[m
[32m+[m[32m                  _HomeActivitiesSection([m
[32m+[m[32m                    userId: user.uid,[m
                   ),[m
[32m+[m
                   const SizedBox(height: 28),[m
[32m+[m
                   const _SectionTitle([m
                     title: 'Side quest',[m
                     subtitle: 'Something worth making time for.',[m
                   ),[m
                   const SizedBox(height: 14),[m
[32m+[m
                   _SideQuestCard([m
                     sideQuests: _readStringList(data['sideQuests']),[m
                     customSideQuests:[m
                         _readStringList(data['customSideQuests']),[m
                   ),[m
[32m+[m
                   const SizedBox(height: 28),[m
[32m+[m
                   const _SectionTitle([m
                     title: 'This week',[m
                     subtitle: 'Your planned work-life structure.',[m
                   ),[m
                   const SizedBox(height: 14),[m
[32m+[m
                   _WeeklyOverview([m
                     workHours: weeklyWorkHours,[m
                     commuteHours: weeklyCommuteHours,[m
[36m@@ -266,6 +295,263 @@[m [mclass HomeScreen extends StatelessWidget {[m
 [m
     return hour + (minute / 60);[m
   }[m
[32m+[m
[32m+[m[32m  static Future<void> _showActivityDialog([m
[32m+[m[32m    BuildContext context,[m
[32m+[m[32m    String userId, {[m
[32m+[m[32m    DocumentSnapshot<Map<String, dynamic>>? existingActivity,[m
[32m+[m[32m  }) async {[m
[32m+[m[32m    final data = existingActivity?.data();[m
[32m+[m
[32m+[m[32m    final titleController = TextEditingController([m
[32m+[m[32m      text: data?['title']?.toString() ?? '',[m
[32m+[m[32m    );[m
[32m+[m
[32m+[m[32m    final notesController = TextEditingController([m
[32m+[m[32m      text: data?['notes']?.toString() ?? '',[m
[32m+[m[32m    );[m
[32m+[m
[32m+[m[32m    final durationController = TextEditingController([m
[32m+[m[32m      text: data?['durationMinutes']?.toString() ?? '',[m
[32m+[m[32m    );[m
[32m+[m
[32m+[m[32m    String category = data?['category']?.toString() ?? 'Personal';[m
[32m+[m
[32m+[m[32m    final categories = [[m
[32m+[m[32m      'Work',[m
[32m+[m[32m      'Health',[m
[32m+[m[32m      'Personal',[m
[32m+[m[32m      'Leisure',[m
[32m+[m[32m      'Learning',[m
[32m+[m[32m      'Other',[m
[32m+[m[32m    ];[m
[32m+[m
[32m+[m[32m    final isEditing = existingActivity != null;[m
[32m+[m
[32m+[m[32m    await showDialog<void>([m
[32m+[m[32m      context: context,[m
[32m+[m[32m      builder: (dialogContext) {[m
[32m+[m[32m        return StatefulBuilder([m
[32m+[m[32m          builder: (context, setDialogState) {[m
[32m+[m[32m            return AlertDialog([m
[32m+[m[32m              backgroundColor: AppColors.ivory,[m
[32m+[m[32m              title: Text([m
[32m+[m[32m                isEditing ? 'Edit activity' : 'Add activity',[m
[32m+[m[32m                style: GoogleFonts.fraunces([m
[32m+[m[32m                  fontSize: 22,[m
[32m+[m[32m                  fontWeight: FontWeight.w600,[m
[32m+[m[32m                  color: AppColors.ink,[m
[32m+[m[32m                ),[m
[32m+[m[32m              ),[m
[32m+[m[32m              content: SingleChildScrollView([m
[32m+[m[32m                child: Column([m
[32m+[m[32m                  mainAxisSize: MainAxisSize.min,[m
[32m+[m[32m                  crossAxisAlignment: CrossAxisAlignment.start,[m
[32m+[m[32m                  children: [[m
[32m+[m[32m                    TextField([m
[32m+[m[32m                      controller: titleController,[m
[32m+[m[32m                      decoration: const InputDecoration([m
[32m+[m[32m                        labelText: 'Activity',[m
[32m+[m[32m                        hintText: 'What do you want to do?',[m
[32m+[m[32m                      ),[m
[32m+[m[32m                    ),[m
[32m+[m[32m                    const SizedBox(height: 14),[m
[32m+[m[32m                    DropdownButtonFormField<String>([m
[32m+[m[32m                      initialValue: categories.contains(category)[m
[32m+[m[32m                          ? category[m
[32m+[m[32m                          : 'Personal',[m
[32m+[m[32m                      decoration: const InputDecoration([m
[32m+[m[32m                        labelText: 'Category',[m
[32m+[m[32m                      ),[m
[32m+[m[32m                      items: categories[m
[32m+[m[32m                          .map([m
[32m+[m[32m                            (item) => DropdownMenuItem([m
[32m+[m[32m                              value: item,[m
[32m+[m[32m                              child: Text(item),[m
[32m+[m[32m                            ),[m
[32m+[m[32m                          )[m
[32m+[m[32m                          .toList(),[m
[32m+[m[32m                      onChanged: (value) {[m
[32m+[m[32m                        if (value == null) return;[m
[32m+[m
[32m+[m[32m                        setDialogState(() {[m
[32m+[m[32m                          category = value;[m
[32m+[m[32m                        });[m
[32m+[m[32m                      },[m
[32m+[m[32m                    ),[m
[32m+[m[32m                    const SizedBox(height: 14),[m
[32m+[m[32m                    TextField([m
[32m+[m[32m                      controller: durationController,[m
[32m+[m[32m                      keyboardType: TextInputType.number,[m
[32m+[m[32m                      decoration: const InputDecoration([m
[32m+[m[32m                        labelText: 'Duration',[m
[32m+[m[32m                        hintText: 'Minutes',[m
[32m+[m[32m                      ),[m
[32m+[m[32m                    ),[m
[32m+[m[32m                    const SizedBox(height: 14),[m
[32m+[m[32m                    TextField([m
[32m+[m[32m                      controller: notesController,[m
[32m+[m[32m                      maxLines: 3,[m
[32m+[m[32m                      decoration: const InputDecoration([m
[32m+[m[32m                        labelText: 'Notes',[m
[32m+[m[32m                        hintText: 'Optional',[m
[32m+[m[32m                      ),[m
[32m+[m[32m                    ),[m
[32m+[m[32m                  ],[m
[32m+[m[32m                ),[m
[32m+[m[32m              ),[m
[32m+[m[32m              actions: [[m
[32m+[m[32m                TextButton([m
[32m+[m[32m                  onPressed: () {[m
[32m+[m[32m                    Navigator.pop(dialogContext);[m
[32m+[m[32m                  },[m
[32m+[m[32m                  child: const Text('Cancel'),[m
[32m+[m[32m                ),[m
[32m+[m[32m                FilledButton([m
[32m+[m[32m                  onPressed: () async {[m
[32m+[m[32m                    final title = titleController.text.trim();[m
[32m+[m
[32m+[m[32m                    if (title.isEmpty) {[m
[32m+[m[32m                      return;[m
[32m+[m[32m                    }[m
[32m+[m
[32m+[m[32m                    final durationText = durationController.text.trim();[m
[32m+[m[32m                    final duration = durationText.isEmpty[m
[32m+[m[32m                        ? 0[m
[32m+[m[32m                        : int.tryParse(durationText);[m
[32m+[m
[32m+[m[32m                    if (duration == null || duration < 0) {[m
[32m+[m[32m                      ScaffoldMessenger.of(context).showSnackBar([m
[32m+[m[32m                        const SnackBar([m
[32m+[m[32m                          content: Text('Please enter a valid duration in minutes.'),[m
[32m+[m[32m                        ),[m
[32m+[m[32m                      );[m
[32m+[m[32m                      return;[m
[32m+[m[32m                    }[m
[32m+[m[32m                    final service = FirestoreService();[m
[32m+[m
[32m+[m[32m                    if (isEditing) {[m
[32m+[m[32m                      final activityData = existingActivity!.data()!;[m
[32m+[m
[32m+[m[32m                      final dateString =[m
[32m+[m[32m                          activityData['date']?.toString();[m
[32m+[m
[32m+[m[32m                      final date = dateString != null[m
[32m+[m[32m                          ? _parseDateKey(dateString)[m
[32m+[m[32m                          : DateTime.now();[m
[32m+[m
[32m+[m[32m                      await service.updateActivity([m
[32m+[m[32m                        userId: userId,[m
[32m+[m[32m                        activityId: existingActivity.id,[m
[32m+[m[32m                        title: title,[m
[32m+[m[32m                        category: category,[m
[32m+[m[32m                        date: date,[m
[32m+[m[32m                        notes: notesController.text.trim(),[m
[32m+[m[32m                        durationMinutes: duration,[m
[32m+[m[32m                        completed:[m
[32m+[m[32m                            activityData['completed'] == true,[m
[32m+[m[32m                      );[m
[32m+[m[32m                    } else {[m
[32m+[m[32m                      await service.createActivity([m
[32m+[m[32m                        userId: userId,[m
[32m+[m[32m                        title: title,[m
[32m+[m[32m                        category: category,[m
[32m+[m[32m                        date: DateTime.now(),[m
[32m+[m[32m                        notes: notesController.text.trim(),[m
[32m+[m[32m                        durationMinutes: duration,[m
[32m+[m[32m                      );[m
[32m+[m[32m                    }[m
[32m+[m
[32m+[m[32m                    if (dialogContext.mounted) {[m
[32m+[m[32m                      Navigator.pop(dialogContext);[m
[32m+[m[32m                    }[m
[32m+[m[32m                  },[m
[32m+[m[32m                  child: Text([m
[32m+[m[32m                    isEditing ? 'Save changes' : 'Add activity',[m
[32m+[m[32m                  ),[m
[32m+[m[32m                ),[m
[32m+[m[32m              ],[m
[32m+[m[32m            );[m
[32m+[m[32m          },[m
[32m+[m[32m        );[m
[32m+[m[32m      },[m
[32m+[m[32m    );[m
[32m+[m
[32m+[m[32m    titleController.dispose();[m
[32m+[m[32m    notesController.dispose();[m
[32m+[m[32m    durationController.dispose();[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  static DateTime _parseDateKey(String value) {[m
[32m+[m[32m    final parts = value.split('-');[m
[32m+[m
[32m+[m[32m    if (parts.length != 3) {[m
[32m+[m[32m      return DateTime.now();[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    final year = int.tryParse(parts[0]);[m
[32m+[m[32m    final month = int.tryParse(parts[1]);[m
[32m+[m[32m    final day = int.tryParse(parts[2]);[m
[32m+[m
[32m+[m[32m    if (year == null || month == null || day == null) {[m
[32m+[m[32m      return DateTime.now();[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    return DateTime(year, month, day);[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  static Future<void> _deleteActivity([m
[32m+[m[32m    BuildContext context,[m
[32m+[m[32m    String userId,[m
[32m+[m[32m    String activityId,[m
[32m+[m[32m  ) async {[m
[32m+[m[32m    final shouldDelete = await showDialog<bool>([m
[32m+[m[32m      context: context,[m
[32m+[m[32m      builder: (dialogContext) {[m
[32m+[m[32m        return AlertDialog([m
[32m+[m[32m          backgroundColor: AppColors.ivory,[m
[32m+[m[32m          title: Text([m
[32m+[m[32m            'Delete activity?',[m
[32m+[m[32m            style: GoogleFonts.fraunces([m
[32m+[m[32m              fontSize: 21,[m
[32m+[m[32m              fontWeight: FontWeight.w600,[m
[32m+[m[32m              color: AppColors.ink,[m
[32m+[m[32m            ),[m
[32m+[m[32m          ),[m
[32m+[m[32m          content: Text([m
[32m+[m[32m            'This activity will be permanently removed.',[m
[32m+[m[32m            style: GoogleFonts.inter([m
[32m+[m[32m              fontSize: 13,[m
[32m+[m[32m              color: AppColors.sub,[m
[32m+[m[32m            ),[m
[32m+[m[32m          ),[m
[32m+[m[32m          actions: [[m
[32m+[m[32m            TextButton([m
[32m+[m[32m              onPressed: () {[m
[32m+[m[32m                Navigator.pop(dialogContext, false);[m
[32m+[m[32m              },[m
[32m+[m[32m              child: const Text('Cancel'),[m
[32m+[m[32m            ),[m
[32m+[m[32m            FilledButton([m
[32m+[m[32m              onPressed: () {[m
[32m+[m[32m                Navigator.pop(dialogContext, true);[m
[32m+[m[32m              },[m
[32m+[m[32m              child: const Text('Delete'),[m
[32m+[m[32m            ),[m
[32m+[m[32m          ],[m
[32m+[m[32m        );[m
[32m+[m[32m      },[m
[32m+[m[32m    );[m
[32m+[m
[32m+[m[32m    if (shouldDelete != true) {[m
[32m+[m[32m      return;[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    await FirestoreService().deleteActivity([m
[32m+[m[32m      userId: userId,[m
[32m+[m[32m      activityId: activityId,[m
[32m+[m[32m    );[m
[32m+[m[32m  }[m
 }[m
 [m
 class _HomeHeader extends StatelessWidget {[m
[36m@@ -347,191 +633,114 @@[m [mclass _HomeHeader extends StatelessWidget {[m
   }[m
 }[m
 [m
[31m-class _TodayCard extends StatelessWidget {[m
[31m-  const _TodayCard();[m
[31m-[m
[31m-  @override[m
[31m-  Widget build(BuildContext context) {[m
[31m-    return Container([m
[31m-      width: double.infinity,[m
[31m-      padding: const EdgeInsets.all(20),[m
[31m-      decoration: BoxDecoration([m
[31m-        color: AppColors.eucalyptus,[m
[31m-        borderRadius: BorderRadius.circular(22),[m
[31m-      ),[m
[31m-      child: Row([m
[31m-        children: [[m
[31m-          Expanded([m
[31m-            child: Column([m
[31m-              crossAxisAlignment: CrossAxisAlignment.start,[m
[31m-              children: [[m
[31m-                Text([m
[31m-                  'TODAY',[m
[31m-                  style: GoogleFonts.inter([m
[31m-                    fontSize: 10,[m
[31m-                    fontWeight: FontWeight.w700,[m
[31m-                    letterSpacing: 1,[m
[31m-                    color: AppColors.eucalyptusDark,[m
[31m-                  ),[m
[31m-                ),[m
[31m-                const SizedBox(height: 8),[m
[31m-                Text([m
[31m-                  'Make space for life.',[m
[31m-                  style: GoogleFonts.fraunces([m
[31m-                    fontSize: 22,[m
[31m-                    fontWeight: FontWeight.w600,[m
[31m-                    color: AppColors.ink,[m
[31m-                  ),[m
[31m-                ),[m
[31m-                const SizedBox(height: 7),[m
[31m-                Text([m
[31m-                  'Track your day without letting the day track you.',[m
[31m-                  style: GoogleFonts.inter([m
[31m-                    fontSize: 11.5,[m
[31m-                    height: 1.45,[m
[31m-                    color: AppColors.eucalyptusDark,[m
[31m-                  ),[m
[31m-                ),[m
[31m-              ],[m
[31m-            ),[m
[31m-          ),[m
[31m-          const SizedBox(width: 16),[m
[31m-          Container([m
[31m-            width: 58,[m
[31m-            height: 58,[m
[31m-            decoration: BoxDecoration([m
[31m-              color: Colors.white.withValues(alpha: 0.55),[m
[31m-              shape: BoxShape.circle,[m
[31m-            ),[m
[31m-            child: const Icon([m
[31m-              Icons.eco_outlined,[m
[31m-              color: AppColors.eucalyptusDark,[m
[31m-              size: 28,[m
[31m-            ),[m
[31m-          ),[m
[31m-        ],[m
[31m-      ),[m
[31m-    );[m
[31m-  }[m
[31m-}[m
[31m-[m
[31m-class _SectionTitle extends StatelessWidget {[m
[31m-  final String title;[m
[31m-  final String subtitle;[m
[32m+[m[32mclass _DailySnapshot extends StatelessWidget {[m
[32m+[m[32m  final String userId;[m
 [m
[31m-  const _SectionTitle({[m
[31m-    required this.title,[m
[31m-    required this.subtitle,[m
[32m+[m[32m  const _DailySnapshot({[m
[32m+[m[32m    required this.userId,[m
   });[m
 [m
   @override[m
   Widget build(BuildContext context) {[m
[31m-    return Column([m
[31m-      crossAxisAlignment: CrossAxisAlignment.start,[m
[31m-      children: [[m
[31m-        Text([m
[31m-          title,[m
[31m-          style: GoogleFonts.fraunces([m
[31m-            fontSize: 20,[m
[31m-            fontWeight: FontWeight.w600,[m
[31m-            color: AppColors.ink,[m
[31m-          ),[m
[31m-        ),[m
[31m-        const SizedBox(height: 3),[m
[31m-        Text([m
[31m-          subtitle,[m
[31m-          style: GoogleFonts.inter([m
[31m-            fontSize: 11.5,[m
[31m-            color: AppColors.sub,[m
[31m-          ),[m
[31m-        ),[m
[31m-      ],[m
[31m-    );[m
[31m-  }[m
[31m-}[m
[31m-[m
[31m-class _TimeOverview extends StatelessWidget {[m
[31m-  final double workHours;[m
[31m-  final int commuteMinutes;[m
[32m+[m[32m    final today = DateTime.now();[m
 [m
[31m-  const _TimeOverview({[m
[31m-    required this.workHours,[m
[31m-    required this.commuteMinutes,[m
[31m-  });[m
[32m+[m[32m    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>([m
[32m+[m[32m      stream: FirestoreService().dailyCheckIn([m
[32m+[m[32m        userId,[m
[32m+[m[32m        today,[m
[32m+[m[32m      ),[m
[32m+[m[32m      builder: (context, checkInSnapshot) {[m
[32m+[m[32m        final checkInData = checkInSnapshot.data?.data();[m
 [m
[31m-  String _formatHours(double hours) {[m
[31m-    if (hours == hours.roundToDouble()) {[m
[31m-      return '${hours.toInt()}h';[m
[31m-    }[m
[32m+[m[32m        final energy = checkInData?['energyScore'];[m
 [m
[31m-    return '${hours.toStringAsFixed(1)}h';[m
[31m-  }[m
[32m+[m[32m        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>([m
[32m+[m[32m          stream: FirestoreService().activeGoals(userId),[m
[32m+[m[32m          builder: (context, goalSnapshot) {[m
[32m+[m[32m            final goals = goalSnapshot.data?.docs ?? [];[m
 [m
[31m-  String _formatCommute(int minutes) {[m
[31m-    if (minutes >= 60) {[m
[31m-      final hours = minutes ~/ 60;[m
[31m-      final remaining = minutes % 60;[m
[32m+[m[32m            final todayKey = _dateKey(today);[m
 [m
[31m-      if (remaining == 0) {[m
[31m-        return '${hours}h';[m
[31m-      }[m
[32m+[m[32m            final todayGoals = goals.where((goal) {[m
[32m+[m[32m              return goal.data()['date']?.toString() == todayKey;[m
[32m+[m[32m            }).toList();[m
 [m
[31m-      return '${hours}h ${remaining}m';[m
[31m-    }[m
[32m+[m[32m            final completedGoals = todayGoals.where((goal) {[m
[32m+[m[32m              return goal.data()['completed'] == true;[m
[32m+[m[32m            }).length;[m
 [m
[31m-    return '${minutes}m';[m
[32m+[m[32m            return Row([m
[32m+[m[32m              children: [[m
[32m+[m[32m                Expanded([m
[32m+[m[32m                  child: _SnapshotCard([m
[32m+[m[32m                    icon: Icons.bolt_outlined,[m
[32m+[m[32m                    label: 'Energy',[m
[32m+[m[32m                    value: checkInSnapshot.hasError[m
[32m+[m[32m                      ? '—'[m
[32m+[m[32m                      : energy is num[m
[32m+[m[32m                        ? '${energy.round()}/10'[m
[32m+[m[32m                        : '—',[m
[32m+[m[32m                    subtitle: checkInSnapshot.hasError[m
[32m+[m[32m                      ? 'Could not load'[m
[32m+[m[32m                      : energy is num[m
[32m+[m[32m                        ? 'Logged today'[m
[32m+[m[32m                        : 'Not checked in',[m
[32m+[m[32m                  ),[m
[32m+[m[32m                ),[m
[32m+[m[32m                const SizedBox(width: 10),[m
[32m+[m[32m                Expanded([m
[32m+[m[32m                  child: _SnapshotCard([m
[32m+[m[32m                    icon: Icons.flag_outlined,[m
[32m+[m[32m                    label: "Today's goals",[m
[32m+[m[32m                    value: goalSnapshot.hasError[m
[32m+[m[32m                      ? '—'[m
[32m+[m[32m                      : '${completedGoals}/${todayGoals.length}',[m
[32m+[m[32m                    subtitle: goalSnapshot.hasError[m
[32m+[m[32m                      ? 'Could not load'[m
[32m+[m[32m                      : todayGoals.isEmpty[m
[32m+[m[32m                        ? 'No goals yet'[m
[32m+[m[32m                        : completedGoals == todayGoals.length[m
[32m+[m[32m                            ? 'All complete'[m
[32m+[m[32m                            : 'Keep going',[m
[32m+[m[32m                  ),[m
[32m+[m[32m                ),[m
[32m+[m[32m              ],[m
[32m+[m[32m            );[m
[32m+[m[32m          },[m
[32m+[m[32m        );[m
[32m+[m[32m      },[m
[32m+[m[32m    );[m
   }[m
 [m
[31m-  @override[m
[31m-  Widget build(BuildContext context) {[m
[31m-    return Row([m
[31m-      children: [[m
[31m-        Expanded([m
[31m-          child: _TimeTile([m
[31m-            icon: Icons.work_outline,[m
[31m-            label: 'Work',[m
[31m-            value: _formatHours(workHours),[m
[31m-          ),[m
[31m-        ),[m
[31m-        const SizedBox(width: 10),[m
[31m-        Expanded([m
[31m-          child: _TimeTile([m
[31m-            icon: Icons.directions_car_outlined,[m
[31m-            label: 'Commute',[m
[31m-            value: _formatCommute(commuteMinutes),[m
[31m-          ),[m
[31m-        ),[m
[31m-        const SizedBox(width: 10),[m
[31m-        const Expanded([m
[31m-          child: _TimeTile([m
[31m-            icon: Icons.bed_outlined,[m
[31m-            label: 'Sleep',[m
[31m-            value: '—',[m
[31m-          ),[m
[31m-        ),[m
[31m-      ],[m
[31m-    );[m
[32m+[m[32m  static String _dateKey(DateTime date) {[m
[32m+[m[32m    final year = date.year.toString().padLeft(4, '0');[m
[32m+[m[32m    final month = date.month.toString().padLeft(2, '0');[m
[32m+[m[32m    final day = date.day.toString().padLeft(2, '0');[m
[32m+[m
[32m+[m[32m    return '$year-$month-$day';[m
   }[m
 }[m
 [m
[31m-class _TimeTile extends StatelessWidget {[m
[32m+[m[32mclass _SnapshotCard extends StatelessWidget {[m
   final IconData icon;[m
   final String label;[m
   final String value;[m
[32m+[m[32m  final String subtitle;[m
 [m
[31m-  const _TimeTile({[m
[32m+[m[32m  const _SnapshotCard({[m
     required this.icon,[m
     required this.label,[m
     required this.value,[m
[32m+[m[32m    required this.subtitle,[m
   });[m
 [m
   @override[m
   Widget build(BuildContext context) {[m
     return Container([m
[31m-      padding: const EdgeInsets.fromLTRB(12, 14, 12, 13),[m
[32m+[m[32m      padding: const EdgeInsets.fromLTRB(14, 15, 14, 14),[m
       decoration: BoxDecoration([m
         color: Colors.white,[m
[31m-        borderRadius: BorderRadius.circular(16),[m
[32m+[m[32m        borderRadius: BorderRadius.circular(17),[m
         border: Border.all([m
           color: AppColors.line,[m
         ),[m
[36m@@ -541,14 +750,14 @@[m [mclass _TimeTile extends StatelessWidget {[m
         children: [[m
           Icon([m
             icon,[m
[31m-            size: 18,[m
[32m+[m[32m            size: 19,[m
             color: AppColors.clayDark,[m
           ),[m
[31m-          const SizedBox(height: 12),[m
[32m+[m[32m          const SizedBox(height: 11),[m
           Text([m
             value,[m
             style: GoogleFonts.fraunces([m
[31m-              fontSize: 20,[m
[32m+[m[32m              fontSize: 22,[m
               fontWeight: FontWeight.w600,[m
               color: AppColors.ink,[m
             ),[m
[36m@@ -558,6 +767,15 @@[m [mclass _TimeTile extends StatelessWidget {[m
             label,[m
             style: GoogleFonts.inter([m
               fontSize: 10.5,[m
[32m+[m[32m              fontWeight: FontWeight.w600,[m
[32m+[m[32m              color: AppColors.ink,[m
[32m+[m[32m            ),[m
[32m+[m[32m          ),[m
[32m+[m[32m          const SizedBox(height: 2),[m
[32m+[m[32m          Text([m
[32m+[m[32m            subtitle,[m
[32m+[m[32m            style: GoogleFonts.inter([m
[32m+[m[32m              fontSize: 9.5,[m
               color: AppColors.sub,[m
             ),[m
           ),[m
[36m@@ -567,47 +785,255 @@[m [mclass _TimeTile extends StatelessWidget {[m
   }[m
 }[m
 [m
[31m-class _ScheduleCard extends StatelessWidget {[m
[31m-  final String workStartTime;[m
[31m-  final String workEndTime;[m
[32m+[m[32mclass _EnergyCheckInSection extends StatelessWidget {[m
[32m+[m[32m  final String userId;[m
 [m
[31m-  const _ScheduleCard({[m
[31m-    required this.workStartTime,[m
[31m-    required this.workEndTime,[m
[32m+[m[32m  const _EnergyCheckInSection({[m
[32m+[m[32m    required this.userId,[m
   });[m
 [m
   @override[m
   Widget build(BuildContext context) {[m
[31m-    return Container([m
[31m-      decoration: BoxDecoration([m
[31m-        color: Colors.white,[m
[31m-        borderRadius: BorderRadius.circular(18),[m
[31m-        border: Border.all([m
[31m-          color: AppColors.line,[m
[31m-        ),[m
[32m+[m[32m    final today = DateTime.now();[m
[32m+[m
[32m+[m[32m    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>([m
[32m+[m[32m      stream: FirestoreService().dailyCheckIn([m
[32m+[m[32m        userId,[m
[32m+[m[32m        today,[m
[32m+[m[32m      ),[m
[32m+[m[32m      builder: (context, snapshot) {[m
[32m+[m[32m        if (snapshot.hasError) {[m
[32m+[m[32m          return const _HomeLoadError([m
[32m+[m[32m            message: 'Energy check-in could not be loaded.',[m
[32m+[m[32m          );[m
[32m+[m[32m        }[m
[32m+[m
[32m+[m[32m        final data = snapshot.data?.data();[m
[32m+[m
[32m+[m[32m        if (data == null) {[m
[32m+[m[32m          return _EnergyPrompt([m
[32m+[m[32m            onRate: (score) async {[m
[32m+[m[32m              await FirestoreService().createOrUpdateDailyCheckIn([m
[32m+[m[32m                userId: userId,[m
[32m+[m[32m                date: today,[m
[32m+[m[32m                energyScore: score,[m
[32m+[m[32m              );[m
[32m+[m[32m            },[m
[32m+[m[32m          );[m
[32m+[m[32m        }[m
[32m+[m
[32m+[m[32m        final rawScore = data['energyScore'];[m
[32m+[m[32m        final score = rawScore is num ? rawScore.round() : 0;[m
[32m+[m
[32m+[m[32m        return _EnergyLoggedCard([m
[32m+[m[32m          score: score,[m
[32m+[m[32m          onEdit: () {[m
[32m+[m[32m            _showEnergyDialog([m
[32m+[m[32m              context,[m
[32m+[m[32m              userId,[m
[32m+[m[32m              existingScore: score,[m
[32m+[m[32m            );[m
[32m+[m[32m          },[m
[32m+[m[32m          onDelete: () async {[m
[32m+[m[32m            await FirestoreService().deleteDailyCheckIn([m
[32m+[m[32m              userId: userId,[m
[32m+[m[32m              date: today,[m
[32m+[m[32m            );[m
[32m+[m[32m          },[m
[32m+[m[32m        );[m
[32m+[m[32m      },[m
[32m+[m[32m    );[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  static Future<void> _showEnergyDialog([m
[32m+[m[32m    BuildContext context,[m
[32m+[m[32m    String userId, {[m
[32m+[m[32m    int? existingScore,[m
[32m+[m[32m  }) async {[m
[32m+[m[32m    var selectedScore = existingScore ?? 5;[m
[32m+[m
[32m+[m[32m    await showDialog<void>([m
[32m+[m[32m      context: context,[m
[32m+[m[32m      builder: (dialogContext) {[m
[32m+[m[32m        return StatefulBuilder([m
[32m+[m[32m          builder: (context, setState) {[m
[32m+[m[32m            return AlertDialog([m
[32m+[m[32m              backgroundColor: AppColors.ivory,[m
[32m+[m[32m              title: Text([m
[32m+[m[32m                existingScore == null[m
[32m+[m[32m                    ? 'How are you feeling?'[m
[32m+[m[32m                    : 'Update your energy',[m
[32m+[m[32m                style: GoogleFonts.fraunces([m
[32m+[m[32m                  fontSize: 22,[m
[32m+[m[32m                  fontWeight: FontWeight.w600,[m
[32m+[m[32m                  color: AppColors.ink,[m
[32m+[m[32m                ),[m
[32m+[m[32m              ),[m
[32m+[m[32m              content: Column([m
[32m+[m[32m                mainAxisSize: MainAxisSize.min,[m
[32m+[m[32m                children: [[m
[32m+[m[32m                  Text([m
[32m+[m[32m                    '$selectedScore / 10',[m
[32m+[m[32m                    style: GoogleFonts.fraunces([m
[32m+[m[32m                      fontSize: 34,[m
[32m+[m[32m                      fontWeight: FontWeight.w600,[m
[32m+[m[32m                      color: AppColors.clayDark,[m
[32m+[m[32m                    ),[m
[32m+[m[32m                  ),[m
[32m+[m[32m                  const SizedBox(height: 12),[m
[32m+[m[32m                  Slider([m
[32m+[m[32m                    value: selectedScore.toDouble(),[m
[32m+[m[32m                    min: 1,[m
[32m+[m[32m                    max: 10,[m
[32m+[m[32m                    divisions: 9,[m
[32m+[m[32m                    activeColor: AppColors.clay,[m
[32m+[m[32m                    onChanged: (value) {[m
[32m+[m[32m                      setState(() {[m
[32m+[m[32m                        selectedScore = value.round();[m
[32m+[m[32m                      });[m
[32m+[m[32m                    },[m
[32m+[m[32m                  ),[m
[32m+[m[32m                  const Row([m
[32m+[m[32m                    mainAxisAlignment: MainAxisAlignment.spaceBetween,[m
[32m+[m[32m                    children: [[m
[32m+[m[32m                      Text('Low'),[m
[32m+[m[32m                      Text('High'),[m
[32m+[m[32m                    ],[m
[32m+[m[32m                  ),[m
[32m+[m[32m                ],[m
[32m+[m[32m              ),[m
[32m+[m[32m              actions: [[m
[32m+[m[32m                TextButton([m
[32m+[m[32m                  onPressed: () {[m
[32m+[m[32m                    Navigator.pop(dialogContext);[m
[32m+[m[32m                  },[m
[32m+[m[32m                  child: const Text('Cancel'),[m
[32m+[m[32m                ),[m
[32m+[m[32m                FilledButton([m
[32m+[m[32m                  onPressed: () async {[m
[32m+[m[32m                    await FirestoreService().createOrUpdateDailyCheckIn([m
[32m+[m[32m                      userId: userId,[m
[32m+[m[32m                      date: DateTime.now(),[m
[32m+[m[32m                      energyScore: selectedScore,[m
[32m+[m[32m                    );[m
[32m+[m
[32m+[m[32m                    if (dialogContext.mounted) {[m
[32m+[m[32m                      Navigator.pop(dialogContext);[m
[32m+[m[32m                    }[m
[32m+[m[32m                  },[m
[32m+[m[32m                  child: const Text('Save'),[m
[32m+[m[32m                ),[m
[32m+[m[32m              ],[m
[32m+[m[32m            );[m
[32m+[m[32m          },[m
[32m+[m[32m        );[m
[32m+[m[32m      },[m
[32m+[m[32m    );[m
[32m+[m[32m  }[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mclass _EnergyPrompt extends StatelessWidget {[m
[32m+[m[32m  final Future<void> Function(int score) onRate;[m
[32m+[m
[32m+[m[32m  const _EnergyPrompt({[m
[32m+[m[32m    required this.onRate,[m
[32m+[m[32m  });[m
[32m+[m
[32m+[m[32m  @override[m
[32m+[m[32m  Widget build(BuildContext context) {[m
[32m+[m[32m    return Container([m
[32m+[m[32m      width: double.infinity,[m
[32m+[m[32m      padding: const EdgeInsets.all(18),[m
[32m+[m[32m      decoration: BoxDecoration([m
[32m+[m[32m        color: AppColors.peach,[m
[32m+[m[32m        borderRadius: BorderRadius.circular(18),[m
[32m+[m[32m        border: Border.all([m
[32m+[m[32m          color: AppColors.line,[m
[32m+[m[32m        ),[m
       ),[m
       child: Column([m
[32m+[m[32m        crossAxisAlignment: CrossAxisAlignment.start,[m
         children: [[m
[31m-          _ScheduleItem([m
[31m-            time: workStartTime,[m
[31m-            title: 'Work starts',[m
[31m-            subtitle: 'Your usual workday',[m
[31m-            icon: Icons.work_outline,[m
[31m-            isLast: false,[m
[31m-          ),[m
[31m-          const _ScheduleItem([m
[31m-            time: '12:00 PM',[m
[31m-            title: 'Lunch',[m
[31m-            subtitle: 'Take a proper break',[m
[31m-            icon: Icons.restaurant_outlined,[m
[31m-            isLast: false,[m
[31m-          ),[m
[31m-          _ScheduleItem([m
[31m-            time: workEndTime,[m
[31m-            title: 'Work ends',[m
[31m-            subtitle: 'Time to transition out of work',[m
[31m-            icon: Icons.logout_outlined,[m
[31m-            isLast: true,[m
[32m+[m[32m          Row([m
[32m+[m[32m            children: [[m
[32m+[m[32m              Container([m
[32m+[m[32m                width: 38,[m
[32m+[m[32m                height: 38,[m
[32m+[m[32m                decoration: BoxDecoration([m
[32m+[m[32m                  color: Colors.white.withValues(alpha: 0.7),[m
[32m+[m[32m                  borderRadius: BorderRadius.circular(11),[m
[32m+[m[32m                ),[m
[32m+[m[32m                child: const Icon([m
[32m+[m[32m                  Icons.bolt_outlined,[m
[32m+[m[32m                  color: AppColors.clayDark,[m
[32m+[m[32m                  size: 20,[m
[32m+[m[32m                ),[m
[32m+[m[32m              ),[m
[32m+[m[32m              const SizedBox(width: 12),[m
[32m+[m[32m              Expanded([m
[32m+[m[32m                child: Column([m
[32m+[m[32m                  crossAxisAlignment: CrossAxisAlignment.start,[m
[32m+[m[32m                  children: [[m
[32m+[m[32m                    Text([m
[32m+[m[32m                      'ENERGY CHECK-IN',[m
[32m+[m[32m                      style: GoogleFonts.inter([m
[32m+[m[32m                        fontSize: 9.5,[m
[32m+[m[32m                        fontWeight: FontWeight.w700,[m
[32m+[m[32m                        letterSpacing: 0.7,[m
[32m+[m[32m                        color: AppColors.clayDark,[m
[32m+[m[32m                      ),[m
[32m+[m[32m                    ),[m
[32m+[m[32m                    const SizedBox(height: 4),[m
[32m+[m[32m                    Text([m
[32m+[m[32m                      'How are you feeling today?',[m
[32m+[m[32m                      style: GoogleFonts.inter([m
[32m+[m[32m                        fontSize: 12.5,[m
[32m+[m[32m                        fontWeight: FontWeight.w600,[m
[32m+[m[32m                        color: AppColors.ink,[m
[32m+[m[32m                      ),[m
[32m+[m[32m                    ),[m
[32m+[m[32m                  ],[m
[32m+[m[32m                ),[m
[32m+[m[32m              ),[m
[32m+[m[32m            ],[m
[32m+[m[32m          ),[m
[32m+[m[32m          const SizedBox(height: 16),[m
[32m+[m[32m          Wrap([m
[32m+[m[32m            spacing: 7,[m
[32m+[m[32m            runSpacing: 7,[m
[32m+[m[32m            children: List.generate([m
[32m+[m[32m              10,[m
[32m+[m[32m              (index) {[m
[32m+[m[32m                final score = index + 1;[m
[32m+[m
[32m+[m[32m                return SizedBox([m
[32m+[m[32m                  width: 42,[m
[32m+[m[32m                  height: 40,[m
[32m+[m[32m                  child: OutlinedButton([m
[32m+[m[32m                    onPressed: () async {[m
[32m+[m[32m                      await onRate(score);[m
[32m+[m[32m                    },[m
[32m+[m[32m                    style: OutlinedButton.styleFrom([m
[32m+[m[32m                      padding: EdgeInsets.zero,[m
[32m+[m[32m                      side: BorderSide([m
[32m+[m[32m                        color: AppColors.clay.withValues(alpha: 0.35),[m
[32m+[m[32m                      ),[m
[32m+[m[32m                      foregroundColor: AppColors.clayDark,[m
[32m+[m[32m                      shape: RoundedRectangleBorder([m
[32m+[m[32m                        borderRadius: BorderRadius.circular(10),[m
[32m+[m[32m                      ),[m
[32m+[m[32m                    ),[m
[32m+[m[32m                    child: Text([m
[32m+[m[32m                      '$score',[m
[32m+[m[32m                      style: GoogleFonts.inter([m
[32m+[m[32m                        fontSize: 12,[m
[32m+[m[32m                        fontWeight: FontWeight.w600,[m
[32m+[m[32m                      ),[m
[32m+[m[32m                    ),[m
[32m+[m[32m                  ),[m
[32m+[m[32m                );[m
[32m+[m[32m              },[m
[32m+[m[32m            ),[m
           ),[m
         ],[m
       ),[m
[36m@@ -615,32 +1041,257 @@[m [mclass _ScheduleCard extends StatelessWidget {[m
   }[m
 }[m
 [m
[31m-class _ScheduleItem extends StatelessWidget {[m
[31m-  final String time;[m
[31m-  final String title;[m
[31m-  final String subtitle;[m
[31m-  final IconData icon;[m
[32m+[m[32mclass _EnergyLoggedCard extends StatelessWidget {[m
[32m+[m[32m  final int score;[m
[32m+[m[32m  final VoidCallback onEdit;[m
[32m+[m[32m  final VoidCallback onDelete;[m
[32m+[m
[32m+[m[32m  const _EnergyLoggedCard({[m
[32m+[m[32m    required this.score,[m
[32m+[m[32m    required this.onEdit,[m
[32m+[m[32m    required this.onDelete,[m
[32m+[m[32m  });[m
[32m+[m
[32m+[m[32m  @override[m
[32m+[m[32m  Widget build(BuildContext context) {[m
[32m+[m[32m    return Container([m
[32m+[m[32m      width: double.infinity,[m
[32m+[m[32m      padding: const EdgeInsets.all(17),[m
[32m+[m[32m      decoration: BoxDecoration([m
[32m+[m[32m        color: AppColors.eucalyptus,[m
[32m+[m[32m        borderRadius: BorderRadius.circular(18),[m
[32m+[m[32m      ),[m
[32m+[m[32m      child: Row([m
[32m+[m[32m        children: [[m
[32m+[m[32m          Container([m
[32m+[m[32m            width: 46,[m
[32m+[m[32m            height: 46,[m
[32m+[m[32m            decoration: BoxDecoration([m
[32m+[m[32m              color: Colors.white.withValues(alpha: 0.6),[m
[32m+[m[32m              shape: BoxShape.circle,[m
[32m+[m[32m            ),[m
[32m+[m[32m            child: Center([m
[32m+[m[32m              child: Text([m
[32m+[m[32m                '$score',[m
[32m+[m[32m                style: GoogleFonts.fraunces([m
[32m+[m[32m                  fontSize: 20,[m
[32m+[m[32m                  fontWeight: FontWeight.w600,[m
[32m+[m[32m                  color: AppColors.eucalyptusDark,[m
[32m+[m[32m                ),[m
[32m+[m[32m              ),[m
[32m+[m[32m            ),[m
[32m+[m[32m          ),[m
[32m+[m[32m          const SizedBox(width: 13),[m
[32m+[m[32m          Expanded([m
[32m+[m[32m            child: Column([m
[32m+[m[32m              crossAxisAlignment: CrossAxisAlignment.start,[m
[32m+[m[32m              children: [[m
[32m+[m[32m                Text([m
[32m+[m[32m                  'TODAY’S ENERGY',[m
[32m+[m[32m                  style: GoogleFonts.inter([m
[32m+[m[32m                    fontSize: 9.5,[m
[32m+[m[32m                    fontWeight: FontWeight.w700,[m
[32m+[m[32m                    letterSpacing: 0.7,[m
[32m+[m[32m                    color: AppColors.eucalyptusDark,[m
[32m+[m[32m                  ),[m
[32m+[m[32m                ),[m
[32m+[m[32m                const SizedBox(height: 4),[m
[32m+[m[32m                Text([m
[32m+[m[32m                  _energyMessage(score),[m
[32m+[m[32m                  style: GoogleFonts.inter([m
[32m+[m[32m                    fontSize: 12,[m
[32m+[m[32m                    fontWeight: FontWeight.w600,[m
[32m+[m[32m                    color: AppColors.ink,[m
[32m+[m[32m                  ),[m
[32m+[m[32m                ),[m
[32m+[m[32m              ],[m
[32m+[m[32m            ),[m
[32m+[m[32m          ),[m
[32m+[m[32m          PopupMenuButton<String>([m
[32m+[m[32m            icon: const Icon([m
[32m+[m[32m              Icons.more_horiz,[m
[32m+[m[32m              color: AppColors.eucalyptusDark,[m
[32m+[m[32m            ),[m
[32m+[m[32m            onSelected: (value) {[m
[32m+[m[32m              if (value == 'edit') {[m
[32m+[m[32m                onEdit();[m
[32m+[m[32m              } else if (value == 'delete') {[m
[32m+[m[32m                onDelete();[m
[32m+[m[32m              }[m
[32m+[m[32m            },[m
[32m+[m[32m            itemBuilder: (context) => const [[m
[32m+[m[32m              PopupMenuItem([m
[32m+[m[32m                value: 'edit',[m
[32m+[m[32m                child: Text('Update'),[m
[32m+[m[32m              ),[m
[32m+[m[32m              PopupMenuItem([m
[32m+[m[32m                value: 'delete',[m
[32m+[m[32m                child: Text('Delete'),[m
[32m+[m[32m              ),[m
[32m+[m[32m            ],[m
[32m+[m[32m          ),[m
[32m+[m[32m        ],[m
[32m+[m[32m      ),[m
[32m+[m[32m    );[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  String _energyMessage(int score) {[m
[32m+[m[32m    if (score <= 3) {[m
[32m+[m[32m      return 'Running a little low today.';[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    if (score <= 6) {[m
[32m+[m[32m      return 'You’re somewhere in the middle.';[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    if (score <= 8) {[m
[32m+[m[32m      return 'You’re feeling pretty good today.';[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    return 'You’re feeling energized today.';[m
[32m+[m[32m  }[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mclass _HomeScheduleSection extends StatelessWidget {[m
[32m+[m[32m  final String userId;[m
[32m+[m
[32m+[m[32m  const _HomeScheduleSection({[m
[32m+[m[32m    required this.userId,[m
[32m+[m[32m  });[m
[32m+[m
[32m+[m[32m  @override[m
[32m+[m[32m  Widget build(BuildContext context) {[m
[32m+[m[32m    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>([m
[32m+[m[32m      stream: FirestoreService().scheduleForDate([m
[32m+[m[32m        userId,[m
[32m+[m[32m        DateTime.now(),[m
[32m+[m[32m      ),[m
[32m+[m[32m      builder: (context, snapshot) {[m
[32m+[m[32m        final events = snapshot.data?.docs ?? [];[m
[32m+[m
[32m+[m[32m        final sortedEvents = [...events][m
[32m+[m[32m          ..sort([m
[32m+[m[32m            (a, b) {[m
[32m+[m[32m              final aMinutes = _readInt([m
[32m+[m[32m                a.data()['startMinutes'],[m
[32m+[m[32m              );[m
[32m+[m
[32m+[m[32m              final bMinutes = _readInt([m
[32m+[m[32m                b.data()['startMinutes'],[m
[32m+[m[32m              );[m
[32m+[m
[32m+[m[32m              return aMinutes.compareTo(bMinutes);[m
[32m+[m[32m            },[m
[32m+[m[32m          );[m
[32m+[m
[32m+[m[32m        final previewEvents = sortedEvents.take(3).toList();[m
[32m+[m
[32m+[m[32m        return Column([m
[32m+[m[32m          crossAxisAlignment: CrossAxisAlignment.start,[m
[32m+[m[32m          children: [[m
[32m+[m[32m            Row([m
[32m+[m[32m              crossAxisAlignment: CrossAxisAlignment.end,[m
[32m+[m[32m              children: [[m
[32m+[m[32m                const Expanded([m
[32m+[m[32m                  child: _SectionTitle([m
[32m+[m[32m                    title: 'Your schedule',[m
[32m+[m[32m                    subtitle: 'What’s coming up today.',[m
[32m+[m[32m                  ),[m
[32m+[m[32m                ),[m
[32m+[m[32m                TextButton([m
[32m+[m[32m                  onPressed: () {[m
[32m+[m[32m                    Navigator.of(context).pushReplacement([m
[32m+[m[32m                      MaterialPageRoute([m
[32m+[m[32m                        builder: (_) => const ScheduleScreen(),[m
[32m+[m[32m                      ),[m
[32m+[m[32m                    );[m
[32m+[m[32m                  },[m
[32m+[m[32m                  child: Text([m
[32m+[m[32m                    'See all',[m
[32m+[m[32m                    style: GoogleFonts.inter([m
[32m+[m[32m                      fontSize: 11,[m
[32m+[m[32m                      fontWeight: FontWeight.w600,[m
[32m+[m[32m                      color: AppColors.eucalyptusDark,[m
[32m+[m[32m                    ),[m
[32m+[m[32m                  ),[m
[32m+[m[32m                ),[m
[32m+[m[32m              ],[m
[32m+[m[32m            ),[m
[32m+[m[32m            const SizedBox(height: 10),[m
[32m+[m[32m            if (snapshot.hasError)[m
[32m+[m[32m              const _HomeLoadError([m
[32m+[m[32m                message: 'Your schedule could not be loaded.',[m
[32m+[m[32m              )[m
[32m+[m[32m            else if (previewEvents.isEmpty)[m
[32m+[m[32m              _EmptyScheduleCard([m
[32m+[m[32m                onAdd: () {[m
[32m+[m[32m                  Navigator.of(context).pushReplacement([m
[32m+[m[32m                    MaterialPageRoute([m
[32m+[m[32m                      builder: (_) => const ScheduleScreen(),[m
[32m+[m[32m                    ),[m
[32m+[m[32m                  );[m
[32m+[m[32m                },[m
[32m+[m[32m              )[m
[32m+[m[32m            else[m
[32m+[m[32m              Container([m
[32m+[m[32m                decoration: BoxDecoration([m
[32m+[m[32m                  color: Colors.white,[m
[32m+[m[32m                  borderRadius: BorderRadius.circular(18),[m
[32m+[m[32m                  border: Border.all([m
[32m+[m[32m                    color: AppColors.line,[m
[32m+[m[32m                  ),[m
[32m+[m[32m                ),[m
[32m+[m[32m                child: Column([m
[32m+[m[32m                  children: [[m
[32m+[m[32m                    for (var i = 0; i < previewEvents.length; i++)[m
[32m+[m[32m                      _ScheduleEventPreview([m
[32m+[m[32m                        data: previewEvents[i].data(),[m
[32m+[m[32m                        isLast: i == previewEvents.length - 1,[m
[32m+[m[32m                      ),[m
[32m+[m[32m                  ],[m
[32m+[m[32m                ),[m
[32m+[m[32m              ),[m
[32m+[m[32m          ],[m
[32m+[m[32m        );[m
[32m+[m[32m      },[m
[32m+[m[32m    );[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  static int _readInt(dynamic value) {[m
[32m+[m[32m    if (value is num) {[m
[32m+[m[32m      return value.round();[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    return 0;[m
[32m+[m[32m  }[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mclass _ScheduleEventPreview extends StatelessWidget {[m
[32m+[m[32m  final Map<String, dynamic> data;[m
   final bool isLast;[m
 [m
[31m-  const _ScheduleItem({[m
[31m-    required this.time,[m
[31m-    required this.title,[m
[31m-    required this.subtitle,[m
[31m-    required this.icon,[m
[32m+[m[32m  const _ScheduleEventPreview({[m
[32m+[m[32m    required this.data,[m
     required this.isLast,[m
   });[m
 [m
   @override[m
   Widget build(BuildContext context) {[m
[32m+[m[32m    final startMinutes = data['startMinutes'] is num[m
[32m+[m[32m        ? (data['startMinutes'] as num).round()[m
[32m+[m[32m        : 0;[m
[32m+[m
[32m+[m[32m    final title = data['title']?.toString() ?? 'Untitled event';[m
[32m+[m[32m    final category = data['category']?.toString() ?? 'Other';[m
[32m+[m
     return Padding([m
[31m-      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),[m
[32m+[m[32m      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),[m
       child: Row([m
[31m-        crossAxisAlignment: CrossAxisAlignment.start,[m
         children: [[m
           SizedBox([m
[31m-            width: 67,[m
[32m+[m[32m            width: 64,[m
             child: Text([m
[31m-              time,[m
[32m+[m[32m              _formatMinutes(startMinutes),[m
               style: GoogleFonts.inter([m
                 fontSize: 10.5,[m
                 fontWeight: FontWeight.w600,[m
[36m@@ -652,11 +1303,11 @@[m [mclass _ScheduleItem extends StatelessWidget {[m
             width: 30,[m
             height: 30,[m
             decoration: BoxDecoration([m
[31m-              color: AppColors.peach,[m
[32m+[m[32m              color: _categoryBackground(category),[m
               borderRadius: BorderRadius.circular(9),[m
             ),[m
             child: Icon([m
[31m-              icon,[m
[32m+[m[32m              _categoryIcon(category),[m
               size: 16,[m
               color: AppColors.clayDark,[m
             ),[m
[36m@@ -668,23 +1319,640 @@[m [mclass _ScheduleItem extends StatelessWidget {[m
               children: [[m
                 Text([m
                   title,[m
[32m+[m[32m                  maxLines: 1,[m
[32m+[m[32m                  overflow: TextOverflow.ellipsis,[m
                   style: GoogleFonts.inter([m
                     fontSize: 12,[m
                     fontWeight: FontWeight.w600,[m
                     color: AppColors.ink,[m
                   ),[m
                 ),[m
[31m-                const SizedBox(height: 3),[m
[32m+[m[32m                const SizedBox(height: 2),[m
                 Text([m
[31m-                  subtitle,[m
[32m+[m[32m                  category,[m
                   style: GoogleFonts.inter([m
[31m-                    fontSize: 10.5,[m
[32m+[m[32m                    fontSize: 10,[m
                     color: AppColors.sub,[m
                   ),[m
                 ),[m
               ],[m
             ),[m
           ),[m
[32m+[m[32m          if (!isLast)[m
[32m+[m[32m            const SizedBox.shrink(),[m
[32m+[m[32m        ],[m
[32m+[m[32m      ),[m
[32m+[m[32m    );[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  static String _formatMinutes(int totalMinutes) {[m
[32m+[m[32m    final hour24 = (totalMinutes ~/ 60).clamp(0, 23);[m
[32m+[m[32m    final minute = totalMinutes % 60;[m
[32m+[m
[32m+[m[32m    final period = hour24 >= 12 ? 'PM' : 'AM';[m
[32m+[m[32m    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;[m
[32m+[m
[32m+[m[32m    return '$hour12:${minute.toString().padLeft(2, '0')} $period';[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  static IconData _categoryIcon(String category) {[m
[32m+[m[32m    switch (category.toLowerCase()) {[m
[32m+[m[32m      case 'work':[m
[32m+[m[32m        return Icons.work_outline;[m
[32m+[m[32m      case 'health':[m
[32m+[m[32m        return Icons.favorite_border;[m
[32m+[m[32m      case 'personal':[m
[32m+[m[32m        return Icons.person_outline;[m
[32m+[m[32m      case 'leisure':[m
[32m+[m[32m        return Icons.spa_outlined;[m
[32m+[m[32m      case 'learning':[m
[32m+[m[32m        return Icons.menu_book_outlined;[m
[32m+[m[32m      default:[m
[32m+[m[32m        return Icons.event_outlined;[m
[32m+[m[32m    }[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  static Color _categoryBackground(String category) {[m
[32m+[m[32m    switch (category.toLowerCase()) {[m
[32m+[m[32m      case 'work':[m
[32m+[m[32m        return AppColors.peach;[m
[32m+[m[32m      case 'health':[m
[32m+[m[32m        return AppColors.eucalyptus;[m
[32m+[m[32m      default:[m
[32m+[m[32m        return AppColors.peach;[m
[32m+[m[32m    }[m
[32m+[m[32m  }[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mclass _EmptyScheduleCard extends StatelessWidget {[m
[32m+[m[32m  final VoidCallback onAdd;[m
[32m+[m
[32m+[m[32m  const _EmptyScheduleCard({[m
[32m+[m[32m    required this.onAdd,[m
[32m+[m[32m  });[m
[32m+[m
[32m+[m[32m  @override[m
[32m+[m[32m  Widget build(BuildContext context) {[m
[32m+[m[32m    return Container([m
[32m+[m[32m      width: double.infinity,[m
[32m+[m[32m      padding: const EdgeInsets.all(20),[m
[32m+[m[32m      decoration: BoxDecoration([m
[32m+[m[32m        color: Colors.white,[m
[32m+[m[32m        borderRadius: BorderRadius.circular(18),[m
[32m+[m[32m        border: Border.all([m
[32m+[m[32m          color: AppColors.line,[m
[32m+[m[32m        ),[m
[32m+[m[32m      ),[m
[32m+[m[32m      child: Column([m
[32m+[m[32m        children: [[m
[32m+[m[32m          const Icon([m
[32m+[m[32m            Icons.calendar_today_outlined,[m
[32m+[m[32m            size: 26,[m
[32m+[m[32m            color: AppColors.clayDark,[m
[32m+[m[32m          ),[m
[32m+[m[32m          const SizedBox(height: 10),[m
[32m+[m[32m          Text([m
[32m+[m[32m            'Nothing scheduled yet',[m
[32m+[m[32m            style: GoogleFonts.inter([m
[32m+[m[32m              fontSize: 12.5,[m
[32m+[m[32m              fontWeight: FontWeight.w600,[m
[32m+[m[32m              color: AppColors.ink,[m
[32m+[m[32m            ),[m
[32m+[m[32m          ),[m
[32m+[m[32m          const SizedBox(height: 4),[m
[32m+[m[32m          Text([m
[32m+[m[32m            'Add something to your schedule to see it here.',[m
[32m+[m[32m            textAlign: TextAlign.center,[m
[32m+[m[32m            style: GoogleFonts.inter([m
[32m+[m[32m              fontSize: 10.5,[m
[32m+[m[32m              color: AppColors.sub,[m
[32m+[m[32m            ),[m
[32m+[m[32m          ),[m
[32m+[m[32m          const SizedBox(height: 12),[m
[32m+[m[32m          TextButton([m
[32m+[m[32m            onPressed: onAdd,[m
[32m+[m[32m            child: const Text('Open schedule'),[m
[32m+[m[32m          ),[m
[32m+[m[32m        ],[m
[32m+[m[32m      ),[m
[32m+[m[32m    );[m
[32m+[m[32m  }[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mclass _HomeActivitiesSection extends StatelessWidget {[m
[32m+[m[32m  final String userId;[m
[32m+[m
[32m+[m[32m  const _HomeActivitiesSection({[m
[32m+[m[32m    required this.userId,[m
[32m+[m[32m  });[m
[32m+[m
[32m+[m[32m  @override[m
[32m+[m[32m  Widget build(BuildContext context) {[m
[32m+[m[32m    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>([m
[32m+[m[32m      stream: FirestoreService().activitiesForDate([m
[32m+[m[32m        userId,[m
[32m+[m[32m        DateTime.now(),[m
[32m+[m[32m      ),[m
[32m+[m[32m      builder: (context, snapshot) {[m
[32m+[m[32m        final activities = snapshot.data?.docs ?? [];[m
[32m+[m
[32m+[m[32m        final sortedActivities = [...activities][m
[32m+[m[32m          ..sort([m
[32m+[m[32m            (a, b) {[m
[32m+[m[32m              final aCompleted = a.data()['completed'] == true;[m
[32m+[m[32m              final bCompleted = b.data()['completed'] == true;[m
[32m+[m
[32m+[m[32m              if (aCompleted == bCompleted) {[m
[32m+[m[32m                return 0;[m
[32m+[m[32m              }[m
[32m+[m
[32m+[m[32m              return aCompleted ? 1 : -1;[m
[32m+[m[32m            },[m
[32m+[m[32m          );[m
[32m+[m
[32m+[m[32m        return Column([m
[32m+[m[32m          crossAxisAlignment: CrossAxisAlignment.start,[m
[32m+[m[32m          children: [[m
[32m+[m[32m            Row([m
[32m+[m[32m              children: [[m
[32m+[m[32m                const Expanded([m
[32m+[m[32m                  child: _SectionTitle([m
[32m+[m[32m                    title: 'Today’s activities',[m
[32m+[m[32m                    subtitle: 'Check things off as you go.',[m
[32m+[m[32m                  ),[m
[32m+[m[32m                ),[m
[32m+[m[32m                if (activities.isNotEmpty)[m
[32m+[m[32m                  Text([m
[32m+[m[32m                    '${activities.where((item) => item.data()['completed'] == true).length}/${activities.length}',[m
[32m+[m[32m                    style: GoogleFonts.inter([m
[32m+[m[32m                      fontSize: 11,[m
[32m+[m[32m                      fontWeight: FontWeight.w600,[m
[32m+[m[32m                      color: AppColors.eucalyptusDark,[m
[32m+[m[32m                    ),[m
[32m+[m[32m                  ),[m
[32m+[m[32m              ],[m
[32m+[m[32m            ),[m
[32m+[m[32m            const SizedBox(height: 12),[m
[32m+[m[32m            if (snapshot.hasError)[m
[32m+[m[32m              const _HomeLoadError([m
[32m+[m[32m                message: 'Today’s activities could not be loaded.',[m
[32m+[m[32m              )[m
[32m+[m[32m            else if (sortedActivities.isEmpty)[m
[32m+[m[32m              _EmptyActivitiesCard([m
[32m+[m[32m                onAdd: () {[m
[32m+[m[32m                  _showActivityDialog([m
[32m+[m[32m                    context,[m
[32m+[m[32m                    userId,[m
[32m+[m[32m                  );[m
[32m+[m[32m                },[m
[32m+[m[32m              )[m
[32m+[m[32m            else[m
[32m+[m[32m              Container([m
[32m+[m[32m                decoration: BoxDecoration([m
[32m+[m[32m                  color: Colors.white,[m
[32m+[m[32m                  borderRadius: BorderRadius.circular(18),[m
[32m+[m[32m                  border: Border.all([m
[32m+[m[32m                    color: AppColors.line,[m
[32m+[m[32m                  ),[m
[32m+[m[32m                ),[m
[32m+[m[32m                child: Column([m
[32m+[m[32m                  children: [[m
[32m+[m[32m                    for (var i = 0; i < sortedActivities.length; i++)[m
[32m+[m[32m                      _ActivityTile([m
[32m+[m[32m                        userId: userId,[m
[32m+[m[32m                        activity: sortedActivities[i],[m
[32m+[m[32m                        isLast: i == sortedActivities.length - 1,[m
[32m+[m[32m                      ),[m
[32m+[m[32m                  ],[m
[32m+[m[32m                ),[m
[32m+[m[32m              ),[m
[32m+[m[32m          ],[m
[32m+[m[32m        );[m
[32m+[m[32m      },[m
[32m+[m[32m    );[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  static Future<void> _showActivityDialog([m
[32m+[m[32m    BuildContext context,[m
[32m+[m[32m    String userId, {[m
[32m+[m[32m    DocumentSnapshot<Map<String, dynamic>>? existingActivity,[m
[32m+[m[32m  }) {[m
[32m+[m[32m    return HomeScreen._showActivityDialog([m
[32m+[m[32m      context,[m
[32m+[m[32m      userId,[m
[32m+[m[32m      existingActivity: existingActivity,[m
[32m+[m[32m    );[m
[32m+[m[32m  }[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mclass _ActivityTile extends StatelessWidget {[m
[32m+[m[32m  final String userId;[m
[32m+[m[32m  final DocumentSnapshot<Map<String, dynamic>> activity;[m
[32m+[m[32m  final bool isLast;[m
[32m+[m
[32m+[m[32m  const _ActivityTile({[m
[32m+[m[32m    required this.userId,[m
[32m+[m[32m    required this.activity,[m
[32m+[m[32m    required this.isLast,[m
[32m+[m[32m  });[m
[32m+[m
[32m+[m[32m  @override[m
[32m+[m[32m  Widget build(BuildContext context) {[m
[32m+[m[32m    final data = activity.data() ?? {};[m
[32m+[m
[32m+[m[32m    final title = data['title']?.toString() ?? 'Untitled activity';[m
[32m+[m[32m    final category = data['category']?.toString() ?? 'Personal';[m
[32m+[m[32m    final completed = data['completed'] == true;[m
[32m+[m[32m    final duration = data['durationMinutes'] is num[m
[32m+[m[32m        ? (data['durationMinutes'] as num).round()[m
[32m+[m[32m        : 0;[m
[32m+[m
[32m+[m[32m    return InkWell([m
[32m+[m[32m      onTap: () {[m
[32m+[m[32m        HomeScreen._showActivityDialog([m
[32m+[m[32m          context,[m
[32m+[m[32m          userId,[m
[32m+[m[32m          existingActivity: activity,[m
[32m+[m[32m        );[m
[32m+[m[32m      },[m
[32m+[m[32m      child: Padding([m
[32m+[m[32m        padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),[m
[32m+[m[32m        child: Row([m
[32m+[m[32m          children: [[m
[32m+[m[32m            Checkbox([m
[32m+[m[32m              value: completed,[m
[32m+[m[32m              activeColor: AppColors.eucalyptusDark,[m
[32m+[m[32m              onChanged: (value) async {[m
[32m+[m[32m                await FirestoreService().updateActivityCompletion([m
[32m+[m[32m                  userId: userId,[m
[32m+[m[32m                  activityId: activity.id,[m
[32m+[m[32m                  completed: value ?? false,[m
[32m+[m[32m                );[m
[32m+[m[32m              },[m
[32m+[m[32m            ),[m
[32m+[m[32m            Expanded([m
[32m+[m[32m              child: Column([m
[32m+[m[32m                crossAxisAlignment: CrossAxisAlignment.start,[m
[32m+[m[32m                children: [[m
[32m+[m[32m                  Text([m
[32m+[m[32m                    title,[m
[32m+[m[32m                    maxLines: 1,[m
[32m+[m[32m                    overflow: TextOverflow.ellipsis,[m
[32m+[m[32m                    style: GoogleFonts.inter([m
[32m+[m[32m                      fontSize: 12,[m
[32m+[m[32m                      fontWeight: FontWeight.w600,[m
[32m+[m[32m                      color: completed[m
[32m+[m[32m                          ? AppColors.sub[m
[32m+[m[32m                          : AppColors.ink,[m
[32m+[m[32m                      decoration:[m
[32m+[m[32m                          completed ? TextDecoration.lineThrough : null,[m
[32m+[m[32m                    ),[m
[32m+[m[32m                  ),[m
[32m+[m[32m                  const SizedBox(height: 3),[m
[32m+[m[32m                  Row([m
[32m+[m[32m                    children: [[m
[32m+[m[32m                      Text([m
[32m+[m[32m                        category,[m
[32m+[m[32m                        style: GoogleFonts.inter([m
[32m+[m[32m                          fontSize: 9.5,[m
[32m+[m[32m                          color: AppColors.sub,[m
[32m+[m[32m                        ),[m
[32m+[m[32m                      ),[m
[32m+[m[32m                      if (duration > 0) ...[[m
[32m+[m[32m                        Text([m
[32m+[m[32m                          ' · ',[m
[32m+[m[32m                          style: GoogleFonts.inter([m
[32m+[m[32m                            fontSize: 9.5,[m
[32m+[m[32m                            color: AppColors.sub,[m
[32m+[m[32m                          ),[m
[32m+[m[32m                        ),[m
[32m+[m[32m                        Text([m
[32m+[m[32m                          '$duration min',[m
[32m+[m[32m                          style: GoogleFonts.inter([m
[32m+[m[32m                            fontSize: 9.5,[m
[32m+[m[32m                            color: AppColors.sub,[m
[32m+[m[32m                          ),[m
[32m+[m[32m                        ),[m
[32m+[m[32m                      ],[m
[32m+[m[32m                    ],[m
[32m+[m[32m                  ),[m
[32m+[m[32m                ],[m
[32m+[m[32m              ),[m
[32m+[m[32m            ),[m
[32m+[m[32m            PopupMenuButton<String>([m
[32m+[m[32m              icon: const Icon([m
[32m+[m[32m                Icons.more_horiz,[m
[32m+[m[32m                size: 19,[m
[32m+[m[32m                color: AppColors.sub,[m
[32m+[m[32m              ),[m
[32m+[m[32m              onSelected: (value) async {[m
[32m+[m[32m                if (value == 'edit') {[m
[32m+[m[32m                  HomeScreen._showActivityDialog([m
[32m+[m[32m                    context,[m
[32m+[m[32m                    userId,[m
[32m+[m[32m                    existingActivity: activity,[m
[32m+[m[32m                  );[m
[32m+[m[32m                } else if (value == 'delete') {[m
[32m+[m[32m                  await HomeScreen._deleteActivity([m
[32m+[m[32m                    context,[m
[32m+[m[32m                    userId,[m
[32m+[m[32m                    activity.id,[m
[32m+[m[32m                  );[m
[32m+[m[32m                }[m
[32m+[m[32m              },[m
[32m+[m[32m              itemBuilder: (context) => const [[m
[32m+[m[32m                PopupMenuItem([m
[32m+[m[32m                  value: 'edit',[m
[32m+[m[32m                  child: Text('Edit'),[m
[32m+[m[32m                ),[m
[32m+[m[32m                PopupMenuItem([m
[32m+[m[32m                  value: 'delete',[m
[32m+[m[32m                  child: Text('Delete'),[m
[32m+[m[32m                ),[m
[32m+[m[32m              ],[m
[32m+[m[32m            ),[m
[32m+[m[32m          ],[m
[32m+[m[32m        ),[m
[32m+[m[32m      ),[m
[32m+[m[32m    );[m
[32m+[m[32m  }[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mclass _EmptyActivitiesCard extends StatelessWidget {[m
[32m+[m[32m  final VoidCallback onAdd;[m
[32m+[m
[32m+[m[32m  const _EmptyActivitiesCard({[m
[32m+[m[32m    required this.onAdd,[m
[32m+[m[32m  });[m
[32m+[m
[32m+[m[32m  @override[m
[32m+[m[32m  Widget build(BuildContext context) {[m
[32m+[m[32m    return Container([m
[32m+[m[32m      width: double.infinity,[m
[32m+[m[32m      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),[m
[32m+[m[32m      decoration: BoxDecoration([m
[32m+[m[32m        color: Colors.white,[m
[32m+[m[32m        borderRadius: BorderRadius.circular(18),[m
[32m+[m[32m        border: Border.all([m
[32m+[m[32m          color: AppColors.line,[m
[32m+[m[32m        ),[m
[32m+[m[32m      ),[m
[32m+[m[32m      child: Column([m
[32m+[m[32m        children: [[m
[32m+[m[32m          Container([m
[32m+[m[32m            width: 48,[m
[32m+[m[32m            height: 48,[m
[32m+[m[32m            decoration: BoxDecoration([m
[32m+[m[32m              color: AppColors.eucalyptus,[m
[32m+[m[32m              borderRadius: BorderRadius.circular(15),[m
[32m+[m[32m            ),[m
[32m+[m[32m            child: const Icon([m
[32m+[m[32m              Icons.checklist_outlined,[m
[32m+[m[32m              color: AppColors.eucalyptusDark,[m
[32m+[m[32m              size: 23,[m
[32m+[m[32m            ),[m
[32m+[m[32m          ),[m
[32m+[m[32m          const SizedBox(height: 12),[m
[32m+[m[32m          Text([m
[32m+[m[32m            'Your day starts here',[m
[32m+[m[32m            style: GoogleFonts.fraunces([m
[32m+[m[32m              fontSize: 19,[m
[32m+[m[32m              fontWeight: FontWeight.w600,[m
[32m+[m[32m              color: AppColors.ink,[m
[32m+[m[32m            ),[m
[32m+[m[32m          ),[m
[32m+[m[32m          const SizedBox(height: 5),[m
[32m+[m[32m          Text([m
[32m+[m[32m            'Add your first activity and check things off as you go.',[m
[32m+[m[32m            textAlign: TextAlign.center,[m
[32m+[m[32m            style: GoogleFonts.inter([m
[32m+[m[32m              fontSize: 10.5,[m
[32m+[m[32m              height: 1.45,[m
[32m+[m[32m              color: AppColors.sub,[m
[32m+[m[32m            ),[m
[32m+[m[32m          ),[m
[32m+[m[32m          const SizedBox(height: 13),[m
[32m+[m[32m          FilledButton.icon([m
[32m+[m[32m            onPressed: onAdd,[m
[32m+[m[32m            icon: const Icon(Icons.add, size: 17),[m
[32m+[m[32m            label: const Text('Add first activity'),[m
[32m+[m[32m            style: FilledButton.styleFrom([m
[32m+[m[32m              backgroundColor: AppColors.clay,[m
[32m+[m[32m              foregroundColor: Colors.white,[m
[32m+[m[32m            ),[m
[32m+[m[32m          ),[m
[32m+[m[32m        ],[m
[32m+[m[32m      ),[m
[32m+[m[32m    );[m
[32m+[m[32m  }[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mclass _HomeFab extends StatelessWidget {[m
[32m+[m[32m  final VoidCallback onPressed;[m
[32m+[m
[32m+[m[32m  const _HomeFab({[m
[32m+[m[32m    required this.onPressed,[m
[32m+[m[32m  });[m
[32m+[m
[32m+[m[32m  @override[m
[32m+[m[32m  Widget build(BuildContext context) {[m
[32m+[m[32m    return FloatingActionButton([m
[32m+[m[32m      onPressed: onPressed,[m
[32m+[m[32m      backgroundColor: AppColors.clay,[m
[32m+[m[32m      foregroundColor: Colors.white,[m
[32m+[m[32m      elevation: 3,[m
[32m+[m[32m      tooltip: 'Add activity',[m
[32m+[m[32m      child: const Icon(Icons.add),[m
[32m+[m[32m    );[m
[32m+[m[32m  }[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mclass _SectionTitle extends StatelessWidget {[m
[32m+[m[32m  final String title;[m
[32m+[m[32m  final String subtitle;[m
[32m+[m
[32m+[m[32m  const _SectionTitle({[m
[32m+[m[32m    required this.title,[m
[32m+[m[32m    required this.subtitle,[m
[32m+[m[32m  });[m
[32m+[m
[32m+[m[32m  @override[m
[32m+[m[32m  Widget build(BuildContext context) {[m
[32m+[m[32m    return Column([m
[32m+[m[32m      crossAxisAlignment: CrossAxisAlignment.start,[m
[32m+[m[32m      children: [[m
[32m+[m[32m        Text([m
[32m+[m[32m          title,[m
[32m+[m[32m          style: GoogleFonts.fraunces([m
[32m+[m[32m            fontSize: 20,[m
[32m+[m[32m            fontWeight: FontWeight.w600,[m
[32m+[m[32m            color: AppColors.ink,[m
[32m+[m[32m          ),[m
[32m+[m[32m        ),[m
[32m+[m[32m        const SizedBox(height: 3),[m
[32m+[m[32m        Text([m
[32m+[m[32m          subtitle,[m
[32m+[m[32m          style: GoogleFonts.inter([m
[32m+[m[32m            fontSize: 11.5,[m
[32m+[m[32m            color: AppColors.sub,[m
[32m+[m[32m          ),[m
[32m+[m[32m        ),[m
[32m+[m[32m      ],[m
[32m+[m[32m    );[m
[32m+[m[32m  }[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mclass _HomeLoadError extends StatelessWidget {[m
[32m+[m[32m  final String message;[m
[32m+[m
[32m+[m[32m  const _HomeLoadError({[m
[32m+[m[32m    required this.message,[m
[32m+[m[32m  });[m
[32m+[m
[32m+[m[32m  @override[m
[32m+[m[32m  Widget build(BuildContext context) {[m
[32m+[m[32m    return Container([m
[32m+[m[32m      width: double.infinity,[m
[32m+[m[32m      padding: const EdgeInsets.all(15),[m
[32m+[m[32m      decoration: BoxDecoration([m
[32m+[m[32m        color: Colors.white,[m
[32m+[m[32m        borderRadius: BorderRadius.circular(16),[m
[32m+[m[32m        border: Border.all(color: AppColors.line),[m
[32m+[m[32m      ),[m
[32m+[m[32m      child: Row([m
[32m+[m[32m        children: [[m
[32m+[m[32m          const Icon([m
[32m+[m[32m            Icons.error_outline,[m
[32m+[m[32m            size: 18,[m
[32m+[m[32m            color: AppColors.clayDark,[m
[32m+[m[32m          ),[m
[32m+[m[32m          const SizedBox(width: 10),[m
[32m+[m[32m          Expanded([m
[32m+[m[32m            child: Text([m
[32m+[m[32m              message,[m
[32m+[m[32m              style: GoogleFonts.inter([m
[32m+[m[32m                fontSize: 11,[m
[32m+[m[32m                color: AppColors.sub,[m
[32m+[m[32m              ),[m
[32m+[m[32m            ),[m
[32m+[m[32m          ),[m
[32m+[m[32m        ],[m
[32m+[m[32m      ),[m
[32m+[m[32m    );[m
[32m+[m[32m  }[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mclass _TimeOverview extends StatelessWidget {[m
[32m+[m[32m  final double workHours;[m
[32m+[m[32m  final int commuteMinutes;[m
[32m+[m
[32m+[m[32m  const _TimeOverview({[m
[32m+[m[32m    required this.workHours,[m
[32m+[m[32m    required this.commuteMinutes,[m
[32m+[m[32m  });[m
[32m+[m
[32m+[m[32m  String _formatHours(double hours) {[m
[32m+[m[32m    if (hours == hours.roundToDouble()) {[m
[32m+[m[32m      return '${hours.toInt()}h';[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    return '${hours.toStringAsFixed(1)}h';[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  String _formatCommute(int minutes) {[m
[32m+[m[32m    if (minutes >= 60) {[m
[32m+[m[32m      final hours = minutes ~/ 60;[m
[32m+[m[32m      final remaining = minutes % 60;[m
[32m+[m
[32m+[m[32m      if (remaining == 0) {[m
[32m+[m[32m        return '${hours}h';[m
[32m+[m[32m      }[m
[32m+[m
[32m+[m[32m      return '${hours}h ${remaining}m';[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    return '${minutes}m';[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  @override[m
[32m+[m[32m  Widget build(BuildContext context) {[m
[32m+[m[32m    return Row([m
[32m+[m[32m      children: [[m
[32m+[m[32m        Expanded([m
[32m+[m[32m          child: _TimeTile([m
[32m+[m[32m            icon: Icons.work_outline,[m
[32m+[m[32m            label: 'Work',[m
[32m+[m[32m            value: _formatHours(workHours),[m
[32m+[m[32m          ),[m
[32m+[m[32m        ),[m
[32m+[m[32m        const SizedBox(width: 10),[m
[32m+[m[32m        Expanded([m
[32m+[m[32m          child: _TimeTile([m
[32m+[m[32m            icon: Icons.directions_car_outlined,[m
[32m+[m[32m            label: 'Commute',[m
[32m+[m[32m            value: _formatCommute(commuteMinutes),[m
[32m+[m[32m          ),[m
[32m+[m[32m        ),[m
[32m+[m[32m        const SizedBox(width: 10),[m
[32m+[m[32m        const Expanded([m
[32m+[m[32m          child: _TimeTile([m
[32m+[m[32m            icon: Icons.bed_outlined,[m
[32m+[m[32m            label: 'Sleep',[m
[32m+[m[32m            value: '—',[m
[32m+[m[32m          ),[m
[32m+[m[32m        ),[m
[32m+[m[32m      ],[m
[32m+[m[32m    );[m
[32m+[m[32m  }[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mclass _TimeTile extends StatelessWidget {[m
[32m+[m[32m  final IconData icon;[m
[32m+[m[32m  final String label;[m
[32m+[m[32m  final String value;[m
[32m+[m
[32m+[m[32m  const _TimeTile({[m
[32m+[m[32m    required this.icon,[m
[32m+[m[32m    required this.label,[m
[32m+[m[32m    required this.value,[m
[32m+[m[32m  });[m
[32m+[m
[32m+[m[32m  @override[m
[32m+[m[32m  Widget build(BuildContext context) {[m
[32m+[m[32m    return Container([m
[32m+[m[32m      padding: const EdgeInsets.fromLTRB(12, 14, 12, 13),[m
[32m+[m[32m      decoration: BoxDecoration([m
[32m+[m[32m        color: Colors.white,[m
[32m+[m[32m        borderRadius: BorderRadius.circular(16),[m
[32m+[m[32m        border: Border.all([m
[32m+[m[32m          color: AppColors.line,[m
[32m+[m[32m        ),[m
[32m+[m[32m      ),[m
[32m+[m[32m      child: Column([m
[32m+[m[32m        crossAxisAlignment: CrossAxisAlignment.start,[m
[32m+[m[32m        children: [[m
[32m+[m[32m          Icon([m
[32m+[m[32m            icon,[m
[32m+[m[32m            size: 18,[m
[32m+[m[32m            color: AppColors.clayDark,[m
[32m+[m[32m          ),[m
[32m+[m[32m          const SizedBox(height: 12),[m
[32m+[m[32m          Text([m
[32m+[m[32m            value,[m
[32m+[m[32m            style: GoogleFonts.fraunces([m
[32m+[m[32m              fontSize: 20,[m
[32m+[m[32m              fontWeight: FontWeight.w600,[m
[32m+[m[32m              color: AppColors.ink,[m
[32m+[m[32m            ),[m
[32m+[m[32m          ),[m
[32m+[m[32m          const SizedBox(height: 2),[m
[32m+[m[32m          Text([m
[32m+[m[32m            label,[m
[32m+[m[32m            style: GoogleFonts.inter([m
[32m+[m[32m              fontSize: 10.5,[m
[32m+[m[32m              color: AppColors.sub,[m
[32m+[m[32m            ),[m
[32m+[m[32m          ),[m
         ],[m
       ),[m
     );[m
[36m@@ -798,10 +2066,12 @@[m [mclass _WeeklyOverview extends StatelessWidget {[m
   Widget build(BuildContext context) {[m
     final totalTrackedHours = workHours + commuteHours;[m
 [m
[31m-    final workFlex = workHours.round().clamp(1, 100);[m
[31m-    final commuteFlex = commuteHours.round().clamp(1, 100);[m
[32m+[m[32m    final workFlex =[m
[32m+[m[32m        workHours.round().clamp(1, 100).toInt();[m
[32m+[m[32m    final commuteFlex =[m
[32m+[m[32m        commuteHours.round().clamp(1, 100).toInt();[m
     final remainingFlex =[m
[31m-        (168 - totalTrackedHours).round().clamp(1, 168);[m
[32m+[m[32m        (168 - totalTrackedHours).round().clamp(1, 168).toInt();[m
 [m
     return Container([m
       width: double.infinity,[m
[1mdiff --git a/lib/services/firestore_service.dart b/lib/services/firestore_service.dart[m
[1mindex 2884f2b..7d2a1ef 100644[m
[1m--- a/lib/services/firestore_service.dart[m
[1m+++ b/lib/services/firestore_service.dart[m
[36m@@ -63,4 +63,299 @@[m [mclass FirestoreService {[m
 [m
     return data?['onboardingCompleted'] == true;[m
   }[m
[32m+[m
[32m+[m[32m  // ---------------------------------------------------------------------------[m
[32m+[m[32m  // ACTIVITIES[m
[32m+[m[32m  // ---------------------------------------------------------------------------[m
[32m+[m
[32m+[m[32m  CollectionReference<Map<String, dynamic>> activitiesCollection([m
[32m+[m[32m    String userId,[m
[32m+[m[32m  ) {[m
[32m+[m[32m    return userDocument(userId).collection('activities');[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Stream<QuerySnapshot<Map<String, dynamic>>> activitiesForDate([m
[32m+[m[32m    String userId,[m
[32m+[m[32m    DateTime date,[m
[32m+[m[32m  ) {[m
[32m+[m[32m    final dateKey = _dateKey(date);[m
[32m+[m
[32m+[m[32m    return activitiesCollection(userId)[m
[32m+[m[32m        .where('date', isEqualTo: dateKey)[m
[32m+[m[32m        .orderBy('createdAt', descending: false)[m
[32m+[m[32m        .snapshots();[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Future<DocumentReference<Map<String, dynamic>>> createActivity({[m
[32m+[m[32m    required String userId,[m
[32m+[m[32m    required String title,[m
[32m+[m[32m    required String category,[m
[32m+[m[32m    required DateTime date,[m
[32m+[m[32m    String? notes,[m
[32m+[m[32m    int? durationMinutes,[m
[32m+[m[32m  }) {[m
[32m+[m[32m    return activitiesCollection(userId).add({[m
[32m+[m[32m      'title': title,[m
[32m+[m[32m      'category': category,[m
[32m+[m[32m      'date': _dateKey(date),[m
[32m+[m[32m      'notes': notes ?? '',[m
[32m+[m[32m      'durationMinutes': durationMinutes ?? 0,[m
[32m+[m[32m      'completed': false,[m
[32m+[m[32m      'createdAt': FieldValue.serverTimestamp(),[m
[32m+[m[32m      'updatedAt': FieldValue.serverTimestamp(),[m
[32m+[m[32m    });[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Future<void> updateActivity({[m
[32m+[m[32m    required String userId,[m
[32m+[m[32m    required String activityId,[m
[32m+[m[32m    required String title,[m
[32m+[m[32m    required String category,[m
[32m+[m[32m    required DateTime date,[m
[32m+[m[32m    String? notes,[m
[32m+[m[32m    int? durationMinutes,[m
[32m+[m[32m    required bool completed,[m
[32m+[m[32m  }) {[m
[32m+[m[32m    return activitiesCollection(userId).doc(activityId).update({[m
[32m+[m[32m      'title': title,[m
[32m+[m[32m      'category': category,[m
[32m+[m[32m      'date': _dateKey(date),[m
[32m+[m[32m      'notes': notes ?? '',[m
[32m+[m[32m      'durationMinutes': durationMinutes ?? 0,[m
[32m+[m[32m      'completed': completed,[m
[32m+[m[32m      'updatedAt': FieldValue.serverTimestamp(),[m
[32m+[m[32m    });[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Future<void> updateActivityCompletion({[m
[32m+[m[32m    required String userId,[m
[32m+[m[32m    required String activityId,[m
[32m+[m[32m    required bool completed,[m
[32m+[m[32m  }) {[m
[32m+[m[32m    return activitiesCollection(userId).doc(activityId).update({[m
[32m+[m[32m      'completed': completed,[m
[32m+[m[32m      'updatedAt': FieldValue.serverTimestamp(),[m
[32m+[m[32m    });[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Future<void> deleteActivity({[m
[32m+[m[32m    required String userId,[m
[32m+[m[32m    required String activityId,[m
[32m+[m[32m  }) {[m
[32m+[m[32m    return activitiesCollection(userId).doc(activityId).delete();[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  // ---------------------------------------------------------------------------[m
[32m+[m[32m  // DAILY ENERGY CHECK-INS[m
[32m+[m[32m  // ---------------------------------------------------------------------------[m
[32m+[m
[32m+[m[32m  CollectionReference<Map<String, dynamic>> checkInsCollection([m
[32m+[m[32m    String userId,[m
[32m+[m[32m  ) {[m
[32m+[m[32m    return userDocument(userId).collection('checkIns');[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  DocumentReference<Map<String, dynamic>> checkInDocument({[m
[32m+[m[32m    required String userId,[m
[32m+[m[32m    required DateTime date,[m
[32m+[m[32m  }) {[m
[32m+[m[32m    return checkInsCollection(userId).doc(_dateKey(date));[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Stream<DocumentSnapshot<Map<String, dynamic>>> dailyCheckIn([m
[32m+[m[32m    String userId,[m
[32m+[m[32m    DateTime date,[m
[32m+[m[32m  ) {[m
[32m+[m[32m    return checkInDocument([m
[32m+[m[32m      userId: userId,[m
[32m+[m[32m      date: date,[m
[32m+[m[32m    ).snapshots();[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Future<void> createOrUpdateDailyCheckIn({[m
[32m+[m[32m    required String userId,[m
[32m+[m[32m    required DateTime date,[m
[32m+[m[32m    required int energyScore,[m
[32m+[m[32m    String? note,[m
[32m+[m[32m  }) {[m
[32m+[m[32m    return checkInDocument([m
[32m+[m[32m      userId: userId,[m
[32m+[m[32m      date: date,[m
[32m+[m[32m    ).set({[m
[32m+[m[32m      'date': _dateKey(date),[m
[32m+[m[32m      'energyScore': energyScore,[m
[32m+[m[32m      'note': note ?? '',[m
[32m+[m[32m      'updatedAt': FieldValue.serverTimestamp(),[m
[32m+[m[32m    }, SetOptions(merge: true));[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Future<void> deleteDailyCheckIn({[m
[32m+[m[32m    required String userId,[m
[32m+[m[32m    required DateTime date,[m
[32m+[m[32m  }) {[m
[32m+[m[32m    return checkInDocument([m
[32m+[m[32m      userId: userId,[m
[32m+[m[32m      date: date,[m
[32m+[m[32m    ).delete();[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  // ---------------------------------------------------------------------------[m
[32m+[m[32m  // GOALS[m
[32m+[m[32m  // ---------------------------------------------------------------------------[m
[32m+[m
[32m+[m[32m  CollectionReference<Map<String, dynamic>> goalsCollection([m
[32m+[m[32m    String userId,[m
[32m+[m[32m  ) {[m
[32m+[m[32m    return userDocument(userId).collection('goals');[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Stream<QuerySnapshot<Map<String, dynamic>>> activeGoals([m
[32m+[m[32m    String userId,[m
[32m+[m[32m  ) {[m
[32m+[m[32m    return goalsCollection(userId)[m
[32m+[m[32m        .where('active', isEqualTo: true)[m
[32m+[m[32m        .orderBy('createdAt', descending: false)[m
[32m+[m[32m        .snapshots();[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Future<DocumentReference<Map<String, dynamic>>> createGoal({[m
[32m+[m[32m    required String userId,[m
[32m+[m[32m    required String title,[m
[32m+[m[32m    required DateTime date,[m
[32m+[m[32m    String? category,[m
[32m+[m[32m  }) {[m
[32m+[m[32m    return goalsCollection(userId).add({[m
[32m+[m[32m      'title': title,[m
[32m+[m[32m      'date': _dateKey(date),[m
[32m+[m[32m      'category': category ?? 'Personal',[m
[32m+[m[32m      'completed': false,[m
[32m+[m[32m      'active': true,[m
[32m+[m[32m      'createdAt': FieldValue.serverTimestamp(),[m
[32m+[m[32m      'updatedAt': FieldValue.serverTimestamp(),[m
[32m+[m[32m    });[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Future<void> updateGoal({[m
[32m+[m[32m    required String userId,[m
[32m+[m[32m    required String goalId,[m
[32m+[m[32m    required String title,[m
[32m+[m[32m    required DateTime date,[m
[32m+[m[32m    String? category,[m
[32m+[m[32m    required bool completed,[m
[32m+[m[32m    required bool active,[m
[32m+[m[32m  }) {[m
[32m+[m[32m    return goalsCollection(userId).doc(goalId).update({[m
[32m+[m[32m      'title': title,[m
[32m+[m[32m      'date': _dateKey(date),[m
[32m+[m[32m      'category': category ?? 'Personal',[m
[32m+[m[32m      'completed': completed,[m
[32m+[m[32m      'active': active,[m
[32m+[m[32m      'updatedAt': FieldValue.serverTimestamp(),[m
[32m+[m[32m    });[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Future<void> updateGoalCompletion({[m
[32m+[m[32m    required String userId,[m
[32m+[m[32m    required String goalId,[m
[32m+[m[32m    required bool completed,[m
[32m+[m[32m  }) {[m
[32m+[m[32m    return goalsCollection(userId).doc(goalId).update({[m
[32m+[m[32m      'completed': completed,[m
[32m+[m[32m      'updatedAt': FieldValue.serverTimestamp(),[m
[32m+[m[32m    });[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Future<void> deleteGoal({[m
[32m+[m[32m    required String userId,[m
[32m+[m[32m    required String goalId,[m
[32m+[m[32m  }) {[m
[32m+[m[32m    return goalsCollection(userId).doc(goalId).delete();[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  // ---------------------------------------------------------------------------[m
[32m+[m[32m  // SCHEDULE EVENTS[m
[32m+[m[32m  // ---------------------------------------------------------------------------[m
[32m+[m
[32m+[m[32m  CollectionReference<Map<String, dynamic>> scheduleCollection([m
[32m+[m[32m    String userId,[m
[32m+[m[32m  ) {[m
[32m+[m[32m    return userDocument(userId).collection('schedule');[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Stream<QuerySnapshot<Map<String, dynamic>>> scheduleForDate([m
[32m+[m[32m    String userId,[m
[32m+[m[32m    DateTime date,[m
[32m+[m[32m  ) {[m
[32m+[m[32m    final dateKey = _dateKey(date);[m
[32m+[m
[32m+[m[32m    return scheduleCollection(userId)[m
[32m+[m[32m        .where('date', isEqualTo: dateKey)[m
[32m+[m[32m        .orderBy('startMinutes', descending: false)[m
[32m+[m[32m        .snapshots();[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Future<DocumentReference<Map<String, dynamic>>> createScheduleEvent({[m
[32m+[m[32m    required String userId,[m
[32m+[m[32m    required String title,[m
[32m+[m[32m    required String category,[m
[32m+[m[32m    required DateTime date,[m
[32m+[m[32m    required int startMinutes,[m
[32m+[m[32m    required int durationMinutes,[m
[32m+[m[32m    String? notes,[m
[32m+[m[32m    String? activityId,[m
[32m+[m[32m  }) {[m
[32m+[m[32m    return scheduleCollection(userId).add({[m
[32m+[m[32m      'title': title,[m
[32m+[m[32m      'category': category,[m
[32m+[m[32m      'date': _dateKey(date),[m
[32m+[m[32m      'startMinutes': startMinutes,[m
[32m+[m[32m      'durationMinutes': durationMinutes,[m
[32m+[m[32m      'notes': notes ?? '',[m
[32m+[m[32m      'activityId': activityId,[m
[32m+[m[32m      'createdAt': FieldValue.serverTimestamp(),[m
[32m+[m[32m      'updatedAt': FieldValue.serverTimestamp(),[m
[32m+[m[32m    });[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Future<void> updateScheduleEvent({[m
[32m+[m[32m    required String userId,[m
[32m+[m[32m    required String eventId,[m
[32m+[m[32m    required String title,[m
[32m+[m[32m    required String category,[m
[32m+[m[32m    required DateTime date,[m
[32m+[m[32m    required int startMinutes,[m
[32m+[m[32m    required int durationMinutes,[m
[32m+[m[32m    String? notes,[m
[32m+[m[32m    String? activityId,[m
[32m+[m[32m  }) {[m
[32m+[m[32m    return scheduleCollection(userId).doc(eventId).update({[m
[32m+[m[32m      'title': title,[m
[32m+[m[32m      'category': category,[m
[32m+[m[32m      'date': _dateKey(date),[m
[32m+[m[32m      'startMinutes': startMinutes,[m
[32m+[m[32m      'durationMinutes': durationMinutes,[m
[32m+[m[32m      'notes': notes ?? '',[m
[32m+[m[32m      'activityId': activityId,[m
[32m+[m[32m      'updatedAt': FieldValue.serverTimestamp(),[m
[32m+[m[32m    });[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Future<void> deleteScheduleEvent({[m
[32m+[m[32m    required String userId,[m
[32m+[m[32m    required String eventId,[m
[32m+[m[32m  }) {[m
[32m+[m[32m    return scheduleCollection(userId).doc(eventId).delete();[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  // ---------------------------------------------------------------------------[m
[32m+[m[32m  // HELPERS[m
[32m+[m[32m  // ---------------------------------------------------------------------------[m
[32m+[m
[32m+[m[32m  String _dateKey(DateTime date) {[m
[32m+[m[32m    final year = date.year.toString().padLeft(4, '0');[m
[32m+[m[32m    final month = date.month.toString().padLeft(2, '0');[m
[32m+[m[32m    final day = date.day.toString().padLeft(2, '0');[m
[32m+[m
[32m+[m[32m    return '$year-$month-$day';[m
[32m+[m[32m  }[m
 }[m
\ No newline at end of file[m
