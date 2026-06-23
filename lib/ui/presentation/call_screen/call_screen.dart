import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/utils/orientation_helper.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../utils/di.dart';
import '../../widgets/header_widget.dart';
import 'bloc/contact_bloc.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _contactBloc = sl.get<ContactBloc>();
  int? expandedIndex;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _headerKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    _contactBloc.add(GetEmployeeLisET());
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ContactBloc, ContactState>(
      listenWhen: (p, c) => c is ContactLoadingState,
      listener: (context, state) {
        if (state is ContactLoadingState) {
          if (state.isLoading == true) {
            showDialog(
                context: context,
                builder: (context) => Dialog(
                      child: SizedBox(
                        height: SizeConfig().getHeight(80),
                        width: SizeConfig().getHeight(80),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ));
          } else {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const HeaderWidget(),
        body: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: false,
              delegate: _ContactHeaderDelegate(
                minHeight: 40.h,
                maxHeight: 45.h,
                headerKey: _headerKey,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                child: Container(
                  height: 45.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {}); // Update UI for suffix icon
                      _contactBloc.add(SearchContactsEvent(value));
                    },
                    style: TextStyle(
                      color: const Color(0xFF1A1A53),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: translate('home.search_by_name_or_id'),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 12.h,
                        horizontal: 20.w,
                      ),
                      hintStyle: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade500,
                      ),
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(12.w),
                        child: Image.asset(
                          'assets/png/search_icon.png',
                          width: 18.w,
                          height: 18.w,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.grey.shade600,
                                size: 20.w,
                              ),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                });
                                _contactBloc.add(const SearchContactsEvent(''));
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            BlocBuilder<ContactBloc, ContactState>(
              bloc: _contactBloc,
              builder: (context, state) {
                if (state is EmployeeListLoaded) {
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        var emp = state.employees[index];
                        bool isExpanded = expandedIndex == index;

                        return Padding(
                          padding: EdgeInsets.only(bottom: 5.h),
                          child: ContactTile(
                            color: const [darkGrey, darkGrey],
                            textColor: white,
                            gradientAlignment: index.isOdd,
                            image: emp.profilePhotoUrl.toString(),
                            name: emp.name!,
                            job: emp.jobId.toString(),
                            emp: emp.empId ?? emp.id.toString(),
                            department: emp.department ?? '',
                            num: emp.mobilePhone.toString(),
                            isExpanded: isExpanded,
                            onTapExpand: () {
                              setState(() {
                                expandedIndex = isExpanded ? null : index;
                              });
                            },
                            onTapCall: () =>
                                _makePhoneCall('tel:${emp.mobilePhone}'),
                            onTapWhatsApp: () =>
                                _openWhatsApp(emp.mobilePhone.toString()),
                            onTapEmail: () => _sendEmail(emp.name!),
                          ),
                        );
                      },
                      childCount: state.employees.length,
                    ),
                  );
                }

                return const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                );
              },
            ),
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  final systemBottomInset = context.systemBottomInset;
                  // Ensure minimum 150.h padding for devices without system navigation
                  final totalPadding =
                      systemBottomInset > 0 ? systemBottomInset + 20.h : 150.h;
                  return SizedBox(height: totalPadding);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    String url = "https://wa.me/$phoneNumber";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch WhatsApp';
    }
  }

  Future<void> _sendEmail(String name) async {
    String url = "mailto:?subject=Hello $name";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch email';
    }
  }
}

class _ContactHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final GlobalKey? headerKey;

  _ContactHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    this.headerKey,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      key: headerKey,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      alignment: Alignment.center,
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            translate('home.contact'),
            style: GoogleFonts.poppins(
              fontSize: 25.sp,
              fontWeight: FontWeight.w400,
              color: appFontColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

Widget searchWidget(ContactBloc bloc) {
  return Container(
    height: 40,
    width: 250,
    decoration: BoxDecoration(
      border: Border.all(
        color: Colors.grey,
      ),
      // boxShadow: const [
      //   BoxShadow(color: darkGrey, offset: Offset(2, 4), blurRadius: 12)
      // ],
      borderRadius: BorderRadius.circular(25),
      // gradient: const LinearGradient(
      //     begin: Alignment.topCenter,
      //     end: Alignment.bottomCenter,
      //     colors: [Color(0xffE5E4E2), Color(0xffD3D3D3)])
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TextFormField(
        onChanged: (value) {
          bloc.add(SearchContactsEvent(value));
        },
        style: const TextStyle(
          color: Color(0xFF1A1A53),
          fontSize: 15,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
            border: InputBorder.none,
            // hintText: 'SEARCH CONTACT',
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            hintStyle: const TextStyle(
                fontSize: 12,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w400,
                color: Color(0xFF1A1A53)),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset(
                'assets/png/menu.png',
                width: 10,
                height: 10,
              ),
            ),
            suffixIcon: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(
                  "assets/png/search_icon.png",
                  width: 14,
                  height: 14,
                  color: Colors.grey,
                ))),
      ),
    ),
  );
}

class ContactTile extends StatefulWidget {
  final List<Color> color;
  final Color textColor;
  final bool gradientAlignment;
  final String image;
  final String name;
  final String job;
  final String emp;
  final String department;
  final String num;
  final bool isExpanded;
  final VoidCallback onTapExpand;
  final VoidCallback onTapCall;
  final VoidCallback onTapWhatsApp;
  final VoidCallback onTapEmail;
  final ScrollController? scrollController;
  final GlobalKey? headerKey;

