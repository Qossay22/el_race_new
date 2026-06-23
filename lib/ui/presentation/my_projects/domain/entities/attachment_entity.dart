import 'package:equatable/equatable.dart';

class AttachmentEntity extends Equatable {
  final int id;
  final String name;
  final String type;
  final String url;
  final String source;
  final bool isFile;
  final String folder;

  const AttachmentEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    required this.source,
    required this.isFile,
    required this.folder,
  });

  @override
  List<Object?> get props => [id, name, type, url, source, isFile, folder];
}