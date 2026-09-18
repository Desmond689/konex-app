import 'package:flutter_test/flutter_test.dart';
import 'package:konex/features/chat/domain/entities/chat_entity.dart';

void main() {
  group('MessageEntity', () {
    test('reactions map is empty by default', () {
      final m = MessageEntity(
        id: '1',
        conversationId: 'c1',
        senderId: 'u1',
        senderName: 'vortex',
        body: 'hello',
        createdAt: DateTime.now(),
      );
      expect(m.reactions, isEmpty);
      expect(m.pinned, isFalse);
      expect(m.mediaUrl, isNull);
    });

    test('props include reactions and pinned', () {
      final now = DateTime.now();
      final a = MessageEntity(
        id: '1',
        conversationId: 'c1',
        senderId: 'u1',
        senderName: 'vortex',
        body: 'hi',
        createdAt: now,
        reactions: const {'🔥': 2},
        pinned: true,
      );
      final b = MessageEntity(
        id: '1',
        conversationId: 'c1',
        senderId: 'u1',
        senderName: 'vortex',
        body: 'hi',
        createdAt: now,
        reactions: const {'🔥': 2},
        pinned: true,
      );
      expect(a, equals(b));
    });
  });
}
