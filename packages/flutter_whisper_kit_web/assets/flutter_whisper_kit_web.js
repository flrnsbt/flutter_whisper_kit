// flutter_whisper_kit_web.js
// ES module for Flutter Web -> Transformers.js (Whisper) bridge
//
// Usage: put this file in web/ and add to web/index.html:
// <script type="module" src="flutter_whisper_kit_web.js"></script>
//
// Notes: This file imports Transformers.js from jsDelivr CDN. Change version if needed.

import { pipeline, env } from 'https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.7.6/dist/transformers.min.js';

// Optional: tweak env for caching behavior (transformers.js exposes env)
env.useBrowserCache = true;    // cache converted model files in IndexedDB when possible
env.allowLocalModels = false;  // not using local models by default

// Internal state
let transcriber = null;
let loadedModelName = null;

let transcriptionListeners = [];
let progressListeners = [];

let mediaStream = null;
let mediaRecorder = null;
let recording = false;

// Debounce in-flight audio transcriptions to avoid piling up
let _inflight = false;

// Default model to use if none supplied
const DEFAULT_MODEL = 'Xenova/whisper-small'; // change to whisper-base/tiny as desired

// Helper: emit transcription object to registered listeners
function emitTranscription(obj) {
  try {
    transcriptionListeners.forEach(cb => {
      try { cb(obj); } catch (e) { console.error('transcription listener error', e); }
    });
  } catch (e) { console.error('emitTranscription error', e); }
}

function emitProgress(obj) {
  try {
    progressListeners.forEach(cb => {
      try { cb(obj); } catch (e) { console.error('progress listener error', e); }
    });
  } catch (e) { console.error('emitProgress error', e); }
}

// Load the Whisper model (pipeline). returns string status
// Load the Whisper model (pipeline). returns {status, model}
async function _loadModel(opts) {
  // opts: { variant, repo, redownload }
  const modelName = (opts && opts.variant) ? opts.variant : DEFAULT_MODEL;

  // Optional: if you want to apply repo (unused in transformers.js)
  // You can modify how modelName is built if needed:
  // const modelId = opts.repo ? `${opts.repo}/${modelName}` : modelName;
  // but since transformers.js expects a full HF model id, keep simple:
  const modelId = modelName;

  // Prevent reload if unchanged
  if (transcriber && loadedModelName === modelId && !opts.redownload) {
    return { status: 'already_loaded', model: modelId };
  }

  try {
    emitProgress({ status: 'loading', model: modelId, progress: 0 });

    transcriber = await pipeline("automatic-speech-recognition", modelId);
    loadedModelName = modelId;

    emitProgress({ status: 'loaded', model: modelId, progress: 1 });

    return { status: 'loaded', model: modelId };
  } catch (err) {
    console.error("Model load failed", err);

    transcriber = null;
    loadedModelName = null;

    emitProgress({ status: 'error', error: String(err) });

    throw err;
  }
}


// Transcribe a Blob (audio data). options: {language, task, chunk_length_s, stride_length_s}
async function _transcribeBlob(blob, options = {}) {
  if (!transcriber) {
    throw new Error('Model not loaded. Call loadModel() first.');
  }

  const opts = {
    // sensible defaults; user-supplied options override
    chunk_length_s: options.chunk_length_s ?? 30,
    stride_length_s: options.stride_length_s ?? 5,
    task: options.task ?? 'transcribe',
    language: options.language ?? undefined,
    return_timestamps: options.return_timestamps ?? false,
    ...options
  };

  // Call the pipeline. Transformers.js accepts Blobs / Files for audio transcription.
  // It may return { text, segments } depending on model and options.
  const result = await transcriber(blob, opts);

  // Normalize result
  return {
    text: result.text ?? '',
    segments: result.segments ?? [],
    raw: result
  };
}

// Utility: fetch filePath (could be URL or relative path) to Blob
async function _fetchToBlob(filePath) {
  // If it's already a blob-like object (e.g., passed as a File object via postMessage),
  // caller can pass it directly. But Flutter will pass filePath string, so we fetch.
  const r = await fetch(filePath);
  if (!r.ok) throw new Error(`Failed to fetch ${filePath}: ${r.status}`);
  return await r.blob();
}

