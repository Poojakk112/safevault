import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/nominee.dart';
import '../bloc/nominees_cubit.dart';

/// List of trusted family members (nominees).
class NomineesPage extends StatelessWidget {
  const NomineesPage({super.key});

  Future<void> _addNominee(BuildContext context) async {
    final nominee = await showDialog<Nominee>(
      context: context,
      builder: (_) => const _AddNomineeDialog(),
    );
    if (nominee != null && context.mounted) {
      await context.read<NomineesCubit>().add(nominee);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nominees')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addNominee(context),
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: BlocBuilder<NomineesCubit, NomineesState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.nominees.isEmpty) {
            return const Center(
              child: Text(
                'Add the family members who should\n'
                'be able to access your documents.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.builder(
            itemCount: state.nominees.length,
            itemBuilder: (context, i) {
              final n = state.nominees[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(n.name.isNotEmpty ? n.name[0].toUpperCase() : '?'),
                ),
                title: Text(n.name),
                subtitle: Text([n.relation, n.phone, n.email]
                    .where((s) => s.isNotEmpty)
                    .join(' • ')),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => context.read<NomineesCubit>().remove(n.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AddNomineeDialog extends StatefulWidget {
  const _AddNomineeDialog();

  @override
  State<_AddNomineeDialog> createState() => _AddNomineeDialogState();
}

class _AddNomineeDialogState extends State<_AddNomineeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _relation = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _relation, _phone, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add nominee'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _relation,
                decoration: const InputDecoration(
                  labelText: 'Relation',
                  hintText: 'e.g. Mother, Spouse',
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
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
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              Nominee(
                id: const Uuid().v4(),
                name: _name.text.trim(),
                relation: _relation.text.trim(),
                phone: _phone.text.trim(),
                email: _email.text.trim(),
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
