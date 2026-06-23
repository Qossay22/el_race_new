import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_actions_pagination_mixin.dart';
import 'package:el_race/ui/presentation/my_documents/screens/attachment_viewer_screen.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:share_plus/share_plus.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with MyActionsPaginationMixin<ReportsScreen> {
  static const String _erpBaseUrl = 'https://erp.elrace.com';

  @override
  MyActionsType get actionsType => MyActionsType.reports;

  @override
  void initState() {
    super.initState();
    initActionsPagination();
  }

  @override
  void dispose() {
    disposeActionsPagination();
    super.dispose();
  }

  String _formatDisplayDate(String? rawDate) {
    final input = (rawDate ?? '').trim();
    if (input.isEmpty) return '';

    final parsed = DateTime.tryParse(input);
    if (parsed == null) return input;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _formatLastUpdateLabel(String? rawDate) {
    final text = _formatDisplayDate(rawDate);
    return text.isEmpty ? 'Last update: -' : 'Last update: $text';
  }

  Future<void> _openReportLink(
    BuildContext context,
    _ReportRequestItem item,
  ) async {
    final rawLink = item.reportLink.trim();

    if (rawLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file URL available for this report')),
      );
      return;
    }

    final fullUrl = _normalizeReportUrl(rawLink);
    final uri = Uri.tryParse(fullUrl);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid file URL')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttachmentViewerScreen(
          publicUrl: fullUrl,
          title:
              item.reportName.trim().isEmpty ? 'Attachment' : item.reportName,
          // Most my-reports attachments are PDFs even when URL has no .pdf suffix.
          attachmentType: 'application/pdf',
        ),
      ),
    );
  }

  Future<void> _shareReportLink(
    BuildContext context,
    _ReportRequestItem item,
  ) async {
    final rawLink = item.reportLink.trim();
    if (rawLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file URL available to share')),
      );
      return;
    }

    final fullUrl = _normalizeReportUrl(rawLink);
    final subject = item.reportName.trim().isEmpty ? 'Report' : item.reportName;
    await SharePlus.instance.share(
      ShareParams(
        text: '$subject\n$fullUrl',
        subject: subject,
      ),
    );
  }

  String _normalizeReportUrl(String rawLink) {
    var link = rawLink.trim();
    if (link.isEmpty) return '';

    if (!link.startsWith('http://') && !link.startsWith('https://')) {
      if (!link.startsWith('/')) {
        link = '/$link';
      }
      link = '$_erpBaseUrl$link';
    }

    final uri = Uri.tryParse(link);
    if (uri == null) return link;

    // Odoo "/web/content" can return a preview response.
    // Force downloadable binary response so PDF renders correctly in-app.
    if (uri.path.contains('/web/content')) {
      final query = Map<String, String>.from(uri.queryParameters);
      query['download'] = 'true';
      return uri.replace(queryParameters: query).toString();
    }

    return uri.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: const HeaderWidget(),
      body: SafeArea(
        top: false,
        child: Builder(
          builder: (context) {
            if (actionsInitialLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (actionsError != null && actionItems.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off,
                          size: 60.w, color: const Color(0xFFB5B7C1)),
                      SizedBox(height: 16.h),
                      Text(
                        'Service not available',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5A5A5A),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'This feature is currently unavailable.\nPlease try again later.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          color: const Color(0xFF9AA0A6),
                        ),
                      ),
                      SizedBox(height: 14.h),
                      TextButton(
                        onPressed: retryInitialActionsLoad,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final items = List<MyActionItem>.from(actionItems);

            // Map API items to display items
            final reportItems = items.map((item) {
              return _ReportRequestItem(
                reportId: item.id,
                reportName: item.name.trim().isNotEmpty
                    ? item.name
                    : 'Report #${item.id}',
                displayDate: _formatDisplayDate(item.date),
                lastUpdateLabel: _formatLastUpdateLabel(item.date),
                reportLink: item.reportLink?.trim().isNotEmpty == true
                    ? item.reportLink!
                    : '',
                reportType: item.reportType.trim().isNotEmpty
                    ? item.reportType.trim()
                    : 'Report',
                previewImages: item.previewImages,
                totalImages: item.totalImages,
              );
            }).toList();

            return RefreshIndicator(
              onRefresh: refreshActions,
              child: ListView(
                controller: actionsScrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(top: 8.h, bottom: 80.h),
                children: [
                  // Header
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/png/my-reports-frame.png',
                            width: 26.w,
                            height: 26.w,
                            fit: BoxFit.contain,
                            color: const Color(0xFFD21B2E),
                            colorBlendMode: BlendMode.srcIn,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'MY REPORTS',
                            style: GoogleFonts.poppins(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF101C36),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (reportItems.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 24.h),
                      child: Center(
                        child: Text(
                          'No reports found.',
                          style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF5A5A5A),
                          ),
                        ),
                      ),
                    )
                  else
                    ...reportItems.map(
                      (item) => Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 7.h),
                        child: _ReportRequestCard(
                          item: item,
                          onTap: () => _openReportLink(context, item),
                          onShare: () => _shareReportLink(context, item),
                          onRename: () => _showComingSoon(context, 'Rename'),
                          onDelete: () => _showComingSoon(context, 'Delete'),
                        ),
                      ),
                    ),
                  buildActionsPaginationFooter(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action is not available yet')),
    );
  }
}

