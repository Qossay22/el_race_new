import 'dart:ui';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  bool _needsScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfScrollNeeded();
    });
  }

  void _checkIfScrollNeeded() {
    if (!mounted) return;
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      setState(() {
        _needsScrolling = true;
      });
      _startScrolling();
    }
  }

  void _startScrolling() async {
    if (!mounted || !_needsScrolling) return;

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    while (mounted && _needsScrolling) {
      // Scroll to end slowly
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(
            milliseconds: (widget.text.length * 120).clamp(4000, 15000)),
        curve: Curves.linear,
      );

      if (!mounted) break;
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) break;

      // Jump back to start instantly (no animation)
      _scrollController.jumpTo(0);

      await Future.delayed(const Duration(milliseconds: 1500));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      child: Text(
        widget.text,
        style: widget.style,
        textAlign: widget.textAlign,
      ),
    );
  }
}

class LpoCardWidget extends StatelessWidget {
  const LpoCardWidget({
    super.key,
    this.poId,
    this.name,
    this.vendorName,
    this.projectName,
    this.date,
    this.amount,
    this.attachments,
    this.lpoCount,
    this.clientPhoto,
    this.requestedByUserPhoto,
    this.requestedBy,
    this.requesterManager,
    this.state,
    this.onTap,
  });

  final int? poId;
  final String? name;
  final String? vendorName;
  final String? projectName;
  final String? date;
  final String? amount;
  final List<dynamic>? attachments;
  final String? lpoCount;
  final String? clientPhoto;
  final String? requestedByUserPhoto;
  final String? requestedBy;
  final String? requesterManager;
  final String? state;
  final VoidCallback? onTap;

  static final _amountFormat = NumberFormat('#,##0.##', 'en');

  String? _formatAmount(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.,]'), '');
    final value = double.tryParse(cleaned.replaceAll(',', ''));
    if (value == null) return raw;
    return _amountFormat.format(value);
  }

  String? _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      // Backend sometimes returns "yyyy-MM-dd HH:mm:ss".
      final normalized = raw.contains(' ') && !raw.contains('T')
          ? raw.replaceFirst(' ', 'T')
          : raw;
      final parsed = DateTime.tryParse(normalized);
      if (parsed == null) return raw;
      return DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedAmount = _formatAmount(amount);
    final formattedDate = _formatDate(date);

    // Reference design shows RCC/LPO/<id> on top.
    final codeText = poId != null
        ? 'RCC/LPO/$poId'
        : ((name ?? '').trim().isNotEmpty ? name!.trim() : 'RCC/LPO');

    final titleText = ((projectName ?? '').trim().isNotEmpty
            ? projectName!.trim()
            : (vendorName ?? '').trim())
        .toUpperCase();
    final subtitleText =
        ((vendorName ?? '').trim().isNotEmpty ? vendorName!.trim() : null)
            ?.toUpperCase();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: const Color(0xFF8F929A), width: 1),
          color: const Color(0xFFD0D2D6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 8.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                    child: Text(
                      codeText,
                      maxLines: null,
                      overflow: TextOverflow.visible,
                      style: GoogleFonts.poppins(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0E3A76),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  SizedBox(height: 25.h),
                  Padding(
                    padding: EdgeInsetsDirectional.only(start: 2.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          titleText.isNotEmpty ? titleText : '-',
                          maxLines: 2,
                          overflow: TextOverflow.visible,
                          style: GoogleFonts.poppins(
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            height: 1.15,
                          ),
                        ),
                        if (subtitleText != null && subtitleText.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 6.h),
                            child: Text(
                              subtitleText,
                              maxLines: null,
                              overflow: TextOverflow.visible,
                              style: GoogleFonts.poppins(
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w700,
                                color: greyText,
                                height: 1.1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(start: 2.w),
                          child: Text(
                            (formattedDate ?? '').isNotEmpty
                                ? formattedDate!
                                : '',
                            maxLines: null,
                            overflow: TextOverflow.visible,
                            style: GoogleFonts.poppins(
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w600,
                              color: greyText,
                            ),
                          ),
                        ),
                      ),
                      if (formattedAmount != null && formattedAmount.isNotEmpty)
                        Text(
                          formattedAmount,
                          maxLines: null,
                          overflow: TextOverflow.visible,
                          style: GoogleFonts.poppins(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0E3A76),
                            letterSpacing: 0.3,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PositionedDirectional(
              start: 10.w,
              top: 10.h,
              child: Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE6E7EA), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.14),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: clientPhoto != null && clientPhoto!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          clientPhoto!,
                          fit: BoxFit.contain,
                          width: 42.w,
                          height: 42.w,
                          headers: {
                            'Accept': 'image/*',
                            'Authorization':
                                'Bearer ${SharedPref.getLoginData().result?.token ?? ''}',
                          },
                          errorBuilder: (_, __, ___) => _buildInitialsAvatar(),
                        ),
                      )
                    : _buildInitialsAvatar(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    return Text(
      (vendorName != null && vendorName!.isNotEmpty)
          ? vendorName!.characters.take(2).toString().toUpperCase()
          : (name != null && name!.isNotEmpty)
              ? name!.characters.take(2).toString().toUpperCase()
              : 'V',
      style: GoogleFonts.poppins(
        fontSize: 22.sp,
        fontWeight: FontWeight.w700,
        color: appFontColor,
      ),
    );
  }
}

void showAttachmentDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: _buildDialogContent(context),
      );
    },
  );
}

Widget _buildDialogContent(BuildContext context) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔹 Title
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Transform.rotate(
              angle: -0.8, // in radians (not degrees)
              child: const Icon(
                Icons.attachment,
                color: Colors.black,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "ATTACHMENTS",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: Colors.black,
                //letterSpacing: 1.2,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 🔸 LPO No
        Row(
          children: [
            const Icon(Icons.tag, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Text(
              "LPO NO",
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 🔸 Vendor Name
        Row(
          children: [
            const Icon(Icons.handshake, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Text(
              "VENDOR NAME",
              style: GoogleFonts.poppins(
                color: Colors.blue,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 🔸 Project Name
        Row(
          children: [
            const Icon(Icons.business_center, color: Colors.black, size: 20),
            const SizedBox(width: 8),
            Text(
              "PROJECT NAME",
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),

        // 🔘 Button
        Center(
          child: SizedBox(
            width: 180,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF191F52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                // TODO: Add your view attachment logic here
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Transform.rotate(
                    angle: -0.8, // in radians (not degrees)
                    child: const Icon(
                      Icons.attachment,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "VIEW ATTACHMENT",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
