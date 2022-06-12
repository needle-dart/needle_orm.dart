// ignore_for_file: constant_identifier_names
import 'dart:collection';
import 'dart:math';

import 'package:logging/logging.dart';

import 'core.dart';
import 'inspector.dart';
import 'meta.dart';
import 'sql.dart';
import 'sql_query.dart';
import 'common.dart';

class ColumnQuery<T, R> {
  final List<ColumnCondition> conditions = [];
  final String name;

  ColumnQuery(this.name);

  bool get hasCondition => conditions.isNotEmpty;

  void clear() {
    conditions.clear();
  }

  static String classNameForType(String type) {
    switch (type) {
      case 'int':
        return 'IntColumn';
      case 'double':
        return 'DoubleColumn';
      case 'bool':
        return 'BoolColumn';
      case 'DateTime':
        return 'DateTimeColumn';
      case 'String':
        return 'StringColumn';
      default:
        return 'ColumnQuery';
    }
  }

  R _addCondition(ColumnConditionOper oper, dynamic value) {
    conditions.add(ColumnCondition(name, oper, value));
    return this as R;
  }

  R eq(T value) => _addCondition(ColumnConditionOper.EQ, value);

  Iterable<SqlCondition> toSqlConditions(String tableAlias) {
    return conditions.map((e) => _toSqlCondition(tableAlias, e));
  }

  SqlCondition _toSqlCondition(String tableAlias, ColumnCondition cc) {
    SqlCondition sc = SqlCondition("r.deleted = 0");
    String columnName = '$tableAlias.$name';
    String paramName = '${tableAlias}__$name';
    bool isRemote = false;
    String? ssExpr;
    if (cc.value is ServerSideExpr) {
      isRemote = true;
      ssExpr = (cc.value as ServerSideExpr).expr;
    }
    String op = toSql(cc.oper);
    switch (cc.oper) {
      case ColumnConditionOper.EQ:
      case ColumnConditionOper.GT:
      case ColumnConditionOper.LT:
      case ColumnConditionOper.GE:
      case ColumnConditionOper.LE:
      case ColumnConditionOper.LIKE:
        sc = isRemote
            ? SqlCondition("$columnName $op ${ssExpr!} ")
            : SqlCondition(
                "$columnName $op @$paramName ", {paramName: cc.value});
        break;
      case ColumnConditionOper.BETWEEN:
      case ColumnConditionOper.NOT_BETWEEN:
        sc = SqlCondition(
            "$columnName $op @${paramName}_from and @${paramName}_to",
            {'${paramName}_from': cc.value[0], '${paramName}_to': cc.value[1]});
        break;
      case ColumnConditionOper.IN:
      case ColumnConditionOper.NOT_IN:
        sc =
            SqlCondition("$columnName $op @$paramName ", {paramName: cc.value});
        break;
      case ColumnConditionOper.IS_NULL:
      case ColumnConditionOper.IS_NOT_NULL:
        sc = SqlCondition("$columnName $op ");
        break;
    }
    return sc;
  }

  OrderField asc() => OrderField(this, Order.asc);

  OrderField desc() => OrderField(this, Order.desc);
}

enum Order { asc, desc }

class OrderField {
  ColumnQuery column;
  Order order;
  OrderField(this.column, this.order);

  @override
  String toString() {
    return column.name + (order == Order.desc ? ' desc' : '');
  }
}

class ServerSideExpr {
  final String expr;
  ServerSideExpr(this.expr);
}

mixin RangeCondition<T, R> on ColumnQuery<T, R> {
  // ignore: non_constant_identifier_names
  R IN(List<T> value) => _addCondition(ColumnConditionOper.IN, value);

  R notIn(List<T> value) => _addCondition(ColumnConditionOper.NOT_IN, value);
}

mixin NullCondition<T, R> on ColumnQuery<T, R> {
  R isNull() => _addCondition(ColumnConditionOper.IS_NULL, null);

  R isNotNull() => _addCondition(ColumnConditionOper.IS_NOT_NULL, null);
}

