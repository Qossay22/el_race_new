import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../utils/di.dart';
import '../../../../utils/urll_utils.dart';
import '../../signin/data/repository.dart';
import '../data/media_model.dart';
import '../data/content_model.dart';
import 'i_media_repository.dart';

class MediaRepository implements IMediaRepository {
  final userRepo = sl.get<UserRepo>();

  @override
  Future<List<MediaModel>> getMediaList() async {
    try {
      final loginResponse = await userRepo.getLoginResponse();
      var token = loginResponse!.result!.token!;

      Map<String, String> headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token"
      };

      final body = jsonEncode({"jsonrpc": "2.0", "params": {}});
      final url = Uri.parse("${UrlUtil.baseUrl}${UrlUtil.mediaAttachmentsApi}");
      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..body = body;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['result'] != null && json['result']['data'] != null) {
          List<dynamic> mediaData = json['result']['data'];
          return mediaData.map((item) => MediaModel.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      log('Error in getMediaList: $e');
      return [];
    }
  }

  @override
  Future<void> addMedia(MediaModel media) async {
    throw UnimplementedError('Add media functionality not implemented in API');
  }

  @override
  Future<void> updateMedia(MediaModel media) async {
    throw UnimplementedError(
        'Update media functionality not implemented in API');
  }

  @override
  Future<void> deleteMedia(String mediaId) async {
    throw UnimplementedError(
        'Delete media functionality not implemented in API');
  }

  @override
  Future<List<MediaModel>> getMediaByType(MediaType type) async {
    final allMedia = await getMediaList();
    return allMedia.where((media) => media.type == type).toList();
  }

  @override
  Future<List<MediaModel>> searchMedia(String keyword) async {
    final allMedia = await getMediaList();
    return allMedia
        .where((media) =>
            media.name.toLowerCase().contains(keyword.toLowerCase()) ||
            media.type.name.toLowerCase().contains(keyword.toLowerCase()) ||
            media.fileExtension.toLowerCase().contains(keyword.toLowerCase()))
        .toList();
  }

  @override
  Future<String?> prepareShare(String mediaId) async {
    try {
      final loginResponse = await userRepo.getLoginResponse();
      if (loginResponse == null || loginResponse.result == null) {
        return null;
      }

      var token = loginResponse.result!.token!;

      Map<String, String> headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token"
      };

      final parsedAttachmentId = int.tryParse(mediaId);

      final body = jsonEncode({
        "jsonrpc": "2.0",
        "params": {
          // Backend currently expects attachment_id for simplified share URL.
          "attachment_id": parsedAttachmentId ?? mediaId,
          // Keep media_id for backward compatibility with older API behavior.
          "media_id": parsedAttachmentId ?? mediaId,
        }
      });

      final url = Uri.parse("${UrlUtil.baseUrl}${UrlUtil.prepareShareApi}");

      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        // Check different possible response structures
        if (json['result'] != null) {
          // Try different possible field names for the URL
          final result = json['result'];
          String? shareUrl;

          if (result is Map) {
            // Prioritize share_url as it's the main field returned by the API
            shareUrl =
                result['share_url'] ?? result['url'] ?? result['x_web_url'];
          } else if (result is String) {
            shareUrl = result;
          }

          if (shareUrl != null && shareUrl.isNotEmpty) {
            return shareUrl;
          }
        }
      }

      return null;
    } catch (e, stackTrace) {
      log('Error in prepareShare: $e\n$stackTrace');
      return null;
    }
  }

  @override
  Future<ContentsResponse?> getContents() async {
    try {
      final loginResponse = await userRepo.getLoginResponse();
      var token = loginResponse?.result?.token;

      Map<String, String> headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        if (token != null) "Authorization": "Bearer $token"
      };

      final body = jsonEncode({"jsonrpc": "2.0", "params": {}});
      final url = Uri.parse("${UrlUtil.baseUrl}${UrlUtil.getContentsGroupedApi}");

      // Use GET request with body (similar to other API calls in this app)
      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..body = body;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['result'] != null && json['result']['status'] == 'success') {
          return ContentsResponse.fromJson(json);
        }
      }
      return null;
    } catch (e, stackTrace) {
      log('Error in getContents: $e\n$stackTrace');
      return null;
    }
  }
}
