import 'package:el_race/ui/presentation/landing_screen/screens/menu/menu_model.dart';
import 'package:flutter/material.dart';

import '../../../../../utils/color_utils.dart';
import '../../../../widgets/footer_widget.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // const HeaderWidget(),
              menuList(context),
              const FooterWidget()
            ],
          ),
        ),
      ),
    );
  }
}

Widget menuList(BuildContext context) {
  return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 40),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, childAspectRatio: 1 // 2 columns
          ),
      shrinkWrap: true,
      itemCount: menuListItems.length,
      itemBuilder: (context, index) {
        return Column(
          children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: white,
                  boxShadow: const [
                    BoxShadow(
                        color: darkGrey, offset: Offset(2, 4), blurRadius: 12)
                  ]),
              child: Image.asset(menuListItems[index].icon),
            ),
          ],
        );
      });
}
