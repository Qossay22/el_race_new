import 'dart:convert';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:http/http.dart' as http;
import '../models/qr_question_model.dart';
import '../models/qr_document_model.dart';
import '../models/qr_media_model.dart';

class QrSurveyApiService {
  static const String baseUrl = 'https://erp.elrace.com/api';

  /// Get content after QR code is scanned
  /// Returns a Map with type and data
  /// type can be: 'survey', 'documents', 'media'
  Future<Map<String, dynamic>?> getContentAfterQrCodeScanned() async {
    try {
      final token = SharedPref.getLoginData().result?.token;

      // GET with body (non-standard but trying as requested)
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final url = Uri.parse('$baseUrl/survey/any_published');

      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': {},
      });

      print('🌐 QR API Request:');
      print('  - URL: $url');
      print('  - Method: GET with body');
      print('  - Has Auth: ${token != null}');
      print('  - Body: $body');

      // Using http.Request to send GET with body
      final request = http.Request('GET', url);
      request.headers.addAll(headers);
      request.body = body;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('🌐 QR API Response:');
      print('  - Status: ${response.statusCode} ${response.reasonPhrase}');
      print('  - Body Length: ${response.body.length}');

      if (response.statusCode == 200) {
        final bodyText = response.body;
        print('🌐 QR API Response Body: $bodyText');
        final data = jsonDecode(bodyText);

        // Response format: { "jsonrpc": "2.0", "id": null, "result": { "type": "media", "data": [...] } }
        if (data['result'] != null) {
          final result = data['result'];
          final type = result['type'];
          final contentData = result['data'];

          if (type == null || contentData == null) {
            print('⚠️ QR API: Missing type or data in result');
            return null;
          }

          print(
              '🌐 QR API: type=$type, data count=${(contentData as List).length}');

          // Return based on type
          if (type == 'survey') {
            return {
              'type': 'survey',
              'survey_id': result['survey_id'],
              'title': result['title'],
              'data': (contentData as List)
                  .map((q) => QrQuestionModel.fromJson(q))
                  .toList(),
            };
          } else if (type == 'documents') {
            return {
              'type': 'documents',
              'data': (contentData as List)
                  .map((d) => QrDocumentModel.fromJson(d))
                  .toList(),
            };
          } else if (type == 'media') {
            return {
              'type': 'media',
              'data': (contentData as List)
                  .map((m) => QrMediaModel.fromJson(m))
                  .toList(),
            };
          } else {
            print('⚠️ QR API: Unknown type=$type');
            return null;
          }
        } else {
          print('⚠️ QR API: result is missing');
        }
      } else {
        print('❌ QR API non-200: body=${response.body}');
      }

      return null;
    } catch (e) {
      print('❌ Error fetching QR content: $e');
      return null;
    }
  }

  /// Submit survey answers
  Future<bool> submitSurveyAnswers({
    required int surveyId,
    required List<QrQuestionModel> questions,
    String? guestName,
    String? guestContact,
  }) async {
    try {
      final token = SharedPref.getLoginData().result?.token;
      final isGuest = token == null;

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      // Prepare answers
      final answers = questions.map((q) {
        Map<String, dynamic> answer = {
          'question_id': q.id,
        };

        switch (q.type) {
          case 'date':
            if (q.dateAnswer != null) {
              answer['answer'] = q.dateAnswer!.toIso8601String();
            }
            break;
          case 'simple_choice':
            if (q.selectedAnswer != null) {
              answer['answer'] = q.selectedAnswer;
            }
            break;
          case 'char_box':
            if (q.textAnswer != null) {
              answer['answer'] = q.textAnswer;
            }
            break;
        }

        return answer;
      }).toList();

      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': {
          'survey_id': surveyId,
          'answers': answers,
          if (isGuest) ...{
            'guest_name': guestName,
            'guest_contact': guestContact,
          },
        },
      });

      final url = Uri.parse('$baseUrl/survey/submit/$surveyId');
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['result']?['status'] == 'success';
      }

      return false;
    } catch (e) {
      print('❌ Error submitting survey: $e');
      return false;
    }
  }
}
