import '../../domain/entities/measurement_entity.dart';

/// Measurements of the loaded series, kept per slice (by slice index), so a
/// measurement shows only on the slice it was drawn on.
class SliceMeasurements {
  final Map<int, List<MeasurementEntity>> _bySlice = {};

  /// The measurements on [slice]. The list is live: adding to or removing
  /// from it changes that slice.
  List<MeasurementEntity> onSlice(int slice) =>
      _bySlice.putIfAbsent(slice, () => []);

  int countOn(int slice) => _bySlice[slice]?.length ?? 0;

  MeasurementEntity? find(String id, {required int slice}) {
    for (final m in _bySlice[slice] ?? const <MeasurementEntity>[]) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Puts a copy of measurement [id] from slice [from] on slice [to], with
  /// [newId]. Returns the copy, or null if [id] is not on [from].
  MeasurementEntity? copy(
    String id, {
    required int from,
    required int to,
    required String newId,
  }) {
    final original = find(id, slice: from);
    if (original == null) return null;
    final copy = original.copyWith(id: newId);
    onSlice(to).add(copy);
    return copy;
  }

  /// Moves measurement [id] from slice [from] to slice [to].
  bool move(String id, {required int from, required int to}) {
    final measurement = find(id, slice: from);
    if (measurement == null) return false;
    onSlice(from).removeWhere((m) => m.id == id);
    onSlice(to).add(measurement);
    return true;
  }

  void remove(String id, {required int slice}) =>
      _bySlice[slice]?.removeWhere((m) => m.id == id);

  void clearAll() => _bySlice.clear();
}
