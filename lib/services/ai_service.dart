import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AiService {
  static const String _endpoint = 'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-4o';
  static const Duration _timeout = Duration(seconds: 30);

  String? get _apiKey => dotenv.env['OPENAI_API_KEY'];

  static const Map<String, dynamic> _defaultExtractionResult = {
    'suggestedPriority': 'Informational',
    'actionableDate': null,
    'dateContext': '',
    'letterDate': null,
    'summary': '',
    'tags': <String>[],
  };

  /// Reads the image at [imagePath], sends it to the OpenAI API, and returns
  /// a map with the extracted priority, dates, summary, and tags.
  ///
  /// Returns default/empty values on any failure so the app remains functional.
  Future<Map<String, dynamic>> extractPriorityAndDates(String imagePath) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_api_key_here') {
      return Map<String, dynamic>.from(_defaultExtractionResult);
    }

    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(imageBytes);

      const systemPrompt =
          'You are a document analysis assistant. Analyse this letter/document image and identify any actionable dates and the priority level. Respond ONLY with valid JSON, no markdown or other text:\n'
          '{\n'
          '  "suggestedPriority": "One of: Action Required, Informational, Completed",\n'
          '  "actionableDate": "The most important actionable date in YYYY-MM-DD format (appointment, payment deadline, response deadline, etc.), or null if none found",\n'
          '  "dateContext": "A short description of what this date relates to, e.g. \'GP appointment at City Medical Centre\' or \'Invoice payment deadline\'. Empty string if no date found",\n'
          '  "letterDate": "The date printed on the letter in YYYY-MM-DD format, or null if not found",\n'
          '  "summary": "A 1-2 sentence summary of what this document is about",\n'
          '  "tags": ["tag1", "tag2", "tag3"]\n'
          '}';

      final requestBody = jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': systemPrompt},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
              },
            ],
          },
        ],
        'max_tokens': 500,
      });

      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: requestBody,
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return Map<String, dynamic>.from(_defaultExtractionResult);
      }

      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final content =
          responseJson['choices'][0]['message']['content'] as String;
      final parsed = jsonDecode(content) as Map<String, dynamic>;

      // Ensure tags is always a List<String>
      if (parsed['tags'] != null && parsed['tags'] is List) {
        parsed['tags'] = (parsed['tags'] as List)
            .map((e) => e.toString())
            .toList();
      } else {
        parsed['tags'] = <String>[];
      }

      return parsed;
    } catch (_) {
      return Map<String, dynamic>.from(_defaultExtractionResult);
    }
  }

  /// Sends [query] and [documentSummaries] to the OpenAI API and returns the
  /// AI's explanation of which documents are most relevant.
  ///
  /// Returns a fallback message on any failure.
  Future<String> searchDocumentsWithAI(
    String query,
    List<Map<String, String>> documentSummaries,
  ) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_api_key_here') {
      return 'AI search is unavailable. Please add your OpenAI API key.';
    }

    try {
      final docsText = documentSummaries
          .map((doc) {
            return 'Title: ${doc['title'] ?? ''}\nSummary: ${doc['aiSummary'] ?? ''}\nTags: ${doc['aiTags'] ?? ''}';
          })
          .join('\n\n---\n\n');

      final userMessage =
          'The user is searching for: "$query"\n\n'
          'Here are the available documents:\n\n$docsText\n\n'
          'Identify which documents are most relevant to the search query and explain why in 2-4 sentences.';

      final requestBody = jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a helpful document search assistant. Given a list of document summaries and a search query, identify the most relevant documents and briefly explain why they match.',
          },
          {'role': 'user', 'content': userMessage},
        ],
        'max_tokens': 400,
      });

      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: requestBody,
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return 'AI search unavailable. Showing local results instead.';
      }

      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      return responseJson['choices'][0]['message']['content'] as String;
    } catch (_) {
      return 'AI search unavailable. Showing local results instead.';
    }
  }
}
