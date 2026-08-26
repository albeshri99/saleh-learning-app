import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// نتيجة تقييم نطق الطفل.
class SpeechResult {
  const SpeechResult({
    required this.correct,
    this.confidence = 0,
    this.recognizedWords = '',
  });

  final bool correct;
  final double confidence;
  final String recognizedWords;
}

/// خدمة التعرف على الصوت — تُستخدم في مشاهد التدريب فقط.
abstract interface class SpeechService {
  /// يستمع ثم يقيّم هل نطق الطفل [expected].
  Future<SpeechResult> listenFor(String expected);

  Future<void> dispose();
}

/// تحقق حقيقي باستخدام خدمة التعرف على الكلام في الجهاز.
/// الجلسة قصيرة ومهيأة للعربية لأنها مخصصة لحرف واحد لا للإملاء الطويل.
class DeviceSpeechService implements SpeechService {
  final SpeechToText _speech = SpeechToText();

  @override
  Future<SpeechResult> listenFor(String expected) async {
    var recognizedWords = '';
    var confidence = 0.0;
    var finished = false;
    Timer? timeout;
    final completer = Completer<SpeechResult>();

    void finish() {
      if (finished) return;
      finished = true;
      timeout?.cancel();
      if (!completer.isCompleted) {
        completer.complete(
          SpeechResult(
            correct: speechMatchesExpected(recognizedWords, expected),
            confidence: confidence < 0 ? 0 : confidence,
            recognizedWords: recognizedWords,
          ),
        );
      }
    }

    try {
      final available = await _speech.initialize(
        onError: (error) {
          debugPrint('[speech] ${error.errorMsg}');
          finish();
        },
        onStatus: (status) {
          if (status == SpeechToText.doneStatus ||
              status == SpeechToText.notListeningStatus) {
            finish();
          }
        },
      );
      if (!available) return const SpeechResult(correct: false);

      final locales = await _speech.locales();
      final arabicLocales = locales.where(
        (locale) => locale.localeId.toLowerCase().startsWith('ar'),
      );
      final localeId = arabicLocales
              .where((locale) {
                final id = locale.localeId.toLowerCase().replaceAll('-', '_');
                return id == 'ar_sa';
              })
              .map((locale) => locale.localeId)
              .firstOrNull ??
          arabicLocales.map((locale) => locale.localeId).firstOrNull;

      await _speech.listen(
        onResult: (result) {
          recognizedWords = result.recognizedWords;
          confidence = result.confidence;
          if (result.finalResult) finish();
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 5),
          pauseFor: const Duration(seconds: 2),
          localeId: localeId,
          listenMode: ListenMode.confirmation,
          partialResults: true,
          cancelOnError: true,
          autoPunctuation: false,
          onDevice: false,
        ),
      );
      timeout = Timer(const Duration(seconds: 6), () async {
        await _speech.stop();
        finish();
      });
      return await completer.future;
    } catch (error) {
      debugPrint('[speech] initialization/listening failed: $error');
      finish();
      return completer.future;
    }
  }

  @override
  Future<void> dispose() async {
    await _speech.cancel();
  }
}

@visibleForTesting
bool speechMatchesExpected(String recognized, String expected) {
  String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll(RegExp('[إأآٱ]'), 'ا')
      .replaceAll(RegExp(r'[^\u0621-\u064A]'), '');

  final heard = normalize(recognized);
  final target = normalize(expected);
  if (heard.isEmpty || target.isEmpty) return false;
  if (heard == target) return true;

  return false;
}

class MockSpeechService implements SpeechService {
  const MockSpeechService({this.result = const SpeechResult(correct: true)});

  final SpeechResult result;

  @override
  Future<SpeechResult> listenFor(String expected) async => result;

  @override
  Future<void> dispose() async {}
}
