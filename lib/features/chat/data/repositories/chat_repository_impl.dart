import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/network/base_repository.dart';
import '../../domain/entities/chat_entity.dart';
import '../datasources/chat_remote_data_source.dart';

abstract class ChatRepository {
  Future<Result<List<ConversationEntity>>> listInbox();
  Future<Result<String>> getOrCreateDm(String otherUserId);
  Future<Result<String>> getOrCreateSquadChat(String squadId);
  Future<Result<String>> getOrCreateCommunityChat(String communityId);
  Future<Result<String>> createGroupChat({required String title, required List<String> memberIds});
  Future<Result<List<Map<String, dynamic>>>> listParticipants(String conversationId);
  Future<Result<List<MessageEntity>>> getMessages(String conversationId);
  Future<Result<MessageEntity>> sendMessage(
    String conversationId,
    String body, {
    String? mediaUrl,
    String? mediaType,
  });
  Future<Result<String>> uploadChatMedia(File file);
  Future<Result<void>> pinMessage(String messageId, bool pinned);
  Future<Result<void>> deleteMessage(String messageId);
  Future<Result<void>> setConversationPinned(String conversationId, bool pinned);
  Future<Result<void>> setConversationMuted(String conversationId, bool muted);
  Future<Result<void>> archiveConversation(String conversationId);
  Future<Result<void>> markConversationRead(String conversationId);
  Future<Result<void>> reactToMessage(String messageId, String emoji);
  Future<Result<DateTime?>> otherLastReadAt(String conversationId);
  Future<Result<void>> sendTyping(String conversationId, bool isTyping);
  RealtimeChannel subscribeTyping(String conversationId, void Function(String userId, bool isTyping) onTyping);
  RealtimeChannel subscribeMessages(String conversationId, void Function(MessageEntity) onInsert);
}

class ChatRepositoryImpl with BaseRepository implements ChatRepository {
  ChatRepositoryImpl(this._remote);
  final ChatRemoteDataSource _remote;

  @override
  Future<Result<List<ConversationEntity>>> listInbox() =>
      guard(() => _remote.listInbox());

  @override
  Future<Result<String>> getOrCreateDm(String otherUserId) =>
      guard(() => _remote.getOrCreateDm(otherUserId));

  @override
  Future<Result<String>> getOrCreateSquadChat(String squadId) =>
      guard(() => _remote.getOrCreateSquadChat(squadId));

  @override
  Future<Result<String>> getOrCreateCommunityChat(String communityId) =>
      guard(() => _remote.getOrCreateCommunityChat(communityId));

  @override
  Future<Result<String>> createGroupChat({
    required String title,
    required List<String> memberIds,
  }) =>
      guard(() => _remote.createGroupChat(title: title, memberIds: memberIds));

  @override
  Future<Result<List<Map<String, dynamic>>>> listParticipants(String conversationId) =>
      guard(() => _remote.listParticipants(conversationId));

  @override
  Future<Result<List<MessageEntity>>> getMessages(String conversationId) =>
      guard(() => _remote.getMessages(conversationId));

  @override
  Future<Result<MessageEntity>> sendMessage(
    String conversationId,
    String body, {
    String? mediaUrl,
    String? mediaType,
  }) =>
      guard(() => _remote.sendMessage(
            conversationId,
            body,
            mediaUrl: mediaUrl,
            mediaType: mediaType,
          ));

  @override
  Future<Result<String>> uploadChatMedia(File file) =>
      guard(() => _remote.uploadChatMedia(file));

  @override
  Future<Result<void>> pinMessage(String messageId, bool pinned) =>
      guard(() => _remote.pinMessage(messageId, pinned));

  @override
  Future<Result<void>> deleteMessage(String messageId) =>
      guard(() => _remote.deleteMessage(messageId));

  @override
  Future<Result<void>> setConversationPinned(String conversationId, bool pinned) =>
      guard(() => _remote.setConversationPinned(conversationId, pinned));

  @override
  Future<Result<void>> setConversationMuted(String conversationId, bool muted) =>
      guard(() => _remote.setConversationMuted(conversationId, muted));

  @override
  Future<Result<void>> archiveConversation(String conversationId) =>
      guard(() => _remote.archiveConversation(conversationId));

  @override
  Future<Result<void>> markConversationRead(String conversationId) =>
      guard(() => _remote.markConversationRead(conversationId));

  @override
  Future<Result<void>> reactToMessage(String messageId, String emoji) =>
      guard(() => _remote.reactToMessage(messageId, emoji));

  @override
  Future<Result<DateTime?>> otherLastReadAt(String conversationId) =>
      guard(() => _remote.otherLastReadAt(conversationId));

  @override
  Future<Result<void>> sendTyping(String conversationId, bool isTyping) =>
      guard(() => _remote.sendTyping(conversationId, isTyping));

  @override
  RealtimeChannel subscribeTyping(
    String conversationId,
    void Function(String userId, bool isTyping) onTyping,
  ) =>
      _remote.subscribeTyping(conversationId, onTyping);

  @override
  RealtimeChannel subscribeMessages(
    String conversationId,
    void Function(MessageEntity) onInsert,
  ) =>
      _remote.subscribeMessages(conversationId, onInsert);
}
