import 'dart:async';

import 'package:inflection3/inflection3.dart';
import 'package:needle_orm/src/common.dart';
import 'package:recase/recase.dart';

import 'annotation.dart';
import 'query.dart';
import 'sql_query.dart';

class OrmMetaClass {
  final String name;
  final String? superClassName;
  final bool isAbstract;
  final List<OrmAnnotation> ormAnnotations;
  final List<OrmMetaField> fields;
  final ModelInspector modelInspector;

  String? _tableName;

  OrmMetaClass(this.name, this.modelInspector,
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

  List<OrmMetaField> allFields({bool searchParents = false}) {
    var parentClz = modelInspector.meta(superClassName!);
    return [
      ...fields,
      if (searchParents && parentClz != null)
        ...parentClz.allFields(searchParents: searchParents)
    ];
  }

  List<OrmMetaField> idFields() {
    return allFields(searchParents: true)
        .where((f) => f.ormAnnotations.any((annot) => annot.runtimeType == ID))
        .toList();
  }

  List<OrmMetaField> serverSideFields(ActionType actionType,
      {bool searchParents = false}) {
    var fields = allFields(searchParents: false)
        .where((element) => element.ormAnnotations
            .any((element) => element.isServerSide(actionType)))
        .toList();

    if (searchParents && superClassName != null) {
      var superClz = modelInspector.meta(superClassName!);
      if (superClz == null) return fields;
      return [
        ...fields,
        ...superClz.serverSideFields(actionType, searchParents: searchParents)
      ];
    }
    return fields;
  }
}

class OrmMetaField {
  final String name;
  final String type;
  final List<OrmAnnotation> ormAnnotations;

  OrmMetaField(this.name, this.type, {this.ormAnnotations = const []});
}

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

abstract class ModelInspector<M> {
  String getClassName(M model);
  M newInstance(String className);
  OrmMetaClass? meta(String className);
  List<OrmMetaClass> get allOrmMetaClasses;
  Map<String, dynamic> getDirtyFields(M model);
  dynamic getFieldValue(M model, String fieldName);
  void setFieldValue(M model, String fieldName, dynamic value);

  void loadModel(M model, Map<String, dynamic> m,
      {errorOnNonExistField: false});
}

abstract class BaseModelQuery<M extends Model, D>
    extends AbstractModelQuery<M, D> {
  final SqlExecutor sqlExecutor;

  late BaseModelQuery _topQuery;

  final Map<String, BaseModelQuery> queryMap = {};

  String get className;

  String _alias = '';

  String get alias => _alias;

  List<ColumnQuery> get columns;

  List<BaseModelQuery> get joins;

  // for join
  BaseModelQuery? relatedQuery;
  String? propName;

  BaseModelQuery(this.sqlExecutor, {BaseModelQuery? topQuery, this.propName}) {
    this._topQuery = topQuery ?? this;
  }

  bool _hasCondition([List<BaseModelQuery>? refrenceCache = null]) {
    // prevent cycle reference
    if (refrenceCache == null) {
      refrenceCache = [this];
    } else {
      if (refrenceCache.contains(this)) {
        return false;
      }
    }

    return columns.any((c) => c.hasCondition) ||
        joins.any((j) => j._hasCondition(refrenceCache));
  }

  BaseModelQuery get topQuery => _topQuery;

  @override
  Future<M?> findById(D id) async {
    return sqlExecutor.findById<M>(id);
  }

  @override
  Future<List<M>> findAll() async {
    return sqlExecutor.findAll(this);
  }

  SqlJoin _toSqlJoin() {
    var clz = sqlExecutor.modelInspector.meta(className)!;
    var tableName = clz.tableName;

    var joinStmt = '${relatedQuery!._alias}.${propName}_id = ${_alias}.id';

    return SqlJoin(tableName, _alias, joinStmt).apply((join) {
      columns.where((column) => column.hasCondition).forEach((column) {
        join.conditions.appendAll(column.toSqlConditions(_alias));
      });
    });
  }

  @override
  Future<List<M>> findList() async {
    // init all table aliases.
    _beforeQuery();

    var clz = sqlExecutor.modelInspector.meta(className)!;
    var tableName = clz.tableName;

    SqlQuery q = SqlQuery(tableName, _alias);
    q.columns.addAll(clz.fields.map((f) => "$_alias.${f.name}"));

    // _allJoins().map((e) => )
    q.joins.addAll(_allJoins().map((e) => e._toSqlJoin()));

    var conditions = columns.fold<List<SqlCondition>>(
        [], (init, e) => init..addAll(e.toSqlConditions(_alias)));

    q.conditions.appendAll(conditions);

    var sql = q.toSql();
    var params = q.params;

    var rows = await sqlExecutor.query(tableName, sql, params);

    // print('\t sql: $sql');

    // return sqlExecutor.findList(this);
    return [];
  }

  T findQuery<T extends BaseModelQuery>(String modelName, String propName) {
    var q = topQuery.queryMap[modelName];
    if (q == null) {
      q = createQuery(modelName, propName)..relatedQuery = this;
      topQuery.queryMap[modelName] = q;
    }
    return q as T;
  }

  BaseModelQuery createQuery(String modelName, String propName);

  void _beforeQuery() {
    if (this._topQuery != this) return;
    var allJoins = _allJoins();
    int i = 0;
    this._alias = "t${i++}";
    allJoins.forEach((element) {
      element._alias = "t${i++}";
    });
  }

  List<BaseModelQuery> _allJoins() {
    return _subJoins([]);
  }

  List<BaseModelQuery> _subJoins(List<BaseModelQuery> refrenceCache) {
    joins
        // filter those with conditions
        .where((j) => j._hasCondition())
        // prevent cycle reference
        .where((j) => !refrenceCache.contains(j))
        .forEach((j) {
      refrenceCache.add(j);
    });
    return refrenceCache;
  }
}
