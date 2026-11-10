import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/credential_store.dart';
import '../data/ledger_repository.dart';
import '../domain/operation.dart';

final repositoryProvider = Provider<LedgerRepository>(
  (ref) => throw UnimplementedError('Override at startup'),
);
final credentialProvider = Provider<CredentialStore>(
  (ref) => SecureCredentialStore(),
);
final entitiesProvider = StreamProvider<List<EntityView>>(
  (ref) => ref.watch(repositoryProvider).watch(),
);

final syncRequestProvider = StateProvider<int>((ref) => 0);
