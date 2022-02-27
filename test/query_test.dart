import 'package:needle_orm/src/query.dart';
import 'package:test/test.dart';

void main() {
  test('column condition test', () {
    var userDef = UserDef();
    userDef
      ..age.gt(10).lt(20)
      ..name.startsWith('admin')
      ..active.isTrue()
      ..birthday.between(
          DateTime.now().subtract(Duration(days: 365 * 10)), DateTime.now());

    userDef.columns.map((e) => e.conditions).forEach(print);
  });
}

class UserDef {
  IntColumn age = IntColumn();
  StringColumn name = StringColumn();
  DateTimeColumn birthday = DateTimeColumn();
  BoolColumn active = BoolColumn();

  List<ColumnQuery> get columns => [age, name, birthday, active];
}
