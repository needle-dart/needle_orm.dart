Example code can be found here: [needle_orm_generator example](https://github.com/needle-dart/needle_orm_generator.dart/blob/main/test/all_test.dart) .

Steps:

## Define Model

```dart
@Entity()
abstract class _BaseModel {
  @ID()
  int? _id;

  @Version()
  int? _version;

  @SoftDelete()
  bool? _deleted;

  @WhenCreated()
  DateTime? _createdAt;

  @WhenModified()
  DateTime? _updatedAt;

  @WhoCreated()
  String? _createdBy; // user login name

  @WhoModified()
  String? _lastUpdatedBy; // user login name

  @Column()
  String? _remark;

  _BaseModel();
}

@Table(name: 'tbl_user')
@Entity(prePersist: 'beforeInsert', postPersist: 'afterInsert')
class _User extends _BaseModel {
  @Column()
  String? _name;

  @Column()
  String? _loginName;

  @Column()
  String? _address;

  @Column()
  int? _age;

  @OneToMany(mappedBy: "_author")
  List<_Book>? books;

  _User();
}


@Table()
@Entity()
class _Book extends _BaseModel {
  @Column()
  String? _title;

  @Column()
  double? _price;

  @ManyToOne()
  _User? _author;

  _Book();
}

```

## Enhance business logic

```dart
extension Biz_User on User {
  bool isAdmin() {
    return name!.startsWith('admin');
  }

  // @override
  void beforeInsert() {
    _version = 1;
    _deleted = false;
    print('before insert user ....');
  }

  void afterInsert() {
    print('after insert user ....');
  }
}
```

## Usage

```dart

Future<Database> initPostgreSQL() async {
  return PostgreSqlPoolDatabase(PgPool(
    PgEndpoint(
      host: 'localhost',
      port: 5432,
      database: 'appdb',
      username: 'postgres',
      password: 'postgres',
    ),
    settings: PgPoolSettings()
      ..maxConnectionAge = Duration(hours: 1)
      ..concurrency = 5,
  ));
}

late Database globalDs;

void main() async {
  globalDb = await initPostgreSQL();

  // Create or update :
  {
    var user = User();
    user
      ..name = 'administrator'
      ..address = 'abc'
      ..age = 23
      ..save(); // or insert()

    print('user saved, id= ${user.id}');

    user
      ..name = 'another name'
      ..save(); // or update()

    // call business method
    print('is admin? ${user.isAdmin()}');

    // toMap, can also be used to generate json
    var valueMap = user.toMap();
    // or only output some fields
    valueMap = user.toMap(fields:'id,name');

    // load from a map
    user.loadMap({"name": 'admin123', "xxxx": 'xxxx'});

    var book = Book();
    book
      ..author = user
      ..title = 'Dart'
      ..price = 14.99
      ..insert();

    // toMap supports nested fields: 'author(id,name)'
    valueMap = book.toMap(fields:'id,title,price,author(id,name)');
  }

  // Typed-Query:
  {
    Book.Query()
      ..title.startsWith('dart')
      ..price.between(10.0, 20.0)
      ..author.apply((author) {
        author
          ..age.ge(18)
          ..address.startsWith('China Shanghai');
      })
      ..orders = [Book.Query().price.desc()]
      ..offset = 10
      ..maxRows = 20  // limit
      ..findList();
  }

  // Soft Delete:
  {
    var q = Book.Query()
      ..price.between(18, 19)
      ..title.endsWith('test');
    var total = await q.count();  // without deleted records
    var totalWithDeleted = await q.count(includeSoftDeleted: true);
    print('found books , total: $total, totalWithDeleted: $totalWithDeleted');

    int deletedCount = await q.delete();
    print('soft deleted books: $deletedCount');

    total = await q.count();
    totalWithDeleted = await q.count(includeSoftDeleted: true);
    print('found books after soft delete , total: $total, totalWithDeleted: $totalWithDeleted');
  }

  // Permanent delete
  {
    var q = Book.Query()
    ..price.between(100, 1000);
    var total = await q.count();

    print('found expensive books, total count: $total');

    int deletedCount = await q.deletePermanent();
    print('permanent deleted books : $deletedCount');
  }

  // batch insert
  {
    var n = 10;
    var users = <User>[];
    for (int i = 0; i < n; i++) {
      var user = User()
        ..name = 'name_$i'
        ..address = 'China Shanghai street_$i'
        ..age = (n * 0.1).toInt();
      users.add(user);
    }
    print('users created');
    await User.Query().insertBatch(users, batchSize: 5);
    print('users saved');
    var idList = users.map((e) => e.id).toList();
    print('ids: $idList');
  }

  // Transaction : only works on PostgreSQL, there're still some problems on MariaDB
  {
    var q = User.Query();
    print('count before insert : ${await q.count()}');
    var db2 = await initPostgreSQL();
    await db2.transaction((db) async {
      // var query = User.Query(db: db);
      var n = 50;
      for (int i = 1; i < n; i++) {
        var user = User()
          ..name = 'tx_name_$i'
          ..address = 'China Shanghai street_$i ' * i
          ..age = n;
        await user.save(db: db); // throw rollback exception at the 10th loop because address is too long
        print('\t used saved with id: ${user.id}');
      }
    });

    // the next line will never be executed because of the rollback exception.
    // print('count after insert : ${await q.count()}');
  }
}

```

