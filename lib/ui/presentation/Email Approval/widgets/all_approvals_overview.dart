import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class AllApprovalsOverview extends StatelessWidget {
  final int invoiceCount;
  final int pettyCashCount;
  final int rfqCount;
  final int hrCount;
  final int delayedCount;
  final int? rorInvoiceCount;
  final int? rorPettyCashCount;
  final int? rorRfqCount;
  final int? rorHrCount;
  final int? rorPercentage;
  // Per-category ROR percentages from API
  final int? rorHrRor;
  final int? rorRfqRor;
  final int? rorInvoiceRor;
  final int? rorPettyCashRor;
  final VoidCallback? onDelayedTap;
  final VoidCallback? onHrTestCasesTap;

  const AllApprovalsOverview({
    super.key,
    required this.invoiceCount,
    required this.pettyCashCount,
    required this.rfqCount,
    required this.hrCount,
    required this.delayedCount,
    this.rorInvoiceCount,
    this.rorPettyCashCount,
    this.rorRfqCount,
    this.rorHrCount,
    this.rorPercentage,
    this.rorHrRor,
    this.rorRfqRor,
    this.rorInvoiceRor,
    this.rorPettyCashRor,
    this.onDelayedTap,
    this.onHrTestCasesTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalBottomPadding =
        kBottomNavigationBarHeight + context.systemBottomInset + 100.h;
    final totalCount = invoiceCount + pettyCashCount + rfqCount + hrCount;

    return Expanded(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          left: 18.w,
          right: 18.w,
          top: 120.w,
          bottom: totalBottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CategoryRingsRow(
              rfqCount: rfqCount,
              hrCount: hrCount,
              totalCount: totalCount,
              pettyCashCount: pettyCashCount,
              invoiceCount: invoiceCount,
            ),
            SizedBox(height: 20.h),
            _RorCard(
              hrCount: rorHrCount ?? hrCount,
              rfqCount: rorRfqCount ?? rfqCount,
              pettyCashCount: rorPettyCashCount ?? pettyCashCount,
              invoiceCount: rorInvoiceCount ?? invoiceCount,
              rorPercentage: rorPercentage,
              hrRor: rorHrRor,
              rfqRor: rorRfqRor,
              invoiceRor: rorInvoiceRor,
              pettyCashRor: rorPettyCashRor,
            ),
            SizedBox(height: 14.h),
            _DelayedRequestCard(value: delayedCount, onTap: onDelayedTap),
            if (onHrTestCasesTap != null) ...[
              SizedBox(height: 14.h),
              _HrTestCasesCard(onTap: onHrTestCasesTap!),
            ],
          ],
        ),
      ),
    );
  }
}

class _HrTestCasesCard extends StatelessWidget {
  final VoidCallback onTap;

