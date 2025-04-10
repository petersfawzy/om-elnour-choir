import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_states.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VerceCubit extends Cubit<VerceState> {
  String currentVerse = "";
  DateTime _lastFetchDate = DateTime.now(); // تخزين آخر تاريخ تم فيه جلب الآية

  // مفاتيح التخزين المؤقت
  static const String _cachedVerseKey = 'cached_verse';
  static const String _cachedVerseDateKey = 'cached_verse_date';

  VerceCubit() : super(VerceInitial()) {
    // تحميل تاريخ آخر جلب من التخزين المؤقت عند إنشاء الكيوبت
    _loadLastFetchDate();
  }

  static VerceCubit get(context) => BlocProvider.of(context);

  // تحميل تاريخ آخر جلب من التخزين المؤقت
  Future<void> _loadLastFetchDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastFetchMillis = prefs.getInt(_cachedVerseDateKey);

      if (lastFetchMillis != null) {
        _lastFetchDate = DateTime.fromMillisecondsSinceEpoch(lastFetchMillis);
        print(
            "📅 تم تحميل تاريخ آخر جلب من التخزين المؤقت: ${_lastFetchDate.toString()}");
      }
    } catch (e) {
      print("❌ خطأ في تحميل تاريخ آخر جلب: $e");
    }
  }

  // حفظ تاريخ آخر جلب في التخزين المؤقت
  Future<void> _saveLastFetchDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _cachedVerseDateKey, _lastFetchDate.millisecondsSinceEpoch);
      print(
          "💾 تم حفظ تاريخ آخر جلب في التخزين المؤقت: ${_lastFetchDate.toString()}");
    } catch (e) {
      print("❌ خطأ في حفظ تاريخ آخر جلب: $e");
    }
  }

  // حفظ الآية في التخزين المؤقت
  Future<void> _cacheVerse(String verse) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedVerseKey, verse);
      print(
          "💾 تم تخزين الآية مؤقتًا: ${verse.substring(0, min(30, verse.length))}...");
    } catch (e) {
      print("❌ خطأ في تخزين الآية مؤقتًا: $e");
    }
  }

  // تحميل الآية من التخزين المؤقت
  Future<String?> _loadCachedVerse() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedVerse = prefs.getString(_cachedVerseKey);

      if (cachedVerse != null && cachedVerse.isNotEmpty) {
        print(
            "📖 تم تحميل الآية من التخزين المؤقت: ${cachedVerse.substring(0, min(30, cachedVerse.length))}...");
        return cachedVerse;
      }
      return null;
    } catch (e) {
      print("❌ خطأ في تحميل الآية من التخزين المؤقت: $e");
      return null;
    }
  }

  // تحسين دالة fetchVerse للبحث عن آية اليوم حسب التوقيت المحلي للمستخدم
  void fetchVerse() async {
    try {
      emit(VerceLoading());

      // الحصول على تاريخ اليوم في بداية اليوم (00:00:00) بالتوقيت المحلي للمستخدم
      DateTime now = DateTime.now();
      DateTime todayStart = DateTime(now.year, now.month, now.day);

      // التحقق مما إذا كان اليوم هو نفس يوم آخر جلب
      bool isSameDay = _lastFetchDate.year == now.year &&
          _lastFetchDate.month == now.month &&
          _lastFetchDate.day == now.day;

      // إذا كان نفس اليوم، نحاول تحميل الآية من التخزين المؤقت
      if (isSameDay) {
        final cachedVerse = await _loadCachedVerse();
        if (cachedVerse != null) {
          currentVerse = cachedVerse;
          emit(VerceLoaded(cachedVerse));
          print("✅ تم استخدام الآية المخزنة مؤقتًا لنفس اليوم");
          return;
        }
      }

      // إذا لم نجد آية مخزنة مؤقتًا أو كان يومًا جديدًا، نجلب من Firestore
      String todayDateString = "${now.day}/${now.month}/${now.year}";

      print("📅 البحث عن آية بتاريخ: ${DateFormat('dd/MM/yyyy').format(now)}");
      print("🔍 تنسيق التاريخ النصي: $todayDateString");
      print("🕒 بداية اليوم بالتوقيت المحلي: ${todayStart.toIso8601String()}");

      // تحويل التاريخ المحلي إلى Timestamp للبحث
      Timestamp todayTimestamp = Timestamp.fromDate(todayStart);

      // البحث عن آية اليوم باستخدام حقل dateTimestamp أولاً (أكثر دقة)
      var timestampSnapshot = await FirebaseFirestore.instance
          .collection('verses')
          .where('dateTimestamp', isEqualTo: todayTimestamp)
          .limit(1)
          .get();

      if (timestampSnapshot.docs.isNotEmpty) {
        var todayVerseData = timestampSnapshot.docs.first.data();
        String verseContent = todayVerseData['content'].toString().trim();
        print("✅ تم استرجاع الآية باستخدام dateTimestamp: $verseContent");

        String arabicVerse = convertNumbersToArabic(verseContent);
        currentVerse = arabicVerse;
        _lastFetchDate = now; // تحديث تاريخ آخر جلب

        // حفظ الآية وتاريخ الجلب في التخزين المؤقت
        await _cacheVerse(arabicVerse);
        await _saveLastFetchDate();

        emit(VerceLoaded(arabicVerse));
        return;
      }

      // إذا لم نجد آية باستخدام dateTimestamp، نبحث باستخدام التنسيق النصي
      print(
          "⚠️ لم يتم العثور على آية باستخدام dateTimestamp، جاري البحث باستخدام التنسيق النصي");

      var snapshot = await FirebaseFirestore.instance
          .collection('verses')
          .where('date', isEqualTo: todayDateString)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        var todayVerseData = snapshot.docs.first.data();
        String verseContent = todayVerseData['content'].toString().trim();
        print("✅ تم استرجاع الآية باستخدام التنسيق النصي: $verseContent");

        // تحديث حقل dateTimestamp إذا كان غير موجود
        if (!todayVerseData.containsKey('dateTimestamp') ||
            todayVerseData['dateTimestamp'] == null) {
          await FirebaseFirestore.instance
              .collection('verses')
              .doc(snapshot.docs.first.id)
              .update({
            'dateTimestamp': todayTimestamp,
          });
          print("✅ تم تحديث حقل dateTimestamp للآية");
        }

        String arabicVerse = convertNumbersToArabic(verseContent);
        currentVerse = arabicVerse;
        _lastFetchDate = now; // تحديث تاريخ آخر جلب

        // حفظ الآية وتاريخ الجلب في التخزين المؤقت
        await _cacheVerse(arabicVerse);
        await _saveLastFetchDate();

        emit(VerceLoaded(arabicVerse));
        return;
      }

      // إذا لم نجد آية لليوم الحالي، نبحث عن أحدث آية
      print("⚠️ لم يتم العثور على آية لليوم الحالي، جاري البحث عن أحدث آية");

      var latestVerseSnapshot = await FirebaseFirestore.instance
          .collection('verses')
          .orderBy('dateTimestamp', descending: true)
          .limit(1)
          .get();

      if (latestVerseSnapshot.docs.isNotEmpty) {
        var latestVerseData = latestVerseSnapshot.docs.first.data();
        String verseContent = latestVerseData['content'].toString().trim();
        print("✅ تم استرجاع أحدث آية: $verseContent");

        String arabicVerse = convertNumbersToArabic(verseContent);
        currentVerse = arabicVerse;
        _lastFetchDate = now; // تحديث تاريخ آخر جلب

        // حفظ الآية وتاريخ الجلب في التخزين المؤقت
        await _cacheVerse(arabicVerse);
        await _saveLastFetchDate();

        emit(VerceLoaded(arabicVerse));
        return;
      }

      // إذا لم نجد أي آية، نعرض رسالة مناسبة
      print("⚠️ لم يتم العثور على أي آية");
      emit(VerceError("لم يتم العثور على آية لليوم"));
    } catch (e) {
      print("❌ خطأ في استرجاع الآية: $e");

      // في حالة الخطأ، نحاول استخدام الآية المخزنة مؤقتًا
      final cachedVerse = await _loadCachedVerse();
      if (cachedVerse != null) {
        currentVerse = cachedVerse;
        emit(VerceLoaded(cachedVerse));
        print("✅ تم استخدام الآية المخزنة مؤقتًا بسبب خطأ في الاتصال");
        return;
      }

      emit(VerceError("حدث خطأ أثناء تحميل الآية: $e"));
    }
  }

  // التحقق مما إذا كان يجب تحديث الآية (إذا تغير اليوم)
  bool shouldUpdateVerse() {
    DateTime now = DateTime.now();
    DateTime lastFetchDay =
        DateTime(_lastFetchDate.year, _lastFetchDate.month, _lastFetchDate.day);
    DateTime today = DateTime(now.year, now.month, now.day);

    return lastFetchDay.isBefore(today);
  }

  // دالة للتحقق من تحديث الآية عند استئناف التطبيق
  void checkForVerseUpdate() {
    if (shouldUpdateVerse()) {
      print("📅 تم اكتشاف يوم جديد، جاري تحديث الآية");
      fetchVerse();
    }
  }

  String convertNumbersToArabic(String input) {
    const englishNumbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    for (int i = 0; i < englishNumbers.length; i++) {
      input = input.replaceAll(englishNumbers[i], arabicNumbers[i]);
    }
    return input;
  }

  // تحسين دالة createVerce لحفظ الآية بالتنسيقين
  Future<bool> createVerce(
      {required String content, required String date}) async {
    try {
      emit(VerceLoading());

      // تحويل التاريخ من النص إلى كائن DateTime
      List<String> dateParts = date.split('/');
      if (dateParts.length != 3) {
        throw Exception("تنسيق التاريخ غير صحيح");
      }

      int day = int.parse(dateParts[0]);
      int month = int.parse(dateParts[1]);
      int year = int.parse(dateParts[2]);

      // إنشاء كائن DateTime في بداية اليوم (00:00:00)
      DateTime dateTime = DateTime(year, month, day);
      Timestamp dateTimestamp = Timestamp.fromDate(dateTime);

      print("📅 إضافة/تحديث آية بتاريخ: $date (${dateTime.toIso8601String()})");

      // التحقق من وجود آية بنفس التاريخ (بأي من التنسيقين)
      var existingVerses = await FirebaseFirestore.instance
          .collection('verses')
          .where('date', isEqualTo: date)
          .get();

      if (existingVerses.docs.isNotEmpty) {
        // إذا كانت هناك آية موجودة بالفعل في هذا التاريخ، قم بتحديثها
        await FirebaseFirestore.instance
            .collection('verses')
            .doc(existingVerses.docs.first.id)
            .update({
          'content': content,
          'dateTimestamp': dateTimestamp, // تحديث التنسيق الجديد أيضًا
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print("✅ تم تحديث الآية الموجودة بتاريخ: $date");
      } else {
        // البحث باستخدام dateTimestamp
        var timestampVerses = await FirebaseFirestore.instance
            .collection('verses')
            .where('dateTimestamp', isEqualTo: dateTimestamp)
            .get();

        if (timestampVerses.docs.isNotEmpty) {
          // تحديث الآية الموجودة
          await FirebaseFirestore.instance
              .collection('verses')
              .doc(timestampVerses.docs.first.id)
              .update({
            'content': content,
            'date': date, // تحديث التنسيق القديم أيضًا
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print("✅ تم تحديث الآية الموجودة باستخدام dateTimestamp");
        } else {
          // إضافة آية جديدة بكلا التنسيقين
          await FirebaseFirestore.instance.collection('verses').add({
            'content': content,
            'date': date,
            'dateTimestamp': dateTimestamp,
            'createdAt': FieldValue.serverTimestamp(),
          });
          print("✅ تم إضافة آية جديدة بتاريخ: $date");
        }
      }

      // التحقق مما إذا كانت الآية المضافة هي لليوم الحالي
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);

      if (dateTime.isAtSameMomentAs(today)) {
        // إذا كانت الآية لليوم الحالي، قم بتحديثها في الواجهة
        String arabicVerse = convertNumbersToArabic(content);
        currentVerse = arabicVerse;

        // تحديث التخزين المؤقت
        await _cacheVerse(arabicVerse);
        _lastFetchDate = now;
        await _saveLastFetchDate();

        emit(VerceLoaded(arabicVerse));
      } else {
        // إذا كانت الآية ليست لليوم الحالي، أعد تحميل آية اليوم الحالي
        print("⚠️ الآية المضافة ليست لليوم الحالي، جاري إعادة تحميل آية اليوم");
        fetchVerse();
      }

      return true;
    } catch (e) {
      print("❌ خطأ في إضافة/تحديث الآية: $e");
      emit(VerceError("حدث خطأ أثناء حفظ الآية: $e"));
      return false;
    }
  }

  // دالة ترحيل البيانات القديمة لإضافة حقل dateTimestamp
  Future<void> migrateOldVerses() async {
    try {
      print("🔄 بدء ترحيل الآيات القديمة...");

      // الحصول على جميع الآيات التي لا تحتوي على حقل dateTimestamp
      var snapshot =
          await FirebaseFirestore.instance.collection('verses').get();

      int migratedCount = 0;
      for (var doc in snapshot.docs) {
        try {
          var data = doc.data();

          // تخطي الوثائق التي تحتوي بالفعل على dateTimestamp صحيح
          if (data.containsKey('dateTimestamp') &&
              data['dateTimestamp'] != null) {
            continue;
          }

          // التحقق من وجود حقل date
          if (!data.containsKey('date') || data['date'] == null) {
            print("⚠️ الوثيقة ${doc.id} لا تحتوي على حقل date");
            continue;
          }

          String dateStr = data['date'];
          List<String> dateParts = dateStr.split('/');
          if (dateParts.length != 3) {
            print("⚠️ تنسيق تاريخ غير صحيح: $dateStr في الوثيقة ${doc.id}");
            continue;
          }

          int day = int.parse(dateParts[0]);
          int month = int.parse(dateParts[1]);
          int year = int.parse(dateParts[2]);

          // إنشاء كائن DateTime في بداية اليوم (00:00:00)
          DateTime dateTime = DateTime(year, month, day);
          Timestamp dateTimestamp = Timestamp.fromDate(dateTime);

          await FirebaseFirestore.instance
              .collection('verses')
              .doc(doc.id)
              .update({
            'dateTimestamp': dateTimestamp,
          });

          migratedCount++;
          print("✅ تم ترحيل الآية بتاريخ: $dateStr (${doc.id})");
        } catch (e) {
          print("❌ خطأ في ترحيل الآية ${doc.id}: $e");
        }
      }

      print("✅ اكتمل ترحيل الآيات القديمة. تم ترحيل $migratedCount آية");
    } catch (e) {
      print("❌ خطأ في عملية الترحيل: $e");
    }
  }

  // دالة مساعدة للحصول على الحد الأدنى من رقمين
  int min(int a, int b) {
    return a < b ? a : b;
  }
}
