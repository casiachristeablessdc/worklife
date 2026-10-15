import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

class AdminDatabaseScreen extends StatefulWidget {
  const AdminDatabaseScreen({super.key});

  @override
  State<AdminDatabaseScreen> createState() => _AdminDatabaseScreenState();
}

class _AdminDatabaseScreenState extends State<AdminDatabaseScreen> {
  static const _collections = ['activities', 'checkIns', 'goals', 'schedule'];
  static const _userPageSize = 250;
  static const _recordPageSize = 25;
  final _db = FirebaseFirestore.instance;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  String? _uid;
  String? _collection;
  String? _usersError;
  String? _recordsError;
  bool _loadingUsers = true;
  bool _loadingRecords = false;
  bool _loadingMore = false;
  bool _saving = false;
  bool _hasMoreRecords = false;
  int _recordsRequest = 0;
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastRecord;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _records = [];

  bool get _canMutateRecords =>
      _selectedCollection != null &&
      _users.isNotEmpty &&
      _usersError == null &&
      _recordsError == null &&
      !_loadingUsers &&
      !_loadingRecords &&
      !_loadingMore &&
      !_saving;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loadingUsers = true;
      _usersError = null;
    });
    try {
      final users = <Map<String, dynamic>>[];
      final baseQuery = _db
          .collection('users')
          .orderBy(FieldPath.documentId)
          .limit(_userPageSize);
      Query<Map<String, dynamic>> query = baseQuery;
      while (true) {
        final page = await query.get();
        users.addAll(
          page.docs.map((document) {
            final data = document.data();
            return <String, dynamic>{
              'uid': document.id,
              'displayName': (data['name'] as String? ?? '').trim(),
              'email': (data['email'] as String? ?? '').trim(),
            };
          }),
        );
        if (page.docs.length < _userPageSize) break;
        query = baseQuery.startAfterDocument(page.docs.last);
      }
      if (!mounted) return;
      setState(() {
        _users = users;
        if (!_users.any((user) => user['uid'] == _uid)) {
          _uid = null;
        }
        _loadingUsers = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _usersError = adminServiceErrorMessage(error);
        _loadingUsers = false;
      });
    }
  }

  CollectionReference<Map<String, dynamic>>? get _selectedCollection {
    final uid = _uid;
    final collection = _collection;
    if (uid == null || collection == null) return null;
    return _db.collection('users').doc(uid).collection(collection);
  }

  Future<void> _loadRecords({bool append = false}) async {
    if (append && (!_hasMoreRecords || _loadingMore)) return;
    final request = ++_recordsRequest;
    final collection = _selectedCollection;
    if (collection == null) {
      setState(() {
        _records = [];
        _lastRecord = null;
        _hasMoreRecords = false;
        _recordsError = null;
        _loadingRecords = false;
        _loadingMore = false;
      });
      return;
    }
    setState(() {
      _recordsError = null;
      if (append) {
        _loadingMore = true;
      } else {
        _loadingRecords = true;
        _loadingMore = false;
        _records = [];
        _lastRecord = null;
        _hasMoreRecords = false;
      }
    });

    try {
      Query<Map<String, dynamic>> query = collection
          .orderBy(FieldPath.documentId)
          .limit(_recordPageSize);
      if (append && _lastRecord != null) {
        query = query.startAfterDocument(_lastRecord!);
      }
      final page = await query.get();
      if (!mounted || request != _recordsRequest) return;
      setState(() {
        _records = append ? [..._records, ...page.docs] : page.docs;
        _lastRecord = page.docs.isEmpty ? _lastRecord : page.docs.last;
        _hasMoreRecords = page.docs.length == _recordPageSize;
        _loadingRecords = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || request != _recordsRequest) return;
      setState(() {
        _recordsError = adminServiceErrorMessage(error);
        _loadingRecords = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _editRecord({
    QueryDocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    if (!_canMutateRecords) return;
    final uid = _uid;
    final collectionName = _collection;
    if (uid == null || collectionName == null) {
      _message('Select a user and collection first.');
      return;
    }
    final values = await showDialog<_RecordValues>(
      context: context,
      builder: (_) =>
          _RecordEditor(collection: collectionName, document: document),
    );
    if (values == null || !mounted) return;
    if (uid != _uid || collectionName != _collection) return;
    if (!_canMutateRecords) return;
    setState(() => _saving = true);
    try {
      final collection = _db
          .collection('users')
          .doc(uid)
          .collection(collectionName);
      final data = {
        ...?document?.data(),
        ...values.data,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (document == null) {
        final id = values.id.trim().isEmpty && collectionName == 'checkIns'
            ? values.data['date'] as String
            : values.id.trim();
        final ref = id.isEmpty ? collection.doc() : collection.doc(id);
        data['createdAt'] = FieldValue.serverTimestamp();
        await ref.set(data);
      } else {
        await collection.doc(document.id).update(data);
      }
      await _loadRecords();
      _message(document == null ? 'Record created.' : 'Record updated.');
    } catch (error) {
      _message(
        'Could not save this record. ${adminServiceErrorMessage(error)}',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteRecord(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    if (!_canMutateRecords) return;
    final uid = _uid;
    final collectionName = _collection;
    if (uid == null || collectionName == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text('Delete “${document.id}” permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (!_canMutateRecords || uid != _uid || collectionName != _collection) {
      return;
    }
    setState(() => _saving = true);
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection(collectionName)
          .doc(document.id)
          .delete();
      await _loadRecords();
      _message('Record deleted.');
    } catch (error) {
      _message(
        'Could not delete this record. ${adminServiceErrorMessage(error)}',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _refresh() async {
    await _loadUsers();
    if (_uid != null && _collection != null) await _loadRecords();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _filteredRecords {
    final term = _search.text.trim().toLowerCase();
    if (term.isEmpty) return _records;
    return _records
        .where((record) {
          if (record.id.toLowerCase().contains(term)) return true;
          return record.data().values.any(
            (value) => _formatValue(value).toLowerCase().contains(term),
          );
        })
        .toList(growable: false);
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    child: DropdownButtonFormField<String>(
                      initialValue: _uid,
                      hint: const Text('Select a user...'),
                      decoration: const InputDecoration(labelText: 'User'),
                      items: _users
                          .map(
                            (user) => DropdownMenuItem(
                              value: user['uid'] as String,
                              child: Text(
                                (user['displayName'] as String? ?? '').isEmpty
                                    ? ((user['email'] as String? ?? '').isEmpty
                                          ? user['uid'] as String
                                          : user['email'] as String)
                                    : '${user['displayName']} · ${user['email'] ?? ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _loadingUsers || _usersError != null
                          ? null
                          : (value) {
                              setState(() => _uid = value);
                              _loadRecords();
                            },
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<String>(
                      initialValue: _collection,
                      hint: const Text('Select a collection.'),
                      decoration: const InputDecoration(
                        labelText: 'Collection',
                      ),
                      items: _collections
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        setState(() => _collection = value);
                        _loadRecords();
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh Firebase data',
                    onPressed: _loadingUsers || _loadingRecords
                        ? null
                        : _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _search,
                enabled: _uid != null && _collection != null,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search records by title, date, or ID...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              if (_loadingUsers || _loadingRecords || _saving)
                const LinearProgressIndicator(minHeight: 2),
            ],
          ),
        ),
        Expanded(child: _recordBody()),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _canMutateRecords ? () => _editRecord() : null,
                icon: const Icon(Icons.add),
                label: const Text('Add record'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _recordBody() {
    if (_usersError != null) return _retryState(_usersError!, _loadUsers);
    if (_loadingUsers && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_users.isEmpty) {
      return _emptyState(
        icon: Icons.people_outline,
        title: 'No user profiles found',
        message:
            'User records will appear here after they are saved to Firestore.',
      );
    }
    if (_uid == null || _collection == null) {
      return _emptyState(
        icon: Icons.storage_outlined,
        title: 'Choose what to view',
        message: 'Select a user and collection to load its Firestore records.',
      );
    }
    if (_recordsError != null) return _retryState(_recordsError!, _loadRecords);
    if (_loadingRecords && _records.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final records = _filteredRecords;
    if (records.isEmpty) {
      final hasSearch = _search.text.trim().isNotEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasSearch ? Icons.search_off_rounded : Icons.inbox_outlined,
                size: 38,
                color: AppColors.sub,
              ),
              const SizedBox(height: 12),
              Text(
                hasSearch
                    ? 'No matching records on this page.'
                    : 'No records in $_collection yet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                hasSearch && _hasMoreRecords
                    ? 'Load another page to search more records.'
                    : 'Add a record to this user’s $_collection collection.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppColors.sub, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (hasSearch && _hasMoreRecords)
                OutlinedButton.icon(
                  onPressed: _loadingMore
                      ? null
                      : () => _loadRecords(append: true),
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Load more records'),
                )
              else if (!hasSearch)
                OutlinedButton.icon(
                  onPressed: _canMutateRecords ? () => _editRecord() : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add first record'),
                ),
              if (_loadingMore) const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      children: [
        for (final record in records) _recordCard(record),
        if (_hasMoreRecords)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: OutlinedButton.icon(
              onPressed: _loadingMore ? null : () => _loadRecords(append: true),
              icon: _loadingMore
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(_loadingMore ? 'Loading...' : 'Load more records'),
            ),
          ),
      ],
    );
  }

  Widget _recordCard(QueryDocumentSnapshot<Map<String, dynamic>> record) {
    final fields = _clean(record.data()).entries.toList(growable: false);
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.line),
      ),
      child: ExpansionTile(
        title: Text(
          _recordTitle(record),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('ID: ${record.id}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          for (final field in fields)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                field.key,
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.sub),
              ),
              subtitle: SelectableText(
                _formatValue(field.value),
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.ink),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => _showRecord(record),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View'),
                ),
                TextButton.icon(
                  onPressed: _canMutateRecords
                      ? () => _editRecord(document: record)
                      : null,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: _canMutateRecords
                      ? () => _deleteRecord(record)
                      : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: AppColors.sub),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.sub, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  Widget _retryState(String message, Future<void> Function() retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 36),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadingUsers || _loadingRecords ? null : retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );

  String _recordTitle(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final title = data['title'] ?? data['date'] ?? data['name'];
    return title == null ? document.id : '$title';
  }

  Map<String, dynamic> _clean(Map<String, dynamic> data) => {
    for (final entry in data.entries)
      if (entry.key != 'createdAt' && entry.key != 'updatedAt')
        entry.key: entry.value is Timestamp
            ? (entry.value as Timestamp).toDate().toIso8601String()
            : entry.value,
  };

  String _formatValue(Object? value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is Map || value is List) return jsonEncode(value);
    return value?.toString() ?? 'Not set';
  }

  Future<void> _showRecord(
    QueryDocumentSnapshot<Map<String, dynamic>> record,
  ) async {
    final fields = _clean(record.data()).entries.toList(growable: false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _recordTitle(record),
          style: GoogleFonts.fraunces(fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: 430,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Document ID: ${record.id}'),
                const Divider(height: 24),
                for (final field in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field.key,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.sub,
                          ),
                        ),
                        const SizedBox(height: 3),
                        SelectableText(_formatValue(field.value)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _RecordValues {
  const _RecordValues(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
}

class _RecordEditor extends StatefulWidget {
  const _RecordEditor({required this.collection, this.document});
  final String collection;
  final QueryDocumentSnapshot<Map<String, dynamic>>? document;

  @override
  State<_RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<_RecordEditor> {
  late final TextEditingController _id;
  late final Map<String, TextEditingController> _fields;
  late final Map<String, bool> _toggles;
  String? _error;

  List<String> get _textFields => switch (widget.collection) {
    'activities' => ['title', 'category', 'date', 'notes', 'durationMinutes'],
    'checkIns' => ['date', 'energyScore', 'note'],
    'goals' => ['title', 'date', 'category'],
    'schedule' => [
      'title',
      'category',
      'date',
      'startMinutes',
      'durationMinutes',
      'notes',
      'activityId',
    ],
    _ => const [],
  };

  List<String> get _boolFields => switch (widget.collection) {
    'activities' => ['completed'],
    'goals' => ['completed', 'active'],
    _ => const [],
  };

  @override
  void initState() {
    super.initState();
    final existing = widget.document?.data() ?? const <String, dynamic>{};
    _id = TextEditingController(text: widget.document?.id ?? '');
    _fields = {
      for (final key in _textFields)
        key: TextEditingController(
          text: existing[key]?.toString() ?? _defaultValue(key),
        ),
    };
    _toggles = {
      for (final key in _boolFields)
        key: existing.containsKey(key)
            ? existing[key] == true
            : key == 'active',
    };
  }

  String _defaultValue(String key) => switch (key) {
    'category' => 'Personal',
    'durationMinutes' => '30',
    'energyScore' => '3',
    'startMinutes' => '540',
    'active' => 'true',
    _ => '',
  };

  @override
  void dispose() {
    _id.dispose();
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final data = <String, dynamic>{};
    for (final entry in _fields.entries) {
      final text = entry.value.text.trim();
      if (entry.key == 'durationMinutes' ||
          entry.key == 'startMinutes' ||
          entry.key == 'energyScore') {
        final value = int.tryParse(text);
        final invalid =
            value == null ||
            value < 0 ||
            (entry.key == 'energyScore' && (value < 1 || value > 5)) ||
            (entry.key == 'startMinutes' && value > 1439) ||
            (entry.key == 'durationMinutes' &&
                widget.collection == 'schedule' &&
                value == 0);
        if (invalid) {
          setState(() => _error = 'Enter a valid ${entry.key} value.');
          return;
        }
        data[entry.key] = value;
      } else if (text.isNotEmpty ||
          entry.key == 'notes' ||
          entry.key == 'note') {
        data[entry.key] = text;
      }
    }
    if (_boolFields.isNotEmpty) data.addAll(_toggles);
    if (data['date'] == null ||
        data['date'].toString().isEmpty ||
        (data['title'] == null && widget.collection != 'checkIns')) {
      setState(() => _error = 'A title and date are required.');
      return;
    }
    final dateText = data['date'].toString();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateText) ||
        DateTime.tryParse(dateText) == null) {
      setState(() => _error = 'Use a valid date in YYYY-MM-DD format.');
      return;
    }
    if (widget.collection == 'checkIns' &&
        _id.text.trim().isNotEmpty &&
        _id.text.trim() != dateText) {
      setState(() => _error = 'A check-in document ID must match its date.');
      return;
    }
    final id = widget.collection == 'checkIns' && _id.text.trim().isEmpty
        ? data['date'] as String
        : _id.text;
    Navigator.pop(context, _RecordValues(id, data));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.document == null
          ? 'Create ${widget.collection} record'
          : 'Edit ${widget.collection} record',
    ),
    content: SizedBox(
      width: 430,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _id,
              enabled: widget.document == null,
              decoration: const InputDecoration(
                labelText: 'Document ID (optional)',
              ),
            ),
            for (final entry in _fields.entries)
              TextField(
                controller: entry.value,
                keyboardType:
                    {
                      'durationMinutes',
                      'startMinutes',
                      'energyScore',
                    }.contains(entry.key)
                    ? TextInputType.number
                    : TextInputType.text,
                maxLines: {'notes', 'note'}.contains(entry.key) ? 3 : 1,
                decoration: InputDecoration(labelText: entry.key),
              ),
            for (final key in _boolFields)
              SwitchListTile(
                title: Text(key),
                value: _toggles[key]!,
                onChanged: (value) => setState(() => _toggles[key] = value),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
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
