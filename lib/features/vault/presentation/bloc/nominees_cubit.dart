import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/nominee.dart';
import '../../domain/vault_repository.dart';

final class NomineesState extends Equatable {
  const NomineesState({
    this.nominees = const [],
    this.isLoading = true,
    this.errorMessage,
  });

  final List<Nominee> nominees;
  final bool isLoading;
  final String? errorMessage;

  @override
  List<Object?> get props => [nominees, isLoading, errorMessage];
}

/// A Cubit is a simpler BLoC: the UI calls methods instead of adding events.
/// Good fit for a simple list like nominees.
class NomineesCubit extends Cubit<NomineesState> {
  NomineesCubit({required VaultRepository repository, required String uid})
      : _repository = repository,
        _uid = uid,
        super(const NomineesState());

  final VaultRepository _repository;
  final String _uid;
  StreamSubscription<List<Nominee>>? _subscription;

  void start() {
    _subscription?.cancel();
    _subscription = _repository.watchNominees(_uid).listen(
          (list) => emit(NomineesState(nominees: list, isLoading: false)),
          onError: (Object _) => emit(NomineesState(
            nominees: state.nominees,
            isLoading: false,
            errorMessage: 'Could not load nominees.',
          )),
        );
  }

  Future<void> add(Nominee nominee) => _guard(
        () => _repository.addNominee(_uid, nominee),
      );

  Future<void> remove(String nomineeId) => _guard(
        () => _repository.deleteNominee(_uid, nomineeId),
      );

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Failure catch (f) {
      emit(NomineesState(
        nominees: state.nominees,
        isLoading: false,
        errorMessage: f.message,
      ));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
