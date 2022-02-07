import 'dart:async';

abstract class DataSource {
  final DatabaseType databaseType;
  final String databaseVersion;

  const DataSource(this.databaseType, this.databaseVersion);

  factory DataSource.lookup(String dsName) {
    throw 'DataSource[$dsName] not exist!';
  }

  /// Executes a single query.
  Future<List<List>> execute(
      String tableName, String sql, Map<String, dynamic> substitutionValues,
      [List<String> returningFields = const []]);

  /// Enters a database transaction, performing the actions within,
  /// and returning the results of [f].
  ///
  /// If [f] fails, the transaction will be rolled back, and the
  /// responsible exception will be re-thrown.
  ///
  /// Whether nested transactions are supported depends on the
  /// underlying driver.
  // Future<T> transaction<T>(FutureOr<T> Function(DataSource) f);
}

enum DatabaseType { MySQL, MariaDB, PostgreSQL, Sqlite }
