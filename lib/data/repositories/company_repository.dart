import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/repositories/i_company_repository.dart';
import 'package:el_race/report_module/data/models/company_model.dart';
import 'package:hive/hive.dart';

class CompanyRepository implements ICompanyRepository {
  static int? selectedCompany = 1;
  static CompanyModel? company;
  static Box<CompanyModel>? _companyBox;

  Future<Box<CompanyModel>> _getCompanyBox() async {
    if (_companyBox != null && _companyBox!.isOpen) {
      return _companyBox!;
    }

    try {
      _companyBox = Hive.box<CompanyModel>('companybox');
    } catch (_) {
      // If box is not yet available via Hive.box, open it safely
      _companyBox = await Hive.openBox<CompanyModel>('companybox');
    }

    return _companyBox!;
  }




  @override
  Future<CompanyModel> getCompany() async {
    int id = SharedPref.getSelectedCompany();
    final box = await _getCompanyBox();
    selectedCompany = id;
    print('🏢 data/CompanyRepository.getCompany() → selectedCompany=$id');

    // Determine the correct logo based on company ID
    final String correctLogo =
        (id == 1) ? 'assets/newapp/logo.png' : 'assets/newapp/logo2.png';

    final stored = box.get(id);
    if (stored != null) {
      // Always override logo to ensure correctness
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

  @override
  Future<void> updateCompany(CompanyModel company) async {
    final box = await _getCompanyBox();
    int id = SharedPref.getSelectedCompany();
    selectedCompany = id;
    box.put(id, company);
  }
}
