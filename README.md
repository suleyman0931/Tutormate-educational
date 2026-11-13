# TutorMate 📚 - Educational PDF Reader with AI Chat

A modern Flutter application for reading educational PDFs with AI-powered tutoring, annotation capabilities, and biometric security. Built as a portfolio project showcasing advanced Flutter development.

## 🌟 Features

### Core Reading
- **Hybrid PDF Engine**: Intelligent switching between flutter_pdfview (reading) and pdfrx (annotations)
- **Dark Mode**: Full dark theme support in both reading and annotation modes
- **Multiple Reading Modes**: Continuous vertical scroll or single-page horizontal swipe
- **Document Support**: PDF, Text, Word documents (.docx/.doc) with on-demand conversion
- **High Performance**: Optimized for all device tiers from Samsung A10s to modern flagships

### Annotations & Drawing
- **Freehand Pen**: Draw with customizable stroke width and colors
- **Smart Eraser**: Drag-to-erase with precise touch detection
- **Auto Scroll Control**: Pen activation automatically locks scrolling
- **Accurate Positioning**: Fixed coordinate conversion for exact drawing placement
- **Smooth Gestures**: 60 FPS annotation experience

### Reading Progress
- **Continue Reading**: Remembers last opened page for each book
- **Bookmarks**: Save specific pages with titles and descriptions
- **Progress Tracking**: Visual progress bars and page counters
- **Auto-Save**: Progress automatically saved while reading

### AI Features
- **Context-Aware Chat**: AI tutor knows which book and page you're reading
- **Gemini Integration**: Real Google Generative AI responses
- **Language Detection**: Automatically detects and uses response language
- **Language Selection**: 13 supported languages with user preference
- **Smart Responses**: Markdown-formatted answers with proper text rendering

### Security
- **Biometric Authentication**: Fingerprint/Face ID login
- **PIN Fallback**: Secure PIN as backup authentication
- **Encrypted Storage**: All data encrypted at rest
- **Secure API**: API keys managed safely with .gitignore

## 📸 Screenshots

```
[Dashboard]           [Reader - Light]      [Reader - Dark]
Home stats            PDF viewing           Dark mode enabled
Continue reading      Toolbar visible       Smooth scrolling

[Annotations]         [Bookmarks]          [AI Chat]
Pen active            Saved pages          Context-aware Q&A
Drawing visible       Page list            Gemini responses
```

## 🛠 Tech Stack

### Framework & UI
- **Flutter 3.13+**: Cross-platform UI framework
- **Material Design 3**: Modern design system
- **Riverpod**: Advanced state management

### PDF & Documents
- **flutter_pdfview**: High-performance PDF rendering
- **pdfrx**: Annotation-capable PDF viewer
- **pdf**: PDF generation for document conversion

### Database & Storage
- **Drift (SQLite)**: Type-safe database with migrations
- **SharedPreferences**: User settings persistence

### AI & Backend
- **google_generative_ai**: Gemini API integration
- **http**: Network requests

### Security
- **local_auth**: Biometric authentication
- **crypto**: Secure data encryption

### Navigation
- **GoRouter**: Type-safe routing and deep linking

## 📱 Installation

