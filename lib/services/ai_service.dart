import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AiService {
  static const String _endpoint = 'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-4o';
  static const Duration _timeout = Duration(seconds: 30);

  String? get _apiKey => dotenv.env['OPENAI_API_KEY'];

  static const Map<String, dynamic> _defaultAnalysisResult = {
    'suggestedTitle': null,
    'suggestedCategory': null,
    'suggestedPriority': 'Informational',
    'letterDate': null,
    'actionableDate': null,
    'actionableDateContext': null,
    'notes': null,
  };

  /// Analyses the document image at [imagePath] using GPT-4o and returns a map
  /// with suggested title, category, priority, dates, and notes.
  ///
  /// Returns default/empty values on any failure so the app remains functional.
  Future<Map<String, dynamic>> analyseDocument(String imagePath) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_api_key_here') {
      debugPrint('AI Analysis: No valid API key found, returning defaults');
      return Map<String, dynamic>.from(_defaultAnalysisResult);
    }

    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(imageBytes);

      const systemPrompt =
          'You are a document analysis assistant. Analyse this letter/document image and extract ALL of the following information. Respond ONLY with valid JSON, no markdown or other text:\n'
          '{\n'
          '  "suggestedTitle": "A short descriptive title for this document, e.g. \'Chase Bank Statement - March 2026\' or \'GP Appointment Letter\'",\n'
          '  "suggestedCategory": "Category must be exactly one of: Financial, Medical, Bills, Other — Financial: bank statements, account letters, investment correspondence, tax documents, insurance policies; Medical: appointment letters, test results, prescriptions, hospital correspondence, referrals; Bills: utility bills, invoices, payment demands, subscription charges, council tax, phone/broadband bills; Other: anything that does not fit the above categories",\n'
          '  "suggestedPriority": "One of: Action Required, Informational, Completed — use \'Action Required\' if there is a deadline, payment due, appointment, or any response needed. Use \'Informational\' if it is a statement, summary, or record with no action needed. Use \'Completed\' only if the document confirms something already done.",\n'
          '  "letterDate": "The date printed on the letter/document in YYYY-MM-DD format, or null if no date is visible",\n'
          '  "actionableDate": "Any deadline, due date, appointment date, payment date, or expiry date found in the document in YYYY-MM-DD format, or null if none found. Examples: \'pay by\' dates, appointment dates, renewal deadlines, response deadlines.",\n'
          '  "actionableDateContext": "A short explanation of what the actionable date relates to, e.g. \'Payment due for invoice #1234\', \'GP appointment at City Medical Centre\', \'Insurance renewal deadline\'. Set to null if no actionable date found.",\n'
          '  "notes": "A 2-3 sentence summary of what this document is about. If action is required, explain what needs to be done and why. If informational, summarise the key details. Keep it concise and useful."\n'
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
        'max_tokens': 600,
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
        debugPrint('AI Analysis: API returned status ${response.statusCode}');
        debugPrint('AI Analysis: Response body: ${response.body}');
        return Map<String, dynamic>.from(_defaultAnalysisResult);
      }

      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      var content =
          (responseJson['choices'][0]['message']['content'] as String).trim();

      // Strip markdown code fences if present (e.g. ```json ... ```)
      final fencePattern = RegExp(r'^```(?:json)?\s*\n?(.*?)\n?\s*```$', dotAll: true);
      final match = fencePattern.firstMatch(content);
      if (match != null) {
        content = match.group(1)!.trim();
      }

      final parsed = jsonDecode(content) as Map<String, dynamic>;

      debugPrint('AI Analysis Result: $parsed');

      return parsed;
    } catch (e) {
      debugPrint('AI Analysis: Exception occurred: $e');
      return Map<String, dynamic>.from(_defaultAnalysisResult);
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
