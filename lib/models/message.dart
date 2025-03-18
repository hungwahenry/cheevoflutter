//models/message.dart
class Message {
  final String text;
  final bool isFromMe;
  final int timestamp;
  
  Message({
    required this.text,
    required this.isFromMe,
    required this.timestamp,
  });
  
  // Convert from JSON (for data channel)
  factory Message.fromJson(Map<String, dynamic> json, bool isFromMe) {
    return Message(
      text: json['text'] as String,
      isFromMe: isFromMe,
      timestamp: json['timestamp'] as int,
    );
  }
  
  // Convert to JSON (for data channel)
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'timestamp': timestamp,
    };
  }
}