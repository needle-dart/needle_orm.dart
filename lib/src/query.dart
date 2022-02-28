class ColumnQuery<T, R> {
  final List<ColumnCondition> conditions = [];
  final String name;

  ColumnQuery(this.name);

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