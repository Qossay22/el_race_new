import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class AddReportPhotosScreen extends StatefulWidget {
  final String reportName;
  final String reportType;

  const AddReportPhotosScreen({
    super.key,
    required this.reportName,
    required this.reportType,
  });

  @override
  State<AddReportPhotosScreen> createState() => _AddReportPhotosScreenState();
}

class _AddReportPhotosScreenState extends State<AddReportPhotosScreen> {
  final List<ReportPhotoItem> _photoItems = [];
  int _currentIndex = 0;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Add first empty item
    _photoItems.add(ReportPhotoItem());
  }

  Future<void> _showImageSourceDialog() async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Container(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Photo',
                style: GoogleFonts.poppins(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF27304E),
                ),
              ),
              SizedBox(height: 20.h),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF27304E)),
                title: Text(
                  'Take Photo',
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF27304E)),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _photoItems[_currentIndex].imagePath = image.path;
      });
    }
  }

  void _addNewPhotoItem() {
    if (_photoItems[_currentIndex].imagePath != null &&
        _photoItems[_currentIndex].description.isNotEmpty) {
      setState(() {
        _photoItems.add(ReportPhotoItem());
        _currentIndex = _photoItems.length - 1;
      });
    }
  }

  void _navigateToNext() {
    if (_currentIndex < _photoItems.length - 1) {
      setState(() {
        _currentIndex++;
      });
    }
  }

  void _navigateToPrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = _photoItems[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // Close button at top right
          SafeArea(
            child: Container(
              padding: EdgeInsets.only(right: 20.w, top: 10.h),
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE81E25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, color: Colors.white, size: 20.w),
                ),
              ),
            ),
          ),

          // Scrollable content area
          Expanded(
            child: Container(
              margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.w),
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Add Pictures Button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (currentItem.imagePath == null) {
                            _showImageSourceDialog();
                          } else {
                            _addNewPhotoItem();
                            _showImageSourceDialog();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF27304E),
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 14.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        icon: Icon(Icons.camera_alt, size: 20.w, color: Colors.white),
                        label: Text(
                          'Add Pictures',
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 20.h),
                    // Image Container
                    GestureDetector(
                      onTap: currentItem.imagePath == null
                          ? _showImageSourceDialog
                          : null,
                      child: Container(
                        width: double.infinity,
                        height: 250.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: const Color(0xFFE0E0E0),
                            width: 2,
                          ),
                        ),
                        child: currentItem.imagePath == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 60.w,
                                    color: const Color(0xFFB0B0B0),
                                  ),
                                  SizedBox(height: 12.h),
                                  Text(
                                    'Tap to add photo',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.sp,
                                      color: const Color(0xFFB0B0B0),
                                    ),
                                  ),
                                ],
                              )
                            : Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(18.r),
                                    child: Image.file(
                                      File(currentItem.imagePath!),
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 10.h,
                                    right: 10.w,
                                    child: Row(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.9),
                                            shape: BoxShape.circle,
                                          ),
                                          child: IconButton(
                                            icon: Icon(
                                              Icons.camera_alt,
                                              color: const Color(0xFF27304E),
                                              size: 20.w,
                                            ),
                                            onPressed: _showImageSourceDialog,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.9),
                                            shape: BoxShape.circle,
                                          ),
                                          child: IconButton(
                                            icon: Icon(
                                              Icons.edit,
                                              color: const Color(0xFF27304E),
                                              size: 20.w,
                                            ),
                                            onPressed: _showImageSourceDialog,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    SizedBox(height: 20.h),

                    // Location Dropdown
                    _buildDropdownCard(
                      title: 'Location',
                      value: currentItem.location,
                      hint: 'Select location',
                      items: const [
                        'Site A',
                        'Site B',
                        'Site C',
                        'Building 1',
                        'Building 2',
                      ],
                      onChanged: (value) {
                        setState(() {
                          currentItem.location = value;
                        });
                      },
                    ),

                    SizedBox(height: 20.h),

                    // Description Field
                    _buildDescriptionCard(
                      controller: currentItem.descriptionController,
                      onChanged: (value) {
                        currentItem.description = value;
                      },
                    ),

                    SizedBox(height: 30.h),

                    // Navigation Controls
                    if (_photoItems.length > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _currentIndex > 0 ? _navigateToPrevious : null,
                            icon: Icon(
                              Icons.arrow_back_ios,
                              size: 24.w,
                              color: _currentIndex > 0
                                  ? const Color(0xFF27304E)
                                  : const Color(0xFFD0D0D0),
                            ),
                          ),
                          SizedBox(width: 20.w),
                          Text(
                            'Items no ${_currentIndex + 1}/${_photoItems.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6A6D78),
                            ),
                          ),
                          SizedBox(width: 20.w),
                          IconButton(
                            onPressed: _currentIndex < _photoItems.length - 1
                                ? _navigateToNext
                                : null,
                            icon: Icon(
                              Icons.arrow_forward_ios,
                              size: 24.w,
                              color: _currentIndex < _photoItems.length - 1
                                  ? const Color(0xFF27304E)
                                  : const Color(0xFFD0D0D0),
                            ),
                          ),
                        ],
                      ),

                    SizedBox(height: 30.h),

                    // Generate Report Button
                    SizedBox(
                      width: double.infinity,
                      height: 55.h,
                      child: ElevatedButton(
                        onPressed: () {
                          // Handle report generation
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF27304E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: Text(
                          'Generate Report',
                          style: GoogleFonts.poppins(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 20.h),

                    // Share Button
                    Container(
                      width: 60.w,
                      height: 60.w,
                      decoration: const BoxDecoration(
                        color: Color(0xFF27304E),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () {
                          // Handle share
                        },
                        icon: Icon(
                          Icons.share,
                          color: Colors.white,
                          size: 24.w,
                        ),
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

  Widget _buildDropdownCard({
    required String title,
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6A6D78),
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: items.contains(value) ? value : null,
                hint: Text(
                  hint,
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    color: const Color(0xFFB0B0B0),
                  ),
                ),
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF27304E)),
                items: items
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(
                          item,
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            color: const Color(0xFF27304E),
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard({
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Description',
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6A6D78),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.text_fields, size: 20.w, color: const Color(0xFF6A6D78)),
                  SizedBox(width: 8.w),
                  Icon(Icons.format_list_bulleted, size: 20.w, color: const Color(0xFF6A6D78)),
                  SizedBox(width: 8.w),
                  Icon(Icons.format_list_numbered, size: 20.w, color: const Color(0xFF6A6D78)),
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: TextField(
              controller: controller,
              maxLines: 5,
              onChanged: onChanged,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: const Color(0xFF27304E),
              ),
              decoration: InputDecoration(
                hintText: 'Enter description...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  color: const Color(0xFFB0B0B0),
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReportPhotoItem {
  String? imagePath;
  String? location;
  String description = '';
  final TextEditingController descriptionController = TextEditingController();
}
