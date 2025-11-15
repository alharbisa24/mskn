import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mskn/services/gemini_chat_service.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');
  final key = dotenv.env['GEMINI_API_KEY'];
  if (key == null || key.isEmpty) {
    print('Missing GEMINI_API_KEY');
    return;
  }
  final chat = GeminiChatService(apiKey: key);
  try {
    final reply = await chat.sendMessage('اختبر الرد بالعربية');
    print('Gemini reply: $reply');
  } catch (e) {
    print('Gemini error: $e');
  }
}