// Microphone streaming: transcribe short chunks and emit partial results
async function _startMicStreaming(options = {}) {
  if (recording) return { status: 'already_recording' };

  // request mic
  mediaStream = await navigator.mediaDevices.getUserMedia({ audio: true });
  // prefer webm if supported; MediaRecorder may pick codec automatically
  const mimeType = MediaRecorder.isTypeSupported('audio/webm;codecs=opus') ? 'audio/webm;codecs=opus'
                 : MediaRecorder.isTypeSupported('audio/webm') ? 'audio/webm'
                 : 'audio/wav';

  // chunk interval: how often MediaRecorder emits dataavailable. default 1000ms
  const chunkMs = options.chunkMs ?? 1000;

  const chunks = [];
  mediaRecorder = new MediaRecorder(mediaStream, { mimeType });
  recording = true;

  mediaRecorder.ondataavailable = async (ev) => {
    if (ev.data && ev.data.size > 0) {
      // accumulate chunk
      const blob = ev.data;

      // If a transcription is already in flight, we queue but avoid runaway queueing.
      if (_inflight) {
        // keep last chunk only (drop older) to avoid memory buildup
        chunks.length = 0;
        chunks.push(blob);
        return;
      }

      _inflight = true;
      try {
        // send chunk for transcription
        const result = await _transcribeBlob(blob, options);
        // Emit intermediate partial
        emitTranscription({
          text: result.text,
          isPartial: true,
          segments: result.segments
        });
      } catch (err) {
        console.error('mic chunk transcription error', err);
        emitProgress({ status: 'error', error: String(err) });
      } finally {
        _inflight = false;
      }
    }
  };

  mediaRecorder.onstart = () => emitProgress({ status: 'recording_started' });
  mediaRecorder.onstop = () => emitProgress({ status: 'recording_stopped' });
  mediaRecorder.onerror = (ev) => emitProgress({ status: 'record_error', error: ev });

  mediaRecorder.start(chunkMs);

  return { status: 'recording_started' };
}

async function _stopMicStreaming() {
  if (!recording) return { status: 'not_recording' };
  recording = false;

  try {
    if (mediaRecorder && mediaRecorder.state !== 'inactive') {
      mediaRecorder.stop();
    }
    if (mediaStream) {
      mediaStream.getTracks().forEach(t => t.stop());
    }
    mediaRecorder = null;
    mediaStream = null;
    return { status: 'stopped' };
  } catch (err) {
    console.error('stopMicStreaming error', err);
    throw err;
  }
}

// --------- Expose API on window.flutterWhisperKit -------------
window.flutterWhisperKit = {
  // loadModel(variant: string|null, opts: object) -> Promise<string>
  async loadModel(variant, options = {}) {
    const repo = options.modelRepo || "argmax/whisper";
    const redownload = !!options.redownload;

    // your real whisper wasm import here
    const result = await _loadModel({
      variant,
      repo,
      redownload
    });

    return result;
  },

  // transcribeFromFile(filePath: string, options: object) -> Promise<{text, segments}>
  transcribeFromFile: async (filePath, options = {}) => {
    try {
      // If filePath is a data URL or object URL or remote URL, fetch and transcribe
      const blob = await _fetchToBlob(filePath);
      const res = await _transcribeBlob(blob, options);
      return { text: res.text, segments: res.segments ?? [], raw: res.raw };
    } catch (err) {
      console.error('transcribeFromFile failed', err);
      throw err;
    }
  },

  // startRecording(options = {}, loop = true) -> Promise<string>
  startRecording: async (options = {}, loop = true) => {
    try {
      // Ensure model loaded (auto-load default if not)
      if (!transcriber) {
        await _loadModel(DEFAULT_MODEL);
      }
      const r = await _startMicStreaming(options);
      return r.status ?? 'recording_started';
    } catch (err) {
      console.error('startRecording error', err);
      throw err;
    }
  },

  // stopRecording() -> Promise<string>
  stopRecording: async () => {
    const r = await _stopMicStreaming();
    return r.status ?? 'stopped';
  },

  // Register a callback for transcription results: function(jsResult) { ... }
  // Flutter will pass an interop function using allowInterop
  onTranscription: (cb) => {
    if (typeof cb === 'function') {
      transcriptionListeners.push(cb);
    } else {
      console.warn('onTranscription expects a function');
    }
  },

  // Register progress callback similarly
  onProgress: (cb) => {
    if (typeof cb === 'function') {
      progressListeners.push(cb);
    } else {
      console.warn('onProgress expects a function');
    }
  },

  // Language detection wrapper (simple: transcribe with 'language' returned)
  detectLanguage: async (audioPath) => {
    try {
      const blob = await _fetchToBlob(audioPath);
      // use 'transcribe' but some models populate language; transformers.js may include language info
      const res = await _transcribeBlob(blob, { task: 'transcribe' });
      // best-effort
      return {
        language: res.raw?.language ?? null,
        confidence: 1.0
      };
    } catch (err) {
      console.error('detectLanguage error', err);
      throw err;
    }
  },

  deviceName:  () => {
    return navigator.userAgent ?? 'browser';
  },

  // Unload models & free memory
  unloadModels:  () => {
    try {
      transcriber = null;
      loadedModelName = null;
      // transformers.js does not currently expose a global unload API,
      // clearing local references helps GC; IndexedDB cache remains for later reuse.
      return 'unloaded';
    } catch (err) {
      console.error('unloadModels error', err);
      throw err;
    }
  },

  clearState: async () => {
    // Reset internal state (does not touch cached model files)
    transcriptionListeners.length = 0;
    progressListeners.length = 0;
    await _stopMicStreaming().catch(()=>{});
    transcriber = null;
    loadedModelName = null;
    return 'cleared';
  },

  loggingCallback:  ({ level } = {}) => {
    // Simple hook to set logging verbosity; Transformers.js does not use this directly.
    console.log('loggingCallback set level:', level);
  }
};
