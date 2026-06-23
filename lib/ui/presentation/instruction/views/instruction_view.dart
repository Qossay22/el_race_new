import 'package:el_race/resources/app_colors.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:el_race/ui/widgets/custom_button.dart';
import 'package:el_race/utils/extensions/size_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:el_race/ui/presentation/home_screen/screens/home_screen.dart';
import 'package:el_race/utils/Util.dart';

import '../view_model/instruction_view_model.dart';

class InstructionView extends StatelessWidget {
  final InstructionViewController controller = InstructionViewController();
  final LoginResponseModel loginResponseModel;

  InstructionView({required this.loginResponseModel, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlack,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.appBarColor,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 1),
              Icon(
                Icons.camera_alt_outlined,
                color: AppColors.loaderColors,
                size: 0.1.sh,
              ),
              SizedBox(height: 0.02.sh),
              Text(
                translate('instruction.selfie_time'),
                style: TextStyle(
                  fontSize: 0.05.sh,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  shadows: [
                    Shadow(
                      color: Colors.black.withAlpha((0.15 * 255).toInt()),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 0.01.sh),
              Text(
                translate('instruction.get_ready'),
                style: TextStyle(
                  fontSize: 0.025.sh,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 0.05.sh),

              // Instruction list with icons
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: controller.instructions.map((tip) {
                  final icon =
                      controller.instructionIcons[tip] ?? Icons.info_rounded;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          icon,
                          color: AppColors.loaderColors,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tip,
                            style: TextStyle(
                              fontSize: 0.020.sh,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              SizedBox(height: 0.07.sh),

              // Action Button
              CustomButton(
                text: translate('instruction.lets_go'),
                onTap: () async {
                  // Navigate to home screen – auth setup happens there
                  Util.pushPageAndRemoveRoutes(const HomeScreen(), context);
                },
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
