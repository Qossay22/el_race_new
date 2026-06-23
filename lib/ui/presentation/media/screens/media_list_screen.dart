import 'dart:async';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bloc/media_bloc.dart';
import '../data/media_model.dart';
import '../data/content_model.dart';
import '../widgets/media_item_widget.dart';
import '../widgets/content_item_widget.dart';
import 'yoyo_video_player_screen.dart';
import '../../lpo/screens/lpo_pdf_viewer_screen.dart';

class MediaListScreen extends StatefulWidget {
  const MediaListScreen({super.key});

  @override
  State<MediaListScreen> createState() => _MediaListScreenState();
}

enum _MediaFilterTab {
  videos,
  photos,
  view360,
}

class _MediaListScreenState extends State<MediaListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  final bool _showSearch = false;
  _MediaFilterTab _activeTab = _MediaFilterTab.videos;
  final GlobalKey _videosTabKey = GlobalKey();
  final GlobalKey _photosTabKey = GlobalKey();
  final GlobalKey _view360TabKey = GlobalKey();

  Map<String, String>? get _imageHeaders {
    final token = SharedPref.getLoginData().result?.token;
    if (token == null || token.isEmpty) return null;
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'image/*,*/*',
    };
  }

  String _safeImageUrl(String rawUrl) {
    final input = rawUrl.trim();
    if (input.isEmpty) return input;
    return Uri.encodeFull(input);
  }

  void _logPhotoLoadError({
    required String source,
    required String rawUrl,
    required Object error,
  }) {}

  Widget _buildPhotoLoadingPlaceholder(
    BuildContext context,
    ImageChunkEvent? loadingProgress,
  ) {
    final progress = loadingProgress?.expectedTotalBytes != null
        ? loadingProgress!.cumulativeBytesLoaded /
            loadingProgress.expectedTotalBytes!
        : null;

    return Container(
      color: const Color(0xFFE9E9E9),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24.w,
            height: 24.w,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: const Color(0xFF6E6E6E),
              value: progress,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Loading...',
            style: GoogleFonts.poppins(
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6E6E6E),
            ),
          ),
        ],
      ),
    );
  }

  void _setActiveTab(_MediaFilterTab tab) {
    if (_activeTab == tab) return;
    setState(() => _activeTab = tab);

    // Fetch appropriate data based on tab
    if (tab == _MediaFilterTab.videos) {
      context.read<MediaBloc>().add(const FetchMediaList());
    } else {
      context.read<MediaBloc>().add(const FetchContents());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? ctx;
      switch (tab) {
        case _MediaFilterTab.videos:
          ctx = _videosTabKey.currentContext;
          break;
        case _MediaFilterTab.photos:
          ctx = _photosTabKey.currentContext;
          break;
        case _MediaFilterTab.view360:
          ctx = _view360TabKey.currentContext;
          break;
      }
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    context.read<MediaBloc>().add(const FetchMediaList());
    _searchController.addListener(() {
      final text = _searchController.text.trim();
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        context.read<MediaBloc>().add(SearchMedia(text));
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: BlocConsumer<MediaBloc, MediaState>(
        listener: (context, state) {
          if (state is MediaError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.message,
                  style: GoogleFonts.poppins(),
                ),
              ),
            );
          }
          if (state is MediaActionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.message,
                  style: GoogleFonts.poppins(),
                ),
              ),
            );
          }
          if (state is MediaActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Media action completed successfully',
                  style: GoogleFonts.poppins(),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 6.h, bottom: 8.h),
                  child: _buildHeader(),
                ),
              ),
              if (state is MediaLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 40.h),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        if (state is MediaLoaded &&
                            _activeTab == _MediaFilterTab.videos)
                          (() {
                            final q =
                                _searchController.text.trim().toLowerCase();

                            final list = state.mediaList.where((m) {
                              if (!m.isVideo) return false;
                              if (q.isEmpty) return true;

                              final name = m.name.toLowerCase();
                              final typeLabel = m.isImage ? 'image' : 'video';
                              final id = m.id.toLowerCase();
                              final url = (m.url).toLowerCase();
                              final s3 = (m.xWebUrl ?? '').toLowerCase();
                              final ext = m.fileExtension.toLowerCase();
                              return name.contains(q) ||
                                  typeLabel.contains(q) ||
                                  id.contains(q) ||
                                  url.contains(q) ||
                                  s3.contains(q) ||
                                  ext.contains(q);
                            }).toList();

                            return list.isEmpty
                                ? _buildEmptyState()
                                : ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: list.length,
                                    itemBuilder: (context, index) {
                                      final media = list[index];
                                      return MediaItemWidget(
                                        media: media,
                                        onTap: () {
                                          if (media.isVideo) {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    YoYoVideoPlayerScreen(
                                                        media: media),
                                              ),
                                            );
                                          } else {
                                            _showMediaDetails(context, media);
                                          }
                                        },
                                        onLongPress: () {
                                          _showDeleteConfirmation(
                                              context, media.id);
                                        },
                                      );
                                    },
                                    separatorBuilder:
                                        (BuildContext context, int index) =>
                                            SizedBox(height: 6.w),
                                  );
                          })()
                        else if (state is ContentsLoaded)
                          _buildContentsList(state.contents)
                        else if (state is MediaError)
                          _buildErrorState(state.message),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/png/camera.png', width: 24.w, height: 24.w),
            const SizedBox(width: 8),
            if (!_showSearch)
              Text(
                translate('home.media'),
                style: GoogleFonts.poppins(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w400,
                  color: appFontColor,
                  letterSpacing: 1.5,
                ),
                overflow: TextOverflow.visible,
              )
            else
              Expanded(child: _buildInlineSearchField()),
          ],
        ),
        SizedBox(height: 10.h),
        _buildFilterTabs(),
        SizedBox(height: 14.h),
      ],
    );
  }

  Widget _buildFilterTabs() {
    const unfocusedStart = Color(0xFFD6D6D6);
    const unfocusedEnd = Color(0xFFADB2BD);
    // Provided as #1B1F26B8 (RRGGBBAA) -> Flutter uses AARRGGBB.
    const focusedStart = Color(0xB81B1F26);
    const focusedEnd = Color(0xFF717171);

    final screenWidth = MediaQuery.sizeOf(context).width;
    // Make tabs slightly smaller so a portion of the next tab is visible.
    final contentWidth =
        screenWidth - 24.w; // header has 12.w horizontal padding
    final tabWidth = contentWidth * 0.40;
    final effectiveTabWidth = tabWidth < 120.w ? 120.w : tabWidth;

    Widget buildTab({
      required _MediaFilterTab tab,
      required Widget child,
      required Key tabKey,
    }) {
      final bool isActive = _activeTab == tab;

      return InkWell(
        borderRadius: BorderRadius.circular(22.r),
        onTap: () {
          _setActiveTab(tab);
        },
        child: Container(
          key: tabKey,
          width: effectiveTabWidth,
          height: 44.h,
          padding: EdgeInsets.symmetric(horizontal: 18.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22.r),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isActive
                  ? const [focusedStart, focusedEnd]
                  : const [unfocusedStart, unfocusedEnd],
            ),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      );
    }

    Text label(String text) {
      return Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 16.sp,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
        maxLines: null,
        overflow: TextOverflow.visible,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          buildTab(
              tab: _MediaFilterTab.videos,
              tabKey: _videosTabKey,
              child: label('VIDEOS')),
          SizedBox(width: 10.w),
          buildTab(
              tab: _MediaFilterTab.photos,
              tabKey: _photosTabKey,
              child: label('PHOTOS')),
          SizedBox(width: 10.w),
          buildTab(
              tab: _MediaFilterTab.view360,
              tabKey: _view360TabKey,
              child: Image.asset(
                'assets/newapp/newicon/360 degrees.png',
                width: 50.w,
                height: 50.w,
                fit: BoxFit.contain,
              )),
        ],
      ),
    );
  }

  // The search field is kept for future use but may be hidden in some screens.
  // ignore: unused_element
  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/png/bg_atten.png'),
          fit: BoxFit.none,
        ),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(29.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.2 * 255).toInt()),
            blurRadius: 4,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Find media',
          hintStyle: GoogleFonts.poppins(
            fontSize: 12.sp,
            color: appFontColor,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.menu, size: 18, color: appFontColor),
          ),
          suffixIcon: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.search, size: 18, color: appFontColor),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        ),
      ),
    );
  }

  Widget _buildInlineSearchField() {
    return Container(
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/png/bg_atten.png'),
          fit: BoxFit.none,
        ),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(29.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.2 * 255).toInt()),
            blurRadius: 4,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Find media',
          hintStyle: GoogleFonts.poppins(
            fontSize: 12.sp,
            color: appFontColor,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.search, size: 18, color: appFontColor),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildFilterButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildFilterButton('All', () {
          context.read<MediaBloc>().add(const FetchMediaList());
        }),
        _buildFilterButton('Images', () {
          context
              .read<MediaBloc>()
              .add(const FetchMediaByType(MediaType.image));
        }),
        _buildFilterButton('Videos', () {
          context
              .read<MediaBloc>()
              .add(const FetchMediaByType(MediaType.video));
        }),
      ],
    );
  }

  Widget _buildFilterButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: appFontColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 14.sp,
          fontWeight: FontWeight.w400,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildContentsList(ContentsResponse contents) {
    final q = _searchController.text.trim().toLowerCase();

    if (_activeTab == _MediaFilterTab.photos) {
      var photos = List<ContentModel>.from(contents.photos);

      if (q.isNotEmpty) {
        photos = photos.where((item) {
          final name = item.fileName.toLowerCase();
          final project = item.projectName.toLowerCase();
          return name.contains(q) || project.contains(q);
        }).toList();
      }

      if (photos.isEmpty) {
        return _buildEmptyState();
      }

      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          return _buildSinglePhotoCard(photos[index]);
        },
        separatorBuilder: (BuildContext context, int index) =>
            SizedBox(height: 12.h),
      );
    }

    List<ContentModel> list;
    if (_activeTab == _MediaFilterTab.view360) {
      list = contents.view360;
    } else {
      list = [];
    }

    if (q.isNotEmpty) {
      list = list.where((c) {
        final name = c.fileName.toLowerCase();
        final project = c.projectName.toLowerCase();
        return name.contains(q) || project.contains(q);
      }).toList();
    }

    if (list.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final content = list[index];
        return ContentItemWidget(
          content: content,
          onTap: () => _handleContentTap(context, content),
        );
      },
      separatorBuilder: (BuildContext context, int index) =>
          SizedBox(height: 6.w),
    );
  }

  Widget _buildSinglePhotoCard(ContentModel content) {
    final uploadedDate = content.dateCreated == null
        ? null
        : DateFormat('dd/MM/yyyy').format(content.dateCreated!);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: const Color(0xB8484848), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                uploadedDate == null
                    ? 'Uploaded at --/--/----'
                    : 'Uploaded at $uploadedDate',
                style: GoogleFonts.poppins(
                  fontSize: 10.sp,
                  color: const Color(0xFF292929),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: 6.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(20.r),
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openPhotoOrPdf(context, content),
                    child: _isPdfContent(content)
                        ? Container(
                            color: const Color(0xFFF5F5F5),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: Colors.red.shade700,
                                  size: 48.sp,
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  content.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.sp,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Image.network(
                      _safeImageUrl(content.displayImageUrl),
                      headers: _imageHeaders,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return _buildPhotoLoadingPlaceholder(
                          context,
                          loadingProgress,
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        _logPhotoLoadError(
                          source: 'single-card',
                          rawUrl: content.displayImageUrl,
                          error: error,
                        );
                        return Container(
                          color: Colors.white.withOpacity(0.45),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.image_outlined,
                            color: appFontColor.withOpacity(0.6),
                            size: 28.sp,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content.displayName,
                        maxLines: null,
                        overflow: TextOverflow.visible,
                        style: GoogleFonts.poppins(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        content.projectName,
                        maxLines: null,
                        overflow: TextOverflow.visible,
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6.w),
                Padding(
                  padding: EdgeInsets.only(top: 2.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(12.r),
                        onTap: () => _openPhotoOrPdf(context, content),
                        child: Container(
                          height: 22.h,
                          padding: EdgeInsets.symmetric(horizontal: 14.w),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6E6E6E),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            'View',
                            style: GoogleFonts.poppins(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 5.w),
                      InkWell(
                        borderRadius: BorderRadius.circular(12.r),
                        onTap: () => _sharePhotoItem(content),
                        child: Container(
                          width: 28.w,
                          height: 24.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD5D5D5),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/newapp/newicon/media_share_icon.png',
                              width: 30.w,
                              height: 30.h,
                              fit: BoxFit.contain,
                            ),
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

  bool _isPdfContent(ContentModel content) => content.isPdf;

  /// Checks URL content-type via HEAD request, then opens PDF viewer or photo preview.
  Future<void> _openPhotoOrPdf(BuildContext context, ContentModel content) async {
    // First check static indicators (filename / known fileType)
    if (_isPdfContent(content)) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LpoPdfViewerScreen(
            pdfUrl: content.previewUrl,
            title: content.displayName,
          ),
        ),
      );
      return;
    }

    // For URLs without extension (e.g. /my/public/file/12345),
    // do a HEAD request to detect the actual content-type.
    final rawUrl = content.previewUrl.trim();
    final hasNoExtension = !rawUrl.contains('?') &&
        !rawUrl.split('/').last.contains('.');
    if (hasNoExtension && rawUrl.isNotEmpty) {
      try {
        final token = SharedPref.getLoginData().result?.token ?? '';
        final headers = token.isNotEmpty
            ? {'Authorization': 'Bearer $token'}
            : <String, String>{};
        final headResp = await http
            .head(Uri.parse(rawUrl), headers: headers)
            .timeout(const Duration(seconds: 6));
        final ct = (headResp.headers['content-type'] ?? '').toLowerCase();
        if (!context.mounted) return;
        if (ct.contains('pdf')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LpoPdfViewerScreen(
                pdfUrl: rawUrl,
                title: content.displayName,
              ),
            ),
          );
          return;
        }
      } catch (_) {
        // fall through to photo preview on error
      }
    }

    if (!context.mounted) return;
    _showPhotoPreview(context, [content], initialIndex: 0);
  }

  Future<void> _sharePhotoItem(ContentModel content) async {
    final text = '${content.fileName}\n${content.previewUrl}'.trim();
    await SharePlus.instance.share(ShareParams(text: text));
  }

  void _handleContentTap(BuildContext context, ContentModel content) async {
    if (content.is360View) {
      // Open 360 view in browser or webview
      final url = Uri.parse(content.previewUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } else {
      // Show photo in full screen or dialog
      _showPhotoPreview(context, [content], initialIndex: 0);
    }
  }

  void _showPhotoPreview(
    BuildContext context,
    List<ContentModel> photos, {
    int initialIndex = 0,
  }) {
    if (photos.isEmpty) return;

    final safeInitialIndex = initialIndex.clamp(0, photos.length - 1).toInt();
    final pageController = PageController(initialPage: safeInitialIndex);

    showDialog(
      context: context,
      builder: (dialogContext) {
        int currentIndex = safeInitialIndex;
        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                EdgeInsets.symmetric(horizontal: 10.w, vertical: 18.h),
            child: Stack(
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: PageView.builder(
                        controller: pageController,
                        itemCount: photos.length,
                        onPageChanged: (index) {
                          setDialogState(() => currentIndex = index);
                        },
                        itemBuilder: (context, index) {
                          final content = photos[index];
                          return Image.network(
                            _safeImageUrl(content.displayImageUrl),
                            headers: _imageHeaders,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.black54,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              _logPhotoLoadError(
                                source: 'preview',
                                rawUrl: content.displayImageUrl,
                                error: error,
                              );
                              return Container(
                                color: Colors.black54,
                                child: const Center(
                                  child: Icon(Icons.error,
                                      color: Colors.white, size: 48),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ),
                if (photos.length > 1)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        '${currentIndex + 1}/${photos.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          photos[currentIndex].displayName,
                          style: GoogleFonts.poppins(
                            fontSize: 16.sp,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (photos[currentIndex].projectName.isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Text(
                            photos[currentIndex].projectName,
                            style: GoogleFonts.poppins(
                              fontSize: 12.sp,
                              color: Colors.white70,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.all(50.w),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.perm_media_outlined,
              size: 64.sp,
              color: Colors.grey,
            ),
            SizedBox(height: 16.h),
            Text(
              'No media files yet',
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Your media collection will appear here',
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: Colors.grey,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: EdgeInsets.all(50.w),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.sp,
              color: Colors.red,
            ),
            SizedBox(height: 16.h),
            Text(
              'Error loading media',
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: Colors.grey,
                letterSpacing: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () {
                // Retry based on current tab
                if (_activeTab == _MediaFilterTab.videos) {
                  context.read<MediaBloc>().add(const FetchMediaList());
                } else {
                  context.read<MediaBloc>().add(const FetchContents());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: appFontColor,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaDetails(BuildContext context, MediaModel media) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          media.name,
          style: GoogleFonts.poppins(
            letterSpacing: 1.0,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type: ${media.isImage ? 'Image' : 'Video'}',
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: Colors.grey[600],
                letterSpacing: 1.0,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Created: ${media.dateCreated.day}/${media.dateCreated.month}/${media.dateCreated.year}',
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: Colors.grey[600],
                letterSpacing: 1.0,
              ),
            ),
            if (media.size != null) ...[
              SizedBox(height: 8.h),
              Text(
                'Size: ${media.size!.toStringAsFixed(1)} MB',
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                  letterSpacing: 1.0,
                ),
              ),
            ],
            if (media.isVideo && media.duration != null) ...[
              SizedBox(height: 8.h),
              Text(
                'Duration: ${media.duration} seconds',
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String mediaId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Delete Media',
          style: GoogleFonts.poppins(
            letterSpacing: 1.0,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this media file?',
          style: GoogleFonts.poppins(
            letterSpacing: 1.0,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                letterSpacing: 1.0,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<MediaBloc>().add(DeleteMedia(mediaId));
              Navigator.of(dialogContext).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
