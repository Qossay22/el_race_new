// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_item_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReportItemModelAdapter extends TypeAdapter<ReportItemModel> {
  @override
  final int typeId = 104;

  @override
  ReportItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReportItemModel(
      id: fields[0] as String,
      reportId: fields[1] as String,
      type: fields[2] as String,
      image: fields[3] as String,
      location: fields[4] as String,
      description: fields[5] as String,
      createdAt: fields[6] as DateTime,
      updatedAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ReportItemModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.reportId)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.image)
      ..writeByte(4)
      ..write(obj.location)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
