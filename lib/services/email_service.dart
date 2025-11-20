import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // REPLACE WITH YOUR GMAIL AND APP PASSWORD
  static const String _gmailUser = 'morenorudues@gmail.com';
  static const String _gmailAppPassword = 'tstr antt pfts aiad';

  String _generateOTP() {
    return (100000 + Random().nextInt(900000)).toString();
  }

  Future<String?> sendOTP(String email) async {
    try {
      final otp = _generateOTP();
      await _firestore.collection('otp_codes').doc(email).set({
        'otp': otp,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(Duration(minutes: 10)).millisecondsSinceEpoch,
      });
      
      final smtpServer = gmail(_gmailUser, _gmailAppPassword);
      final message = Message()
        ..from = Address(_gmailUser, 'FishOn App')
        ..recipients.add(email)
        ..subject = 'FishOn Password Reset OTP'
        ..html = '<h2>Password Reset</h2><p>Your OTP: <strong style="font-size:24px;color:#2196F3">$otp</strong></p><p>Expires in 10 minutes.</p>';
      
      await send(message, smtpServer);
      print('OTP sent to $email');
      
      return otp;
    } catch (e) {
      print('Error sending OTP: $e');
      return null;
    }
  }

  Future<bool> verifyOTP(String email, String otp) async {
    try {
      final doc = await _firestore.collection('otp_codes').doc(email).get();
      if (!doc.exists) return false;
      
      final data = doc.data()!;
      final storedOTP = data['otp'];
      final expiresAt = data['expiresAt'];
      
      if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
        await _firestore.collection('otp_codes').doc(email).delete();
        return false;
      }
      
      return storedOTP == otp;
    } catch (e) {
      print('Error verifying OTP: $e');
      return false;
    }
  }

  Future<void> deleteOTP(String email) async {
    try {
      await _firestore.collection('otp_codes').doc(email).delete();
    } catch (e) {
      print('Error deleting OTP: $e');
    }
  }
}
