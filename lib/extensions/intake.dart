/// Import and notification adapters propose drafts; they never mutate SQL.
/// A future review screen will validate category mappings and duplicate keys.
abstract interface class BillImporter {
  String get source;
  Future<List<EntryDraft>> parse(Stream<List<int>> bytes);
}

abstract interface class NotificationRecognizer {
  EntryDraft? recognize({required String packageName, required String text});
}

class EntryDraft {
  const EntryDraft({
    required this.sourceKey,
    required this.amountMinor,
    required this.date,
    required this.note,
  });
  final String sourceKey, date, note;
  final int amountMinor;
}
