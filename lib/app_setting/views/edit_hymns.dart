import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // مكتبة لتنسيق التاريخ
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';

class EditHymns extends StatefulWidget {
  final DocumentSnapshot hymn;

  const EditHymns({super.key, required this.hymn});

  @override
  _EditHymnsState createState() => _EditHymnsState();
}

class _EditHymnsState extends State<EditHymns> {
  late TextEditingController _titleController;
  late TextEditingController _youtubeUrlController;
  late TextEditingController _dateController;
  bool _isLoading = false;
  DateTime? _selectedDate;

  // متغيرات للقوائم المنسدلة
  List<String> _albums = [];
  List<String> _categories = [];
  String? _selectedAlbum;
  String? _selectedCategory;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.hymn['songName']);
    _youtubeUrlController =
        TextEditingController(text: widget.hymn['youtubeUrl'] ?? '');

    // تحويل `Timestamp` إلى `DateTime` ثم إلى نص
    Timestamp timestamp = widget.hymn['dateAdded'];
    _selectedDate = timestamp.toDate();
    _dateController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(_selectedDate!));

    // تعيين القيم الأولية للألبوم والتصنيف
    _selectedAlbum = widget.hymn['songAlbum'];
    _selectedCategory = widget.hymn['songCategory'];

    // تحميل قوائم الألبومات والتصنيفات
    _loadAlbumsAndCategories();
  }

  // دالة لتحميل قوائم الألبومات والتصنيفات
  Future<void> _loadAlbumsAndCategories() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      // تحميل الألبومات
      final albumsSnapshot =
          await FirebaseFirestore.instance.collection('albums').get();

      List<String> albums = [];
      for (var doc in albumsSnapshot.docs) {
        String albumName = doc['name'];
        if (albumName != null && albumName.isNotEmpty) {
          albums.add(albumName);
        }
      }

      // تحميل التصنيفات
      final categoriesSnapshot =
          await FirebaseFirestore.instance.collection('categories').get();

      List<String> categories = [];
      for (var doc in categoriesSnapshot.docs) {
        String categoryName = doc['name'];
        if (categoryName != null && categoryName.isNotEmpty) {
          categories.add(categoryName);
        }
      }

      // تحديث الحالة
      if (mounted) {
        setState(() {
          _albums = albums;
          _categories = categories;
          _isLoadingData = false;

          // التأكد من أن القيم المحددة موجودة في القوائم
          if (_selectedAlbum != null && !_albums.contains(_selectedAlbum)) {
            _albums.add(_selectedAlbum!);
          }

          if (_selectedCategory != null &&
              !_categories.contains(_selectedCategory)) {
            _categories.add(_selectedCategory!);
          }
        });
      }
    } catch (e) {
      print('❌ خطأ في تحميل الألبومات والتصنيفات: $e');
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ في تحميل البيانات')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _updateHymn() async {
    if (_titleController.text.isEmpty ||
        _selectedCategory == null ||
        _selectedAlbum == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("يجب إدخال جميع البيانات المطلوبة")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('hymns')
          .doc(widget.hymn.id)
          .update({
        'songName': _titleController.text,
        'songAlbum': _selectedAlbum,
        'songCategory': _selectedCategory,
        'youtubeUrl': _youtubeUrlController.text,
        'dateAdded': Timestamp.fromDate(_selectedDate!), // حفظ التاريخ الجديد
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ تم تعديل الترنيمة بنجاح")),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ حدث خطأ أثناء تعديل الترنيمة")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title:
            Text("تعديل الترنيمة", style: TextStyle(color: AppColors.appamber)),
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.appamber),
      ),
      body: _isLoadingData
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.appamber),
                  SizedBox(height: 16),
                  Text(
                    "جاري تحميل البيانات...",
                    style: TextStyle(color: AppColors.appamber),
                  ),
                ],
              ),
            )
          : Padding(
              padding: EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(_titleController, "اسم الترنيمة"),
                    SizedBox(height: 16),

                    // قائمة الألبومات المنسدلة
                    _buildDropdown(
                      "الألبوم",
                      _selectedAlbum,
                      _albums,
                      (value) {
                        setState(() {
                          _selectedAlbum = value;
                        });
                      },
                    ),
                    SizedBox(height: 16),

                    // قائمة التصنيفات المنسدلة
                    _buildDropdown(
                      "التصنيف",
                      _selectedCategory,
                      _categories,
                      (value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                    ),
                    SizedBox(height: 16),

                    _buildTextField(
                        _youtubeUrlController, "رابط YouTube (اختياري)"),
                    SizedBox(height: 16),
                    _buildDatePicker(),
                    SizedBox(height: 24),
                    _buildButtons(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      style: TextStyle(color: AppColors.appamber),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.appamber),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.appamber),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.black.withOpacity(0.1),
      ),
    );
  }

  // دالة لبناء القائمة المنسدلة
  Widget _buildDropdown(String label, String? selectedValue, List<String> items,
      Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.appamber,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.appamber),
            borderRadius: BorderRadius.circular(8),
            color: Colors.black.withOpacity(0.1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedValue,
              isExpanded: true,
              dropdownColor: AppColors.backgroundColor,
              style: TextStyle(color: AppColors.appamber, fontSize: 16),
              icon: Icon(Icons.arrow_drop_down, color: AppColors.appamber),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: onChanged,
              hint: Text(
                "اختر $label",
                style: TextStyle(color: AppColors.appamber.withOpacity(0.7)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "تاريخ الإضافة",
          style: TextStyle(
            color: AppColors.appamber,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: _dateController,
          readOnly: true,
          style: TextStyle(color: AppColors.appamber),
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.appamber),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
              borderRadius: BorderRadius.circular(8),
            ),
            suffixIcon: IconButton(
              icon: Icon(Icons.calendar_today, color: AppColors.appamber),
              onPressed: _selectDate,
            ),
            filled: true,
            fillColor: Colors.black.withOpacity(0.1),
          ),
          onTap: _selectDate,
        ),
      ],
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => Navigator.pop(context),
          child: Text("إلغاء",
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _isLoading ? null : _updateHymn,
          child: _isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text("حفظ التعديلات",
                  style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ],
    );
  }
}