mixin ComparableCondition<T, R> on ColumnQuery<T, R> {
  R gt(T value) => _addCondition(ColumnConditionOper.GT, value);

  R ge(T value) => _addCondition(ColumnConditionOper.GE, value);

  R lt(T value) => _addCondition(ColumnConditionOper.LT, value);

  R le(T value) => _addCondition(ColumnConditionOper.LE, value);

  R between(T beginValue, T endValue) =>
      _addCondition(ColumnConditionOper.BETWEEN, [beginValue, endValue]);

  R notBetween(T beginValue, T endValue) =>
      _addCondition(ColumnConditionOper.NOT_BETWEEN, [beginValue, endValue]);

/* 
  R operator >(T value) => gt(value);
  R operator <(T value) => lt(value);
  R operator >=(T value) => ge(value);
  R operator <=(T value) => le(value);
 */
}

class ColumnCondition {
  final String name;
  final ColumnConditionOper oper;
  final dynamic value;

  ColumnCondition(this.name, this.oper, this.value);

  @override
  String toString() => '($name : ${oper.name} : $value)';
}

class NumberColumn<T, R> extends ColumnQuery<T, R>
    with ComparableCondition<T, R>, RangeCondition<T, R> {
  NumberColumn(String name) : super(name);
}

class IntColumn extends NumberColumn<int, IntColumn> {
  IntColumn(String name) : super(name);
}

class DoubleColumn extends NumberColumn<double, DoubleColumn> {
  DoubleColumn(String name) : super(name);
}

class StringColumn extends ColumnQuery<String, StringColumn>
    with
        ComparableCondition<String, StringColumn>,
        RangeCondition<String, StringColumn>,
        NullCondition<String, StringColumn> {
  StringColumn(String name) : super(name);

  StringColumn like(String pattern) =>
      _addCondition(ColumnConditionOper.LIKE, pattern);

  StringColumn startsWith(String prefix) =>
      _addCondition(ColumnConditionOper.LIKE, '$prefix%');

  StringColumn endsWith(String prefix) =>
      _addCondition(ColumnConditionOper.LIKE, '%$prefix');

  StringColumn contains(String subString) =>
      _addCondition(ColumnConditionOper.LIKE, '%$subString%');
}

class BoolColumn extends ColumnQuery<bool, BoolColumn> {
  BoolColumn(String name) : super(name);

  BoolColumn isTrue() => _addCondition(ColumnConditionOper.EQ, true);

  BoolColumn isFalse() => _addCondition(ColumnConditionOper.EQ, false);
}

class DateTimeColumn extends ColumnQuery<DateTime, DateTimeColumn>
    with
        ComparableCondition<DateTime, DateTimeColumn>,
        NullCondition<DateTime, DateTimeColumn> {
  DateTimeColumn(String name) : super(name);
}

enum ColumnConditionOper {
  EQ,
  GT,
  LT,
  GE,
  LE,
  BETWEEN,
  NOT_BETWEEN,
  LIKE,
  IN,
  NOT_IN,
  IS_NULL,
  IS_NOT_NULL
}

const List<String> _sql = [
  '=',
  '>',
  '<',
  '>=',
  '<=',
  'between',
  'not between',
  'like',
  'in',
  'not in',
  'is null',
  'is not null'
];

String toSql(ColumnConditionOper oper) {
  return _sql[oper.index];
}

