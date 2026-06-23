import 'package:el_race/report_module/core/utils/sharedpref.dart';
import 'package:el_race/report_module/data/models/company_model.dart';
import 'package:el_race/report_module/data/services/report_hive_service.dart';
import 'package:hive/hive.dart';

class CompanyRepository {
  static int? selectedCompany = 1;
  static CompanyModel? company;
  static Box<CompanyModel>? _companyBox;

  Future<Box<CompanyModel>> _getCompanyBox() async {
    if (_companyBox == null || !_companyBox!.isOpen) {
      _companyBox = await ReportHiveService.getCompanyBox();
    }
    return _companyBox!;
  }

  Future<CompanyModel> getCompany() async {
    int id = await getSelectedCompany();
    final box = await _getCompanyBox();
    selectedCompany = id;
    print('🏢 CompanyRepository.getCompany() → selectedCompany=$id');

    // Determine the correct logo based on company ID
    final String correctLogo =
        (id == 1) ? 'assets/logo/logo.png' : 'assets/logo/logo2.png';

    final stored = box.get(id);
    if (stored != null) {
      // Always override logo from Hive to ensure correctness
      company = stored.copyWith(logo: correctLogo);
    } else {
      company = (id == 1)
          ? CompanyModel(
              companyName: "El Race Cons. & Gen. Cont. Co. L.C.C",
              logo: correctLogo,
              employeeName: "",
              personEmail: "",
              contactPhone: "",
              employeeID: "",
              endText: "")
          : CompanyModel(
              companyName: "Al Hewar Contracting & Irrigation Est.",
              logo: correctLogo,
              employeeName: "",
              personEmail: "",
              contactPhone: "",
              employeeID: "",
              endText: "");
    }

    return company!;
  }

  Future<void> updateCompany(CompanyModel company) async {
    final box = await _getCompanyBox();
    int id = await getSelectedCompany();
    selectedCompany = id;
    box.put(id, company);
  }
}
