import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/vault_document.dart';
import '../bloc/documents_bloc.dart';
import '../bloc/nominees_cubit.dart';

/// Form to add a new document to the vault.
class AddDocumentPage extends StatefulWidget {
  const AddDocumentPage({super.key});

  @override
  State<AddDocumentPage> createState() => _AddDocumentPageState();
}

class _AddDocumentPageState extends State<AddDocumentPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  DocumentCategory _category = DocumentCategory.bank;
  final Set<String> _selectedNominees = {};
  PlatformFile? _file;

  static const _maxFileBytes = 10 * 1024 * 1024; // 10 MB

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    if (!mounted) return;
    if (picked.size > _maxFileBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File is too large (max 10 MB).')),
      );
      return;
    }
    setState(() => _file = picked);
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final document = VaultDocument(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      category: _category,
      notes: _notesController.text.trim(),
      nomineeIds: _selectedNominees.toList(),
      createdAt: DateTime.now(),
    );
    context
        .read<DocumentsBloc>()
        .add(DocumentAdded(document, filePath: _file?.path));
  }

  @override
  Widget build(BuildContext context) {
    final nominees = context.watch<NomineesCubit>().state.nominees;

    return BlocConsumer<DocumentsBloc, DocumentsState>(
      // Close the page when saving finishes without an error.
      listenWhen: (prev, curr) => prev.isSaving && !curr.isSaving,
      listener: (context, state) {
        if (state.errorMessage == null) Navigator.of(context).pop();
      },
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Add document')),
        body: AbsorbPointer(
          absorbing: state.isSaving,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. SBI savings account',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter a title'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<DocumentCategory>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final c in DocumentCategory.values)
                      DropdownMenuItem(
                        value: c,
                        child: Row(children: [
                          Icon(c.icon, size: 20),
                          const SizedBox(width: 8),
                          Text(c.label),
                        ]),
                      ),
                  ],
                  onChanged: (c) => setState(() => _category = c ?? _category),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'Branch, policy number hint, where the papers are…',
                  ),
                ),
                const SizedBox(height: 16),
                Text('Nominees', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (nominees.isEmpty)
                  const Text('No nominees yet. Add them from the people icon.')
                else
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final n in nominees)
                        FilterChip(
                          label: Text('${n.name} (${n.relation})'),
                          selected: _selectedNominees.contains(n.id),
                          onSelected: (on) => setState(() => on
                              ? _selectedNominees.add(n.id)
                              : _selectedNominees.remove(n.id)),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: Text(_file?.name ?? 'Attach file (PDF / image)'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: state.isSaving ? null : _save,
                  child: state.isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save to vault'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
