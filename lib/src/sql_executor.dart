import 'annotation.dart';
import 'inspector.dart';

abstract class SqlExecutor<M extends Model> {
  ModelInspector<M> modelInspector;

  SqlExecutor(this.modelInspector);

  /// Executes a single query.
  Future<List<List>> query(
      String tableName, String sql, Map<String, dynamic> substitutionValues,
      [List<String> returningFields = const []]);
}
