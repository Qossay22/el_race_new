import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/qr_survey_data_provider.dart';
import 'list_documents_screen.dart';
import 'list_media_screen.dart';
import 'list_questions_screen.dart';

/// Screen with AppBar and BottomNavigationBar for authenticated users
class QrSurveyAuthenticatedScreen extends StatefulWidget {
  const QrSurveyAuthenticatedScreen({super.key});

  @override
  State<QrSurveyAuthenticatedScreen> createState() =>
      _QrSurveyAuthenticatedScreenState();
}

class _QrSurveyAuthenticatedScreenState
    extends State<QrSurveyAuthenticatedScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text(
          'QR Survey',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<QrSurveyDataProvider>(
        builder: (context, provider, child) {
          // Check if content is from QR code
          if (!provider.isFromQrCode) {
            return Center(
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
            );
          }

          // Get content from provider
          final contentType = provider.contentType;
          final dynamic data = provider.contentData;

          // Show QR Survey content based on type
          Widget qrSurveyContent;
          if (contentType == 'survey' && data is Map<String, dynamic>) {
            qrSurveyContent = ListQuestionsScreen(
              questions: data['questions'] ?? [],
              surveyId: data['id'] ?? 0,
              title: data['title'] ?? 'Survey',
            );
          } else if (contentType == 'documents') {
            // documents might be in data['documents'] if data is Map, or data itself if List
            List<dynamic> documents = [];
            if (data is List<dynamic>) {
              documents = data;
            } else if (data is Map<String, dynamic> &&
                data['documents'] is List) {
              documents = data['documents'] as List<dynamic>;
            }
            qrSurveyContent = ListDocumentsScreen(documents: documents);
          } else if (contentType == 'media') {
            // media might be in data['media'] if data is Map, or data itself if List
            List<dynamic> media = [];
            if (data is List<dynamic>) {
              media = data;
            } else if (data is Map<String, dynamic> && data['media'] is List) {
              media = data['media'] as List<dynamic>;
            }
            qrSurveyContent = ListMediaScreen(mediaList: media);
          } else {
            qrSurveyContent = const Center(
              child: Text('No content available'),
            );
          }

          return qrSurveyContent;
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: 1, // Highlight Home tab
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF1E3A5F),
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          onTap: (index) {
            // Navigate back to main screen when any tab is tapped
            Navigator.pop(context);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.call),
              label: 'Call',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt),
              label: 'Camera',
            ),
          ],
        ),
      ),
    );
  }
}
