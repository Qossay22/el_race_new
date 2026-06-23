import '../data/media_model.dart';
import '../data/content_model.dart';

abstract class IMediaRepository {
  Future<List<MediaModel>> getMediaList();
  Future<void> addMedia(MediaModel media);
  Future<void> updateMedia(MediaModel media);
  Future<void> deleteMedia(String mediaId);
  Future<List<MediaModel>> getMediaByType(MediaType type);
  Future<List<MediaModel>> searchMedia(String keyword);
  Future<String?> prepareShare(String mediaId);
  Future<ContentsResponse?> getContents();
}