/* ───────────────────────────── Card ───────────────────────────── */

class _ReportRequestCard extends StatelessWidget {
  final _ReportRequestItem item;
  final VoidCallback? onTap;
  final VoidCallback? onShare;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const _ReportRequestCard({
    required this.item,
    this.onTap,
    this.onShare,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const cardStroke = Color(0xFF3D4463);
    const actionColor = Color(0xFF2B3252);
    const figmaChartBgUrl =
        'https://www.figma.com/api/mcp/asset/2cfebaa4-32c9-45b5-ba1e-2916c627de0e';
    const figmaChartLineUrl =
        'https://www.figma.com/api/mcp/asset/20b943a6-9776-44dc-bb80-85312a603a38';

    final preview = item.previewImages.take(5).toList(growable: false);
    final actualCount =
        (item.totalImages > item.previewImages.length)
            ? item.totalImages
            : item.previewImages.length;
    final extra = actualCount > 5 ? (actualCount - 5) : 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22.r),
      child: Container(
        height: 123.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(color: cardStroke, width: 1),
        ),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned(
                right: -14.w,
                top: -57.h,
                child: IgnorePointer(
                  child: SizedBox(
                    width: 146.w,
                    height: 146.w,
                    child: Image.network(
                      figmaChartBgUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -6.w,
                top: -2.h,
                child: IgnorePointer(
                  child: SizedBox(
                    width: 112.w,
                    height: 68.h,
                    child: Image.network(
                      figmaChartLineUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 2.h,
                left: 0,
                right: 90.w,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.reportName.trim().isEmpty ? 'Report Name' : item.reportName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14.3.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF27314F),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      item.lastUpdateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12.7.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF27314F),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                bottom: 2.h,
                right: 90.w,
                child: Row(
                  children: [
                    ...List.generate(preview.length, (index) {
                      final imageUrl = preview[index];
                      return Padding(
                        padding: EdgeInsets.only(right: 4.w),
                        child: _ReportPreviewAvatar(url: imageUrl),
                      );
                    }),
                    if (extra > 0)
                      Padding(
                        padding: EdgeInsets.only(left: 2.w),
                        child: Text(
                          '+$extra',
                          style: GoogleFonts.poppins(
                            fontSize: 10.146.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF27314F),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 2.h,
                right: 0,
                child: Row(
                  children: [
                    Icon(Icons.drag_handle, size: 22.sp, color: actionColor),
                    SizedBox(width: 6.w),
                    PopupMenuButton<String>(
                      tooltip: 'Report options',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 130),
                      icon: Icon(Icons.more_vert, size: 20.sp, color: actionColor),
                      onSelected: (value) {
                        if (value == 'rename') {
                          onRename?.call();
                        } else if (value == 'delete') {
                          onDelete?.call();
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem<String>(
                          value: 'rename',
                          child: Text('Rename'),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: InkWell(
                  onTap: onShare,
                  borderRadius: BorderRadius.circular(14.r),
                  child: Container(
                    width: 26.3.w,
                    height: 26.3.w,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: actionColor,
                    ),
                    child: Icon(
                      Icons.share_outlined,
                      size: 12.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ──────────────────────── Data model ──────────────────────── */

class _ReportRequestItem {
  final int reportId;
  final String reportName;
  final String displayDate;
  final String lastUpdateLabel;
  final String reportLink;
  final String reportType;
  final List<String> previewImages;
  final int totalImages;

  const _ReportRequestItem({
    required this.reportId,
    required this.reportName,
    required this.displayDate,
    required this.lastUpdateLabel,
    required this.reportLink,
    required this.reportType,
    required this.previewImages,
    required this.totalImages,
  });
}

class _ReportPreviewAvatar extends StatelessWidget {
  final String url;

  const _ReportPreviewAvatar({required this.url});

  @override
  Widget build(BuildContext context) {
    final parsed = Uri.tryParse(url.trim());
    final effectiveUrl = (parsed != null && parsed.hasScheme)
        ? url.trim()
        : 'https://erp.elrace.com${url.startsWith('/') ? '' : '/'}${url.trim()}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(52.r),
      child: Container(
        width: 42.w,
        height: 42.w,
        color: const Color(0xFFD9DCE2),
        child: Image.network(
          effectiveUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.image_outlined,
            size: 16.sp,
            color: const Color(0xFF27314F),
          ),
        ),
      ),
    );
  }
}