  const ContactTile({
    super.key,
    required this.color,
    required this.textColor,
    required this.gradientAlignment,
    required this.image,
    required this.name,
    required this.job,
    required this.emp,
    required this.department,
    required this.num,
    required this.isExpanded,
    required this.onTapExpand,
    required this.onTapCall,
    required this.onTapWhatsApp,
    required this.onTapEmail,
    this.scrollController,
    this.headerKey,
  });
  @override
  State<ContactTile> createState() => _ContactTileState();
}

class _ContactTileState extends State<ContactTile> {
  double _scale = 1.0;

  void _updateScale() {
    final headerContext = widget.headerKey?.currentContext;
    final myContext = context;
    if (headerContext == null || myContext.findRenderObject() == null) return;

    try {
      final RenderBox headerBox = headerContext.findRenderObject() as RenderBox;
      final RenderBox myBox = myContext.findRenderObject() as RenderBox;
      final headerBottom =
          headerBox.localToGlobal(Offset.zero).dy + headerBox.size.height;
      final myTop = myBox.localToGlobal(Offset.zero).dy;

      final overlap = headerBottom - myTop; // positive when under header
      final headerHeight = headerBox.size.height;

      double newScale = 1.0;
      if (overlap > 0) {
        final ratio = (overlap.clamp(0.0, headerHeight)) / headerHeight;
        newScale = 1.0 + (0.06 * ratio); // up to +6%
      }

      if ((newScale - _scale).abs() > 0.001) {
        setState(() {
          _scale = newScale;
        });
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_updateScale);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScale());
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_updateScale);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<String> nameParts = widget.name.split(' ');

    return Transform.scale(
      scale: _scale,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: GestureDetector(
          onTap: widget.onTapExpand,
          child: Container(
            constraints: BoxConstraints(minHeight: 85.h),
            width: double.infinity,
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage('assets/png/contact_back.png'),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.08 * 255).toInt()),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeInOut,
                    margin: EdgeInsets.only(
                      bottom: 12.h,
                      top: 5.h,
                    ),
                    height: widget.isExpanded ? 56.w : 80.w,
                    width: widget.isExpanded ? 56.w : 80.w,
                    padding: EdgeInsets.all(9.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      image: widget.image.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(widget.image),
                              fit: BoxFit.contain,
                            )
                          : null,
                      shape: BoxShape.circle,
                      border: widget.isExpanded
                          ? Border.all(
                              color: Colors.white,
                              width: 2,
                            )
                          : null,
                    ),
                  ),
                  Expanded(
                    child: AnimatedCrossFade(
                      duration: const Duration(milliseconds: 450),
                      crossFadeState: widget.isExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: _buildInfoSection(
                          nameParts, widget.job, widget.emp, widget.department),
                      secondChild: const SizedBox.shrink(),
                      sizeCurve: Curves.easeInOut,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    transitionBuilder: (child, anim) {
                      return FadeTransition(opacity: anim, child: child);
                    },
                    child: widget.isExpanded
                        ? SizedBox(
                            key: const ValueKey('icons'),
                            width: 200.w,
                            child: _buildIconsSection(
                              widget.onTapCall,
                              widget.onTapWhatsApp,
                              widget.onTapEmail,
                            ),
                          )
                        : SizedBox(
                            key: const ValueKey('button'),
                            width: 105.w,
                            child: Container(
                              height: 32.h,
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: const Color(0xFF1A1A53), width: 1),
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Center(
                                child: Text(
                                  translate('home.contact_me'),
                                  style: TextStyle(
                                      color: const Color(0xFF1A1A53),
                                      fontSize: 12.sp),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildInfoSection(
    List<String> nameParts, String job, String emp, String department) {
  // Extract full name (remove ID prefix if exists)
  final nameOnly =
      nameParts.length > 1 ? nameParts.sublist(1) : nameParts;
  String fullName = nameOnly.length > 1
      ? '${nameOnly.first} ${nameOnly.last}'
      : nameOnly.isNotEmpty
          ? nameOnly[0]
          : '';

  return Padding(
    padding: EdgeInsets.only(left: 8.w, top: 8.h, bottom: 8.h),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fullName,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (department.isNotEmpty)
          Text(
            department,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: const Color.fromRGBO(65, 65, 65, 0.50),
            ),
          ),
        Text(
          job,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: const Color.fromRGBO(65, 65, 65, 0.55),
          ),
        ),
        Text(
          emp,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: const Color.fromRGBO(65, 65, 65, 0.55),
          ),
        ),
      ],
    ),
  );
}

Widget _buildIconsSection(
  VoidCallback onTapCall,
  VoidCallback onTapWhatsApp,
  VoidCallback onTapEmail,
) {
  return Container(
    padding: EdgeInsets.symmetric(vertical: 6.w, horizontal: 10.w),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFF1A1A53), width: 2),
      borderRadius: BorderRadius.circular(25),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _iconCircle('assets/png/call.png', onTapCall),
        SizedBox(width: 27.w),
        _iconCircle('assets/png/whatsapp.png', onTapWhatsApp),
        SizedBox(width: 27.w),
        _iconCircle('assets/png/email.png', onTapEmail),
      ],
    ),
  );
}

Widget _iconCircle(String asset, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40.w,
      height: 40.w,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: EdgeInsets.all(7.w),
        child: Image.asset(
          asset,
          color: const Color(0xFF1A1A53),
        ),
      ),
    ),
  );
}
