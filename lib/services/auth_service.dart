import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Rule: google_sign_in v7.2.0 requires manual initialization and web client ID.
  // The client_id is typically the Web client ID for Firebase Authentication.
  // We'll initialize it according to the rule.
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<void> initGoogleSignIn() async {
    // Required step for google_sign_in >= v7.2.0 (as per the User's rule)
    await _googleSignIn.initialize();
  }

  // 1. Sign In with Email/Password
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  // 2. Register with Email/Password
  Future<UserCredential?> registerWithEmail(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  // 3. Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // BƯỚC 1: Buộc khởi tạo (Rule cho v7.2.0)
      // Theo luật của người dùng: dùng .authenticate() và chỉ lấy idToken
      
      // Khởi tạo đã được gọi ở main hoặc init
      // Dùng _googleSignIn.authenticate()
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate(); 

      if (googleUser == null) {
        throw Exception('Người dùng đã hủy đăng nhập');
      }

      // BƯỚC 2: Lấy thông tin xác thực
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // BƯỚC 3: Tạo Credential mới (Chỉ lấy idToken theo rule)
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // BƯỚC 4: Firebase Đăng nhập
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  // 4. Reset Password
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  // 5. Sign Out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }
}
