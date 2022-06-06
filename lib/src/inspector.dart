import 'meta.dart';
import 'query.dart';

abstract class ModelInspector<M> {
  String getClassName(M model);

  M newInstance(String className,
      {bool attachDb = false, required BaseModelQuery topQuery});

  BaseModelQuery newQuery(String className);

  OrmMetaClass? meta(String className);

  List<OrmMetaClass> get allOrmMetaClasses;

  Map<String, dynamic> getDirtyFields(M model);

  dynamic getFieldValue(M model, String fieldName);

  void setFieldValue(M model, String fieldName, dynamic value);

  void loadModel(M model, Map<String, dynamic> m,
      {errorOnNonExistField: false});

  bool isModelType(String type) {
    if (type.endsWith('?')) {
      type = type.substring(0, type.length - 1);
    }
    return meta(type) != null;
  }

  List<OrmMetaField>? idFields(String className) {
    return meta(className)?.idFields();
  }

  List<OrmMetaField>? softDeleteField(String className) {
    return meta(className)?.idFields();
  }

  void markLoaded(M model);
}
