import 'dart:async';
import 'dart:developer';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

import '../../../../../../utils/di.dart';
import '../data/model.dart';
import '../data/repository.dart';

part 'contact_event.dart';
part 'contact_state.dart';

final _contactRepo = sl.get<ContactRepo>();

class ContactBloc extends Bloc<ContactEvent, ContactState> {
  String? _cachedUserKey;

  ContactBloc() : super(ContactInitial()) {
    on<GetEmployeeLisET>(getEmpMethod);
    on<SearchContactsEvent>(searchContactsMethod);
  }

  List<Employee> empList = [];
  List<Employee> filteredEmpList = [];
  FutureOr<void> getEmpMethod(
      GetEmployeeLisET event, Emitter<ContactState> emit) async {
    final currentUserKey = _resolveCurrentUserKey();
    if (_cachedUserKey != null && _cachedUserKey != currentUserKey) {
      // print('🔄 User changed in ContactBloc, clearing cached contacts');
      empList.clear();
      filteredEmpList.clear();
    }

    // print('\\n🟢 ========== FETCHING CONTACTS ==========');
    // print('📊 Current empList size: ${empList.length}');
    // print('👤 Current user key: $currentUserKey');

    if (empList.isNotEmpty) {
      // print('✅ Using cached data');
      filteredEmpList = List<Employee>.from(empList);
      emit(EmployeeListLoaded(List<Employee>.from(filteredEmpList)));
      // print('🟢 ========== END FETCHING CONTACTS ==========\\n');
      return;
    }

    // print('⏳ Loading contacts from API...');
    emit(const ContactLoadingState(isLoading: true));

    log('empModel.result!.employees! 1');

    http.Response? response = await _contactRepo.getEmployeeList();
    log('empModel.result!.employees! 2');

    if (response.statusCode == 200) {
      // print('✅ API Response Success (200)');
      final empModel = employeeModelFromJson(response.body);

      // Guard against error payloads and nulls
      final employees = empModel.result?.employees ?? [];
      // print('📊 Parsed ${employees.length} employees');

      emit(const ContactLoadingState(isLoading: false));
      if (employees.isNotEmpty) {
        empList = employees;
        filteredEmpList = employees;
        _cachedUserKey = currentUserKey;

        // First 3 employees print silenced
        emit(EmployeeListLoaded(List<Employee>.from(filteredEmpList)));
        // print('✅ Emitted ${employees.length} employees to UI');
        // print('🟢 ========== END FETCHING CONTACTS ==========\\n');
      }
      return;
    } else {
      // print('❌ API Response Failed: ${response.statusCode}');
      // print('🟢 ========== END FETCHING CONTACTS ==========\\n');
    }

    log(response.body);
    try {} catch (e) {
      log('getEmpMethod $e');
    }
  }

  FutureOr<void> searchContactsMethod(
      SearchContactsEvent event, Emitter<ContactState> emit) async {
    final keyword = event.keyword.toLowerCase();

    if (keyword.isEmpty) {
      filteredEmpList = empList;
    } else {
      filteredEmpList = empList
          .where((employee) =>
              employee.name?.toLowerCase().contains(keyword) == true ||
              employee.empId?.toString().toLowerCase().contains(keyword) ==
                  true ||
              employee.id?.toString().toLowerCase().contains(keyword) == true ||
              employee.department?.toString().toLowerCase().contains(keyword) ==
                  true ||
              employee.mobilePhone
                      ?.toString()
                      .toLowerCase()
                      .contains(keyword) ==
                  true ||
              employee.jobId?.toString().toLowerCase().contains(keyword) ==
                  true)
          .toList();
    }

    emit(EmployeeListLoaded(List<Employee>.from(filteredEmpList)));
  }

  String _resolveCurrentUserKey() {
    final login = SharedPref.getLoginDataOrNull();
    final data = login?.result?.data;

    final byUid = data?.uid?.toString();
    if (byUid != null && byUid.isNotEmpty) return 'uid:$byUid';

    final byUser = data?.odoo_user_id?.toString();
    if (byUser != null && byUser.isNotEmpty) return 'odoo:$byUser';

    final byEmp = data?.employee_id?.toString();
    if (byEmp != null && byEmp.isNotEmpty) return 'emp:$byEmp';

    final byUsername = data?.username?.trim();
    if (byUsername != null && byUsername.isNotEmpty) {
      return 'username:$byUsername';
    }

    return 'guest';
  }
}
