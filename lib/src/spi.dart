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

  OrmMetaInfoClass(this.name,
      {this.superClassName,
      this.isAbstract = false,
      this.ormAnnotations = const [],
      this.fields = const []});
}

class OrmMetaInfoField {
  final String name;
  final String type;
  final List<OrmAnnotation> ormAnnotations;

  OrmMetaInfoField(this.name, this.type, {this.ormAnnotations = const []});
}

abstract class SqlExecutor<T extends Model> {
  ModelInspector<T> modelInspector;
  List<OrmMetaInfoClass> metaInfoClasses;

  SqlExecutor(this.modelInspector, this.metaInfoClasses);

  Iterable<OrmMetaInfoField> _serverSideFields(
      ActionType actionType, String entityClassName,
      [bool searchParents = false]) {
    var clz =
        metaInfoClasses.where((element) => element.name == entityClassName);
    if (clz.isEmpty) return [];
    var fields = clz.first.fields.where((element) => element.ormAnnotations
        .any((element) => element.isServerSide(actionType)));

    if (searchParents && clz.first.superClassName != null) {
      return [
        ...fields,
        ..._serverSideFields(
            actionType, clz.first.superClassName!, searchParents)
      ];
    }
    return fields;
  }

  void insert(T entity) {
    var action = ActionType.Insert;
    var entityClassName = modelInspector.getEntityClassName(entity);
    var tableName = getTableName(entityClassName);
    var dirtyMap = modelInspector.getDirtyFields(entity);
    var ssFields = _serverSideFields(action, entityClassName, true);

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
    print('SQL: $sql');
    query(tableName, sql, dirtyMap);
  }

  void update(T entity) {
    var tableName = getTableName(modelInspector.getEntityClassName(entity));
    print(
        'update $tableName , fields: ${modelInspector.getDirtyFields(entity)}');
  }

  void delete(T entity) {
    var tableName = getTableName(modelInspector.getEntityClassName(entity));
    print(
        'delete $tableName , fields: ${modelInspector.getDirtyFields(entity)}');
  }

  void deletePermanent(T entity) {
    var tableName = getTableName(modelInspector.getEntityClassName(entity));
    print(
        'deletePermanent $tableName , fields: ${modelInspector.getDirtyFields(entity)}');
  }

  String getTableName(String className) {
    return pluralize(ReCase(className).snakeCase);
  }

  String getColumnName(String fieldName) {
    return ReCase(fieldName).snakeCase;
  }

  /// Executes a single query.
  Future<List<List>> query(
      String tableName, String sql, Map<String, dynamic> substitutionValues,
      [List<String> returningFields = const []]);
}

abstract class ModelInspector<T> {
  String getEntityClassName(T obj);
  Map<String, dynamic> getDirtyFields(T obj);

  void loadEntity(T entity, Map<String, dynamic> m,
      {errorOnNonExistField: false});
}
