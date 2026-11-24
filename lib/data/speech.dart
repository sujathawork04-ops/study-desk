// Voice in and out, using the phone's own engines — no extra cost, and it
// works for Tamil and Hindi when those voices are installed.
import "package:flutter_tts/flutter_tts.dart";
import "package:speech_to_text/speech_to_text.dart";

const _scripts = <(String, String)>[
  (r"[஀-௿]", "ta-IN"),   // Tamil
  (r"[ऀ-ॿ]", "hi-IN"),   // Devanagari
  (r"[ఀ-౿]", "te-IN"),
  (r"[ಀ-೿]", "kn-IN"),
  (r"[ഀ-ൿ]", "ml-IN"),
  (r"[ঀ-৿]", "bn-IN"),
  (r"[઀-૿]", "gu-IN"),
  (r"[؀-ۿ]", "ar-SA"),
];

/// Which voice a piece of text needs, judged by the script it is written in.
String scriptLang(String t) {
  var best = "en-IN", most = 0;
  for (final (pattern, lang) in _scripts) {
    final n = RegExp(pattern).allMatches(t).length;
    if (n > most) { most = n; best = lang; }
  }
  final latin = RegExp(r"[A-Za-z]").allMatches(t).length;
  return most > latin * 0.5 && most > 0 ? best : "en-IN";
}

const localeFor = <String, String>{
  "English": "en-IN", "Hindi": "hi-IN", "Tamil": "ta-IN", "Telugu": "te-IN",
  "Kannada": "kn-IN", "Malayalam": "ml-IN", "Marathi": "mr-IN", "Bengali": "bn-IN",
  "Gujarati": "gu-IN", "Punjabi": "pa-IN", "Urdu": "ur-IN", "Arabic": "ar-SA",
  "French": "fr-FR", "Spanish": "es-ES", "German": "de-DE", "Mandarin": "zh-CN",
  "Japanese": "ja-JP", "Korean": "ko-KR", "Sinhala": "si-LK", "Nepali": "ne-NP",
};

class Speech {
  Speech._();
  static final Speech instance = Speech._();

  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  bool _sttReady = false;

  String _strip(String t) => t
      .replaceAll(RegExp(r"[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]", unicode: true), "")
      .replaceAll(RegExp(r"[*_#>`]"), "");

  /// Reads a reply aloud, switching voice per sentence so a Tamil line is read
  /// in Tamil even inside an English answer.
  Future<void> speak(String text) async {
    await _tts.stop();
    final parts = _strip(text)
        .split(RegExp(r"(?<=[.!?।\n])\s+"))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    for (final part in parts) {
      await _tts.setLanguage(scriptLang(part));
      await _tts.setSpeechRate(0.45);   // Flutter's scale differs from the web's
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(part);
    }
  }

  /// A spelling-bee word: said twice, slowly, and never shown on screen.
  Future<void> sayWord(String word) async {
    if (word.isEmpty) return;
    await _tts.stop();
    await _tts.setLanguage(scriptLang(word));
    for (final rate in [0.35, 0.28]) {
      await _tts.setSpeechRate(rate);
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(word);
    }
  }

  Future<void> stop() => _tts.stop();

  Future<bool> get micAvailable async {
    _sttReady = _sttReady || await _stt.initialize();
    return _sttReady;
  }

  bool get listening => _stt.isListening;

  /// Dictation into the message box. Keeps listening through pauses, so a child
  /// can think mid-sentence without losing what she already said.
  Future<bool> listen({
    required String language,
    required void Function(String words) onWords,
    required void Function() onDone,
  }) async {
    if (!await micAvailable) return false;
    await _stt.listen(
      localeId: localeFor[language] ?? "en-IN",
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 6),
      onResult: (r) => onWords(r.recognizedWords),
      listenOptions: SpeechListenOptions(partialResults: true, cancelOnError: true),
    );
    _stt.statusListener = (s) { if (s == "done" || s == "notListening") onDone(); };
    return true;
  }

  Future<void> stopListening() => _stt.stop();
}
