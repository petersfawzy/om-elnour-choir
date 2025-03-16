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
  late TextEditingController _albumController;
  late TextEditingController _categoryController;
  late TextEditingController _youtubeUrlController;
  late TextEditingController _dateController;
  bool _isLoading = false;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.hymn['songName']);
    _albumController =
        TextEditingController(text: widget.hymn['songAlbum'] ?? '');
    _categoryController =
        TextEditingController(text: widget.hymn['songCategory'] ?? '');
    _youtubeUrlController =
        TextEditingController(text: widget.hymn['youtubeUrl'] ?? '');

    // تحويل `Timestamp` إلى `DateTime` ثم إلى نص
    Timestamp timestamp = widget.hymn['dateAdded'];
    _selectedDate = timestamp.toDate();
    _dateController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(_selectedDate!));
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
        _categoryController.text.isEmpty ||
        _albumController.text.isEmpty) {
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
        'songAlbum': _albumController.text,
        'songCategory': _categoryController.text,
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
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(_titleController, "اسم الترنيمة"),
            SizedBox(height: 10),
            _buildTextField(_albumController, "الألبوم"),
            SizedBox(height: 10),
            _buildTextField(_categoryController, "التصنيف"),
            SizedBox(height: 10),
            _buildTextField(_youtubeUrlController, "رابط YouTube (اختياري)"),
            SizedBox(height: 10),
            _buildDatePicker(),
            SizedBox(height: 20),
            _buildButtons(),
          ],
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
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return TextField(
      controller: _dateController,
      readOnly: true,
      style: TextStyle(color: AppColors.appamber),
      decoration: InputDecoration(
        labelText: "تاريخ الإضافة",
        labelStyle: TextStyle(color: AppColors.appamber),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.appamber),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
        suffixIcon: IconButton(
          icon: Icon(Icons.calendar_today, color: AppColors.appamber),
          onPressed: _selectDate,
        ),
      ),
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
          ),
          onPressed: () => Navigator.pop(context),
          child: Text("إلغاء",
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: _isLoading ? null : _updateHymn,
          child: _isLoading
              ? CircularProgressIndicator(color: Colors.white)
              : Text("حفظ التعديلات",
                  style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ],
    );
  }
}
