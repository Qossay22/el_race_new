import 'package:el_race/report_module/core/constants/colors.dart';
import 'package:el_race/report_module/core/constants/text_styles.dart';
import 'package:el_race/report_module/data/models/cover_page_model.dart';
import 'package:el_race/report_module/data/models/report_detail_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/report_module/data/repositories/company_repository.dart';
import 'package:el_race/report_module/presentation/widgets/bottom_appbar.dart';
import 'package:el_race/report_module/presentation/widgets/custom_textfield.dart';
import 'package:el_race/report_module/presentation/widgets/square_button.dart';
import 'package:flutter/material.dart';

class AddCoverScreen extends StatefulWidget {
  final ReportDetailModel reportDetail;
  final String folderName;

  const AddCoverScreen({
    super.key,
    required this.reportDetail,
    required this.folderName,
  });

  @override
  State<AddCoverScreen> createState() => _AddCoverScreenState();
}

class _AddCoverScreenState extends State<AddCoverScreen> {
  late TextEditingController titleController;
  late TextEditingController descriptionController;

  @override
  void initState() {
    titleController = TextEditingController();
    descriptionController = TextEditingController();
    if (widget.reportDetail.coverPage != null) {
      titleController =
          TextEditingController(text: widget.reportDetail.coverPage!.title);
      descriptionController = TextEditingController(
          text: widget.reportDetail.coverPage!.description ?? "");
    }
    super.initState();
  }

  GlobalKey<FormState> form = GlobalKey<FormState>();

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
        bottom: getBottomAppBar(context,
            report: widget.reportDetail, folderName: widget.folderName),
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CustomTextField(
              maxCharacter: 100,
              showLabel: true,
              required: true,
              controller: titleController,
              inputType: TextInputType.text,
              hintText: "Title",
            ),
            const SizedBox(height: 8),
            CustomTextField(
              maxCharacter: 1000,
              showLabel: true,
              required: false,
              controller: descriptionController,
              inputType: TextInputType.multiline,
              maxLine: 4,
              hintText: "Description",
            ),
            const SizedBox(height: 16),
            MaterialButton(
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                ReportDetailModel? updatedReportCover;
                if (widget.reportDetail.coverPage != null) {
                  updatedReportCover = widget.reportDetail.copyWith(
                      coverPage: widget.reportDetail.coverPage!.copyWith(
                    title: titleController.text,
                    description: descriptionController.text,
                  ));
                  await reportProvider.updateReportDetail(updatedReportCover);
                  Navigator.pop(context, updatedReportCover);
                  return;
                } else {
                  ReportDetailModel updatedReportCover =
                      widget.reportDetail.copyWith(
                          coverPage: CoverPageModel(
                    empId: ReportProvider.empID,
                    title: titleController.text,
                    description: descriptionController.text,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ));

                  await reportProvider.updateReportDetail(updatedReportCover);
                  Navigator.pop(context, updatedReportCover);
                  return;
                }

                // Navigator.pop(context);
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
        ),
      ),
    );
  }
}
