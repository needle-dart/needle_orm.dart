import 'package:recase/recase.dart';

import 'annotation.dart';
import 'inspector.dart';
import 'query.dart';

abstract class SqlExecutor<M extends Model> {
  ModelInspector<M> modelInspector;

  SqlExecutor(this.modelInspector);

  bool _isModelType(String type) {
    // print('\t\t >>> _isModelType: $type');
    if (type.endsWith('?')) {
      type = type.substring(0, type.length - 1);
    }
    return modelInspector.meta(type) != null;
  }

  void insert(M model) {
    var action = ActionType.Insert;
    var className = modelInspector.getClassName(model);
    var clz = modelInspector.meta(className)!;
    var tableName = clz.tableName;
    var dirtyMap = modelInspector.getDirtyFields(model);
    var ssFields = clz.serverSideFields(action, searchParents: true);

    var ssFieldNames = ssFields.map((e) => e.name);
    var fieldNames =
        [...dirtyMap.keys, ...ssFieldNames].map(getColumnName).join(',');

    var ssFieldValues = ssFields
        .map((e) => e.ormAnnotations
            .firstWhere((element) => element.isServerSide(action))
            .serverSideExpr(action))
        .map((e) => "'$e'");

    var fieldVariables = [
      ...dirtyMap.keys.map((e) => '@$e'),
      ...ssFieldValues,
    ].join(',');
    var sql = 'insert into $tableName( $fieldNames ) values( $fieldVariables )';
    print('Insert SQL: $sql');
    query(tableName, sql, dirtyMap);
  }

  void update(M model) {
    var action = ActionType.Update;
    var className = modelInspector.getClassName(model);
    var clz = modelInspector.meta(className)!;
    var tableName = clz.tableName;
    var dirtyMap = modelInspector.getDirtyFields(model);

    var idField = clz.idFields().first; // @TODO

    var idValue = dirtyMap.remove(idField.name);

    var ssFields = clz.serverSideFields(action, searchParents: true);

    var setClause = <String>[];

    dirtyMap.keys.forEach((name) {
      setClause.add('${getColumnName(name)}=@$name');
    });

    ssFields.forEach((field) {
      var name = field.name;
      var value = field.ormAnnotations
          .firstWhere((element) => element.isServerSide(action))
          .serverSideExpr(action);

      setClause.add("${getColumnName(name)}=$value");
    });

    dirtyMap[idField.name] = idValue;
    var sql =
        'update $tableName set ${setClause.join(',')} where ${idField.name}=@${idField.name}';
    print('Update SQL: $sql');
    query(tableName, sql, dirtyMap);
  }

  void delete(M model) {
    var className = modelInspector.getClassName(model);
    var clz = modelInspector.meta(className)!;
    var tableName = clz.tableName;
    print(
        'delete $tableName , fields: ${modelInspector.getDirtyFields(model)}');
  }

  void deletePermanent(M model) {
    var className = modelInspector.getClassName(model);
    var clz = modelInspector.meta(className)!;
    var tableName = clz.tableName;
    print(
        'deletePermanent $tableName , fields: ${modelInspector.getDirtyFields(model)}');
  }

  String getColumnName(String fieldName) {
    return ReCase(fieldName).snakeCase;
  }

  Future<N?> findById<N extends M>(dynamic id) async {
    var className = '$N';
    var clz = modelInspector.meta(className)!;

    var idFields = clz.idFields;
    var idFieldName = idFields().first.name;
    var tableName = clz.tableName;

    var selectFields = clz
        .allFields(searchParents: true)
        .where((element) => !_isModelType(element.type))
        .map((e) => e.name)
        .where((name) => name != idFieldName)
        .toList();

    var fieldNames = selectFields.map(getColumnName).join(',');

    var sql = 'select $fieldNames from $tableName where $idFieldName = $id';
    print('findById: ${N} [$id] => $sql');

    var rows = await query(tableName, sql, {});
    // print('\t result: $result');
    N model = modelInspector.newInstance('$N') as N;
    modelInspector.setFieldValue(model, idFieldName, id);

    if (rows.isNotEmpty) {
      var row = rows[0];
      for (int i = 0; i < row.length; i++) {
        var name = selectFields[i];
        var value = row[i];
        modelInspector.setFieldValue(model, name, value);
      }
    }
    return model;
  }

  Future<List<N>> findAll<N extends M>(BaseModelQuery modelQuery) async {
    print('BaseModelQuery class: ${modelQuery} : ${modelQuery.className}');
    var className = modelQuery.className;
    var clz = modelInspector.meta(className)!;

    var tableName = clz.tableName;

    var selectFields = clz
        .allFields(searchParents: true)
        .where((element) => !_isModelType(element.type))
        .map((e) => e.name)
        .toList();

    var fieldNames = selectFields.map(getColumnName).join(',');

    var sql = 'select $fieldNames from $tableName';
    // print('findAll: ${E} => $sql');

    var rows = await query(tableName, sql, {});
    // print('\t results: $result');

    var result = rows.map((row) {
      N model = modelInspector.newInstance(className) as N;
      for (int i = 0; i < row.length; i++) {
        var name = selectFields[i];
        var value = row[i];
        modelInspector.setFieldValue(model, name, value);
      }
      return model;
    });
    return result.toList();
  }

  Future<List<N>> findList<N extends M>(BaseModelQuery modelQuery) async {
    print('BaseModelQuery class: ${modelQuery} : ${modelQuery.className}');
    var className = modelQuery.className;
    var clz = modelInspector.meta(className)!;

    var tableName = clz.tableName;

    var selectFields = clz
        .allFields(searchParents: true)
        .where((element) => !_isModelType(element.type))
        .map((e) => e.name)
        .toList();

    var fieldNames = selectFields.map(getColumnName).join(',');

    var sql = 'select $fieldNames from $tableName';
    // print('findAll: ${E} => $sql');

    var rows = await query(tableName, sql, {});
    // print('\t results: $result');

    var result = rows.map((row) {
      N model = modelInspector.newInstance(className) as N;
      for (int i = 0; i < row.length; i++) {
        var name = selectFields[i];
        var value = row[i];
        modelInspector.setFieldValue(model, name, value);
      }
      return model;
    });
    return result.toList();
  }

  /// Executes a single query.
  Future<List<List>> query(
      String tableName, String sql, Map<String, dynamic> substitutionValues,
      [List<String> returningFields = const []]);
}
