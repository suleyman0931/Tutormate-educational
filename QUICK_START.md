# TutorMate - Quick Start Guide

## ✨ Key Features to Test

### 1. **Login**
- Username: `admin`
- Password: `@mymomdad143somuch`
- Biometric: Use fingerprint/face ID if available

### 2. **Import a PDF**
1. Go to **Library** tab
2. Tap **+** button to import PDF
3. Select any PDF file from your device

### 3. **Read & Annotate**
1. Tap any book to open
2. **Reading Mode**:
   - Swipe vertically to scroll
   - Tap top bar to show/hide controls
   - Toggle dark mode with moon icon
   - Switch between continuous & single-page with mode button
   
3. **Annotation Mode**:
   - Tap **Pen icon** (top bar) to enable drawing
   - Draw on the page with your finger
   - Tap **Eraser icon** to erase annotations
   - When pen is OFF, scrolling works freely everywhere
   - When pen is ON, only annotated areas respond to touch

### 4. **Bookmarks**
1. While reading, tap **Bookmark icon** to save page
2. Go to **Library > Bookmarks** to view all
3. Tap any bookmark to jump directly to that page

### 5. **AI Chat**
1. While reading, tap **Auto-awesome icon** (top bar)
2. AI tutor knows which page/book you're on
3. Ask questions about the content
4. Change response language in AI settings

### 6. **Dark Mode**
- Toggle with **Moon icon** in reader toolbar
- Works in both reading and annotation modes
- Automatically applies dark theme

## 🎯 Portfolio Demo Points

### Technical Excellence
- ✅ Hybrid PDF engine (flutter_pdfview + pdfrx)
- ✅ Precise touch coordinate conversion
- ✅ Smart gesture handling
- ✅ Real AI integration (Gemini API)
- ✅ Biometric security

### User Experience
- ✅ Smooth animations
- ✅ Intuitive controls
- ✅ Fast performance
- ✅ Clean Material Design 3 UI
- ✅ Responsive layout

### Code Quality
- ✅ Riverpod state management
- ✅ MVVM architecture
- ✅ Proper separation of concerns
- ✅ Well-organized file structure
- ✅ Error handling

## 📱 Testing on Different Devices

### Samsung A10s (Low-end)
- Recommended for stress testing
- Use `app-armeabi-v7a-release.apk`

### Modern Devices
- Use `app-arm64-v8a-release.apk`
- Best performance and features

### Emulator
- Use `app-x86_64-release.apk`

## 🚀 Installation

### Via USB
```bash
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### Via Flutter
```bash
flutter install -d <device_id>
```

## 🐛 Troubleshooting

### App won't open PDF
- Ensure file is a valid PDF
- Try different PDF viewer (PDFView or PDFrx)
- Check file permissions

### Annotations not drawing correctly
- Ensure pen is active (blue color in top bar)
- Try toggling scroll lock off/on
- Restart app and try again

### AI chat not responding
- Verify Gemini API key in `assets/config/gemini_key.txt`
- Check internet connection
- Verify API has usage quota

### Biometric not working
- Ensure device has biometric enrolled
- Check local_auth permissions
- Use PIN backup authentication

## 💡 Tips for Impressive Demo

1. **Start with Dashboard**: Shows stats and "Continue Reading"
2. **Import a PDF**: Shows document conversion in action
3. **Draw Annotations**: Highlight text and add pen marks
4. **Use Bookmarks**: Jump between marked pages instantly
5. **Ask AI Questions**: Show context-aware responses
6. **Toggle Dark Mode**: Highlight modern UI features
7. **Show Settings**: Display security and customization options

## 📊 Performance Metrics

- **App Size**: ~36 MB (arm64)
- **Launch Time**: < 2 seconds
- **PDF Load Time**: < 1 second per page
- **Annotation Smooth**: 60 FPS
- **Memory Usage**: ~150-200 MB while reading

---

**Questions?** Check the code comments or review architecture in main.dart and lib/app/router.dart
