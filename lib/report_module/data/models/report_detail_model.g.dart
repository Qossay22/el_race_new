// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_detail_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReportDetailModelAdapter extends TypeAdapter<ReportDetailModel> {
  @override
  final int typeId = 103;

  @override
  ReportDetailModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReportDetailModel(
      report: fields[0] as ReportModel,
      coverPage: fields[2] as CoverPageModel?,
      reportItems: (fields[1] as List).cast<ReportItemModel>(),
    );
  }

  @override
  void write(BinaryWriter writer, ReportDetailModel obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.report)
      ..writeByte(1)
      ..write(obj.reportItems)
      ..writeByte(2)
      ..write(obj.coverPage);
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
