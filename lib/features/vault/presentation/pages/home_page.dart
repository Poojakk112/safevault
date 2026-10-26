import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../settings/presentation/settings_page.dart';
import '../../domain/vault_document.dart';
import '../bloc/documents_bloc.dart';
import '../bloc/nominees_cubit.dart';
import 'add_document_page.dart';
import 'nominees_page.dart';

/// Main screen: the list of documents in the vault.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  /// New routes don't automatically see blocs provided above this page,
  /// so we pass the existing instances down with BlocProvider.value.
  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<DocumentsBloc>()),
          BlocProvider.value(value: context.read<NomineesCubit>()),
        ],
        child: page,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vault'),
        actions: [
          IconButton(
            tooltip: 'Nominees',
            icon: const Icon(Icons.people_outline),
            onPressed: () => _push(context, const NomineesPage()),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _push(context, const SettingsPage()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _push(context, const AddDocumentPage()),
        icon: const Icon(Icons.add),
        label: const Text('Add document'),
      ),
      body: BlocConsumer<DocumentsBloc, DocumentsState>(
        listenWhen: (prev, curr) =>
            curr.errorMessage != null && prev.errorMessage != curr.errorMessage,
        listener: (context, state) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.errorMessage!))),
        builder: (context, state) {
          switch (state.status) {
            case DocumentsStatus.initial:
            case DocumentsStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case DocumentsStatus.failure:
              return const _EmptyView(
                icon: Icons.cloud_off,
                text: 'Could not load your vault.\nCheck your internet.',
              );
            case DocumentsStatus.success:
              if (state.documents.isEmpty) {
                return const _EmptyView(
                  icon: Icons.folder_open,
                  text: 'Your vault is empty.\nTap "Add document" to start.',
                );
              }
              return Column(
                children: [
                  if (state.isFromCache)
                    const MaterialBanner(
                      content: Text('Showing offline copy'),
                      leading: Icon(Icons.offline_bolt_outlined),
                      actions: [SizedBox.shrink()],
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: state.documents.length,
                      itemBuilder: (context, i) =>
                          _DocumentTile(document: state.documents[i]),
                    ),
                  ),
                ],
              );
          }
        },
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document});

  final VaultDocument document;

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('"${document.title}" will be removed from your vault.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final nominees = context.select((NomineesCubit c) => c.state.nominees);
    final names = nominees
        .where((n) => document.nomineeIds.contains(n.id))
        .map((n) => n.name)
        .join(', ');
    final date = DateFormat.yMMMd().format(document.createdAt);

    return Dismissible(
      key: ValueKey(document.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) =>
          context.read<DocumentsBloc>().add(DocumentDeleted(document)),
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline),
      ),
      child: ListTile(
        leading: CircleAvatar(child: Icon(document.category.icon)),
        title: Text(document.title),
        subtitle: Text([
          document.category.label,
          if (names.isNotEmpty) 'Nominees: $names',
          date,
        ].join(' • ')),
        trailing: document.hasFile ? const Icon(Icons.attach_file) : null,
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      );
}
