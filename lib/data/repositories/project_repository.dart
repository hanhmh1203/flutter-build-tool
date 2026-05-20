import 'package:hive/hive.dart';
import '../../domain/models/project.dart';

class ProjectRepository {
  ProjectRepository(this._box);
  final Box<Project> _box;

  List<Project> list() {
    final items = _box.values.toList();
    items.sort((a, b) {
      final ao = a.lastOpenedAt;
      final bo = b.lastOpenedAt;
      if (ao == null && bo == null) return 0;
      if (ao == null) return 1;
      if (bo == null) return -1;
      return bo.compareTo(ao);
    });
    return items;
  }

  Project? get(String id) => _box.get(id);
  bool exists(String id) => _box.containsKey(id);

  Future<void> add(Project p) => _box.put(p.id, p);
  Future<void> update(Project p) => _box.put(p.id, p);
  Future<void> remove(String id) => _box.delete(id);
}
