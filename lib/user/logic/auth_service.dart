import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // دالة بسيطة للتسجيل
  void _log(String message, {Object? error}) {
    print('AuthService: $message');
    if (error != null) {
      print('Error: $error');
    }
  }

  // الحصول على المستخدم الحالي
  User? get currentUser => _auth.currentUser;

  // تسجيل الدخول باستخدام البريد الإلكتروني وكلمة المرور
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
    BuildContext context,
  ) async {
    try {
      _log('محاولة تسجيل الدخول: $email');

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _log('تم تسجيل الدخول بنجاح: ${userCredential.user?.uid}');

      // التحقق من وجود بيانات المستخدم في Firestore
      DocumentSnapshot userDoc =
          await _firestore
              .collection('userData')
              .doc(userCredential.user!.uid)
              .get();

      if (!userDoc.exists) {
        _log(
          'بيانات المستخدم غير موجودة في Firestore: ${userCredential.user?.uid}',
        );

        // إنشاء بيانات المستخدم في Firestore إذا لم تكن موجودة
        await _firestore
            .collection('userData')
            .doc(userCredential.user!.uid)
            .set({
              'email': email,
              'name': userCredential.user!.displayName ?? 'مستخدم جديد',
              'phoneNumber': userCredential.user!.phoneNumber ?? '',
              'role': 'member',
              'createdAt': FieldValue.serverTimestamp(),
            });

        _log(
          'تم إنشاء بيانات المستخدم في Firestore: ${userCredential.user?.uid}',
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      _log('خطأ في تسجيل الدخول', error: e);

      String errorMessage = 'حدث خطأ أثناء تسجيل الدخول';

      if (e.code == 'user-not-found') {
        errorMessage = 'لم يتم العثور على حساب بهذا البريد الإلكتروني';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'كلمة المرور غير صحيحة';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'البريد الإلكتروني غير صالح';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'تم تعطيل هذا الحساب';
      } else if (e.code == 'too-many-requests') {
        errorMessage =
            'تم تجاوز الحد الأقصى من المحاولات. يرجى المحاولة لاحقًا.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );

      return null;
    } catch (e) {
      _log('خطأ غير متوقع في تسجيل الدخول', error: e);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ غير متوقع: $e'),
          backgroundColor: Colors.red,
        ),
      );

      return null;
    }
  }

  // إنشاء حساب جديد باستخدام البريد الإلكتروني وكلمة المرور
  Future<UserCredential?> registerWithEmailAndPassword(
    String email,
    String password,
    String name,
    String phone,
    BuildContext context,
  ) async {
    try {
      _log('محاولة إنشاء حساب جديد: $email');

      // التحقق من وجود البريد الإلكتروني في Firestore أولاً
      QuerySnapshot querySnapshot =
          await _firestore
              .collection('userData')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        // البريد موجود في Firestore ولكن قد لا يكون موجودًا في Authentication
        _log('البريد الإلكتروني موجود في Firestore: $email');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'البريد الإلكتروني مسجل بالفعل في قاعدة البيانات. جاري محاولة إصلاح الحساب...',
            ),
            backgroundColor: Colors.orange,
          ),
        );

        // محاولة إنشاء المستخدم في Authentication
        try {
          UserCredential userCredential = await _auth
              .createUserWithEmailAndPassword(email: email, password: password);

          _log(
            'تم إنشاء حساب جديد في Authentication: ${userCredential.user?.uid}',
          );

          // ربط الحساب الجديد بالبيانات الموجودة في Firestore
          await _firestore
              .collection('userData')
              .doc(userCredential.user!.uid)
              .set({
                'email': email,
                'name': name,
                'phoneNumber': phone,
                'role': 'member',
                'createdAt': FieldValue.serverTimestamp(),
              });

          _log('تم ربط الحساب بالبيانات الموجودة في Firestore');

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إصلاح الحساب بنجاح!'),
              backgroundColor: Colors.green,
            ),
          );

          return userCredential;
        } catch (authError) {
          // إذا فشلت محاولة الإنشاء، قد يكون الحساب موجودًا بالفعل في Authentication
          _log('فشل إنشاء الحساب في Authentication', error: authError);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'البريد الإلكتروني مسجل بالفعل. يرجى تسجيل الدخول أو استخدام بريد إلكتروني آخر.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return null;
        }
      }

      // إذا لم يكن البريد موجودًا، قم بإنشاء حساب جديد
      _log('إنشاء حساب جديد عبر البريد الإلكتروني');

      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // إنشاء بيانات المستخدم في Firestore
      await _firestore
          .collection('userData')
          .doc(userCredential.user!.uid)
          .set({
            'email': email,
            'name': name,
            'phoneNumber': phone,
            'role': 'member',
            'createdAt': FieldValue.serverTimestamp(),
          });

      _log('تم إنشاء الحساب بنجاح: ${userCredential.user?.uid}');

      // إرسال بريد التحقق
      await userCredential.user!.sendEmailVerification();

      _log('تم إرسال بريد التحقق إلى: $email');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إنشاء الحساب بنجاح! تم إرسال رابط التحقق إلى بريدك الإلكتروني.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      _log('خطأ في إنشاء الحساب: ${e.code}', error: e);

      String errorMessage = 'حدث خطأ أثناء إنشاء الحساب';

      if (e.code == 'email-already-in-use') {
        errorMessage = 'البريد الإلكتروني مستخدم بالفعل';
      } else if (e.code == 'weak-password') {
        errorMessage = 'كلمة المرور ضعيفة جدًا';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'البريد الإلكتروني غير صالح';
      } else if (e.code == 'operation-not-allowed') {
        errorMessage = 'تسجيل البريد الإلكتروني وكلمة المرور غير مفعل';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );

      return null;
    } catch (e) {
      _log('خطأ غير متوقع في إنشاء الحساب', error: e);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ غير متوقع: $e'),
          backgroundColor: Colors.red,
        ),
      );

      return null;
    }
  }

  // تسجيل الخروج
  Future<void> signOut() async {
    try {
      _log('تسجيل الخروج');
      await _auth.signOut();
      _log('تم تسجيل الخروج بنجاح');
    } catch (e) {
      _log('خطأ في تسجيل الخروج', error: e);
      throw e;
    }
  }

  // إعادة تعيين كلمة المرور
  Future<void> resetPassword(String email, BuildContext context) async {
    try {
      _log('إرسال بريد إعادة تعيين كلمة المرور إلى: $email');
      await _auth.sendPasswordResetEmail(email: email);

      _log('تم إرسال بريد إعادة تعيين كلمة المرور بنجاح');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      _log('خطأ في إرسال بريد إعادة تعيين كلمة المرور: ${e.code}', error: e);

      String errorMessage = 'حدث خطأ أثناء إرسال بريد إعادة تعيين كلمة المرور';

      if (e.code == 'user-not-found') {
        errorMessage = 'لم يتم العثور على حساب بهذا البريد الإلكتروني';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'البريد الإلكتروني غير صالح';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } catch (e) {
      _log('خطأ غير متوقع في إرسال بريد إعادة تعيين كلمة المرور', error: e);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ غير متوقع: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // حذف الحساب
  Future<bool> deleteAccount(String password, BuildContext context) async {
    try {
      _log('محاولة حذف الحساب');

      // الحصول على المستخدم الحالي
      final user = _auth.currentUser;
      if (user == null) {
        _log('لا يوجد مستخدم حالي');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يوجد مستخدم مسجل الدخول'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      // إعادة المصادقة قبل حذف الحساب
      final email = user.email;
      if (email == null) {
        _log('لا يوجد بريد إلكتروني للمستخدم الحالي');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لا يمكن حذف الحساب: لا يوجد بريد إلكتروني مرتبط بالحساب',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      // إعادة المصادقة
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      _log('تمت إعادة المصادقة بنجاح');

      // حذف بيانات المستخدم من Firestore
      await _firestore.collection('userData').doc(user.uid).delete();
      _log('تم حذف بيانات المستخدم من Firestore');

      // حذف المفضلة
      final favoritesSnapshot =
          await _firestore
              .collection('favorites')
              .where('userId', isEqualTo: user.uid)
              .get();

      for (var doc in favoritesSnapshot.docs) {
        await doc.reference.delete();
      }
      _log('تم حذف المفضلة للمستخدم');

      // حذف الحساب من Firebase Authentication
      await user.delete();
      _log('تم حذف الحساب بنجاح');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الحساب بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      return true;
    } on FirebaseAuthException catch (e) {
      _log('خطأ في حذف الحساب: ${e.code}', error: e);

      String errorMessage = 'حدث خطأ أثناء حذف الحساب';

      if (e.code == 'requires-recent-login') {
        errorMessage =
            'يرجى تسجيل الخروج وإعادة تسجيل الدخول ثم المحاولة مرة أخرى';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'كلمة المر��ر غير صحيحة';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'لم يتم العثور على المستخدم';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );

      return false;
    } catch (e) {
      _log('خطأ غير متوقع في حذف الحساب', error: e);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ غير متوقع: $e'),
          backgroundColor: Colors.red,
        ),
      );

      return false;
    }
  }

  // إصلاح قاعدة البيانات
  Future<void> repairDatabase(BuildContext context) async {
    try {
      _log('بدء إصلاح قاعدة البيانات');

      // الحصول على جميع المستخدمين من Firestore
      final firestoreUsers = await _firestore.collection('userData').get();

      // عرض رسالة بعدد المستخدمين
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم العثور على ${firestoreUsers.docs.length} مستخدم في Firestore',
          ),
          backgroundColor: Colors.blue,
        ),
      );

      _log('تم إصلاح قاعدة البيانات بنجاح');
    } catch (e) {
      _log('خطأ في إصلاح قاعدة البيانات', error: e);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء إصلاح قاعدة البيانات: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // التحقق من حالة تسجيل الدخول
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // الحصول على بيانات المستخدم من Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      _log('جلب بيانات المستخدم: $uid');

      DocumentSnapshot doc =
          await _firestore.collection('userData').doc(uid).get();

      if (doc.exists) {
        _log('تم جلب بيانات المستخدم بنجاح');
        return doc.data() as Map<String, dynamic>;
      } else {
        _log('بيانات المستخدم غير موجودة: $uid');
        return null;
      }
    } catch (e) {
      _log('خطأ في جلب بيانات المستخدم', error: e);
      return null;
    }
  }

  // تحديث بيانات المستخدم في Firestore
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      _log('تحديث بيانات المستخدم: $uid');
      await _firestore.collection('userData').doc(uid).update(data);
      _log('تم تحديث بيانات المستخدم بنجاح');
    } catch (e) {
      _log('خطأ في تحديث بيانات المستخدم', error: e);
      throw e;
    }
  }
}
