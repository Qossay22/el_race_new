import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;

import '../../../../../../utils/di.dart';
import '../../../../utils/api_query.dart';
import '../../../../utils/urll_utils.dart';
import '../../signin/data/repository.dart';

final userRepo = sl.get<UserRepo>();

class ContactRepo {
  ApiQuery apiQuery = ApiQuery();

  Future<http.Response> getEmployeeList() async {
    var url = Uri.parse(UrlUtil.baseUrl + UrlUtil.contactApi);

    final loginResponse = await userRepo.getLoginResponse();
    final token = loginResponse?.result?.token;
    if (token == null || token.isEmpty) {
      // Return a synthetic 401-like response to be handled by caller
      final body = jsonEncode({
        "jsonrpc": "2.0",
        "id": null,
        "result": {"status": "error", "message": "Invalid token"}
      });
      return http.Response(body, 401,
          headers: {"content-type": "application/json"});
    }

    Map<String, String> header = {
      "Content-Type": "application/json",
      'Accept': 'application/json',
      "Authorization": "Bearer $token"
    };
    final request = http.Request('GET', url)
      ..headers.addAll(header)
      ..body = jsonEncode({});

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    // Contacts API logging silenced to reduce noise

    return response;
  }
}
