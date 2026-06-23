import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/note_model.dart';

class NoteItemWidget extends StatelessWidget {
  final NoteModel note;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const NoteItemWidget({
    super.key,
    required this.note,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      DateFormat('MMM dd, yyyy').format(note.date),
                      style:  GoogleFonts.poppins(
                        fontSize: 13.sp,
                        color: const Color(0xff313131),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        note.description,
                        style:  GoogleFonts.poppins(
                          fontSize: 13.sp,
                          color: const Color(0xff313131),
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: null,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Divider(
          height: 1,
          thickness: 0.7,
          color: Colors.grey,
        ),
      ],
    );
  }
} 