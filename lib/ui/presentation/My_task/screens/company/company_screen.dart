import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/report_module/data/models/company_model.dart';
import 'package:flutter/material.dart';
import '../../../../../core/constants/colors.dart';
import '../../../../../core/constants/text_styles.dart';
import '../../../../../data/repositories/company_repository.dart';
import '../../../../widgets/bottom_appbar.dart';
import '../../../../widgets/custom_textfield.dart';
import '../../../../widgets/square_button.dart';

class CompanyInfoScreen extends StatefulWidget {
  const CompanyInfoScreen({super.key});

  @override
  State<CompanyInfoScreen> createState() => _CompanyInfoScreenState();
}

class _CompanyInfoScreenState extends State<CompanyInfoScreen> {
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController employeeIdController;
  // late TextEditingController endTextController;
  late CompanyModel company;

  getSelectedCompanyData() async {
    company = CompanyRepository.company!;
    nameController = TextEditingController(text: company.employeeName);
    emailController = TextEditingController(text: company.personEmail);
    phoneController = TextEditingController(text: company.contactPhone);
    employeeIdController = TextEditingController(text: company.employeeID);
  }

  @override
  void initState() {
    getSelectedCompanyData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        surfaceTintColor: Colors.transparent,
        backgroundColor: CustomColors.white,
        centerTitle: true,
        leadingWidth: 60,
        leading: Align(
          alignment: Alignment.centerRight,
          child: SquareButton(
            icon: Icons.keyboard_backspace,
            color: CustomColors.white,
            borderColor: CustomColors.black,
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        title: Image.asset(
          CompanyRepository.company!.logo,
          height: 60,
        ),
        bottom: getBottomAppBar(context),
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          Expanded(
              child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () async {
                      await SharedPref.saveSelectedCompany(1);
                      await CompanyRepository().getCompany();
                      await getSelectedCompanyData();
                      setState(() {});
                    },
                    child: Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: CustomColors.maroon,
                              width: CompanyRepository.selectedCompany == 1
                                  ? 2
                                  : 0),
                          color: CustomColors.containerColor,
                          borderRadius: BorderRadius.circular(12)),
                      child: Image.asset("assets/newapp/logo.png"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () async {
                      await SharedPref.saveSelectedCompany(2);
                      await CompanyRepository().getCompany();
                      await getSelectedCompanyData();
                      setState(() {});
                    },
                    child: Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: CustomColors.maroon,
                              width: CompanyRepository.selectedCompany == 2
                                  ? 2
                                  : 0),
                          color: CustomColors.containerColor,
                          borderRadius: BorderRadius.circular(12)),
                      child: Image.asset("assets/newapp/logo2.png"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CustomTextField(
                showLabel: true,
                required: false,
                controller: employeeIdController,
                inputType: TextInputType.text,
                hintText: "Employee ID",
              ),
              const SizedBox(height: 12),
              CustomTextField(
                showLabel: true,
                required: false,
                controller: nameController,
                inputType: TextInputType.text,
                hintText: "Employee Name",
              ),
              const SizedBox(height: 12),
              CustomTextField(
                showLabel: true,
                required: false,
                controller: emailController,
                inputType: TextInputType.text,
                hintText: "Email",
              ),
              const SizedBox(height: 12),
              CustomTextField(
                showLabel: true,
                required: false,
                controller: phoneController,
                inputType: TextInputType.text,
                hintText: "Contact Phone",
              ),

              // SizedBox(height: 12),
              // CustomTextField(
              //   showLabel: true,
              //   required: false,
              //   controller: endTextController,
              //   inputType: TextInputType.text,
              //   hintText: "End Controller",
              // ),
              const SizedBox(height: 16),
              MaterialButton(
                onPressed: () async {
                  await CompanyRepository().updateCompany(company.copyWith(
                    personEmail: emailController.text,
                    contactPhone: phoneController.text,
                    // endText: endTextController.text,
                    personName: nameController.text,
                    employeeID: employeeIdController.text,
                  ));
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                height: 44,
                color: CustomColors.maroon,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Text(
                  "Save",
                  style: CustomTextStyle.reportTitle.copyWith(
                    color: CustomColors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            ],
          ))
        ],
      ),
    );
  }
}
