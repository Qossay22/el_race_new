import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/qr_question_model.dart';
import '../services/qr_survey_api_service.dart';
import '../providers/qr_survey_data_provider.dart';

class ListQuestionsScreen extends StatefulWidget {
  final List<dynamic> questions;
  final int surveyId;
  final String title;

  const ListQuestionsScreen({
    super.key,
    required this.questions,
    required this.surveyId,
    required this.title,
  });

  @override
  State<ListQuestionsScreen> createState() => _ListQuestionsScreenState();
}

class _ListQuestionsScreenState extends State<ListQuestionsScreen> {
  late List<QrQuestionModel> _questions;
  bool _isSubmitting = false;
  final TextEditingController _guestNameController = TextEditingController();
  final TextEditingController _guestContactController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _questions = widget.questions.cast<QrQuestionModel>();
  }

  @override
  void dispose() {
    _guestNameController.dispose();
    _guestContactController.dispose();
    super.dispose();
  }

  Future<void> _submitAnswers() async {
    // Validate all mandatory questions
    bool allAnswered = _questions.every((q) => q.isAnswered);

    if (!allAnswered) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(translate('common.please_answer_all_questions')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await QrSurveyApiService().submitSurveyAnswers(
        surveyId: widget.surveyId,
        questions: _questions,
        guestName: _guestNameController.text.trim(),
        guestContact: _guestContactController.text.trim(),
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(translate('common.success')),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        throw Exception('Failed to submit');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(translate('common.error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Verify this screen was accessed via QR code
    final provider = Provider.of<QrSurveyDataProvider>(context, listen: false);
    if (!provider.isFromQrCode) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.qr_code_scanner,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  'QR Code Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'This content is only accessible by scanning a QR code.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _questions.length,
            itemBuilder: (context, index) {
              return _buildQuestionCard(_questions[index], index);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitAnswers,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    translate('common.submit'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(QrQuestionModel question, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${index + 1}. ${question.title}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (question.isMandatory)
                  const Text(
                    '*',
                    style: TextStyle(color: Colors.red, fontSize: 18),
                  ),
              ],
            ),
            if (question.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                question.description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildQuestionInput(question),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionInput(QrQuestionModel question) {
    switch (question.type) {
      case 'date':
        return _buildDatePicker(question);
      case 'simple_choice':
        return _buildMultipleChoice(question);
      case 'char_box':
      default:
        return _buildTextInput(question);
    }
  }

  Widget _buildDatePicker(QrQuestionModel question) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: question.dateAnswer ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (date != null) {
          setState(() {
            final index = _questions.indexOf(question);
            _questions[index] = question.copyWith(dateAnswer: date);
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              question.dateAnswer != null
                  ? DateFormat('yyyy-MM-dd').format(question.dateAnswer!)
                  : 'Select Date',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color:
                    question.dateAnswer != null ? Colors.black87 : Colors.grey,
              ),
            ),
            const Icon(Icons.calendar_today, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleChoice(QrQuestionModel question) {
    return Column(
      children: (question.suggestedAnswers ?? []).map((answer) {
        return RadioListTile<String>(
          title: Text(answer),
          value: answer,
          groupValue: question.selectedAnswer,
          onChanged: (value) {
            setState(() {
              final index = _questions.indexOf(question);
              _questions[index] = question.copyWith(selectedAnswer: value);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildTextInput(QrQuestionModel question) {
    return TextField(
      onChanged: (value) {
        final index = _questions.indexOf(question);
        _questions[index] = question.copyWith(textAnswer: value);
      },
      decoration: InputDecoration(
        hintText: 'Enter your answer...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      maxLines: 3,
    );
  }
}
