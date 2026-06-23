// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_detail_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReportDetailItemAdapter extends TypeAdapter<ReportDetailItem> {
  @override
  final int typeId = 2;

  @override
  ReportDetailItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReportDetailItem(
      title: fields[0] as String?,
      description: fields[1] as String?,
      id: fields[7] as String,
      createdAt: fields[2] as DateTime,
      type: fields[3] as String,
      sectionName: fields[4] as String?,
      updatedAt: fields[5] as String,
      image: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ReportDetailItem obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.sectionName)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.image)
      ..writeByte(7)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportDetailItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
