import 'dart:io';

import 'package:agrilens/app/chat/components/widgets/chat_action_bar.dart';
import 'package:agrilens/app/chat/components/widgets/chat_busy_indicator.dart';
import 'package:agrilens/app/chat/components/widgets/chat_composer.dart';
import 'package:agrilens/app/chat/components/widgets/chat_message_list.dart';
import 'package:agrilens/app/chat/components/widgets/chat_status_banner.dart';
import 'package:agrilens/app/chat/components/widgets/pending_image_preview_card.dart';
import 'package:agrilens/app/chat/providers/chat_cache_provider.dart';
import 'package:agrilens/app/chat/services/remote_chat_service.dart';
import 'package:agrilens/shared/api/api_client.dart';
import 'package:agrilens/app/chat/models/message.dart';
import 'package:agrilens/app/chat/models/prediction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({
    super.key,
    required this.chatService,
    required this.conversationId,
    required this.onCreateConversation,
    required this.onConversationChanged,
    required this.onDeleteConversation,
    this.serviceWarning,
  });

  final RemoteChatService chatService;
  final String conversationId;
  final Future<String> Function() onCreateConversation;
  final Future<void> Function() onConversationChanged;
  final Future<void> Function(String conversationId) onDeleteConversation;
  final String? serviceWarning;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageController = TextEditingController();
  final _picker = ImagePicker();
  bool _loadingConversation = true;
  bool _busy = false;
  String? _busyLabel;
  String? _inlineError;
  String? _loadError;
  String? _pendingImagePath;
  List<MessageModel> _messages = const [];
  final Map<String, Prediction> _predictionsByMessageId = {};
  final Map<String, AnswerMetadata> _answersByMessageId = {};
  final _scrollController = ScrollController();
  static const _responseLanguagePreferenceKey = 'chat_response_language';
  String _responseLanguage = 'english';
  bool _responseLanguageReady = false;

  @override
  void initState() {
    super.initState();
    _loadResponseLanguage();
    final cached = ref.read(chatSnapshotCacheProvider)[widget.conversationId];
    if (cached != null) {
      _applySnapshot(cached);
      _loadingConversation = false;
    }
    _reloadConversation();
  }

  Future<void> _loadResponseLanguage() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_responseLanguagePreferenceKey);
    if (!mounted) return;
    setState(() {
      if (saved == 'english' || saved == 'shona' || saved == 'ndebele') {
        _responseLanguage = saved!;
      }
      _responseLanguageReady = true;
    });
  }

  Future<void> _setResponseLanguage(String language) async {
    setState(() => _responseLanguage = language);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_responseLanguagePreferenceKey, language);
  }

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _messageController.clear();
      _pendingImagePath = null;
      _inlineError = null;
      _loadError = null;
      final cached = ref.read(chatSnapshotCacheProvider)[widget.conversationId];
      if (cached != null) {
        _applySnapshot(cached);
        _loadingConversation = false;
      } else {
        _messages = const [];
        _predictionsByMessageId.clear();
        _answersByMessageId.clear();
        _loadingConversation = true;
      }
      _reloadConversation();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _reloadConversation() async {
    final cached = ref.read(chatSnapshotCacheProvider)[widget.conversationId];
    setState(() {
      // Retain cached messages while refreshing so the chat never blanks out.
      _loadingConversation = cached == null;
      _loadError = null;
    });
    try {
      final snapshot = await widget.chatService.loadConversation(
        widget.conversationId,
      );
      if (!mounted) return;
      ref
          .read(chatSnapshotCacheProvider.notifier)
          .update((cache) => {...cache, widget.conversationId: snapshot});
      setState(() {
        _applySnapshot(snapshot);
        _loadingConversation = false;
      });
      _scrollToLatest();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingConversation = false;
        // Keep a usable cached conversation visible if refresh fails.
        _loadError = cached == null ? error.toString() : null;
        if (cached != null) _inlineError = error.toString();
      });
    }
  }

  void _applySnapshot(RemoteConversationSnapshot snapshot) {
    _messages = snapshot.messages;
    _predictionsByMessageId
      ..clear()
      ..addAll(snapshot.predictions);
    _answersByMessageId
      ..clear()
      ..addAll(snapshot.answers);
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _newConversation() async {
    setState(() => _inlineError = null);
    try {
      await widget.onCreateConversation();
      await widget.onConversationChanged();
    } catch (error) {
      if (mounted) setState(() => _inlineError = error.toString());
    }
  }

  Future<void> _deleteConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete conversation?'),
            content: const Text('This also deletes its saved leaf photos.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.onDeleteConversation(widget.conversationId);
      await widget.onConversationChanged();
    } catch (error) {
      if (mounted) setState(() => _inlineError = error.toString());
    }
  }

  Future<void> _selectImage(ImageSource source) async {
    final permitted = await _ensurePermission(source);
    if (!permitted) {
      if (!mounted) return;
      setState(
        () =>
            _inlineError =
                source == ImageSource.camera
                    ? 'Camera permission is required to photograph a maize or tomato pest or crop symptom.'
                    : 'Photo access permission is required to choose a maize or tomato pest or crop symptom photo.',
      );
      return;
    }
    final file = await _picker.pickImage(source: source);
    if (file == null || !mounted) return;
    setState(() {
      _pendingImagePath = file.path;
      _inlineError = null;
    });
  }

  Future<void> _replacePendingImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder:
          (context) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(SolarIconsOutline.camera),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(SolarIconsOutline.gallery),
                  title: const Text('Choose from gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
    );
    if (source != null) {
      await _selectImage(source);
    }
  }

  Future<bool> _ensurePermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      return (await Permission.camera.request()).isGranted;
    }
    final photos = await Permission.photos.request();
    if (photos.isGranted || photos.isLimited) return true;
    if (Platform.isAndroid) {
      return (await Permission.storage.request()).isGranted;
    }
    return false;
  }

  Future<void> _analyzeImage() async {
    final path = _pendingImagePath;
    if (path == null) {
      setState(() => _inlineError = 'Please capture or select an image first.');
      return;
    }
    setState(() {
      _busy = true;
      _busyLabel = 'Sending crop photo to AgriLens...';
      _inlineError = null;
    });
    try {
      await widget.chatService.diagnose(
        widget.conversationId,
        path,
        responseLanguage: _responseLanguage,
        onDiagnosisSaved: () {
          if (mounted) setState(() => _pendingImagePath = null);
        },
      );
      await widget.chatService.loadConversation(widget.conversationId);
      await widget.onConversationChanged();
      await _reloadConversation();
    } catch (error) {
      if (mounted) setState(() => _inlineError = error.toString());
      await _reloadConversation();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyLabel = null;
        });
      }
    }
  }

  Future<void> _sendFollowUp() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final now = DateTime.now();
    final pending = MessageModel(
      id: 'pending-${now.microsecondsSinceEpoch}',
      conversationId: widget.conversationId,
      role: MessageRole.user,
      contentType: MessageContentType.text,
      textContent: text,
      lifecycle: MessageLifecycle.pending,
      createdAt: now,
      updatedAt: now,
    );
    setState(() {
      _messages = [..._messages, pending];
      _busy = true;
      _busyLabel = 'Thinking...';
      _inlineError = null;
    });
    final cached = ref.read(chatSnapshotCacheProvider)[widget.conversationId];
    if (cached != null) {
      ref
          .read(chatSnapshotCacheProvider.notifier)
          .update(
            (cache) => {
              ...cache,
              widget.conversationId: RemoteConversationSnapshot(
                conversation: cached.conversation,
                messages: _messages,
                predictions: cached.predictions,
                answers: cached.answers,
              ),
            },
          );
    }
    _scrollToLatest();
    try {
      await widget.chatService.ask(
        widget.conversationId,
        text,
        responseLanguage: _responseLanguage,
      );
      _messageController.clear();
      await widget.onConversationChanged();
      await _reloadConversation();
    } catch (error) {
      if (error is ApiRequestException && error.followUpWasSaved) {
        _messageController.clear();
      }
      if (mounted) setState(() => _inlineError = error.toString());
      await _reloadConversation();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyLabel = null;
        });
      }
    }
  }

  Future<void> _retryAssistant() async {
    setState(() {
      _busy = true;
      _busyLabel = 'Retrying response...';
      _inlineError = null;
    });
    try {
      await widget.chatService.retry(
        widget.conversationId,
        responseLanguage: _responseLanguage,
      );
      await widget.onConversationChanged();
      await _reloadConversation();
    } catch (error) {
      if (mounted) setState(() => _inlineError = error.toString());
      await _reloadConversation();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyLabel = null;
        });
      }
    }
  }

  Future<void> _handleSendPressed() async {
    if (_busy) return;
    if (_pendingImagePath != null) {
      await _analyzeImage();
      return;
    }
    await _sendFollowUp();
  }

  bool get _hasFailedAssistantMessage => _messages.any(
    (message) =>
        message.role.name == 'assistant' && message.lifecycle.name == 'failed',
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ChatActionBar(
        isBusy: _busy || !_responseLanguageReady,
        responseLanguage: _responseLanguage,
        onResponseLanguageChanged: _setResponseLanguage,
        showRetryAction: _hasFailedAssistantMessage,
        onNewChatTap: _newConversation,
        onRetryTap: _retryAssistant,
        onDeleteTap: _deleteConversation,
        onCancelTap: widget.chatService.cancel,
      ),
      if (widget.serviceWarning != null)
        ChatStatusBanner(message: widget.serviceWarning!, opacity: 0.4),
      Expanded(
        child:
            _loadError == null
                ? ChatMessageList(
                  isLoading: _loadingConversation,
                  messages: _messages,
                  predictionsByMessageId: _predictionsByMessageId,
                  answersByMessageId: _answersByMessageId,
                  controller: _scrollController,
                )
                : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _reloadConversation,
                          child: const Text('Retry loading'),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
      if (_busyLabel != null) ChatBusyIndicator(label: _busyLabel!),
      if (_inlineError != null)
        ChatStatusBanner(message: _inlineError!, opacity: 0.35),
      ChatComposer(
        controller: _messageController,
        isBusy: _busy || !_responseLanguageReady,
        hasPendingImage: _pendingImagePath != null,
        attachmentPreview:
            _pendingImagePath == null
                ? null
                : PendingImagePreviewCard(
                  imagePath: _pendingImagePath!,
                  isBusy: _busy,
                  onClearTap: () => setState(() => _pendingImagePath = null),
                  onReplaceTap: _replacePendingImage,
                ),
        onCameraTap: () => _selectImage(ImageSource.camera),
        onGalleryTap: () => _selectImage(ImageSource.gallery),
        onSend: _handleSendPressed,
      ),
    ],
  );
}
