// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cover_page_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CoverPageModelAdapter extends TypeAdapter<CoverPageModel> {
  @override
  final int typeId = 102;

  @override
  CoverPageModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CoverPageModel(
      empId: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String?,
      id: fields[3] as String?,
      createdAt: fields[4] as DateTime?,
      updatedAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, CoverPageModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.empId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.id)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoverPageModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
