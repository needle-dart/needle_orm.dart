import 'package:loggy/loggy.dart';

import 'annotation.dart';
import 'inspector.dart';
import 'meta.dart';
import 'sql_executor.dart';
import 'sql_query.dart';
import 'common.dart';

class ColumnQuery<T, R> {
  final List<ColumnCondition> conditions = [];
  final String name;

  ColumnQuery(this.name);

  bool get hasCondition => !this.conditions.isEmpty;

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
    String? ssExpr = null;
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
            {paramName + '_from': cc.value[0], paramName + '_to': cc.value[1]});
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
}

class ServerSideExpr {
  final String expr;
  ServerSideExpr(this.expr) {}
}

mixin RangeCondition<T, R> on ColumnQuery<T, R> {
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
  String toString() => '($name : ${oper.name} : ${value})';
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
      _addCondition(ColumnConditionOper.LIKE, '%$prefix');

  StringColumn endsWith(String prefix) =>
      _addCondition(ColumnConditionOper.LIKE, '$prefix%');

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
  static Loggy _logger = Loggy('ORM');
  final SqlExecutor sqlExecutor;
  final ModelInspector modelInspector;

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

  BaseModelQuery(this.modelInspector, this.sqlExecutor,
      {BaseModelQuery? topQuery, this.propName}) {
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

  void insert(M model) {
    var action = ActionType.Insert;
    var className = modelInspector.getClassName(model);
    var clz = modelInspector.meta(className)!;
    var tableName = clz.tableName;
    var dirtyMap = modelInspector.getDirtyFields(model);
    var ssFields = clz.serverSideFields(action, searchParents: true);

    var ssFieldNames = ssFields.map((e) => e.name);
    var columnNames = [...dirtyMap.keys, ...ssFieldNames]
        .map((fn) => clz.findField(fn)!.columnName)
        .join(',');

    var ssFieldValues = ssFields
        .map((e) => e.ormAnnotations
            .firstWhere((element) => element.isServerSide(action))
            .serverSideExpr(action))
        .map((e) => "'$e'");

    var fieldVariables = [
      ...dirtyMap.keys.map((e) => '@$e'),
      ...ssFieldValues,
    ].join(',');
    var sql =
        'insert into $tableName( $columnNames ) values( $fieldVariables )';
    _logger.info('Insert SQL: $sql');
    sqlExecutor.query(tableName, sql, dirtyMap);
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
      setClause.add('${clz.findField(name)!.columnName}=@$name');
    });

    ssFields.forEach((field) {
      var name = field.name;
      var value = field.ormAnnotations
          .firstWhere((element) => element.isServerSide(action))
          .serverSideExpr(action);

      setClause.add("${field.columnName}=$value");
    });

    dirtyMap[idField.name] = idValue;
    var sql =
        'update $tableName set ${setClause.join(',')} where ${idField.name}=@${idField.name}';
    _logger.info('Update SQL: $sql');
    sqlExecutor.query(tableName, sql, dirtyMap);
  }

  void delete(M model) {
    var className = modelInspector.getClassName(model);
    var clz = modelInspector.meta(className)!;
    var tableName = clz.tableName;
    _logger.info(
        'delete $tableName , fields: ${modelInspector.getDirtyFields(model)}');
  }

  void deletePermanent(M model) {
    var className = modelInspector.getClassName(model);
    var clz = modelInspector.meta(className)!;
    var tableName = clz.tableName;
    _logger.info(
        'deletePermanent $tableName , fields: ${modelInspector.getDirtyFields(model)}');
  }

  Future<M?> findById(D id) async {
    var clz = modelInspector.meta(className)!;

    var idFields = clz.idFields;
    var idFieldName = idFields().first.name;
    var tableName = clz.tableName;

    var allFields = clz.allFields(searchParents: true);

    var columnNames = allFields.map((f) => f.columnName).join(',');

    var sql = 'select $columnNames from $tableName where $idFieldName = $id';
    _logger.info('findById: ${className} [$id] => $sql');

    var rows = await sqlExecutor.query(tableName, sql, {});

    // _logger.info('\t result: $result');

    if (rows.isNotEmpty) {
      return toModel(rows[0], allFields, className);
    }
    return null;
  }

  N toModel<N extends M>(List<dynamic> dbRow, List<OrmMetaField> selectedFields,
      String className) {
    N model = modelInspector.newInstance(className) as N;
    for (int i = 0; i < dbRow.length; i++) {
      var f = selectedFields[i];
      var name = f.name;
      var value = dbRow[i];
      if (f.isModelType) {
        if (value != null) {
          var obj = modelInspector.newInstance(f.elementType);
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
  Future<List<M>> findList() async {
    // init all table aliases.
    _beforeQuery();

    var clz = sqlExecutor.modelInspector.meta(className)!;
    var tableName = clz.tableName;

    var allFields = clz.allFields(searchParents: true);

    SqlQuery q = SqlQuery(tableName, _alias);
    q.columns.addAll(allFields.map((f) => "$_alias.${f.columnName}"));

    // _allJoins().map((e) => )
    q.joins.addAll(_allJoins().map((e) => e._toSqlJoin()));

    var conditions = columns.fold<List<SqlCondition>>(
        [], (init, e) => init..addAll(e.toSqlConditions(_alias)));

    q.conditions.appendAll(conditions);

    var sql = q.toSql();
    var params = q.params;

    var rows = await sqlExecutor.query(tableName, sql, params);

    // _logger.info('\t sql: $sql');

    var result = rows.map((row) {
      return toModel<M>(row, allFields, className);
    });

    // return sqlExecutor.findList(this);
    return result.toList();
  }

  T findQuery<T extends BaseModelQuery>(String modelName, String propName) {
    var q = topQuery.queryMap[modelName];
    if (q == null) {
      q = modelInspector.newQuery(modelName)
        .._topQuery = this
        ..propName = propName
        ..relatedQuery = this;
      topQuery.queryMap[modelName] = q;
    }
    return q as T;
  }

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