  const _HrTestCasesCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Ink(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: const Color(0xFFFDFDFD),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: const Color(0xFF5E7CC8), width: 1.2),
          ),
          child: Row(
            children: [
              Icon(
                Icons.science_outlined,
                color: const Color(0xFF2A4FA8),
                size: 22.sp,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HR Request Test Cases',
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D2D57),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Open all 19 hardcoded scenarios',
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF5C6991),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: const Color(0xFF7A88AE),
                size: 24.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRingsRow extends StatefulWidget {
  final int rfqCount;
  final int hrCount;
  final int totalCount;
  final int pettyCashCount;
  final int invoiceCount;

  const _CategoryRingsRow({
    required this.rfqCount,
    required this.hrCount,
    required this.totalCount,
    required this.pettyCashCount,
    required this.invoiceCount,
  });

  @override
  State<_CategoryRingsRow> createState() => _CategoryRingsRowState();
}

class _CategoryRingsRowState extends State<_CategoryRingsRow> {
  bool _isExpanded = false;

  void _toggleSpread() {
    setState(() => _isExpanded = !_isExpanded);
  }

  Widget _animatedRing({
    required double collapsedLeft,
    required double expandedLeft,
    required double top,
    required Widget child,
  }) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 430),
      curve: Curves.easeInOutCubic,
      left: _isExpanded ? expandedLeft : collapsedLeft,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleSpread,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84.h,
      child: Center(
        child: SizedBox(
          width: 310.w,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _toggleSpread,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _animatedRing(
                  collapsedLeft: 0,
                  expandedLeft: -40.w,
                  top: 7.h,
                  child: _CountRing(
                    label: 'RFQ',
                    value: widget.rfqCount,
                    borderColor: const Color(0xFFF0A21E),
                  ),
                ),
                _animatedRing(
                  collapsedLeft: 56.w,
                  expandedLeft: 36.w,
                  top: 7.h,
                  child: _CountRing(
                    label: 'HR',
                    value: widget.hrCount,
                    borderColor: const Color(0xFFD4334D),
                  ),
                ),
                _animatedRing(
                  collapsedLeft: 238.w,
                  expandedLeft: 276.w,
                  top: 7.h,
                  child: _CountRing(
                    label: 'Invoice',
                    value: widget.invoiceCount,
                    borderColor: const Color(0xFF2CBF6F),
                  ),
                ),
                _animatedRing(
                  collapsedLeft: 182.w,
                  expandedLeft: 200.w,
                  top: 7.h,
                  child: _CountRing(
                    label: 'Pettycash',
                    value: widget.pettyCashCount,
                    borderColor: const Color(0xFF25B5B3),
                  ),
                ),
                _animatedRing(
                  collapsedLeft: 112.w,
                  expandedLeft: 112.w,
                  top: 2.h,
                  child: _CountRing(
                    label: 'Total',
                    value: widget.totalCount,
                    borderColor: const Color(0xFF4BA0D9),
                    isPrimary: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountRing extends StatelessWidget {
  final String label;
  final int value;
  final Color borderColor;
  final bool isPrimary;

  const _CountRing({
    required this.label,
    required this.value,
    required this.borderColor,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isPrimary ? 84.w : 72.w,
      height: isPrimary ? 84.w : 72.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: borderColor,
          width: isPrimary ? 2.6 : 2.1,
        ),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: const Color(0xFF4BA0D9).withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value.toString(),
            style: GoogleFonts.poppins(
              fontSize: isPrimary ? 18.sp : 15.5.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF444444),
              height: 1,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isPrimary ? 11.sp : 9.2.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF8E8E8E),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RorCard extends StatelessWidget {
    // Per-category ROR % from API (override the count-based chart)
    final int? hrRor;
    final int? rfqRor;
    final int? invoiceRor;
    final int? pettyCashRor;
  final int hrCount;
  final int rfqCount;
  final int pettyCashCount;
  final int invoiceCount;
  final int? rorPercentage;

  const _RorCard({
    required this.hrCount,
    required this.rfqCount,
    required this.pettyCashCount,
    required this.invoiceCount,
    this.rorPercentage,
    this.hrRor,
    this.rfqRor,
    this.invoiceRor,
    this.pettyCashRor,
  });

  @override
  Widget build(BuildContext context) {
    // Use API per-category ROR when available, fall back to item counts
    final bool hasApiRor = hrRor != null || rfqRor != null ||
      invoiceRor != null || pettyCashRor != null;
    final chartValues = hasApiRor
      ? <int>[hrRor ?? 0, rfqRor ?? 0, pettyCashRor ?? 0, invoiceRor ?? 0]
      : <int>[hrCount, rfqCount, pettyCashCount, invoiceCount];
    final maxValue = chartValues.fold<int>(0, (m, v) => v > m ? v : m);
    final highlightedIndex = chartValues.indexOf(maxValue);
    final ror = rorPercentage ?? _calculateRorPercentage();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFCFCFCF), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 18.w,
                height: 18.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF1F4),
                  borderRadius: BorderRadius.circular(5.r),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 18.sp,
                  color: const Color(0xFF596274),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                'ROR',
                style: GoogleFonts.poppins(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                  height: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: 7.h),
          Text(
            'Here, you can review your Response Rate regarding the actions\n'
            'taken on the requests.',
            style: GoogleFonts.poppins(
              fontSize: 10.4.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF676767),
              height: 1.25,
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: SizedBox(
                  height: 220.h,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _RorChartGuidesPainter(),
                        ),
                      ),
                      Positioned.fill(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _RorNeedle(
                              label: 'HR',
                              value: chartValues[0],
                              maxValue: maxValue,
                              highlight: highlightedIndex == 0,
                              isPercentage: hasApiRor,
                            ),
                            _RorNeedle(
                              label: 'RFQ',
                              value: chartValues[1],
                              maxValue: maxValue,
                              highlight: highlightedIndex == 1,
                              isPercentage: hasApiRor,
                            ),
                            _RorNeedle(
                              label: 'Petty cash',
                              value: chartValues[2],
                              maxValue: maxValue,
                              highlight: highlightedIndex == 2,
                              isPercentage: hasApiRor,
                            ),
                            _RorNeedle(
                              label: 'Invoice',
                              value: chartValues[3],
                              maxValue: maxValue,
                              highlight: highlightedIndex == 3,
                              isPercentage: hasApiRor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              SizedBox(
                width: 88.w,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '+$ror%',
                      style: GoogleFonts.poppins(
                        fontSize: 42.sp / 2,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111111),
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'The percentage of\nROR in the past\nweek.',
                      style: GoogleFonts.poppins(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF616161),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _calculateRorPercentage() {
    final total = hrCount + rfqCount + pettyCashCount + invoiceCount;
    if (total <= 0) return 0;
    final weightedDone =
        (hrCount + rfqCount + invoiceCount) + (pettyCashCount * 0.7).round();
    final ratio = (weightedDone / total) * 100;
    return ratio.clamp(0, 100).round();
  }
}

class _RorNeedle extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final bool highlight;
  final bool isPercentage;

  const _RorNeedle({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.highlight,
    this.isPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue <= 0 ? 0.0 : value / maxValue;
    final lineHeight = (28.h + (ratio * 108.h)).clamp(28.h, 136.h);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _ValueBubble(value: value, isPercentage: isPercentage),
        SizedBox(height: 5.h),
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            if (highlight)
              Container(
                width: 38.w,
                height: lineHeight + 18.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE2E9).withOpacity(0.58),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20.r),
                    bottomRight: Radius.circular(20.r),
                  ),
                ),
              )
            else
              Container(
                width: 1.25,
                height: lineHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8D8D8),
                  borderRadius: BorderRadius.circular(28.r),
                ),
              ),
            Container(
              width: 1.2,
              height: lineHeight,
              color: const Color(0xFFCAD1DA),
            ),
            Positioned(
              top: lineHeight * 0.42,
              child: Container(
                width: 6.5.w,
                height: 6.5.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF77A8D8),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            if (highlight)
              Positioned(
                bottom: 0,
                child: Container(
                  width: 38.w,
                  height: 24.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7EBF1).withOpacity(0.9),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20.r),
                      bottomRight: Radius.circular(20.r),
                    ),
                  ),
                ),
              )
            else
              Positioned(
                bottom: 0,
                child: Container(
                  width: 6.5.w,
                  height: 6.5.w,
                  decoration: const BoxDecoration(
                    color: Color(0xFF79A8D8),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 10.h),
        SizedBox(
          width: 58.w,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF171717),
            ),
            maxLines: null,
            overflow: TextOverflow.visible,
          ),
        ),
      ],
    );
  }
}

