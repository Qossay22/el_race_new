import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'requests_event.dart';
import 'requests_state.dart';
import 'dart:convert';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:http/http.dart' as http;

class RequestsBloc extends Bloc<RequestsEvent, RequestsState> {
  static RequestsBloc get(BuildContext context) => BlocProvider.of(context);


  RequestsBloc() : super(RequestsInitial()) {
    on<FetchRequestsCount>(_fetchRequestsCount);
  }

  
  int requestsCount = 0;
  int get getRequestsCount => requestsCount;
  Future<void> _fetchRequestsCount(FetchRequestsCount event, Emitter<RequestsState> emit) async {
    try {
      final token = SharedPref.getLoginData().result?.token;
      final headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      };
      final body = jsonEncode({
        "jsonrpc": "2.0",
        "params": {"keyword": ""},
      });
      final url = Uri.parse("https://erp.elrace.com/api/my_requests");
      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..body = body;
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['result']['data'];
        requestsCount = items.length;
      } else {
        emit(const RequestsError("Failed to load requests:  {response.statusCode}"));
      }
    } catch (e) {
      emit(const RequestsError("Something went wrong. Please try again."));
    }
  }

  
} 