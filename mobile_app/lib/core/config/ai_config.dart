/// AI provider configuration for the photo inspection scanner (tires & brake pads).
///
/// ⚠️ DEMO SETUP — the key is read into the app. Anyone who decompiles the APK
/// can read an embedded key, so for anything beyond a class demo, move this
/// behind the `backend-ai` proxy and have the app call the proxy instead.
///
/// HOW TO GET A FREE KEY:
///   1. Go to https://aistudio.google.com/app/apikey
///   2. "Create API key" (free tier) and copy it — a valid key starts with "AIza…".
///   3. Either paste it into [geminiApiKey] below (replace PASTE_YOUR_KEY_HERE),
///      OR — keeps it out of source — run with:
///         flutter run --dart-define=GEMINI_API_KEY=your_key_here
const String geminiApiKey = String.fromEnvironment(
  'GEMINI_API_KEY',
  defaultValue: 'PASTE_YOUR_KEY_HERE',
);

/// Flash model: fast, free-tier friendly, and strong at image understanding.
/// Fallback options if this is unavailable on your key: 'gemini-flash-latest',
/// 'gemini-1.5-flash'.
const String geminiModel = 'gemini-2.5-flash';

/// True when a real key has been provided.
bool get isAiConfigured =>
    geminiApiKey.isNotEmpty && !geminiApiKey.startsWith('PASTE_');
