import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_whisper_kit/src/models.dart';
import 'package:flutter_whisper_kit/src/platform_specifics/flutter_whisper_kit_platform_interface.dart';
import 'package:web/web.dart' as web;

/// Web implementation of FlutterWhisperKitPlatform
class FlutterWhisperKitWebPlugin extends FlutterWhisperKitPlatform {
  /// Constructor
  FlutterWhisperKitWebPlugin() : super();

  Completer<void>? _jsLoader;

  JSFlutterWhisperKit get _flutterWhisperKit => window.flutterWhisperKit;

  FutureOr<void> _ensureWhisperJsLoaded() async {
    final script = web.document.getElementById('flutter_whisper_kit_web');
    if (script != null) {
      return;
    }
    if (_jsLoader == null) {
      _jsLoader = Completer<void>();

      final script = web.HTMLScriptElement()
        ..type = 'module'
        ..src =
            'packages/flutter_whisper_kit_web/assets/flutter_whisper_kit_web.js'
        ..id = 'flutter_whisper_kit_web'
        ..async = true;

      script.onLoad.listen((_) {
        if (!_jsLoader!.isCompleted) {
          _jsLoader!.complete();
        }
      });

      script.onError.listen((event) {
        if (!_jsLoader!.isCompleted) {
          _jsLoader!.completeError(
            Exception('Failed to load flutter_whisper_kit_web.js'),
          );
        }
      });

      web.document.head!.append(script);
    }

    // Wait for the loader to finish
    await _jsLoader!.future;
  }

  @override
  Future<String?> loadModel(
    String? variant, {
    String? modelRepo,
    bool redownload = false,
  }) async {
    await _ensureWhisperJsLoaded();
    return _flutterWhisperKit
        .loadModel(variant!.toJS, modelRepo?.toJS, redownload.toJS)
        .toDart
        .then((value) => value.toDart);
  }

  @override
  Future<TranscriptionResult?> transcribeFromFile(
    String filePath, {
    DecodingOptions options = const DecodingOptions(),
  }) async {
    await _ensureWhisperJsLoaded();

    return _flutterWhisperKit
        .transcribeFromFile(filePath.toJS, options.toJS)
        .toDart
        .then((jsResult) {
          return jsResult.toDart;
        });
  }

  @override
  Future<String?> startRecording({
    DecodingOptions options = const DecodingOptions(),
    bool loop = true,
  }) async {
    await _ensureWhisperJsLoaded();

    return _flutterWhisperKit
        .startRecording(options.toJS)
        .toDart
        .then((value) => value.toDart);
  }

  @override
  Future<String?> stopRecording({bool loop = true}) async {
    await _ensureWhisperJsLoaded();
    return _flutterWhisperKit.stopRecording().toDart.then(
      (value) => value.toDart,
    );
  }

  StreamController<TranscriptionResult>? _transcriptionController;

  @override
  Stream<TranscriptionResult> get transcriptionStream {
    _transcriptionController ??=
        StreamController<TranscriptionResult>.broadcast();

    // attach only once
    if (!_transcriptionController!.hasListener) {
      _flutterWhisperKit.onProgress(
        (JSObject jsEvent) {
          final event = jsEvent.dartify();
        }.toJS,
      );
    }

    return _transcriptionController!.stream;
  }

  StreamController<Progress>? _modelProgressController;

  @override
  Stream<Progress> get modelProgressStream {
    _modelProgressController ??= StreamController<Progress>.broadcast();

    if (!_modelProgressController!.hasListener) {
      _flutterWhisperKit.onProgress(
        (JSObject jsEvent) {
          final event = jsEvent.dartify();
        }.toJS,
      );
    }

    return _modelProgressController!.stream;
  }

  @override
  Future<LanguageDetectionResult> detectLanguage(String audioPath) async {
    await _ensureWhisperJsLoaded();

    return _flutterWhisperKit.detectLanguage(audioPath.toJS).toDart.then((
      jsRes,
    ) {
      return jsRes.toDart;
    });
  }

  @override
  Future<String> deviceName() async {
    await _ensureWhisperJsLoaded();
    return _flutterWhisperKit.deviceName().toDart;
  }

  @override
  Future<String?> unloadModels() async {
    await _ensureWhisperJsLoaded();
    _flutterWhisperKit.unloadModels();
    return "ok";
  }

  @override
  Future<String?> clearState() async {
    await _ensureWhisperJsLoaded();
    await _flutterWhisperKit.clearState().toDart;
    return "ok";
  }

  @override
  Future<void> loggingCallback({String? level}) async {
    await _ensureWhisperJsLoaded();

    _flutterWhisperKit.loggingCallback(
      (JSObject jsEvent) {
        final event = jsEvent.dartify();
        print(event);
      }.toJS,
    );
  }
}

@JS()
external JSWindow get window;

@JS()
extension type JSWindow(JSObject _) implements JSObject {
  external JSFlutterWhisperKit get flutterWhisperKit;
}

