import 'annotation.dart';

import 'package:recase/recase.dart';
import 'package:inflection3/inflection3.dart';

import 'inspector.dart';

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
    fields.forEach((f) {
      f.clz = this;
    });
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

  OrmMetaField? findField(String name) {
    if (fields.any((element) => element.name == name)) {
      return fields.where((element) => element.name == name).first;
    }
    if (superClassName != null) {
      var parentClz = modelInspector.meta(superClassName!);
      return parentClz?.findField(name);
    }
    return null;
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

  late OrmMetaClass clz;
  OrmMetaField(this.name, this.type, {this.ormAnnotations = const []});

  bool get isModelType => clz.modelInspector.isModelType(elementType);

  String get elementType {
    var t = type;
    if (t.startsWith('List<')) {
      t = t.substring(5, t.length - 1);
    }
    if (t.startsWith('Set<')) {
      t = t.substring(4, t.length - 1);
    }
    if (t.endsWith('?')) {
      t = t.substring(0, t.length - 1);
    }
    return t;
  }

  String get columnName {
    var s = ReCase(name).snakeCase;
    if (isModelType) s += '_id';
    return s;
  }
}