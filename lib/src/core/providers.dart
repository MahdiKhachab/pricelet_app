import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/database/database.dart';

/// The single open database. Overridden in `main` once it has been opened.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

/// Bumped after any write that affects sales, stock or reports, so dependent
/// screens (dashboard, history, reports) reload.
final dataVersionProvider = StateProvider<int>((ref) => 0);

extension DataRefresh on WidgetRef {
  void bumpData() => read(dataVersionProvider.notifier).state++;
}