extension type JSFlutterWhisperKit(JSObject _) implements JSObject {
  external JSPromise<JSString> loadModel(
    JSString path,
    JSString? repo,
    JSBoolean redownload,
  );
  external JSPromise<JSTranscribeResults> transcribeFromFile(
    JSString path,
    JSObject options,
  );
  external JSPromise<JSString> startRecording(JSObject options);
  external JSPromise<JSString> stopRecording();

  external JSVoid onProgress(JSFunction callback);

  external JSPromise<JSDetectLanguageResult> detectLanguage(JSString audioPath);

  external JSString deviceName();

  external JSVoid unloadModels();

  external JSPromise clearState();

  external JSVoid loggingCallback(JSFunction callback);
}

@JS()
extension type JSDetectLanguageResult(JSObject _) implements JSObject {
  external JSString get language;
  external JSNumber get confidence;

  LanguageDetectionResult get toDart => LanguageDetectionResult(
    language: language.toDart,
    probabilities: {language.toDart: confidence.toDartDouble},
  );
}

/// ---------------------------------------------------------------------------
/// Transcription results
/// ---------------------------------------------------------------------------
@JS()
extension type JSTranscribeResults(JSObject _) implements JSObject {
  external JSString get text;
  external JSArray<JSSegment> get segments;
  external JSString get language;

  TranscriptionResult get toDart {
    final dartText = text.toDart;
    final dartSegments = [
      for (final segment in segments.toDart) segment.toDart,
    ];

    return TranscriptionResult(
      text: dartText,
      segments: dartSegments,
      language: language.toDart,
      timings: TranscriptionTimings(),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Individual segment from Whisper
/// ---------------------------------------------------------------------------
@JS()
extension type JSSegment(JSObject _) implements JSObject {
  external JSNumber get start;
  external JSNumber get end;
  external JSString get text;

  TranscriptionSegment get toDart => TranscriptionSegment(
    start: start.toDartDouble,
    end: end.toDartDouble,
    text: text.toDart,
  );
}

@JS()
extension type JSDecodingOptions._(JSObject _) implements JSObject {
  external set task(JSString? value);
  external JSString? get task;

  external set language(JSString? value);
  external JSString? get language;

  external set return_timestamps(JSBoolean? value);
  external JSBoolean? get return_timestamps;

  external set chunk_length_s(JSNumber? value);
  external JSNumber? get chunk_length_s;

  external set stride_length_s(JSAny? value);
  external JSAny? get stride_length_s;

  external set max_new_tokens(JSNumber? value);
  external JSNumber? get max_new_tokens;

  external set num_beams(JSNumber? value);
  external JSNumber? get num_beams;

  external set temperature(JSNumber? value);
  external JSNumber? get temperature;

  external set compression_ratio_threshold(JSNumber? value);
  external JSNumber? get compression_ratio_threshold;

  external set no_speech_threshold(JSNumber? value);
  external JSNumber? get no_speech_threshold;

  external set logprob_threshold(JSNumber? value);
  external JSNumber? get logprob_threshold;

  external set output_scores(JSBoolean? value);
  external JSBoolean? get output_scores;

  external set return_full_text(JSBoolean? value);
  external JSBoolean? get return_full_text;
}

extension on DecodingOptions {
  JSDecodingOptions get toJS {
    final jsOptions = JSDecodingOptions._(JSObject());

    // ----------------------------
    // 1. task: "transcribe" | "translate"
    // ----------------------------
    switch (task) {
      case DecodingTask.transcribe:
        jsOptions.task = 'transcribe'.toJS;
        break;
      case DecodingTask.translate:
        jsOptions.task = 'translate'.toJS;
        break;
    }

    // ----------------------------
    // 2. language
    // ----------------------------
    if (language != null && language!.isNotEmpty) {
      jsOptions.language = language!.toJS;
    }

    // ----------------------------
    // 3. return_timestamps
    // Whisper → return timestamps when NOT skipping timestamps or when wordTimestamps is enabled.
    // ----------------------------
    jsOptions.return_timestamps = (!withoutTimestamps || wordTimestamps).toJS;

    // ----------------------------
    // 4. chunk_length_s + stride_length_s
    // from chunkingStrategy
    // ----------------------------
    switch (chunkingStrategy) {
      case ChunkingStrategy.none:
        // do nothing (no chunking)
        break;

      case ChunkingStrategy.vad:
        jsOptions.chunk_length_s = 30.toJS;
        jsOptions.stride_length_s = 5.toJS;
        break;

      default:
        break;
    }

    // ----------------------------
    // 5. decoding hyperparameters (Transformers.js supported)
    // ----------------------------
    if (temperature >= 0) jsOptions.temperature = temperature.toJS;

    if (compressionRatioThreshold != null) {
      jsOptions.compression_ratio_threshold = compressionRatioThreshold!.toJS;
    }

    if (logProbThreshold != null) {
      jsOptions.logprob_threshold = logProbThreshold!.toJS;
    }

    if (noSpeechThreshold != null) {
      jsOptions.no_speech_threshold = noSpeechThreshold!.toJS;
    }

    jsOptions.return_full_text = true.toJS;

    return jsOptions;
  }
}
