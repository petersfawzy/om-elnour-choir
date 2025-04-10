import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // إنشاء مستخدم جديد
  Future<void> createUser({
    required String uid,
    required String name,
    required String email,
    required String phone,
    String? profileImage,
  }) async {
    try {
      await _firestore.collection("userData").doc(uid).set({
        "uid": uid,
        "name": name,
        "email": email,
        "phoneNumber": phone,
        "role": "member", // الدور الافتراضي هو "member"
        "profileImage": profileImage ?? "assets/images/logo.png",
        "createdAt": FieldValue.serverTimestamp(),
      });
      print('✅ تم إنشاء بيانات المستخدم بنجاح');
    } catch (e) {
      print('❌ خطأ في إنشاء بيانات المستخدم: $e');
      throw e;
    }
  }

  // تحديث بيانات المستخدم
  Future<void> updateUserData({
    required String uid,
    String? name,
    String? phone,
    String? profileImage,
  }) async {
    try {
      Map<String, dynamic> updateData = {};

      if (name != null) updateData['name'] = name;
      if (phone != null) updateData['phoneNumber'] = phone;
      if (profileImage != null) updateData['profileImage'] = profileImage;

      if (updateData.isNotEmpty) {
        updateData['updatedAt'] = FieldValue.serverTimestamp();
        await _firestore.collection("userData").doc(uid).update(updateData);
        print('✅ تم تحديث بيانات المستخدم بنجاح');
      }
    } catch (e) {
      print('❌ خطأ في تحديث بيانات المستخدم: $e');
      throw e;
    }
  }

  // جلب بيانات المستخدم
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection("userData").doc(uid).get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      } else {
        print('⚠️ لم يتم العثور على بيانات المستخدم');
        return null;
      }
    } catch (e) {
      print('❌ خطأ في جلب بيانات المستخدم: $e');
      throw e;
    }
  }

  // التحقق مما إذا كان المستخدم مسؤولاً
  Future<bool> isUserAdmin(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection("userData").doc(uid).get();

      if (doc.exists) {
        Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
        return userData['role'] == 'admin';
      }

      return false;
    } catch (e) {
      print('❌ خطأ في التحقق من صلاحيات المستخدم: $e');
      return false;
    }
  }

  // تسجيل الخروج
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('✅ تم تسجيل الخروج بنجاح');
    } catch (e) {
      print('❌ خطأ في تسجيل الخروج: $e');
      throw e;
    }
  }
}
