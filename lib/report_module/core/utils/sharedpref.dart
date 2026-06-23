import 'package:shared_preferences/shared_preferences.dart';

Future<int> getSelectedCompany() async {
  SharedPreferences pref = await SharedPreferences.getInstance();
  final id = pref.getInt("selectedCompany") ?? 1;
  print('🏢 report_module getSelectedCompany() → $id');
  return id;
}

Future<void> saveSelectedCompany(int id) async {
  print('🏢 report_module saveSelectedCompany($id)');
  SharedPreferences pref = await SharedPreferences.getInstance();
  await pref.setInt("selectedCompany", id);
}
