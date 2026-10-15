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
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    enabled: !_loading || _users.isNotEmpty,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) => _load(
                      query: value.trim().length >= 2 ? value.trim() : null,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search by name or email...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Search profiles',
                  onPressed: _loading
                      ? null
                      : () => _load(query: _activeSearch),
                  icon: const Icon(Icons.search),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: 'Refresh profiles',
                  onPressed: _loading
                      ? null
                      : () => _load(query: _activeSearch),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.peach.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Profiles can be viewed and edited here. Creating or deleting Firebase sign-in accounts requires a trusted backend and is unavailable in this Spark-plan app.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      Expanded(
        child: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 36),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _load(query: _activeSearch),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            : _loading && _users.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _users.isEmpty
            ? Center(
                child: Text(
                  _activeSearch == null
                      ? 'No user profiles found.'
                      : 'No profiles match your search.',
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  for (final user in _users) _userTile(user),
                  if (_next != null)
                    OutlinedButton.icon(
                      onPressed: _loading ? null : () => _load(append: true),
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Load more users'),
                    ),
                ],
              ),
      ),
    ],
  );

  Widget _userTile(Map<String, dynamic> user) {
    final name = (user['name'] as String? ?? '').trim();
    final photo = (user['photoURL'] as String? ?? '').trim();
    final email = (user['email'] as String? ?? '').trim();
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.line),
      ),
      child: ListTile(
        onTap: _canManageUsers ? () => _showDetails(user) : null,
        leading: CircleAvatar(
          backgroundColor: AppColors.eucalyptus,
          foregroundImage: photo.isEmpty ? null : NetworkImage(photo),
          child: photo.isNotEmpty
              ? null
              : Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
        ),
        title: Text(
          name.isEmpty ? 'Unnamed user' : name,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          email.isEmpty ? user['uid'] as String : email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: 'Edit profile',
          onPressed: _canManageUsers ? () => _editProfile(user) : null,
          icon: const Icon(Icons.edit_outlined),
        ),
      ),
    );
  }
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
    title: const Text('Edit user profile'),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
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
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}
