// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CompanyModelAdapter extends TypeAdapter<CompanyModel> {
  @override
  final int typeId = 101;

  @override
  CompanyModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CompanyModel(
      companyName: fields[0] as String,
      logo: fields[1] as String,
      employeeName: fields[2] as String,
      personEmail: fields[3] as String,
      contactPhone: fields[4] as String,
      employeeID: fields[5] as String,
      endText: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CompanyModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.companyName)
      ..writeByte(1)
      ..write(obj.logo)
      ..writeByte(2)
      ..write(obj.employeeName)
      ..writeByte(3)
      ..write(obj.personEmail)
      ..writeByte(4)
      ..write(obj.contactPhone)
      ..writeByte(5)
      ..write(obj.employeeID)
      ..writeByte(6)
      ..write(obj.endText);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompanyModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
