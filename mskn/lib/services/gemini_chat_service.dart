import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiChatService {
  GeminiChatService({
    required String apiKey,
    String? modelName,
  })  : assert(apiKey.isNotEmpty, 'Gemini API key is required'),
        model = _resolveModelName(modelName),
        _model = GenerativeModel(
          model: _resolveModelName(modelName),
          apiKey: apiKey,
          systemInstruction: Content.text(
            'You are an Arabic real estate assistant helping users with the Mskn app. '
            'Provide concise, practical answers and follow-up questions when useful.',
          ),
        ) {
    _chat = _model.startChat();
  }

  static const String _defaultModel = 'gemini-2.5-flash';

  final String model;
  final GenerativeModel _model;
  late ChatSession _chat;

  Future<String> sendMessage(String message) async {
    final response = await _chat.sendMessage(Content.text(message));
    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      throw StateError('رد فارغ من خدمة Gemini');
    }
    return text;
  }

  void reset() {
    _chat = _model.startChat();
  }

  static String _resolveModelName(String? candidate) {
    final selected = candidate?.trim();
    if (selected == null || selected.isEmpty) {
      return _defaultModel;
    }
    return selected;
  }
}