### Prerequisites
- Flutter 3.13 or higher
- Android SDK API 24+
- Gemini API key from [Google AI Studio](https://makersuite.google.com/app/apikey)

### Setup
1. **Clone Repository**
   ```bash
   git clone https://github.com/suleyman0931/Tutormate-educational.git
   cd Tutormate-educational
   ```

2. **Add API Key**
   ```bash
   mkdir -p assets/config
   echo "your-gemini-api-key-here" > assets/config/gemini_key.txt
   ```

3. **Install Dependencies**
   ```bash
   flutter pub get
   ```

4. **Build APK**
   ```bash
   flutter build apk --release --split-per-abi
   ```

5. **Install on Device**
   ```bash
   adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
   ```

## 🎯 Architecture

### Project Structure
```
lib/
├── app/
│   ├── router.dart              # Navigation routes
│   ├── theme/                   # Material Design 3 theme
│   └── constants/               # App constants
├── core/
│   ├── database/                # Drift SQLite setup
│   ├── utils/                   # Helpers (coordinates, document conversion)
│   └── widgets/                 # Reusable components
└── features/
    ├── dashboard/               # Home screen
    ├── library/                 # Book management
    ├── pdf_reader/              # PDF viewing
    ├── annotations/             # Drawing & annotations
    ├── ai/                      # AI chat
    ├── bookmarks/               # Bookmark management
    ├── notes/                   # Note taking
    └── security/                # Biometric auth
```

### Design Patterns
- **MVVM**: Models, ViewModels (Riverpod providers), Views
- **Repository Pattern**: Data access abstraction
- **Dependency Injection**: Via Riverpod providers
- **Error Handling**: Try-catch with user feedback

## 🎓 Key Technical Highlights

### 1. Hybrid PDF Engine
```dart
// Reading: Uses flutter_pdfview (best gestures)
PDFView(/* configuration */)

// Annotation: Switches to pdfrx + overlays
pdfrx.PdfViewer.file(
  controller: _pdfrxController,
  params: PdfViewerParams(
    pageOverlaysBuilder: (context, pageRect, page) => [
      AnnotationOverlay(/* ... */)
    ],
  ),
)
```

### 2. Coordinate Conversion
Accurate touch position by converting between coordinate spaces:
```dart
// Touch → Screen → Normalized → Storage → Screen → Canvas
final screenPos = localPos.translate(pageRect.left, pageRect.top);
final normalized = CoordinateUtils.toNormalized(screenPos, pageRect);
// ... save to database
final canvasPos = screenPos.translate(-pageRect.left, -pageRect.top);
// ... paint on canvas
```

### 3. Smart Gesture Handling
```dart
// Only capture gestures when tool is active
GestureDetector(
  behavior: tool.isActive ? HitTestBehavior.opaque : HitTestBehavior.translucent,
  onPanStart: tool.isActive ? _onPanStart : null,
  // Allows pdfrx to handle scrolling when tool is inactive
)
```

### 4. State Management
```dart
// Providers for all state
final annotationToolProvider = StateProvider<AnnotationTool>((_) => AnnotationTool.none);
final scrollLockProvider = StateProvider<bool>((_) => false);
final annotationColorProvider = StateProvider<Color>((_) => Colors.blue);
```

## 📊 Performance

| Metric | Value |
|--------|-------|
| App Size | 36 MB (arm64) |
| Launch Time | < 2 seconds |
| PDF Load | < 1 second/page |
| Annotation FPS | 60 FPS |
| Memory Usage | 150-200 MB |

## 🔐 Admin Credentials

For testing/demo purposes:
- **Username**: admin
- **Password**: @mymomdad143somuch

⚠️ Change these before production deployment!

## 📚 Documentation

- **[FINAL_SUMMARY.md](FINAL_SUMMARY.md)** - Complete feature overview
- **[QUICK_START.md](QUICK_START.md)** - Testing guide and demo tips

## 🤝 Contributing

This is a portfolio project. Feel free to fork, modify, and use as a reference for your own projects.

## 📝 License

This project is for educational and portfolio purposes.

## 🚀 Future Enhancements

- [ ] Full Word document rendering (requires external API)
- [ ] Cloud sync for bookmarks and notes
- [ ] Advanced text extraction and search
- [ ] Custom annotation shapes (rectangles, circles)
- [ ] Collaborative features
- [ ] Export annotations as PDF
- [ ] Offline support for frequently used books

## 📞 Contact & Support

**GitHub**: https://github.com/suleyman0931/Tutormate-educational

---

**Built with ❤️ using Flutter**

*This project demonstrates professional Flutter development with attention to performance, user experience, and code quality.*
