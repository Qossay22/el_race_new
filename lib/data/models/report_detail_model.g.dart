// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_detail_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReportDetailModelAdapter extends TypeAdapter<ReportDetailModel> {
  @override
  final int typeId = 1;

  @override
  ReportDetailModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReportDetailModel(
      id: fields[0] as String,
      items: (fields[2] as List).cast<ReportDetailItem>(),
      coverPage: (fields[1] as Map?)?.cast<String, dynamic>(),
      sections: (fields[3] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ReportDetailModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.coverPage)
      ..writeByte(2)
      ..write(obj.items)
      ..writeByte(3)
      ..write(obj.sections);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportDetailModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
