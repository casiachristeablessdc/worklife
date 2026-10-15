import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _service = AdminService();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  String? _next;
  String _emailFilter = 'All users';
  bool _loading = true;
  String? _error;
  int _request = 0;

  bool get _canManageUsers => !_loading && _error == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({String? query, bool append = false}) async {
    if (append && (_next == null || _loading)) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = query == null || query.isEmpty
          ? await _service.listUsers(pageToken: append ? _next : null)
          : await _service.searchUsers(query);
      if (!mounted || request != _request) return;
      setState(() {
        _users = append ? [..._users, ...page.users] : page.users;
        _next = query == null || query.isEmpty ? page.nextPageToken : null;
        _truncated = page.truncated;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = adminServiceErrorMessage(error);
        _loading = false;
      });
    }
  }

  bool _truncated = false;

  List<Map<String, dynamic>> get _visibleUsers {
    return _users
        .where((user) {
          final hasEmail = (user['email'] as String? ?? '').trim().isNotEmpty;
          return switch (_emailFilter) {
            'With email' => hasEmail,
            'Without email' => !hasEmail,
            _ => true,
          };
        })
        .toList(growable: false);
  }

  String? get _activeSearch {
    final query = _search.text.trim();
    return query.length >= 2 ? query : null;
  }

  Future<void> _editProfile(Map<String, dynamic> user) async {
    AdminUserDetails detail;
    try {
      detail = await _service.loadUserDetails(user['uid'] as String);
    } catch (error) {
      final message = adminServiceErrorMessage(error);
      _message('Could not load this profile. $message');
      return;
    }
    if (!mounted) return;
    final result = await showDialog<_UserFormData>(
      context: context,
      builder: (_) => _UserEditor(profile: detail.profile),
    );
    if (result == null || !mounted) return;
    try {
      await _service.updateUser(
        uid: user['uid'] as String,
        name: result.name,
        jobTitle: result.jobTitle,
        company: result.company,
      );
      await _load(query: _activeSearch);
      _message('Profile updated.');
    } catch (error) {
      final message = adminServiceErrorMessage(error);
      _message('Could not update this profile. $message');
    }
  }

  Future<void> _showDetails(Map<String, dynamic> user) async {
    try {
      final details = await _service.loadUserDetails(user['uid'] as String);
      if (!mounted) return;
      final profile = details.profile;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            (profile['name'] as String).isEmpty
                ? 'User profile'
                : profile['name'] as String,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detail('Email', profile['email']),
              _detail('User ID', profile['uid']),
              _detail('Job title', profile['jobTitle']),
              _detail('Company', profile['company']),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _editProfile(user);
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit profile'),
            ),
          ],
        ),
      );
    } catch (error) {
      final message = adminServiceErrorMessage(error);
      _message('Could not load this profile. $message');
    }
  }

  Widget _detail(String label, dynamic value) {
    final detail = value?.toString().trim();
    final display = detail == null || detail.isEmpty ? 'Not set' : detail;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('$label: $display'),
    );
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (_loading && _users.isNotEmpty)
        const LinearProgressIndicator(minHeight: 2),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () => _load(query: _activeSearch),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Text(
                'Your community',
                style: GoogleFonts.fraunces(
                  fontSize: 25,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Find someone, review their details, and make updates with care.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.sub,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                enabled: !_loading || _users.isNotEmpty,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) => _load(
                  query: value.trim().length >= 2 ? value.trim() : null,
                ),
                decoration: InputDecoration(
                  hintText: 'Search users',
                  prefixIcon: const Icon(Icons.search, size: 16),
                  suffixIcon: IconButton(
                    tooltip: 'Search users',
                    onPressed: _loading
                        ? null
                        : () => _load(query: _activeSearch),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                ),
                style: GoogleFonts.inter(fontSize: 14),
              ),
              const SizedBox(height: 10),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    Text(
                      'Email',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.sub,
                      ),
                    ),
                    const Spacer(),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _emailFilter,
                        isDense: true,
                        borderRadius: BorderRadius.circular(10),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                        items:
                            const ['All users', 'With email', 'Without email']
                                .map(
                                  (filter) => DropdownMenuItem(
                                    value: filter,
                                    child: Text(filter),
                                  ),
                                )
                                .toList(growable: false),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _emailFilter = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (_error != null) ...[
                _UsersMessageCard(
                  message: _error!,
                  actionLabel: 'Try again',
                  onPressed: _loading
                      ? null
                      : () => _load(query: _activeSearch),
                ),
              ] else if (_loading && _users.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ] else if (_visibleUsers.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      _users.isEmpty
                          ? _activeSearch == null
                                ? 'No user accounts found.'
                                : 'No users match your search.'
                          : 'No users match this email filter.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.sub,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                for (final user in _visibleUsers) _userTile(user),
              ],
              if (_truncated)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Showing the first 100 matches. Refine your search to see a specific account.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.sub,
                    ),
                  ),
                ),
              if (_next != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : () => _load(append: true),
                    icon: const Icon(Icons.expand_more, size: 17),
                    label: Text(
                      'Load more users',
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _userTile(Map<String, dynamic> user) {
    final name = (user['name'] as String? ?? '').trim();
    final photo = (user['photoURL'] as String? ?? '').trim();
    final email = (user['email'] as String? ?? '').trim();
    final uid = user['uid'] as String;
    final jobTitle = (user['jobTitle'] as String? ?? '').trim();
    final company = (user['company'] as String? ?? '').trim();
    final profileSummary = [
      if (jobTitle.isNotEmpty) jobTitle,
      if (company.isNotEmpty) company,
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.pistachio,
                foregroundColor: AppColors.eucalyptusDark,
                foregroundImage: photo.isEmpty ? null : NetworkImage(photo),
                child: photo.isNotEmpty
                    ? null
                    : Text(
                        _initials(name),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: _canManageUsers ? () => _showDetails(user) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Unnamed user' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        email.isEmpty ? uid : email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.sub,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Edit profile',
                visualDensity: VisualDensity.compact,
                onPressed: _canManageUsers ? () => _editProfile(user) : null,
                icon: const Icon(Icons.edit_outlined, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  profileSummary.isEmpty
                      ? 'Job title and company not set'
                      : profileSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.sub),
                ),
              ),
              TextButton.icon(
                onPressed: _canManageUsers ? () => _showDetails(user) : null,
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: Text('Details', style: GoogleFonts.inter(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class _UsersMessageCard extends StatelessWidget {
  const _UsersMessageCard({
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String message;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.peach,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: GoogleFonts.inter(fontSize: 13, height: 1.4)),
        const SizedBox(height: 4),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Text(actionLabel, style: GoogleFonts.inter(fontSize: 13)),
        ),
      ],
    ),
  );
}

class _UserFormData {
  const _UserFormData({
    required this.name,
    required this.jobTitle,
    required this.company,
  });

  final String name;
  final String jobTitle;
  final String company;
}

class _UserEditor extends StatefulWidget {
  const _UserEditor({required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<_UserEditor> createState() => _UserEditorState();
}

class _UserEditorState extends State<_UserEditor> {
  late final TextEditingController _name;
  late final TextEditingController _job;
  late final TextEditingController _company;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.profile['name'] as String? ?? '',
    );
    _job = TextEditingController(
      text: widget.profile['jobTitle'] as String? ?? '',
    );
    _company = TextEditingController(
      text: widget.profile['company'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _job.dispose();
    _company.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    Navigator.pop(
      context,
      _UserFormData(
        name: _name.text.trim(),
        jobTitle: _job.text.trim(),
        company: _company.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Edit user profile'),
    actionsAlignment: MainAxisAlignment.end,
    actionsOverflowAlignment: OverflowBarAlignment.end,
    actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
    buttonPadding: const EdgeInsets.only(left: 8),
    content: SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextFormField(
            enabled: false,
            initialValue: widget.profile['email'] as String? ?? '',
            decoration: const InputDecoration(
              labelText: 'Email (managed by account owner)',
            ),
          ),
          TextField(
            controller: _job,
            decoration: const InputDecoration(labelText: 'Job title'),
          ),
          TextField(
            controller: _company,
            decoration: const InputDecoration(labelText: 'Company'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size(112, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        onPressed: _save,
        child: const Text('Save'),
      ),
    ],
  );
}
