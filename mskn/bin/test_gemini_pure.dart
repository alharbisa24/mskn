import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';

Future<void> main(List<String> args) async {
  final apiKey = await _loadApiKey();
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('GEMINI_API_KEY not found in environment or .env file');
    exit(1);
  }

  final defaultModel = await _loadModelName() ?? 'gemini-2.5-flash';
  final modelName = args.isNotEmpty ? args.first : defaultModel;
  final prompt =
      args.length > 1 ? args.sublist(1).join(' ') : 'قل لي مرحباً بالعربية.';

  stderr.writeln('Using model: $modelName');
  stderr.writeln('Prompt: $prompt');

  final model = GenerativeModel(
    model: modelName,
    apiKey: apiKey,
    systemInstruction: Content.text(
      'You are an Arabic real estate assistant helping users with the Mskn app. '
      'Provide concise, practical answers and follow-up questions when useful.',
    ),
  );

  try {
    final response = await model.generateContent([Content.text(prompt)]);
    final text = response.text;

    if (text == null || text.trim().isEmpty) {
      if (response.promptFeedback != null) {
        stderr.writeln('Prompt blocked: ${response.promptFeedback}');
      }
      final fallback = response.candidates
          .map((candidate) => candidate.content.parts
              .whereType<TextPart>()
              .map((part) => part.text)
              .join(' '))
          .where((value) => value.trim().isNotEmpty)
          .join('\n---\n');
      stderr.writeln('Empty response received. Raw text candidates:');
      stderr.writeln(fallback.isEmpty ? '<no text parts>' : fallback);
      exit(2);
    }

    stdout.writeln(text.trim());
  } on GenerativeAIException catch (error, stackTrace) {
    stderr
      ..writeln('GenerativeAIException: ${error.message}')
      ..writeln('Raw error: $error')
      ..writeln(stackTrace);
    exit(3);
  } catch (error, stackTrace) {
    stderr
      ..writeln('Unexpected error: $error')
      ..writeln(stackTrace);
    exit(4);
  }
}

Future<String?> _loadApiKey() async {
  final envKey = Platform.environment['GEMINI_API_KEY'];
  if (envKey != null && envKey.isNotEmpty) {
    return envKey;
  }

  final envFile = File('.env');
  if (await envFile.exists()) {
    final lines = await envFile.readAsLines();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#') || !trimmed.contains('=')) continue;
      final index = trimmed.indexOf('=');
      final key = trimmed.substring(0, index).trim();
      if (key != 'GEMINI_API_KEY') continue;
      final value = trimmed.substring(index + 1).trim();
      return value.replaceAll('"', '');
    }
  }

  return null;
}

Future<String?> _loadModelName() async {
  final envModel = Platform.environment['GEMINI_MODEL'];
  if (envModel != null && envModel.trim().isNotEmpty) {
    return envModel.trim();
  }

  final envFile = File('.env');
  if (await envFile.exists()) {
    final lines = await envFile.readAsLines();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#') || !trimmed.contains('=')) continue;
      final index = trimmed.indexOf('=');
      final key = trimmed.substring(0, index).trim();
      if (key != 'GEMINI_MODEL') continue;
      final value = trimmed.substring(index + 1).trim();
      if (value.isNotEmpty) {
        return value.replaceAll('"', '');
      }
    }
  }

  return null;
}
