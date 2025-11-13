import 'firestore_service.dart';

class MessagingService {
  final FirestoreService _fs = FirestoreService();

  Future<String> openChat(String a, String b) async {
    return _fs.createOrGetChatId(a, b);
  }

  Future<void> sendMessage(String chatId, String senderId, String text) async {
    await _fs.sendMessage(chatId, senderId, text);
  }
}
