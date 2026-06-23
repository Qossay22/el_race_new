import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_bloc.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_event.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_state.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_dialog.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ProjectListScreen extends StatefulWidget {
  final ProjectListBloc bloc;
  final int? agreementId;
  final int? partnerId;
  final int? projectManagerId;
  final int? cityId;
  final String? partnerName;
  final String? partnerPhoto;

  const ProjectListScreen({
    super.key,
    required this.bloc,
    this.agreementId,
    this.partnerId,
    this.projectManagerId,
    this.cityId,
    this.partnerName,
    this.partnerPhoto,
  });

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  final _scrollController = ScrollController();
  late ProjectListBloc bloc;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    bloc = widget.bloc;

    // Load projects based on selected drill-down filter.
    if (widget.agreementId != null) {
      bloc.add(LoadProjectsByFiltersEvent(
        agreementId: widget.agreementId,
        partnerId: widget.partnerId,
        projectManagerId: widget.projectManagerId,
        cityId: widget.cityId,
      ));
    } else if (widget.projectManagerId != null) {
      bloc.add(LoadProjectsByFiltersEvent(
        projectManagerId: widget.projectManagerId,
      ));
    } else if (widget.cityId != null) {
      bloc.add(LoadProjectsByFiltersEvent(
        cityId: widget.cityId,
      ));
    } else if (widget.partnerId != null) {
      bloc.add(LoadProjectsByPartnerEvent(partnerId: widget.partnerId!));
    } else {
      bloc.add(LoadProjectsEvent());
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      bloc.add(LoadMoreProjectsEvent());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _digitsInKoulen(
    String text, {
    required TextStyle baseStyle,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    final matches = RegExp(r'[0-9]+').allMatches(text);
    if (matches.isEmpty) {
      return Text(
        text,
        textAlign: textAlign,
        style: baseStyle,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final numberStyle = GoogleFonts.poppins(
      fontSize: baseStyle.fontSize,
      fontWeight: baseStyle.fontWeight,
      color: baseStyle.color,
      letterSpacing: baseStyle.letterSpacing,
      height: baseStyle.height,
    );

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(m.start, m.end),
          style: numberStyle,
        ),
      );
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 🔹 Partner Header Section (Scrollable)
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Builder(
                        builder: (context) {
                          // Fix malformed photo URL from API (erp.elrace.compublic -> erp.elrace.com/public)
                          String? photoUrl = widget.partnerPhoto;
                          if (photoUrl != null &&
                              photoUrl.contains('erp.elrace.compublic')) {
                            photoUrl = photoUrl.replaceAll(
                                'erp.elrace.compublic',
                                'erp.elrace.com/public');
                          }

                          print('🖼️ Partner Photo URL: $photoUrl');
                          print('📝 Partner Name: ${widget.partnerName}');

                          if (photoUrl != null && photoUrl.isNotEmpty) {
                            return ClipOval(
                              child: Image.network(
                                photoUrl,
                                height: 50.w,
                                width: 50.w,
                                fit: BoxFit.contain,
                                headers: {
                                  'Accept': 'image/*',
                                  'Authorization':
                                      'Bearer ${SharedPref.getLoginData().result?.token ?? ''}',
                                },
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) {
                                    print(
                                        '✅ Partner photo loaded successfully');
                                    return child;
                                  }
                                  print('⏳ Loading partner photo...');
                                  return SizedBox(
                                    width: 24.w,
                                    height: 24.w,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  print(
                                      '❌ Error loading partner photo: $error');
                                  print('❌ Stack trace: $stackTrace');
                                  return Icon(
                                    Icons.business,
                                    size: 24.w,
                                    color: appFontColor,
                                  );
                                },
                              ),
                            );
                          } else {
                            print('⚠️ No partner photo provided');
                            return Icon(
                              Icons.business,
                              size: 24.w,
                              color: appFontColor,
                            );
                          }
                        },
                      ),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          widget.partnerName != null
                              ? widget.partnerName!.toUpperCase()
                              : 'ABU DHABI POLICE',
                          style: GoogleFonts.poppins(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w500,
                            color: appFontColor,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.visible,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),
              ],
            ),
          ),

          // 🔹 Projects List
          BlocBuilder<ProjectListBloc, ProjectListState>(
            builder: (ctx, state) {
              if (state is ProjectListLoading && bloc.visibleProjects.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              } else if (state is! ProjectListLoading &&
                  bloc.visibleProjects.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text('No data available')),
                );
              } else if (state is ProjectListLoaded ||
                  bloc.visibleProjects.isNotEmpty) {
                final list = bloc.visibleProjects;
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index < list.length) {
                        final item = list[index];
                        return _buildProjectCard(item);
                      } else {
                        return const SizedBox();
                      }
                    },
                    childCount: list.length,
                  ),
                );
              } else if (state is ProjectListError) {
                return SliverFillRemaining(
                  child: Center(child: Text(state.message)),
                );
              } else {
                return const SliverToBoxAdapter(child: SizedBox());
              }
            },
          ),
          // Bottom padding
          SliverPadding(padding: EdgeInsets.only(bottom: 100.h)),
        ],
      ),
    );
  }

  Widget _buildProjectCard(ProjectEntity project) {
    final woNo = project.woRefNo.trim();
    final woName = project.name.trim();
    final formattedAmount = _formatAmount(project.woAmount);
    final formattedDate = _formatDate(project.date);

    final differenceDays = project.differenceDays ?? 0;
    final statusCount = _formatDifferenceDays(differenceDays);

    return GestureDetector(
      onTap: () {
        ProjectDocumentsDialog.show(
          context,
          projectId: project.projectId,
          bloc: bloc,
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: const Color(0xFF1B1F26),
            width: 1.3,
          ),
          gradient: const LinearGradient(
            colors: [Color(0xFFD6D6D6), Color(0xFFADB2BD)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: _digitsInKoulen(
                statusCount,
                baseStyle: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                  color: _getStatusColor(statusCount),
                ),
                maxLines: null,
                overflow: TextOverflow.visible,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 2.h),
                _digitsInKoulen(
                  woNo,
                  textAlign: TextAlign.center,
                  baseStyle: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B6B6B),
                  ),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                ),
                SizedBox(height: 4.h),
                _digitsInKoulen(
                  woName,
                  textAlign: TextAlign.center,
                  baseStyle: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1B1F26),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                ),
                SizedBox(height: 12.h),
                Container(
                  height: 38.h,
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14.r),
                    color: const Color(0xFFE6E6E6),
                    border: Border.all(
                      color: Colors.white,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: _digitsInKoulen(
                                formattedAmount,
                                baseStyle: GoogleFonts.poppins(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1B1F26),
                                ),
                                maxLines: null,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Image.asset(
                              'assets/png/icons/UAE_Dirham_Symbol 1.png',
                              width: 18.w,
                              height: 18.w,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox(),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 28.w,
                        height: 28.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF1B1F26), width: 1),
                          color: Colors.white,
                        ),
                        alignment: Alignment.center,
                        child: project.projectManagerPhoto != null &&
                                project.projectManagerPhoto!.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  project.projectManagerPhoto!,
                                  width: 28.w,
                                  height: 28.w,
                                  fit: BoxFit.cover,
                                  headers: {
                                    'Accept': 'image/*',
                                    'Authorization':
                                        'Bearer ${SharedPref.getLoginData().result?.token ?? ''}',
                                  },
                                  errorBuilder: (_, __, ___) => Text(
                                    _getInitials(project.agreementId),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF1B1F26),
                                    ),
                                  ),
                                ),
                              )
                            : Text(
                                _getInitials(project.agreementId),
                                style: GoogleFonts.poppins(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1B1F26),
                                ),
                              ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _digitsInKoulen(
                            formattedDate,
                            baseStyle: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1B1F26),
                            ),
                            maxLines: null,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,##0', 'en');
    return formatter.format(amount);
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
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

  String _getInitials(String text) {
    if (text.isEmpty) return 'P';
    final words = text.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return text.characters.take(2).toString().toUpperCase();
  }

  Color _getStatusColor(String status) {
    // Green for positive, Red for negative
    if (status.startsWith('+')) {
      return const Color(0xFF009859); // Green for positive
    }
    return const Color(0xFFBA1719); // Red for negative
  }

  String _formatDifferenceDays(int days) {
    if (days > 0) {
      return '+$days';
    } else if (days < 0) {
      return '$days';
    }
    return '0';
  }
}
