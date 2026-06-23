
import 'package:el_race/report_module/data/models/company_model.dart';

abstract class ICompanyRepository {
  Future<void> updateCompany(CompanyModel company);
  Future<CompanyModel> getCompany();
}
