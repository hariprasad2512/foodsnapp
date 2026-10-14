// Placeholder — full shape per TECH_SPEC §5 lands in M6 (timeline).

class ChatMessage {
  final String id;
  final String senderId;
  final String text;

  const ChatMessage({required this.id, required this.senderId, required this.text});

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) =>
      ChatMessage(
        id: id,
        senderId: map['senderId'] as String? ?? '',
        text: map['text'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {'senderId': senderId, 'text': text};
}
