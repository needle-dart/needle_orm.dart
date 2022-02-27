class SqlQuery {
  bool distinct;
  List<String> columns = [];
  String tableName;
  final String alias;
  List<SqlJoin> joins = [];
  SqlAnd conditions = SqlAnd();

  SqlQuery(this.tableName, this.alias, {this.distinct = false});

  String toSql() {
    return [
      'select',
      distinct ? 'distinct' : '',
      columns.join(', '),
      'from',
      tableName,
      alias,
      joins.toSql(),
      conditions.isNotEmpty ? 'where ' + conditions.toSql(wrap: false) : ''
    ].where((element) => element.isNotEmpty).join(' ');
  }
}

class SqlJoin {
  final String tableName;
  final String alias;
  final SqlJoinType joinType;
  SqlConditionGroup conditions = SqlAnd();

  SqlJoin(this.tableName, this.alias, [this.joinType = SqlJoinType.INNER]);

  String toSql() {
    return [
      _joinType(),
      'join',
      tableName,
      alias,
      'on',
      conditions.toSql(wrap: false)
    ].where((element) => element.isNotEmpty).join(' ');
  }

  String _joinType() {
    switch (joinType) {
      case SqlJoinType.INNER:
        return '';
      default:
        return joinType.name;
    }
  }

  Map<String, dynamic> get params => conditions.params;
}

extension SqlJoinGroup on List<SqlJoin> {
  String toSql() {
    return this.map((j) => j.toSql()).join(' ');
  }

  Map<String, dynamic> get params => _params();

  Map<String, dynamic> _params() {
    return this
        .fold(<String, dynamic>{}, (map, join) => map..addAll(join.params));
  }
}

enum SqlJoinType { INNER, LEFT, RIGHT, FULL }

// u1.role_sort > ?
// t1.deleted = 0
class SqlCondition {
  final String stmt;

  final Map<String, dynamic> params = {};

  SqlCondition(this.stmt, [Map<String, dynamic>? params = null]) {
    if (params != null) {
      this.params.addAll(params);
    }
  }

/*   bool get isGroup =>
      oper == ConditionOper.AND ||
      oper == ConditionOper.OR ||
      oper == ConditionOper.NOT;
 */

  String toSql() {
    return stmt;
  }
}

class SqlConditionGroup extends SqlCondition {
  final SqlConditionOper oper;

  final List<SqlCondition> conditions = [];

  SqlConditionGroup(this.oper, {List<SqlCondition>? conditions = null})
      : super('') {
    if (conditions != null) {
      this.conditions.addAll(conditions);
      conditions.forEach((element) {
        params.addAll(element.params);
      });
    }
  }

  bool get isEmpty => conditions.isEmpty;
  bool get isNotEmpty => conditions.isNotEmpty;

  SqlConditionGroup operator +(SqlCondition condition) => append(condition);

  SqlConditionGroup append(SqlCondition condition) {
    conditions.add(condition);
    params.addAll(condition.params);
    if (oper == SqlConditionOper.NOT) {
      assert(conditions.length <= 1);
    }
    return this;
  }

  @override
  String toSql({bool wrap: true}) {
    if (oper == SqlConditionOper.NOT)
      return " NOT ( ${conditions[0].toSql()} ) ";
    var str = conditions.map((c) => c.toSql()).join(' ${oper.name} ');
    return wrap ? '($str)' : str;
  }
}

class SqlAnd extends SqlConditionGroup {
  SqlAnd([List<SqlCondition>? conditions])
      : super(SqlConditionOper.AND, conditions: conditions);
}

class SqlOr extends SqlConditionGroup {
  SqlOr([List<SqlCondition>? conditions])
      : super(SqlConditionOper.OR, conditions: conditions);
}

class SqlNot extends SqlConditionGroup {
  SqlNot([SqlCondition? condition]) : super(SqlConditionOper.NOT) {
    if (condition != null) {
      this.conditions.add(condition);
    }
  }
}

enum SqlConditionOper {
  EQ,
  GT,
  LT,
  LIKE,
  GE,
  LE,
  IN,
  NOT_IN,
  IS_NULL,
  IS_NOT_NULL,
  // EXISTS,
  // NOT EXISTS,
  AND,
  OR,
  NOT,
}