abstract class BaseModelQuery<M extends Model, D>
    extends AbstractModelQuery<M, D> {
  static final Logger _logger = Logger('ORM');
  final Database db;
  final ModelInspector modelInspector;

  late BaseModelQuery _topQuery;

  final Map<String, BaseModelQuery> queryMap = {};

  String get className;

  String _alias = '';

  String get alias => _alias;

  List<ColumnQuery> get columns;

  List<BaseModelQuery> get joins;

  List<OrderField> orders = [];
  int offset = 0;
  int maxRows = 0;

  // for join
  BaseModelQuery? relatedQuery;
  String? propName;

  BaseModelQuery(this.modelInspector, this.db,
      {BaseModelQuery? topQuery, this.propName}) {
    _topQuery = topQuery ?? this;
  }

  bool _hasCondition([List<BaseModelQuery>? refrenceCache]) {
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

  SqlJoin _toSqlJoin() {
    var clz = modelInspector.meta(className)!;
    var tableName = clz.tableName;

    var joinStmt = '${relatedQuery!._alias}.${propName}_id = $_alias.id';

    return SqlJoin(tableName, _alias, joinStmt).apply((join) {
      columns.where((column) => column.hasCondition).forEach((column) {
        join.conditions.appendAll(column.toSqlConditions(_alias));
      });
    });
  }

  Future<int> insert(M model) async {
    var action = ActionType.Insert;
    var className = modelInspector.getClassName(model);
    var clz = modelInspector.meta(className)!;
    var idField = clz.idFields.first;
    var tableName = clz.tableName;

    var softDeleteField = clz.softDeleteField;
    if (softDeleteField != null) {
      modelInspector.markDeleted(model, false);
    }

    var dirtyMap = modelInspector.getDirtyFields(model);
    var ssFields = clz.serverSideFields(action, searchParents: true);

    var ssFieldNames = ssFields.map((e) => e.name);
    var columnNames = [...dirtyMap.keys, ...ssFieldNames]
        .map((fn) => clz.findField(fn)!.columnName)
        .join(',');

    var ssFieldValues = ssFields.map((e) => e.ormAnnotations
        .firstWhere((element) => element.isServerSide(action))
        .serverSideExpr(action));

    var fieldVariables = [
      ...dirtyMap.keys.map((e) => '@$e'),
      ...ssFieldValues,
    ].join(',');
    var sql =
        'insert into $tableName( $columnNames ) values( $fieldVariables )';
    _logger.fine('Insert SQL: $sql');

    dirtyMap.forEach((key, value) {
      if (value is Model) {
        var clz = modelInspector.meta(modelInspector.getClassName(value));
        dirtyMap[key] =
            modelInspector.getFieldValue(value, clz!.idFields.first.name);
      }
    });
    var id = await db.query(sql, dirtyMap,
        returningFields: [idField.columnName], tableName: tableName);
    _logger.fine(' >>> query returned: $id');
    if (id.isNotEmpty) {
      if (id[0].isNotEmpty) {
        modelInspector.setFieldValue(model, idField.name, id[0][0]);
        return id[0][0];
      }
    }
    return 0;
  }

  Future<void> insertBatch(List<M> modelList, {int batchSize = 100}) async {
    if (modelList.isEmpty) return;
    if (modelList.length <= batchSize) return _insertBatch(modelList);

    for (int i = 0; i < modelList.length; i += batchSize) {
      var sublist = modelList.sublist(i, min(modelList.length, i + batchSize));
      await _insertBatch(sublist);
    }
  }

  Future<void> _insertBatch(List<M> modelList) async {
    if (modelList.isEmpty) return;
    var count = modelList.length;
    // var action = ActionType.Insert;
    var className = modelInspector.getClassName(modelList[0]);
    var clz = modelInspector.meta(className)!;
    var idField = clz.idFields.first;
    var idColumnName = idField.columnName;
    var tableName = clz.tableName;

    var softDeleteField = clz.softDeleteField;
    if (softDeleteField != null) {
      for (var model in modelList) {
        modelInspector.markDeleted(model, false);
      }
    }

    // all but id fields
    var allFields = clz.allFields(searchParents: true)
      ..removeWhere((f) => f.isIdField || f.notExistsInDb);

    var columnNames = allFields.map((e) => e.columnName).join(',');

    var fieldVariables = [];
    //allFields.map((e) => '@${e.name}').join(',');

    for (int i = 0; i < count; i++) {
      var one = allFields.map((e) => '@${e.name}_$i').join(',');
      fieldVariables.add('( $one )');
    }

    var sql =
        'insert into $tableName( $columnNames ) values ${fieldVariables.join(",")}';
    _logger.fine('Insert SQL: $sql');

    var dirtyMap = <String, dynamic>{};

    for (var f in allFields) {
      for (int i = 0; i < count; i++) {
        dirtyMap['${f.name}_$i'] =
            modelInspector.getFieldValue(modelList[i], f.name);
      }
    }
    dirtyMap.forEach((key, value) {
      if (value is Model) {
        var clz = modelInspector.meta(modelInspector.getClassName(value));
        dirtyMap[key] =
            modelInspector.getFieldValue(value, clz!.idFields.first.name);
      }
    });
    var rows = await db.query(sql, dirtyMap,
        returningFields: [idColumnName], tableName: tableName);
    _logger.fine(' >>> query returned: $rows');
    if (rows.isNotEmpty) {
      for (int i = 0; i < rows.length; i++) {
        var id = rows[i][0];
        modelInspector.setFieldValue(modelList[i], idField.name, id);
      }
    }
  }

  Future<void> update(M model) async {
    var action = ActionType.Update;
    var className = modelInspector.getClassName(model);
    var clz = modelInspector.meta(className)!;
    var tableName = clz.tableName;
    var dirtyMap = modelInspector.getDirtyFields(model);

    var idField = clz.idFields.first; // @TODO

    var idValue = dirtyMap.remove(idField.name);

    var ssFields = clz.serverSideFields(action, searchParents: true);

    var setClause = <String>[];

    for (var name in dirtyMap.keys) {
      setClause.add('${clz.findField(name)!.columnName}=@$name');
    }

    for (var field in ssFields) {
      // var name = field.name;
      var value = field.ormAnnotations
          .firstWhere((element) => element.isServerSide(action))
          .serverSideExpr(action);

      setClause.add("${field.columnName}=$value");
    }

    dirtyMap[idField.name] = idValue;
    var sql =
        'update $tableName set ${setClause.join(',')} where ${idField.name}=@${idField.name}';
    _logger.fine('Update SQL: $sql');

    dirtyMap.forEach((key, value) {
      if (value is Model) {
        var clz = modelInspector.meta(modelInspector.getClassName(value));
        dirtyMap[key] =
            modelInspector.getFieldValue(value, clz!.idFields.first.name);
      }
    });

    await db.query(sql, dirtyMap, tableName: tableName);
  }

  Future<void> deleteOne(M model) async {
    var className = modelInspector.getClassName(model);
    var clz = modelInspector.meta(className)!;
    var softDeleteField = clz.softDeleteField;
    if (softDeleteField == null) {
      return deleteOnePermanent(model);
    }
    var idField = clz.idFields.first;
    var idValue = modelInspector.getFieldValue(model, idField.name);
    var tableName = clz.tableName;
    _logger.fine('delete $tableName , fields: $idValue');
    var sql =
        'update $tableName set ${softDeleteField.columnName} = 1 where ${idField.columnName} = @id ';
    await db.query(sql, {"id": idValue}, tableName: tableName);
  }

  Future<void> deleteOnePermanent(M model) async {
    var className = modelInspector.getClassName(model);
    var clz = modelInspector.meta(className)!;
    var idField = clz.idFields.first;
    var idValue = modelInspector.getFieldValue(model, idField.name);
    var tableName = clz.tableName;
    _logger.fine('deleteOnePermanent $tableName , id: $idValue');
    var sql = 'delete $tableName where ${idField.columnName} = @id ';
    await db.query(sql, {"id": idValue}, tableName: tableName);
  }

  @override
  Future<int> delete() async {
    // init all table aliases.
    _beforeQuery();

    var clz = modelInspector.meta(className)!;
    var tableName = clz.tableName;
    var idField = clz.idFields.first;
    var softDeleteField = clz.softDeleteField;

    if (softDeleteField == null) {
      return deletePermanent();
    }

    SqlQuery q = SqlQuery(tableName, _alias);

    // _allJoins().map((e) => )
    q.joins.addAll(_allJoins().map((e) => e._toSqlJoin()));

    var conditions = columns.fold<List<SqlCondition>>(
        [], (init, e) => init..addAll(e.toSqlConditions(_alias)));

    q.conditions.appendAll(conditions);

    var sql = q.toSoftDeleteSql(idField.columnName, softDeleteField.columnName);
    var params = q.params;
    params['deleted'] = true;
    _logger.fine('\t soft delete sql: $sql');
    var rows = await db.query(sql, params, tableName: tableName);
    _logger.fine('\t soft delete result rows: ${rows.affectedRowCount}');
    return rows.affectedRowCount ?? -1;
  }

  @override
  Future<int> deletePermanent() async {
    // init all table aliases.
    _beforeQuery();

    var clz = modelInspector.meta(className)!;
    var tableName = clz.tableName;
    var idField = clz.idFields.first;

    SqlQuery q = SqlQuery(tableName, _alias);

    // _allJoins().map((e) => )
    q.joins.addAll(_allJoins().map((e) => e._toSqlJoin()));

    var conditions = columns.fold<List<SqlCondition>>(
        [], (init, e) => init..addAll(e.toSqlConditions(_alias)));

    q.conditions.appendAll(conditions);

    var sql = q.toPermanentDeleteSql(idField.columnName);
    var params = q.params;
    _logger.fine('\t hard delete sql: $sql');

    var rows = await db.query(sql, params, tableName: tableName);
    _logger.fine('\t hard delete result rows: ${rows.affectedRowCount}');
    return rows.affectedRowCount ?? -1;
  }

  @override
  Future<M?> findById(D id,
      {M? existModel, bool includeSoftDeleted = false}) async {
    var clz = modelInspector.meta(className)!;

    var idFields = clz.idFields;
    var idFieldName = idFields.first.name;
    var tableName = clz.tableName;
    var softDeleteField = clz.softDeleteField;

    var allFields = clz.allFields(searchParents: true)
      ..removeWhere((f) => f.notExistsInDb);

    var columnNames = allFields.map((f) => f.columnName).join(',');

    var sql = 'select $columnNames from $tableName where $idFieldName = $id';
    var params = <String, dynamic>{};

    if (softDeleteField != null && !includeSoftDeleted) {
      sql += ' and ${softDeleteField.columnName}=@_deleted ';
      params['_deleted'] = false;
    }

    _logger.fine('findById: $className [$id] => $sql');

    var rows = await db.query(sql, params, tableName: tableName);

    if (rows.isNotEmpty) {
      return toModel(rows[0], allFields, className, existModel: existModel);
    }
    return null;
  }

  @override
  Future<List<M>> findByIds(List idList,
      {List<Model>? existModeList, bool includeSoftDeleted = false}) async {
    var clz = modelInspector.meta(className)!;

    var idFields = clz.idFields;
    var idFieldName = idFields.first.name;
    var tableName = clz.tableName;
    var softDeleteField = clz.softDeleteField;

    var allFields = clz.allFields(searchParents: true)
      ..removeWhere((f) => f.notExistsInDb);

    var columnNames = allFields.map((f) => f.columnName).join(',');

    var sql =
        'select $columnNames from $tableName where $idFieldName in @idList';
    var params = <String, dynamic>{'idList': idList};
    if (softDeleteField != null && !includeSoftDeleted) {
      sql += ' and ${softDeleteField.columnName}=@_deleted ';
      params['_deleted'] = false;
    }
    _logger.fine('findByIds: $className $idList => $sql');

    var rows = await db.query(sql, params, tableName: tableName);
    // _logger.info('\t rows: ${rows.length}');

    return _toModel(rows, allFields, idFieldName, existModeList);
  }

  List<M> _toModel(DbQueryResult rows, List<OrmMetaField> allFields,
      String idFieldName, List<Model>? existModeList) {
    if (rows.isNotEmpty) {
      var idIndex = 0;
      if (existModeList != null) {
        for (int i = 0; i < allFields.length; i++) {
          if (allFields[i].name == idFieldName) {
            idIndex = i;
            break;
          }
        }
      }
      var result = <M>[];
      for (int i = 0; i < rows.length; i++) {
        if (existModeList == null) {
          result.add(toModel(rows[i], allFields, className));
        } else {
          var id = rows[i][idIndex];
          // _logger.info('\t id: $id');
          M? m;
          var list = existModeList.where((element) =>
              modelInspector.getFieldValue(element, idFieldName) == id);
          if (list.isNotEmpty) {
            m = list.first as M;
          }
          // _logger.info('\t existModel: $m');
          result.add(toModel(rows[i], allFields, className, existModel: m));
        }
      }
      return result;
    }
    return [];
  }

  Future<List<M>> findBy(Map<String, dynamic> params,
      {List<Model>? existModeList, bool includeSoftDeleted = false}) async {
    var clz = modelInspector.meta(className)!;

    var idFields = clz.idFields;
    var idFieldName = idFields.first.name;
    var tableName = clz.tableName;
    var softDeleteField = clz.softDeleteField;

    var allFields = clz.allFields(searchParents: true)
      ..removeWhere((f) => f.notExistsInDb);

    var columnNames = allFields.map((f) => f.columnName).join(',');

    var sql = 'select $columnNames from $tableName where ';

    sql += params.keys.map((key) {
      var f = allFields.firstWhere((element) => element.name == key);
      if (f.isModelType) {
        // replace model with it's id.
        var m = params[key];
        if (modelInspector.isModelType(m.runtimeType.toString())) {
          var idFieldName = modelInspector
              .idFields(modelInspector.getClassName(m))!
              .first
              .name;
          params[key] = modelInspector.getFieldValue(m, idFieldName);
        }
        return '${f.columnName}=@$key';
      }
      return '${f.columnName}=@$key';
    }).join(' and ');

    if (softDeleteField != null && !includeSoftDeleted) {
      sql += ' and ${softDeleteField.columnName}=@_deleted ';
      params['_deleted'] = false;
    }
    //_logger.fine('findByIds: ${className} $idList => $sql');

    var rows = await db.query(sql, params, tableName: tableName);

    return _toModel(rows, allFields, idFieldName, existModeList);
  }

  paging(int pageNumber, int pageSize) {
    maxRows = pageSize;
    offset = pageNumber * pageSize;
  }

  N toModel<N extends M>(
      List<dynamic> dbRow, List<OrmMetaField> selectedFields, String className,
      {N? existModel}) {
    N model = existModel ??
        modelInspector.newInstance(className,
            attachDb: true, topQuery: topQuery) as N;
    modelInspector.markLoaded(model);
    for (int i = 0; i < dbRow.length; i++) {
      var f = selectedFields[i];
      var name = f.name;
      var value = dbRow[i];
      if (f.isModelType) {
        if (value != null) {
          var obj = modelInspector.newInstance(f.elementType,
              attachDb: true, topQuery: topQuery);
          modelInspector.setFieldValue(obj, 'id', value);
          modelInspector.setFieldValue(model, name, obj);
        }
      } else {
        modelInspector.setFieldValue(model, name, value);
      }
    }
    return model;
  }

  @override
  Future<List<M>> findList({bool includeSoftDeleted = false}) async {
    // init all table aliases.
    _beforeQuery();

    var clz = modelInspector.meta(className)!;
    var tableName = clz.tableName;
    var softDeleteField = clz.softDeleteField;

    var allFields = clz.allFields(searchParents: true)
      ..removeWhere((f) => f.notExistsInDb);

    SqlQuery q = SqlQuery(tableName, _alias);
    q.columns.addAll(allFields.map((f) => "$_alias.${f.columnName}"));

    // _allJoins().map((e) => )
    q.joins.addAll(_allJoins().map((e) => e._toSqlJoin()));

    if (softDeleteField != null && !includeSoftDeleted) {
      q.conditions.append(
          SqlCondition('$_alias.${softDeleteField.columnName}=@_deleted'));
    }

    var conditions = columns.fold<List<SqlCondition>>(
        [], (init, e) => init..addAll(e.toSqlConditions(_alias)));
    q.conditions.appendAll(conditions);

    var sql = q.toSelectSql();
    var params = q.params;
    if (softDeleteField != null && !includeSoftDeleted) {
      params['_deleted'] = false;
    }

    if (orders.isNotEmpty) {
      sql += ' order by ${orders.map((e) => e.toString()).join(',')}';
    }

    if (maxRows > 0) {
      sql += ' limit $maxRows';
    }

    if (offset > 0) {
      sql += ' offset $offset';
    }

    var rows = await db.query(sql, params, tableName: tableName);

    _logger.fine('\t sql: $sql');
    _logger.fine('\t rows: ${rows.length}');

    var result = rows.map((row) {
      return toModel<M>(row, allFields, className);
    });

    return result.toList();
  }

  @override
  Future<int> count({bool includeSoftDeleted = false}) async {
    // init all table aliases.
    _beforeQuery();

    var clz = modelInspector.meta(className)!;
    var tableName = clz.tableName;
    var softDeleteField = clz.softDeleteField;

    var idColumnName = clz.idFields.first.columnName;

    SqlQuery q = SqlQuery(tableName, _alias);

    // _allJoins().map((e) => )
    q.joins.addAll(_allJoins().map((e) => e._toSqlJoin()));

    if (softDeleteField != null && !includeSoftDeleted) {
      q.conditions.append(
          SqlCondition('$_alias.${softDeleteField.columnName}=@_deleted'));
    }

    var conditions = columns.fold<List<SqlCondition>>(
        [], (init, e) => init..addAll(e.toSqlConditions(_alias)));
    q.conditions.appendAll(conditions);

    var sql = q.toCountSql(idColumnName);
    var params = q.params;

    if (softDeleteField != null && !includeSoftDeleted) {
      params['_deleted'] = false;
    }

    var rows = await db.query(sql, params, tableName: tableName);

    _logger.fine('\t sql: $sql');
    _logger.fine('\t rows: ${rows.length} \t\t $rows');
    return (rows[0][0]).toInt();
  }

  T findQuery<T extends BaseModelQuery>(
      Database db, String modelName, String propName) {
    var q = topQuery.queryMap[modelName];
    if (q == null) {
      q = modelInspector.newQuery(db, modelName)
        .._topQuery = this
        ..propName = propName
        ..relatedQuery = this;
      topQuery.queryMap[modelName] = q;
    }
    return q as T;
  }

  void _beforeQuery() {
    if (_topQuery != this) return;
    var allJoins = _allJoins();
    int i = 0;
    _alias = "t${i++}";
    for (var join in allJoins) {
      join._alias = "t${i++}";
    }
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

class LazyOneToManyList<T extends Model> with ListMixin<T> implements List<T> {
  static final Logger _logger = Logger('ORM');

  late Database db; // model who holds the reference id
  late OrmMetaClass clz; // model who holds the reference id
  late OrmMetaField refField; // field in model
  late dynamic refFieldValue; // usually foreign id

  late List<Model> _list;
  var _loaded = false;

  LazyOneToManyList(
      {required this.db,
      required this.clz,
      required this.refField,
      required this.refFieldValue}) {
    _logger.info(
        'LazyOneToManyList: ${clz.name} : ${refField.name} : $refFieldValue');
  }

  LazyOneToManyList.of(List<Model> list) {
    _list = list;
    _loaded = true;
  }

  @override
  int get length {
    _checkLoaded();
    return _list.length;
  }

  @override
  set length(int value) {
    throw UnimplementedError();
  }

  @override
  T operator [](int index) {
    _checkLoaded();
    return _list[index] as T;
  }

  @override
  void operator []=(int index, T value) {}

  void _checkLoaded() {
    if (!_loaded) {
      throw 'please invoke load() first!';
    }
  }

  Future<void> load() async {
    if (_loaded) return;
    var query = clz.modelInspector.newQuery(db, clz.name);
    _list = await query.findBy({refField.name: refFieldValue});
    _loaded = true;
  }
}
