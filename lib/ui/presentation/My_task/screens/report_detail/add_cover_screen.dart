import 'package:el_race/data/models/report_detail_model.dart';
import 'package:el_race/data/models/report_model.dart';
import 'package:el_race/data/repositories/i_report_repository.dart';
import 'package:el_race/data/repositories/report_repository.dart';
import 'package:el_race/ui/widgets/custom_textfield.dart';
import 'package:flutter/material.dart';

import '../../../../../core/constants/colors.dart';
import '../../../../../core/constants/text_styles.dart';

import '../../../../../data/repositories/company_repository.dart';
import '../../../../widgets/bottom_appbar.dart';
import '../../../../widgets/square_button.dart';

class AddCoverScreen extends StatefulWidget {
  final ReportDetailModel reportDetail;
  final ReportModel report;

  const AddCoverScreen({
    super.key,
    required this.reportDetail,
    required this.report,
  });

  @override
  State<AddCoverScreen> createState() => _AddCoverScreenState();
}

class _AddCoverScreenState extends State<AddCoverScreen> {
  late IReportRepository reportRepository;
  late TextEditingController titleController;
  late TextEditingController descriptionController;

  @override
  void initState() {
    reportRepository = ReportRepository();
    titleController = TextEditingController();
    descriptionController = TextEditingController();
    if (widget.reportDetail.coverPage != null) {
      titleController =
          TextEditingController(text: widget.reportDetail.coverPage!['title']);
      descriptionController = TextEditingController(
          text: widget.reportDetail.coverPage!['description']);
    }
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
        bottom: getBottomAppBar(context, report: widget.report),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CustomTextField(
            maxCharacter: 100,
            showLabel: true,
            required: false,
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
              Map<String, dynamic> updatedCoverPage = {
                "title": titleController.text,
                "description": descriptionController.text,
                "created_at": DateTime.now()
              };
              ReportDetailModel updatedReported =
                  widget.reportDetail.copyWith(coverPage: updatedCoverPage);
              await reportRepository.updateReportDetail(updatedReported);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            height: 44,
            color: CustomColors.maroon,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
    );
  }
}
