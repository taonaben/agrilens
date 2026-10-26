import 'dart:io';

import 'package:agrilens/app/chat/components/widgets/chat_action_bar.dart';
import 'package:agrilens/app/chat/components/widgets/chat_busy_indicator.dart';
import 'package:agrilens/app/chat/components/widgets/chat_composer.dart';
import 'package:agrilens/app/chat/components/widgets/chat_message_list.dart';
import 'package:agrilens/app/chat/components/widgets/chat_status_banner.dart';
import 'package:agrilens/app/chat/components/widgets/pending_image_preview_card.dart';
import 'package:agrilens/app/chat/services/remote_chat_service.dart';
import 'package:agrilens/shared/api/api_client.dart';
import 'package:agrilens/app/chat/models/message.dart';
import 'package:agrilens/app/chat/models/prediction.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:solar_icons/solar_icons.dart';

class ChatPage extends StatefulWidget {
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
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
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

  @override
  void initState() {
    super.initState();
    _reloadConversation();
  }

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _messageController.clear();
      _pendingImagePath = null;
      _inlineError = null;
      _loadError = null;
      _reloadConversation();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _reloadConversation() async {
    setState(() {
      _loadingConversation = true;
      _loadError = null;
    });
    try {
      final snapshot = await widget.chatService.loadConversation(
        widget.conversationId,
      );
      if (!mounted) return;
      setState(() {
        _messages = snapshot.messages;
        _predictionsByMessageId
          ..clear()
          ..addAll(snapshot.predictions);
        _answersByMessageId
          ..clear()
          ..addAll(snapshot.answers);
        _loadingConversation = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingConversation = false;
        _loadError = error.toString();
      });
    }
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
                    ? 'Camera permission is required to capture a leaf photo.'
                    : 'Photo access permission is required to choose a leaf photo.',
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
      _busyLabel = 'Sending leaf image to AgriLens...';
      _inlineError = null;
    });
    try {
      await widget.chatService.diagnose(
        widget.conversationId,
        path,
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
    setState(() {
      _busy = true;
      _busyLabel = 'Thinking...';
      _inlineError = null;
    });
    try {
      await widget.chatService.ask(widget.conversationId, text);
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
      await widget.chatService.retry(widget.conversationId);
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
        isBusy: _busy,
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
        isBusy: _busy,
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