class _ValueBubble extends StatelessWidget {
  final int value;

  final bool isPercentage;

  const _ValueBubble({required this.value, this.isPercentage = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: 24.w),
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2749),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        isPercentage ? '$value%' : value.toString(),
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 8.sp,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _RorChartGuidesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final left = 0.0;
    final right = size.width - 2;

    final topY = size.height * 0.18;
    final midY = size.height * 0.59;
    final bottomY = size.height * 0.77;

    void drawDashedLine({
      required double y,
      required Color color,
      required double dash,
      required double gap,
      required double width,
    }) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke;

      double x = left;
      while (x < right) {
        final x2 = (x + dash).clamp(left, right);
        canvas.drawLine(Offset(x, y), Offset(x2, y), paint);
        x += dash + gap;
      }
    }

    drawDashedLine(
      y: topY,
      color: const Color(0xFF6FC6E2),
      dash: 4,
      gap: 2.8,
      width: 1,
    );
    drawDashedLine(
      y: midY,
      color: const Color(0xFF464646),
      dash: 3,
      gap: 2.2,
      width: 1,
    );
    drawDashedLine(
      y: bottomY,
      color: const Color(0xFFD35A6A),
      dash: 3,
      gap: 2.2,
      width: 1,
    );

    final topDot = Paint()..color = const Color(0xFF36BAE2);
    final midDot = Paint()..color = const Color(0xFF545454);
    final bottomDot = Paint()..color = const Color(0xFFC2262E);
    canvas.drawCircle(Offset(right, topY), 2.6, topDot);
    canvas.drawCircle(Offset(right, midY), 2.6, midDot);
    canvas.drawCircle(Offset(right, bottomY), 2.6, bottomDot);

    final plusPainter = TextPainter(
      text: const TextSpan(
        text: '+',
        style: TextStyle(
          color: Color(0xFF36BAE2),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    plusPainter.paint(canvas, Offset(2, midY - 12));

    final minusPainter = TextPainter(
      text: const TextSpan(
        text: '-',
        style: TextStyle(
          color: Color(0xFFC2262E),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    minusPainter.paint(canvas, Offset(2, bottomY - 12));
  }

  @override
  bool shouldRepaint(covariant _RorChartGuidesPainter oldDelegate) => false;
}

class _DelayedRequestCard extends StatefulWidget {
  final int value;
  final VoidCallback? onTap;

  const _DelayedRequestCard({required this.value, this.onTap});

  @override
  State<_DelayedRequestCard> createState() => _DelayedRequestCardState();
}

class _DelayedRequestCardState extends State<_DelayedRequestCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulse = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    _syncPulseState();
  }

  @override
  void didUpdateWidget(covariant _DelayedRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _syncPulseState();
    }
  }

  void _syncPulseState() {
    if (widget.value > 0) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasDelayedRequests = widget.value > 0;
    final borderRadius = BorderRadius.circular(18.r);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final glowFactor =
            hasDelayedRequests ? (0.35 + (_pulse.value * 0.65)) : 0.0;
        final borderGlowColor =
            const Color(0xFFD44B4B).withOpacity(0.24 + (0.26 * glowFactor));

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: borderRadius,
            child: Ink(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFDFDFD),
                borderRadius: borderRadius,
                border: Border.all(color: const Color(0xFFD44B4B), width: 1.2),
              ),
              child: CustomPaint(
                foregroundPainter: hasDelayedRequests
                    ? _RRectGlowPainter(
                        strokeWidth: 2.2,
                        radius: 18.r,
                        color: borderGlowColor,
                        blurSigma: 6.2 + (4.0 * glowFactor),
                      )
                    : null,
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 22.w, vertical: 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            'Delayed Request',
                            style: GoogleFonts.poppins(
                              fontSize: 21.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A1A),
                              height: 1,
                            ),
                          ),
                          if (widget.onTap != null) ...[
                            SizedBox(width: 6.w),
                            Icon(
                              Icons.chevron_right,
                              color: const Color(0xFF1A1A1A),
                              size: 23.sp,
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 14.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            width: 7.w,
                            height: 30.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC81616),
                              borderRadius: BorderRadius.circular(7.r),
                              boxShadow: hasDelayedRequests
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFC81616)
                                            .withOpacity(
                                                0.20 + (0.30 * glowFactor)),
                                        blurRadius: 4 + (8 * glowFactor),
                                        spreadRadius: 0.1 + (0.6 * glowFactor),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            widget.value.toString(),
                            style: GoogleFonts.poppins(
                              fontSize: 30.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RRectGlowPainter extends CustomPainter {
  final double strokeWidth;
  final double radius;
  final Color color;
  final double blurSigma;

  const _RRectGlowPainter({
    required this.strokeWidth,
    required this.radius,
    required this.color,
    required this.blurSigma,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );

    final softHalo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 1.1
      ..color = color.withOpacity((color.opacity * 0.82).clamp(0.0, 1.0))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);

    final coreGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma * 0.58);

    canvas.drawRRect(rrect, softHalo);
    canvas.drawRRect(rrect, coreGlow);
  }

  @override
  bool shouldRepaint(covariant _RRectGlowPainter oldDelegate) {
    return oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius ||
        oldDelegate.color != color ||
        oldDelegate.blurSigma != blurSigma;
  }
}
