import 'package:needle_orm/needle_orm.dart';
import 'package:test/test.dart';

typedef C = SqlCondition;

void main() {
  test('condition test', () async {
    SqlAnd c = SqlAnd();
    c +
        C("t0.deleted = 0") +
        C("t0.name = @name", {'name': 'admin'}) +
        SqlOr([
          C("t1.age > @age", {"age": 10}),
          C("t1.gendar = @gendar", {'gendar': 'F'}),
        ]);

    expect(c.toSql(wrap: false),
        "t0.deleted = 0 AND t0.name = @name AND (t1.age > @age OR t1.gendar = @gendar)");
    expect(c.params.length, 3);
  });

  test('join test', () {
    SqlJoin j = SqlJoin('user', 'u', SqlJoinType.LEFT);
    j.conditions + C("u.deleted = 0") + C("t0.id = u.id");

    expect(j.toSql(), 'LEFT join user u on u.deleted = 0 AND t0.id = u.id');
  });

  test('complete query test', () {
    SqlQuery q = SqlQuery('user', 'u', distinct: true);
    q.columns.addAll(['u.id', 'u.name', 'u.email', 'u.deleted']);
    q.joins.addAll([
      SqlJoin('user_role', 'ur', SqlJoinType.LEFT).apply((j) {
        j.conditions..append(C("ur.user_id = u.id"));
      }),
      SqlJoin('role', 'r', SqlJoinType.LEFT).apply((j) {
        j.conditions
          ..append(C("r.deleted = 0"))
          ..append(C("r.name like @role_name", {'role_name': '%member'}))
          ..append(C("r.id = ur.role_id"));
      })
    ]);
    q.conditions
      ..append(C("u.deleted = 0"))
      ..append(C("u.email like @email", {'email': '%@gmail.com'}));
    expect(q.toSql(),
        'select distinct u.id, u.name, u.email, u.deleted from user u LEFT join user_role ur on ur.user_id = u.id LEFT join role r on r.deleted = 0 AND r.name like @role_name AND r.id = ur.role_id where u.deleted = 0 AND u.email like @email');
    expect(q.joins.params['role_name'], '%member');
    expect(q.conditions.params['email'], '%@gmail.com');

    expect({...q.joins.params, ...q.conditions.params}.length, 2);
  });
}
