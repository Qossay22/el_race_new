import 'package:el_race/ui/presentation/my_projects/domain/entities/attachment_entity.dart';

class AttachmentModel extends AttachmentEntity {
  const AttachmentModel({
    required super.id,
    required super.name,
    required super.type,
    required super.url,
    required super.source,
    required super.isFile,
    required super.folder,
  });

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    return AttachmentModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      url: json['url'] ?? '',
      source: json['source'] ?? '',
      isFile: json['is_file'] ?? false,
      folder: json['folder'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'url': url,
        'source': source,
        'is_file': isFile,
        'folder': folder,
      };
}
