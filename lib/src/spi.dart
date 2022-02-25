import 'dart:async';

import 'package:inflection3/inflection3.dart';
import 'package:recase/recase.dart';

import 'annotation.dart';

class OrmMetaInfoClass {
  final String name;
  final String? superClassName;
  final bool isAbstract;
  final List<OrmAnnotation> ormAnnotations;
  final List<OrmMetaInfoField> fields;
  final ModelInspector modelInspector;

  String? _tableName;

  OrmMetaInfoClass(this.name, this.modelInspector,
      {this.superClassName,
      this.isAbstract = false,
      this.ormAnnotations = const [],
      this.fields = const []}) {
    var tables = ormAnnotations.whereType<Table>();
    if (tables.isNotEmpty) {
      _tableName = tables.first.name;
    }
    _tableName = _tableName ?? _getTableName(this.name);
  }

  String get tableName => _tableName!;

  String _getTableName(String className) {
    return pluralize(ReCase(className).snakeCase);
  }

  List<OrmMetaInfoField> allFields({bool searchParents = false}) {
    var parentClz = modelInspector.metaInfo(superClassName!);
    return [
      ...fields,
      if (searchParents && parentClz != null)
        ...parentClz.allFields(searchParents: searchParents)
    ];
  }

  List<OrmMetaInfoField> idFields() {
    return allFields(searchParents: true)
        .where((f) => f.ormAnnotations.any((annot) => annot.runtimeType == ID))
        .toList();
  }

  List<OrmMetaInfoField> serverSideFields(ActionType actionType,
      {bool searchParents = false}) {
    var fields = allFields(searchParents: false)
        .where((element) => element.ormAnnotations
            .any((element) => element.isServerSide(actionType)))
        .toList();

    if (searchParents && superClassName != null) {
      var superClz = modelInspector.metaInfo(superClassName!);
      if (superClz == null) return fields;
      return [
        ...fields,
        ...superClz.serverSideFields(actionType, searchParents: searchParents)
      ];
    }
    return fields;
  }
}

class OrmMetaInfoField {
  final String name;
  final String type;
  final List<OrmAnnotation> ormAnnotations;

  OrmMetaInfoField(this.name, this.type, {this.ormAnnotations = const []});
}

abstract class SqlExecutor<T extends Model> {
  ModelInspector<T> modelInspector;

  SqlExecutor(this.modelInspector);

  bool _isEntityType(String type) {
    // print('\t\t >>> isEntityType: $type');
    if (type.endsWith('?')) {
      type = type.substring(0, type.length - 1);
    }
    return modelInspector.metaInfo(type) != null;
  }

  void insert(T entity) {
    var action = ActionType.Insert;
    var entityClassName = modelInspector.getEntityClassName(entity);
    var clz = modelInspector.metaInfo(entityClassName)!;
    var tableName = clz.tableName;
    var dirtyMap = modelInspector.getDirtyFields(entity);
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

  void update(T entity) {
    var action = ActionType.Update;
    var entityClassName = modelInspector.getEntityClassName(entity);
    var clz = modelInspector.metaInfo(entityClassName)!;
    var tableName = clz.tableName;
    var dirtyMap = modelInspector.getDirtyFields(entity);

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

  void delete(T entity) {
    var entityClassName = modelInspector.getEntityClassName(entity);
    var clz = modelInspector.metaInfo(entityClassName)!;
    var tableName = clz.tableName;
    print(
        'delete $tableName , fields: ${modelInspector.getDirtyFields(entity)}');
  }

  void deletePermanent(T entity) {
    var entityClassName = modelInspector.getEntityClassName(entity);
    var clz = modelInspector.metaInfo(entityClassName)!;
    var tableName = clz.tableName;
    print(
        'deletePermanent $tableName , fields: ${modelInspector.getDirtyFields(entity)}');
  }

  String getColumnName(String fieldName) {
    return ReCase(fieldName).snakeCase;
  }

  Future<E?> findById<E extends T>(dynamic id) async {
    var entityClassName = '$E';
    var clz = modelInspector.metaInfo(entityClassName)!;

    var idFields = clz.idFields;
    var idFieldName = idFields().first.name;
    var tableName = clz.tableName;

    var selectFields = clz
        .allFields(searchParents: true)
        .where((element) => !_isEntityType(element.type))
        .map((e) => e.name)
        .where((name) => name != idFieldName)
        .toList();

    var fieldNames = selectFields.map(getColumnName).join(',');

    var sql = 'select $fieldNames from $tableName where $idFieldName = $id';
    print('findById: ${E} [$id] => $sql');

    var rows = await query(tableName, sql, {});
    // print('\t result: $result');
    E entity = modelInspector.newInstance('$E') as E;
    modelInspector.setFieldValue(entity, idFieldName, id);

    if (rows.isNotEmpty) {
      var row = rows[0];
      for (int i = 0; i < row.length; i++) {
        var name = selectFields[i];
        var value = row[i];
        modelInspector.setFieldValue(entity, name, value);
      }
    }
    return entity;
  }

  Future<List<E>> findAll<E extends T>() async {
    var entityClassName = '$E';
    var clz = modelInspector.metaInfo(entityClassName)!;

    var tableName = clz.tableName;

    var selectFields = clz
        .allFields(searchParents: true)
        .where((element) => !_isEntityType(element.type))
        .map((e) => e.name)
        .toList();

    var fieldNames = selectFields.map(getColumnName).join(',');

    var sql = 'select $fieldNames from $tableName';
    // print('findAll: ${E} => $sql');

    var rows = await query(tableName, sql, {});
    // print('\t results: $result');

    var result = rows.map((row) {
      E entity = modelInspector.newInstance('$E') as E;
      for (int i = 0; i < row.length; i++) {
        var name = selectFields[i];
        var value = row[i];
        modelInspector.setFieldValue(entity, name, value);
      }
      return entity;
    });
    return result.toList();
  }

  /// Executes a single query.
  Future<List<List>> query(
      String tableName, String sql, Map<String, dynamic> substitutionValues,
      [List<String> returningFields = const []]);
}

abstract class ModelInspector<T> {
  String getEntityClassName(T obj);
  T newInstance(String entityClassName);
  OrmMetaInfoClass? metaInfo(String entityClassName);
  List<OrmMetaInfoClass> get allOrmMetaInfoClasses;
  Map<String, dynamic> getDirtyFields(T obj);
  dynamic getFieldValue(T obj, String fieldName);
  void setFieldValue(T obj, String fieldName, dynamic value);

  void loadEntity(T entity, Map<String, dynamic> m,
      {errorOnNonExistField: false});
}

abstract class BaseModelQuery<T extends Model, D>
    extends AbstractModelQuery<T, D> {
  final SqlExecutor sqlExecutor;

  String get entityClassName;

  BaseModelQuery(this.sqlExecutor);

  @override
  Future<T?> findById(D id) async {
    return sqlExecutor.findById<T>(id);
  }

  @override
  Future<List<T>> findAll() async {
    return sqlExecutor.findAll<T>();
  }
}
