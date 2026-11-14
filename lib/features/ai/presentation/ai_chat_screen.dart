import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../data/ai_settings.dart';
import '../data/gemini_service.dart';
import '../data/pdf_ai_context_service.dart';
import 'ai_settings_dialog.dart';

/// The AI Tutor tab: chat with Gemini about the PDFs in the library.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({
    super.key,
    this.initialBookId,
    this.initialPage,
    this.initialSelectedText,
  });

  /// When set, the conversation starts focused on this book.
  final int? initialBookId;

  /// When set, passages from this page are prioritised.
  final int? initialPage;

  /// When set, this text is pre-filled and sent automatically to Gemini.
  final String? initialSelectedText;

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];

  int? _selectedBookId;
  int? _focusPage;
  bool _sending = false;
  String _status = '';
  String _selectedLanguage = 'Auto-detect'; // Language selector

  // Available languages
  static const _languages = [
    'Auto-detect',
    'English',
    'Amharic (አማርኛ)',
    'Arabic (العربية)',
    'Spanish (Español)',
    'French (Français)',
    'German (Deutsch)',
    'Chinese (中文)',
    'Japanese (日本語)',
    'Korean (한국어)',
    'Portuguese (Português)',
    'Russian (Русский)',
    'Hindi (हिन्दी)',
  ];

  @override
  void initState() {
    super.initState();
    _selectedBookId = widget.initialBookId;
    _focusPage = widget.initialPage;
    _messages.add(_introMessage());

    // If selected text was passed, pre-fill and auto-send it
    if (widget.initialSelectedText != null &&
        widget.initialSelectedText!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final question =
            'Explain this text from the book:\n\n"${widget.initialSelectedText}"';
        _inputController.text = question;
        // Auto-send after short delay
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _sendMessage();
        });
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  _ChatMessage _introMessage() {
    final pageNote = _focusPage != null
        ? '\n\nThe reader opened page $_focusPage, so I will prioritise that page.'
        : '';
    return _ChatMessage(
      text: 'Hi! I am TutorMate AI. I read the PDFs in your library and help '
          'you understand them.\n\nChoose a book above, or search your whole '
          'library, then ask me anything: explanations, summaries, '
          'definitions, or practice questions.$pageNote',
      isIntro: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(aiSettingsProvider);
    final booksAsync = ref.watch(allBooksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Tutor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'AI settings',
            onPressed: () => showAiSettingsDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'New conversation',
            onPressed:
                _messages.length > 1 && !_sending ? _confirmClearChat : null,
          ),
        ],
      ),
      body: booksAsync.when(
        loading: () =>
            const LoadingIndicator(message: 'Loading your library...'),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load your library.\n$error'),
          ),
        ),
        data: (books) {
          if (books.isEmpty) {
            return EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'No PDFs yet',
              message: 'Import documents (PDF, Word, Text) into your library, then come back to ask '
                  'the AI Tutor questions about it.',
              actionLabel: 'Import PDF',
              onAction: () => context.go(AppRoutes.library),
            );
          }

          final selectedBook = _bookFromList(books, _selectedBookId);
          return Column(
            children: [
              _buildScopeBar(books, selectedBook),
              Expanded(
                child: _buildChatList(settings),
              ),
              _buildComposer(),
            ],
          );
        },
      ),
    );
  }

  // ── Scope ──────────────────────────────────────────────────────────────────

  Widget _buildScopeBar(List<Book> books, Book? selectedBook) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final title = selectedBook?.title ?? 'Entire Library';
    final subtitle = selectedBook != null
        ? '${selectedBook.category.shortLabel} · Grade ${selectedBook.grade}'
        : 'Search all ${books.length} PDF${books.length == 1 ? '' : 's'}';
    final pageSuffix = _focusPage != null ? ' · page $_focusPage' : '';

    return Column(
      children: [
        // Book selector
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Material(
            color: colorScheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _sending ? null : () => _pickScope(books),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        selectedBook != null
                            ? Icons.menu_book_rounded
                            : Icons.library_books_rounded,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$subtitle$pageSuffix',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (_focusPage != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Clear page focus',
                        onPressed: () {
                          setState(() {
                            _focusPage = null;
                            _messages
                              ..clear()
                              ..add(_introMessage());
                          });
                          _scrollToBottom(animate: false);
                        },
                      ),
                    const Icon(Icons.unfold_more, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // Language selector
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Material(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.language,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedLanguage,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      isDense: true,
                      items: _languages.map((lang) {
                        return DropdownMenuItem<String>(
                          value: lang,
                          child: Text(
                            lang,
                            style: theme.textTheme.bodyMedium,
                          ),
                        );
                      }).toList(),
                      onChanged: _sending ? null : (value) {
                        if (value != null) {
                          setState(() => _selectedLanguage = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickScope(List<Book> books) async {
    if (_sending) return;
    final selection = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Answer from',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.library_books_rounded),
                        title: const Text('Entire Library'),
                        subtitle: Text(
                          'Search across all ${books.length} PDF'
                          '${books.length == 1 ? '' : 's'}',
                        ),
                        trailing: _selectedBookId == null
                            ? const Icon(Icons.check_circle)
                            : null,
                        onTap: () => Navigator.of(sheetContext).pop(-1),
                      ),
                      const Divider(height: 1),
                      for (final book in books)
                        ListTile(
                          leading: const Icon(Icons.picture_as_pdf_outlined),
                          title: Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${book.category.shortLabel} · Grade ${book.grade}',
                          ),
                          trailing: _selectedBookId == book.id
                              ? const Icon(Icons.check_circle)
                              : null,
                          onTap: () => Navigator.of(sheetContext).pop(book.id),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (selection == null || !mounted) return;

    setState(() {
      _selectedBookId = selection == -1 ? null : selection;
      _focusPage = null;
      _messages
        ..clear()
        ..add(_introMessage());
    });
    _scrollToBottom(animate: false);
  }

  // ── Chat list ──────────────────────────────────────────────────────────────

  Widget _buildChatList(AiSettings settings) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      children: [
        if (!settings.isConfigured) _buildKeyBanner(),
        for (final message in _messages) _buildMessage(message),
        if (_messages.length == 1) _buildSuggestions(),
        if (_sending) _buildTypingBubble(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildKeyBanner() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.tertiaryContainer.withValues(alpha: 0.55),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.key_outlined, color: colorScheme.onTertiaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Connect Gemini',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Add your free Gemini API key to start asking questions about '
              'your PDFs. The key stays on this device.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => showAiSettingsDialog(context, ref),
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Add API key'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(_ChatMessage message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (message.isError) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              color: colorScheme.onErrorContainer,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isUser = message.isUser;
    final bubbleColor =
        isUser ? colorScheme.primary : colorScheme.surfaceContainerHighest;
    final textColor = isUser ? colorScheme.onPrimary : colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.84,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser && !message.isIntro) ...[
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'TutorMate AI',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            // Use Markdown for nice formatting with bullets, bold, etc.
            MarkdownBody(
              data: _cleanText(message.text),
              styleSheet: MarkdownStyleSheet(
                p: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  height: 1.5,
                ),
                strong: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
                em: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontStyle: FontStyle.italic,
                ),
                listBullet: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                ),
                code: theme.textTheme.bodySmall?.copyWith(
                  color: textColor,
                  fontFamily: 'monospace',
                  backgroundColor: Colors.black12,
                ),
                blockquote: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
              selectable: true,
            ),
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final source in message.sources.take(6))
                    _sourceChip(source),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sourceChip(AiContextSource source) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.picture_as_pdf_outlined,
            size: 13,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${source.bookTitle} · p. ${source.pageNumber}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = <String>[
      if (_focusPage != null) 'Explain page $_focusPage',
      if (_focusPage != null) 'Summarize page $_focusPage',
      'Summarize the key points',
      'Explain the main ideas simply',
      'Give me 5 practice questions',
      'What are the important definitions?',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Try asking',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final suggestion in suggestions)
                ActionChip(
                  avatar: const Icon(Icons.auto_awesome, size: 15),
                  label: Text(suggestion),
                  onPressed: _sending ? null : () => _send(suggestion),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypingBubble() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.62,
              ),
              child: Text(
                _status.isEmpty ? 'Thinking...' : _status,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Composer ───────────────────────────────────────────────────────────────

  Widget _buildComposer() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Ask about your PDFs...',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send',
                  onPressed: _sending ? null : () => _send(),
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Answers come from your PDFs and may contain mistakes. '
                  'Double-check important facts.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _send([String? preset]) async {
    if (_sending) return;

    final question = (preset ?? _inputController.text).trim();
    if (question.isEmpty) return;

    final settings = ref.read(aiSettingsProvider);
    if (!settings.isConfigured) {
      await showAiSettingsDialog(context, ref);
      return;
    }

    final books = ref.read(allBooksProvider).valueOrNull ?? const <Book>[];
    if (books.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import a PDF first')),
      );
      return;
    }

    final selectedBook = _bookFromList(books, _selectedBookId);
    final scopeBooks = selectedBook == null ? books : [selectedBook];

    _inputController.clear();
    setState(() {
      _messages.add(_ChatMessage(text: question, isUser: true));
      _sending = true;
      _status = 'Preparing your PDFs...';
    });
    _scrollToBottom();

    try {
      final contextService = ref.read(pdfAiContextServiceProvider);
      final aiContext = await contextService.buildContext(
        books: scopeBooks,
        question: question,
        searchEntireLibrary: selectedBook == null,
        focusPage: selectedBook == null ? null : _focusPage,
        onStatus: (status) {
          if (mounted) setState(() => _status = status);
        },
      );

      if (!mounted) return;
      setState(() => _status = 'Asking Gemini...');

      final answer = await ref.read(geminiServiceProvider).generateAnswer(
            apiKey: settings.apiKey,
            model: settings.model,
            pdfContext: aiContext.text,
            question: question,
            responseLanguage: _selectedLanguage, // Pass selected language
            history: _buildHistory(),
          );

      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(text: answer, sources: aiContext.sources),
        );
      });
    } on AiException catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(text: error.message, isError: true));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'Something went wrong while answering. $error',
            isError: true,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  List<AiChatTurn> _buildHistory() {
    final turns = <AiChatTurn>[];
    for (final message in _messages) {
      if (message.isIntro || message.isError) continue;
      turns.add(
        AiChatTurn(
          role: message.isUser ? 'user' : 'model',
          text: message.text,
        ),
      );
    }
    // Drop the current question; it is supplied separately with the context.
    if (turns.isNotEmpty && turns.last.role == 'user') {
      turns.removeLast();
    }
    if (turns.length > 10) {
      return turns.sublist(turns.length - 10);
    }
    return turns;
  }

  Future<void> _confirmClearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New conversation?'),
        content: const Text(
          'This clears the chat history. Your PDFs and notes are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Start over'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() {
      _messages
        ..clear()
        ..add(_introMessage());
      _focusPage = null;
    });
    _scrollToBottom(animate: false);
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      final target = position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Book? _bookFromList(List<Book> books, int? id) {
    if (id == null) return null;
    for (final book in books) {
      if (book.id == id) return book;
    }
    return null;
  }

  String _cleanText(String text) {
    return text
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
        .replaceAll('`', '');
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final bool isIntro;
  final List<AiContextSource> sources;

  const _ChatMessage({
    required this.text,
    this.isUser = false,
    this.isError = false,
    this.isIntro = false,
    this.sources = const [],
  });
}
