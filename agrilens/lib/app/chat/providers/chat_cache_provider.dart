import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/remote_chat_service.dart';

/// Keeps the last server snapshot in memory while a conversation is refreshed.
final chatSnapshotCacheProvider =
    StateProvider<Map<String, RemoteConversationSnapshot>>((ref) => {});
