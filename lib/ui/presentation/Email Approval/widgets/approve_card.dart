import 'dart:convert';
import 'package:el_race/ui/presentation/Email%20Approval/Approval_confirmation.dart';
import 'package:el_race/utils/Util.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ApproveCard extends StatelessWidget {
  final Map<dynamic, dynamic> item;
  const ApproveCard({super.key, required this.item});

  // Helper method to check if image_emp is a URL or base64 data
  bool _isImageUrl(String imageData) {
    return imageData.startsWith('http://') || imageData.startsWith('https://');
  }

  // Helper widget to display employee image (URL or base64)
  Widget _buildEmployeeImage(dynamic imageEmp) {
    if (imageEmp != null &&
        imageEmp is String &&
        imageEmp.isNotEmpty &&
        imageEmp.toLowerCase() != "false") {
      if (_isImageUrl(imageEmp)) {
        // It's a URL, use Image.network
        return Image.network(
          imageEmp,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Image(
              image: AssetImage("assets/png/profile_1.png"),
              fit: BoxFit.cover,
            );
          },
        );
      } else {
        // It's base64 data, decode it
        try {
          return Image.memory(
            base64Decode(imageEmp),
            fit: BoxFit.cover,
          );
        } catch (e) {
          return const Image(
            image: AssetImage("assets/png/profile_1.png"),
            fit: BoxFit.cover,
          );
        }
      }
    }
    // Fallback to default image
    return const Image(
      image: AssetImage("assets/png/profile_1.png"),
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    String id = item["id"] ?? '';
    String name = item["name"] ?? '';
    String type = item["type"] ?? 'ALL';
    String empName = item["requester"] ?? '';
    String approver = item["approver"] ?? 'MARWAN ABDELSATTAR';
    String location = item["location"] ?? 'N/A';
    String date = item["date"] ?? '2024-08-09';

    List<String> requesterParts = empName.split(" - ");
    String requesterName = requesterParts.isNotEmpty ? requesterParts[0] : '';
    String requesterRole = requesterParts.length > 1 ? requesterParts[1] : '';

    DateTime parsedDate = DateTime.tryParse(date) ?? DateTime.now();
    String day = parsedDate.day.toString().padLeft(2, '0');
    String month = Util.monthName(parsedDate.month);
    String year = parsedDate.year.toString();

    // Get icon dynamically based on category type
    String iconPath =
        categoryIcons[type.toUpperCase()] ?? "assets/icons/default.png";
    return GestureDetector(
      onTap: () {
        print('Navigating with ID: $id'); // 👈 print before navigation
        print('Navigating with type: $type'); // 👈 print before navigation

        Util.pushPage(
          ApprovalConfirmationScreen(
            requestId: id,
            type: type,
          ),
          context,
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/png/background.png"),
            fit: BoxFit.fill,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(36, 16, 16, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(iconPath, height: 30, width: 30),
                          const SizedBox(width: 8),
                          Text(
                            type,
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: appFontColor,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Icon(Icons.more_horiz, size: 20, color: appFontColor),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.tag, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 16, color: Colors.black54),
                  const SizedBox(width: 8),
                  Text(
                    requesterName,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "- $requesterRole",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.orange,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: Colors.black54),
                  const SizedBox(width: 8),
                  Text(
                    location,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: appFontColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Transform.translate(
                offset: const Offset(0, -13),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: ClipOval(
                          child: _buildEmployeeImage(item["image_emp"]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        approver,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: appFontColor,
                          letterSpacing: 1.0,
                        ),
                        overflow: TextOverflow.visible,
                        maxLines: null,
                        softWrap: false,
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: Container(
                        width: 47,
                        height: 65,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage("assets/png/date_box_bg.png"),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 6),
                              decoration: const BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage("assets/png/date-bg.png"),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Text(
                                day,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              month,
                              style: GoogleFonts.poppins(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            Text(
                              year,
                              style: GoogleFonts.poppins(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static final Map<String, String> categoryIcons = {
    "ALL": "assets/png/all-icon.png",
    "HR": "assets/png/hr-icon.png",
    "RFQ": "assets/png/rfq-icon.png",
    "INVOICE": "assets/png/invoice-icon.png",
    "PETTY CASH": "assets/png/petty-cash-icon.png",
  };
}
