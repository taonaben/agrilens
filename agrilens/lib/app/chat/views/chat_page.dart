import 'dart:io';

import 'package:agrilens/app/chat/components/widgets/chat_action_bar.dart';
import 'package:agrilens/app/chat/components/widgets/chat_busy_indicator.dart';
import 'package:agrilens/app/chat/components/widgets/chat_composer.dart';
import 'package:agrilens/app/chat/components/widgets/chat_message_list.dart';
import 'package:agrilens/app/chat/components/widgets/chat_status_banner.dart';
import 'package:agrilens/app/chat/components/widgets/pending_image_preview_card.dart';
import 'package:agrilens/app/chat/data/message_repository.dart';
import 'package:agrilens/app/chat/data/prediction_repository.dart';
import 'package:agrilens/app/chat/models/message.dart';
import 'package:agrilens/app/chat/models/prediction.dart';
import 'package:agrilens/app/chat/services/diagnosis_pipeline.dart';
import 'package:agrilens/app/chat/services/pipeline_result.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.pipeline,
    required this.messageRepository,
    required this.predictionRepository,
    required this.conversationId,
    required this.onCreateConversation,
    required this.onConversationChanged,
    this.serviceWarning,
  });

  final DiagnosisPipeline pipeline;
  final MessageRepository messageRepository;
  final PredictionRepository predictionRepository;
  final String conversationId;
  final Future<String> Function() onCreateConversation;
  final Future<void> Function() onConversationChanged;
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
  String? _pendingImagePath;

  List<MessageModel> _messages = const [];
  final Map<String, Prediction> _predictionsByMessageId = {};

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
    });

    final messages = await widget.messageRepository.getMessagesForConversation(
      widget.conversationId,
    );

    final predictionMap = <String, Prediction>{};
    for (final msg in messages) {
      if (msg.contentType != MessageContentType.image) continue;
      final prediction = await widget.predictionRepository
          .getPredictionForMessage(msg.id);
      if (prediction != null) {
        predictionMap[msg.id] = prediction;
      }
    }

    if (!mounted) return;
    setState(() {
      _messages = messages;
      _predictionsByMessageId
        ..clear()
        ..addAll(predictionMap);
      _loadingConversation = false;
    });
  }

  Future<void> _newConversation() async {
    setState(() {
      _inlineError = null;
    });
    await widget.onCreateConversation();
    await widget.onConversationChanged();
  }

  Future<void> _selectImage(ImageSource source) async {
    final permitted = await _ensurePermission(source);
    if (!permitted) {
      if (!mounted) return;
      setState(() {
        _inlineError =
            source == ImageSource.camera
                ? 'Camera permission is required to capture a leaf photo.'
                : 'Photo access permission is required to choose a leaf photo.';
      });
      return;
    }

    final file = await _picker.pickImage(
      source: source,
      imageQuality: 95,
      maxWidth: 2048,
    );
    if (file == null || !mounted) return;
    setState(() {
      _pendingImagePath = file.path;
      _inlineError = null;
    });
  }

  Future<bool> _ensurePermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      return status.isGranted;
    }

    final photos = await Permission.photos.request();
    if (photos.isGranted || photos.isLimited) return true;

    if (Platform.isAndroid) {
      final storage = await Permission.storage.request();
      return storage.isGranted;
    }

    return false;
  }

  Future<void> _analyzeImage() async {
    final imagePath = _pendingImagePath;
    if (imagePath == null) {
      setState(() {
        _inlineError = 'Please capture or select an image first.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _busyLabel = 'Analysing leaf image...';
      _inlineError = null;
    });

    final result = await widget.pipeline.analyzeImage(
      conversationId: widget.conversationId,
      sourceImagePath: imagePath,
    );

    if (!mounted) return;

    switch (result) {
      case AnalyzeImageSuccess():
        setState(() {
          _pendingImagePath = null;
        });
      case AnalyzeImagePartialSuccess(:final generationFailureReason):
        setState(() {
          _pendingImagePath = null;
          _inlineError =
              'Prediction was saved, but response generation failed: $generationFailureReason';
        });
      case AnalyzeImageFailure(:final message):
        setState(() {
          _inlineError = message;
        });
    }

    await _reloadConversation();
    await widget.onConversationChanged();

    if (!mounted) return;
    setState(() {
      _busy = false;
      _busyLabel = null;
    });
  }

  Future<void> _sendFollowUp() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _busy = true;
      _busyLabel = 'Generating response...';
      _inlineError = null;
    });

    final result = await widget.pipeline.sendFollowUp(
      conversationId: widget.conversationId,
      text: text,
    );

    if (!mounted) return;

    switch (result) {
      case SendFollowUpSuccess():
        _messageController.clear();
      case SendFollowUpFailure(:final message):
        _inlineError = message;
    }

    await _reloadConversation();
    await widget.onConversationChanged();

    if (!mounted) return;
    setState(() {
      _busy = false;
      _busyLabel = null;
    });
  }

  Future<void> _retryAssistant() async {
    setState(() {
      _busy = true;
      _busyLabel = 'Retrying response generation...';
      _inlineError = null;
    });

    final result = await widget.pipeline.retryAssistantResponse(
      conversationId: widget.conversationId,
    );

    if (!mounted) return;
    switch (result) {
      case AnalyzeImageSuccess():
        break;
      case AnalyzeImagePartialSuccess(:final generationFailureReason):
        _inlineError =
            'Retry still failed: $generationFailureReason. You can retry again.';
      case AnalyzeImageFailure(:final message):
        _inlineError = message;
    }

    await _reloadConversation();
    await widget.onConversationChanged();

    if (!mounted) return;
    setState(() {
      _busy = false;
      _busyLabel = null;
    });
  }

  bool get _hasFailedAssistantMessage {
    return _messages.any(
      (m) =>
          m.role == MessageRole.assistant &&
          m.lifecycle == MessageLifecycle.failed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ChatActionBar(
          isBusy: _busy,
          showRetryAction: _hasFailedAssistantMessage,
          onCameraTap: () => _selectImage(ImageSource.camera),
          onGalleryTap: () => _selectImage(ImageSource.gallery),
          onNewChatTap: _newConversation,
          onRetryTap: _retryAssistant,
          onCancelTap: () {
            widget.pipeline.cancelGeneration();
            setState(() {
              _busy = false;
              _busyLabel = null;
            });
          },
        ),
        if (widget.serviceWarning != null)
          ChatStatusBanner(message: widget.serviceWarning!, opacity: 0.4),
        if (_inlineError != null)
          ChatStatusBanner(message: _inlineError!, opacity: 0.35),
        if (_pendingImagePath != null)
          PendingImagePreviewCard(
            imagePath: _pendingImagePath!,
            isBusy: _busy,
            onAnalyzeTap: _analyzeImage,
            onRetakeTap: () {
              setState(() {
                _pendingImagePath = null;
              });
            },
          ),
        if (_busyLabel != null) ChatBusyIndicator(label: _busyLabel!),
        Expanded(
          child: ChatMessageList(
            isLoading: _loadingConversation,
            messages: _messages,
            predictionsByMessageId: _predictionsByMessageId,
          ),
        ),
        ChatComposer(
          controller: _messageController,
          isBusy: _busy,
          onSend: _sendFollowUp,
        ),
      ],
    );
  }
}
