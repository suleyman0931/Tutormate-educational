# TutorMate 📚

An offline educational PDF reader and AI-powered learning assistant designed for students. Read textbooks, annotate documents, and get instant AI tutoring - all without internet connectivity.

## ✨ Features

### 📖 Advanced PDF Reading
- Smooth two-finger zoom and gesture controls optimized for all devices
- Vertical continuous scroll and horizontal page swipe
- Dark mode for comfortable night reading with color inversion
- Single page and continuous reading modes
- Bookmark pages with custom notes
- Auto-save reading progress and continue from where you left off

### ✍️ Smart Annotations
- Handwriting tool for freehand notes and drawings
- Eraser for corrections
- Hybrid rendering engine (flutter_pdfview + pdfrx) for optimal performance
- Precise annotation positioning on any device
- Edge detection for seamless scrolling while annotating

### 🤖 AI Tutor (Powered by Gemini)
- Ask questions about your PDFs and get instant answers
- Multi-language support (13 languages including English, Amharic, Arabic, Spanish, French, German, Chinese, Japanese, Korean, Portuguese, Russian, Hindi)
- Context-aware responses based on PDF content
- Markdown-formatted explanations for better readability
- Offline-capable with chat history

### 📚 Library Management
- Organize books by category (Textbook, Reference, Workbook, Study Guide, Practice Test)
- Filter by grade level (1-12), subject, and category
- Search functionality
- Import multiple formats: PDF, Word (.docx, .doc), and Text files
- Automatic document conversion for seamless reading
- Custom cover generation from first page
- Duplicate detection using file hashing

### 🔒 Security & Privacy
- Biometric authentication (fingerprint/face unlock)
- Admin password protection for AI settings
- All data stored locally - complete offline functionality
- No data collection or external transmission

### 🎨 User Experience
- Modern Material 3 design with dynamic theming
- Screen wake lock while reading
- Distraction-free mode with auto-hiding toolbar
- Smooth animations and transitions
- Optimized for Samsung A10s and similar devices

## 🚀 Technology Stack

- **Framework:** Flutter 3.11.1
- **State Management:** Riverpod
- **Database:** Drift (SQLite)
- **PDF Rendering:** flutter_pdfview + pdfrx (hybrid approach)
- **AI Integration:** Google Gemini API
- **Authentication:** local_auth (biometric)
- **Storage:** path_provider (local file system)

## 📱 Installation

1. Download the latest APK from the [Releases](../../releases) page
2. Enable "Install from Unknown Sources" on your Android device
3. Install the APK
4. Grant required permissions (storage, biometric)
5. Start importing your educational materials!

## 🛠️ Building from Source

```bash
# Clone the repository
git clone https://github.com/suleyman0931/Tutormate-educational.git
cd Tutormate-educational

# Install dependencies
flutter pub get

# Run the app
flutter run

# Build release APK
flutter build apk --release --split-per-abi
```

## 📋 Requirements

- Android 6.0 (API level 23) or higher
- ~50MB storage space for the app
- Additional storage for your PDF library
- (Optional) Gemini API key for AI tutor features

## 🔑 Configuration

To use the AI Tutor feature:

1. Get a free API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Open TutorMate → Settings → AI Settings
3. Enter admin password: `@mymomdad143somuch`
4. Add your Gemini API key
5. Start chatting with your AI tutor!

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🙏 Acknowledgments

- Built with Flutter
- Powered by Google Gemini AI
- PDF rendering by flutter_pdfview and pdfrx
- Icon design inspired by modern educational apps

## 📞 Support

If you encounter any issues or have suggestions, please [open an issue](../../issues).

---

Made with ❤️ for students everywhere
