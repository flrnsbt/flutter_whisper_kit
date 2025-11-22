import 'package:flutter_whisper_kit/src/models.dart';
import 'package:flutter_whisper_kit/src/platform_specifics/flutter_whisper_kit_platform_interface.dart';

/// Web implementation of FlutterWhisperKitPlatform
class FlutterWhisperKitWebPlugin extends FlutterWhisperKitPlatform {
  /// Constructor
  FlutterWhisperKitWebPlugin() : super();

  @override
  Future<String?> loadModel(
    String? variant, {
    String? modelRepo,
    bool redownload = false,
  }) {
    throw UnimplementedError('loadModel() has not been implemented.');
  }

  @override
  Future<TranscriptionResult?> transcribeFromFile(
    String filePath, {
    DecodingOptions options = const DecodingOptions(),
  }) {
    throw UnimplementedError('transcribeFromFile() has not been implemented.');
  }

  @override
  Future<String?> startRecording({
    DecodingOptions options = const DecodingOptions(),
    bool loop = true,
  }) {
    throw UnimplementedError('startRecording() has not been implemented.');
  }

  @override
  Future<String?> stopRecording({bool loop = true}) {
    throw UnimplementedError('stopRecording() has not been implemented.');
  }

  @override
  Stream<TranscriptionResult> get transcriptionStream {
    throw UnimplementedError('transcriptionStream has not been implemented.');
  }

  @override
  Stream<Progress> get modelProgressStream {
    throw UnimplementedError('modelProgressStream has not been implemented.');
  }

  @override
  Future<List<String>> fetchAvailableModels({
    String modelRepo = 'argmaxinc/whisperkit-coreml',
    List<String> matching = const ['*'],
    String? token,
  }) {
    throw UnimplementedError(
      'fetchAvailableModels() has not been implemented.',
    );
  }

  @override
  Future<LanguageDetectionResult> detectLanguage(String audioPath) {
    throw UnimplementedError('detectLanguage() has not been implemented.');
  }

  @override
  Future<String> deviceName() {
    throw UnimplementedError('deviceName() has not been implemented.');
  }

  @override
  Future<ModelSupport> recommendedModels() {
    throw UnimplementedError('recommendedModels() has not been implemented.');
  }

  @override
  Future<List<String>> formatModelFiles(List<String> modelFiles) {
    throw UnimplementedError('formatModelFiles() has not been implemented.');
  }

  @override
  Future<ModelSupportConfig> fetchModelSupportConfig({
    String repo = 'argmaxinc/whisperkit-coreml',
    String? downloadBase,
    String? token,
  }) {
    throw UnimplementedError(
      'fetchModelSupportConfig() has not been implemented.',
    );
  }

  @override
  Future<ModelSupport> recommendedRemoteModels({
    String repo = 'argmaxinc/whisperkit-coreml',
    String? downloadBase,
    String? token,
  }) {
    throw UnimplementedError(
      'recommendedRemoteModels() has not been implemented.',
    );
  }

  @override
  Future<String?> setupModels({
    String? model,
    String? downloadBase,
    String? modelRepo,
    String? modelToken,
    String? modelFolder,
    bool download = true,
  }) {
    throw UnimplementedError('setupModels() has not been implemented.');
  }

  @override
  Future<String?> download({
    required String variant,
    String? downloadBase,
    bool useBackgroundSession = false,
    String repo = 'argmaxinc/whisperkit-coreml',
    String? token,
  }) {
    throw UnimplementedError('download() has not been implemented.');
  }

  @override
  Future<String?> prewarmModels() {
    throw UnimplementedError('prewarmModels() has not been implemented.');
  }

  @override
  Future<String?> unloadModels() {
    throw UnimplementedError('unloadModels() has not been implemented.');
  }

  @override
  Future<String?> clearState() {
    throw UnimplementedError('clearState() has not been implemented.');
  }

  @override
  Future<void> loggingCallback({String? level}) {
    throw UnimplementedError('loggingCallback() has not been implemented.');
  }
}
