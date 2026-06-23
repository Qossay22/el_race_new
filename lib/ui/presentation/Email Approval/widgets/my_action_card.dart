import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/approval_bloc.dart';
import '../bloc/approval_event.dart';
import '../bloc/approval_state.dart';

class MyActionCard extends StatelessWidget {
  final List<dynamic> approvalItems;
  const MyActionCard({super.key, required this.approvalItems});

  @override
  Widget build(BuildContext context) {
    if (approvalItems.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text('No items found'),
        ),
      );
    }

    return Expanded(
      child: BlocBuilder<ApprovalBloc, ApprovalState>(
        builder: (context, state) {
          final expandedItems = state.expandedItems;

          // Calculate safe bottom padding for devices with navigation bars
          final totalBottomPadding =
              kBottomNavigationBarHeight + context.systemBottomInset + 16;

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4) +
                EdgeInsets.only(bottom: totalBottomPadding, top: 100.w),
            itemCount: approvalItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final item = approvalItems[index];
              final bool isExpanded = expandedItems.contains(index);

              String reqNo =
                  item["name"] ?? item["request_no"] ?? item["req_no"] ?? "N/A";
              String title = item["title"] ?? item["type"] ?? "N/A";
              String dateStr = (item["date"] ?? item["request_date"] ?? "")
                  .toString()
                  .replaceAll('false', '')
                  .replaceAll('true', '');
              String status =
                  (item["status"] ?? "pending").toString().toLowerCase();
              String statusLabel = status.toUpperCase();

              DateTime? parsedDate;
              try {
                parsedDate = DateTime.tryParse(dateStr);
              } catch (e) {
                parsedDate = DateTime.now();
              }

              // 🎨 Status-based styling
              String backgroundImage = 'assets/png/item_bg_green.png';
              Color textColor = Colors.white;

              switch (status) {
                case 'approve':
                case 'approved':
                case 'accept':
                  backgroundImage = 'assets/png/item_bg_green.png';
                  textColor = Colors.green;
                  break;
                case 'pending':
                  backgroundImage = 'assets/png/item_bg_yellow.png';
                  textColor = Colors.amber;
                  break;
                case 'cancel':
                case 'cancelled':
                case 'rejected':
                case 'reject':
                  backgroundImage = 'assets/png/item_bg_red.png';
                  textColor = Colors.red;
                  break;
                default:
                  backgroundImage = 'assets/png/item_bg_green.png';
                  textColor = Colors.white;
              }

              Color bgStart = const Color(0xFF0F0C29);
              Color bgEnd = const Color(0xFF302B63);

              return GestureDetector(
                onTap: () {
                  context.read<ApprovalBloc>().add(ToggleItemExpansion(index));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 0.0, horizontal: 8.0),
                  child: SizedBox(
                    height: 60.w,
                    child: Stack(
                      children: [
                        // 🔹 الطبقة الأساسية (Collapsed)
                        Container(
                          height: 60.w,
                          alignment: Alignment.center,
                          padding: EdgeInsets.symmetric(horizontal: 20.w) +
                              EdgeInsets.only(bottom: 10.w),
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage(backgroundImage),
                              fit: BoxFit.cover,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withAlpha((0.08 * 255).toInt()),
                                blurRadius: 4,
                                spreadRadius: 2,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                width: 80.w,
                                child: Text(
                                  parsedDate != null
                                      ? DateFormat('dd MMM yy')
                                          .format(parsedDate)
                                          .toUpperCase()
                                      : 'N/A',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                    color: appFontColor,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                height: 30,
                                child: VerticalDivider(
                                  color: Colors.grey,
                                  thickness: 2,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      translate('home.REQ_NO'),
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: appFontColor,
                                      ),
                                    ),
                                    Text(
                                      reqNo,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black,
                                      ),
                                      overflow: TextOverflow.visible,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                height: 30,
                                child: VerticalDivider(
                                  color: Colors.grey,
                                  thickness: 2,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: appFontColor,
                                  ),
                                  overflow: TextOverflow.visible,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 🔥 الطبقة العلوية (Expanded)
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isExpanded ? 1.0 : 0.0,
                          child: IgnorePointer(
                            ignoring: !isExpanded,
                            child: Container(
                              height: 55.w,
                              alignment: Alignment.center,
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [bgStart, bgEnd],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Center(
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
                    // AnimatedAlign(
                    //   alignment: isExpanded ? Alignment.centerLeft : Alignment.centerRight,
                    //   duration: const Duration(milliseconds: 900),
                    //   curve: Curves.easeInOut,
                    //   child: Container(
                    //     margin: EdgeInsets.symmetric(horizontal: 10.w),
                    //     key: ValueKey(isExpanded),
                    //     width: 50.w,
                    //     height: 50.w,
                    //     decoration: BoxDecoration(
                    //       shape: BoxShape.circle,
                    //       border: Border.all(color: Colors.white, width: 2),
                    //     ),
                    //     child: ClipOval(
                    //       child: (item["image_emp"] != null &&
                    //               item["image_emp"] is String &&
                    //               (item["image_emp"] as String).isNotEmpty &&
                    //               (item["image_emp"] as String).toLowerCase() != "false")
                    //           ? Image.memory(
                    //               base64Decode(item["image_emp"] as String),
                    //               fit: BoxFit.cover,
                    //               width: double.infinity,
                    //               height: double.infinity,
                    //             )
                    //           : Image.asset(
                    //               'assets/png/profile_1.png',
                    //               fit: BoxFit.cover,
                    //               width: double.infinity,
                    //               height: double.infinity,
                    //             ),
                    //     ),
                    //   ),
                    // ),
           