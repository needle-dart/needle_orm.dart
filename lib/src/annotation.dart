// see javax.persistence.*

abstract class Model {}

abstract class OrmAnnotation {
  final AnnotationTarget _target;
  const OrmAnnotation(this._target);
  bool isServerSide(ActionType actionType) => false;
  String serverSideExpr(ActionType actionType) => '';
}

enum AnnotationTarget {
  Class,
  Field,
  Method,
  All,
  None,
}

enum ActionType { Insert, Update, Delete }

abstract class AbstractModelQuery<T, D> {
  AbstractModelQuery();

  Future<T?> findById(D id);

  Future<List<T>> findAll();
}

abstract class OrmClassAnnotation {}

class Entity extends OrmAnnotation {
  //
  static const DEFAULT_DS = 'defaultDS';

  // final String? name;
  final String? ds; // DataSource name

  final String? prePersist;
  final String? preUpdate;
  final String? preRemove; // respect @SoftDelete
  final String? preRemovePermanent;
  final String? postPersist;
  final String? postUpdate;
  final String? postRemove; // respect @SoftDelete
  final String? postRemovePermanent;
  final String? postLoad;

  const Entity(
      {this.ds = DEFAULT_DS,
      this.prePersist,
      this.preUpdate,
      this.preRemove,
      this.preRemovePermanent,
      this.postPersist,
      this.postUpdate,
      this.postRemove,
      this.postRemovePermanent,
      this.postLoad})
      : super(AnnotationTarget.Class);
}

class Table extends OrmAnnotation {
  final String? name;
  final String? catalog;
  final String? schema;
  final List<Index> indexes;

  // uniqueConstraints

  const Table({this.name, this.catalog, this.schema, this.indexes = const []})
      : super(AnnotationTarget.Class);
}

class ID extends OrmAnnotation {
  const ID() : super(AnnotationTarget.Field);
}

class Column extends OrmAnnotation {
  final String? name;
  final int length;
  final int precision;
  final int scale;
  final bool unique;
  final bool nullable;
  final bool insertable;
  final bool updatable;
  final String? columnDefinition;
  final String? table;

  const Column(
      {this.name,
      this.length = 255,
      this.precision = 0,
      this.scale = 0,
      this.unique = false,
      this.nullable = true,
      this.insertable = true,
      this.updatable = true,
      this.columnDefinition,
      this.table})
      : super(AnnotationTarget.Field);
}

class Lob extends OrmAnnotation {
  const Lob() : super(AnnotationTarget.Field);
}

class Version extends OrmAnnotation {
  const Version() : super(AnnotationTarget.Field);
}

class Index extends OrmAnnotation {
  final String? name;
  final String? columnList;
  final bool unique;
  const Index({this.name, this.columnList, this.unique = false})
      : super(AnnotationTarget.None);
}

class ManyToOne extends OrmAnnotation {
  // cascade
  // fetch
  // optional
  const ManyToOne() : super(AnnotationTarget.Field);
}

class OneToMany extends OrmAnnotation {
  // cascade
  // fetch
  // mappedBy
  // orphanRemoval
  final String? mappedBy;
  const OneToMany({this.mappedBy}) : super(AnnotationTarget.Field);
}

class OneToOne extends OrmAnnotation {
  // cascade
  // fetch
  // optional
  // mappedBy
  // orphanRemoval
  final String? mappedBy;
  const OneToOne({this.mappedBy}) : super(AnnotationTarget.Field);
}

class ManyToMany extends OrmAnnotation {
  const ManyToMany() : super(AnnotationTarget.Field);
}

class OrderBy extends OrmAnnotation {
  final String value;
  // fetch
  // optional
  // mappedBy
  // orphanRemoval
  const OrderBy(this.value) : super(AnnotationTarget.Field);
}

class PrePersist extends OrmAnnotation {
  const PrePersist() : super(AnnotationTarget.Method);
}

class PreUpdate extends OrmAnnotation {
  const PreUpdate() : super(AnnotationTarget.Method);
}

class PreRemove extends OrmAnnotation {
  const PreRemove() : super(AnnotationTarget.Method);
}

class PostPersist extends OrmAnnotation {
  const PostPersist() : super(AnnotationTarget.Method);
}

class PostUpdate extends OrmAnnotation {
  const PostUpdate() : super(AnnotationTarget.Method);
}

class PostRemove extends OrmAnnotation {
  const PostRemove() : super(AnnotationTarget.Method);
}

class PostLoad extends OrmAnnotation {
  const PostLoad() : super(AnnotationTarget.Method);
}

class Transient extends OrmAnnotation {
  const Transient() : super(AnnotationTarget.Field);
}

// io.ebean extension

class DbComment extends OrmAnnotation {
  final String comment;
  const DbComment(this.comment) : super(AnnotationTarget.All);
}

class SoftDelete extends OrmAnnotation {
  const SoftDelete() : super(AnnotationTarget.Field);
}

class WhenCreated extends OrmAnnotation {
  const WhenCreated() : super(AnnotationTarget.Field);

  @override
  bool isServerSide(ActionType actionType) =>
      actionType == ActionType.Insert ? true : false;
  @override
  String serverSideExpr(ActionType actionType) =>
      actionType == ActionType.Insert ? 'now()' : '';
}

class WhenModified extends OrmAnnotation {
  const WhenModified() : super(AnnotationTarget.Field);
  @override
  bool isServerSide(ActionType actionType) =>
      actionType == ActionType.Update || actionType == ActionType.Insert
          ? true
          : false;
  @override
  String serverSideExpr(ActionType actionType) =>
      actionType == ActionType.Update || actionType == ActionType.Insert
          ? 'now()'
          : '';
}

class WhoCreated extends OrmAnnotation {
  const WhoCreated() : super(AnnotationTarget.Field);
}

class WhoModified extends OrmAnnotation {
  const WhoModified() : super(AnnotationTarget.Field);
}
