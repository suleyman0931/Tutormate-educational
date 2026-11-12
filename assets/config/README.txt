Optional: place a file named gemini_key.txt in this folder containing a
Gemini API key to preconfigure the AI Tutor on first launch.

This file (gemini_key.txt) is git-ignored and is only bundled into your local
build. Users can also add or change the key from inside the app:
Settings > AI Assistant > Gemini API Key.

Alternatively run the app with:
flutter run --dart-define=GEMINI_API_KEY=your_key_here
