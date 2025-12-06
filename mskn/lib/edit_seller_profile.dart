import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditSellerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> initialData;
  const EditSellerProfileScreen({super.key, required this.initialData});

  @override
  State<EditSellerProfileScreen> createState() =>
      _EditSellerProfileScreenState();
}

class _EditSellerProfileScreenState extends State<EditSellerProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _licenseNumber;
  late final TextEditingController _licenceCreated;
  late final TextEditingController _licenceExpired;
  late final TextEditingController _x;
  late final TextEditingController _instagram;
  late final TextEditingController _snapchat;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _name = TextEditingController(text: (d['name'] ?? '').toString());
    _phone = TextEditingController(text: (d['phone'] ?? '').toString());
    _licenseNumber =
        TextEditingController(text: (d['license_number'] ?? '').toString());
    _licenceCreated =
        TextEditingController(text: (d['licence_created'] ?? '').toString());
    _licenceExpired =
        TextEditingController(text: (d['licence_expired'] ?? '').toString());
    _x = TextEditingController(text: (d['x'] ?? '').toString());
    _instagram = TextEditingController(text: (d['instagram'] ?? '').toString());
    _snapchat = TextEditingController(text: (d['snapchat'] ?? '').toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _licenseNumber.dispose();
    _licenceCreated.dispose();
    _licenceExpired.dispose();
    _x.dispose();
    _instagram.dispose();
    _snapchat.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller,
      {DateTime? firstDate, DateTime? initialDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.blue)),
        child: child!,
      ),
    );
    if (picked != null) {
      controller.text = "${picked.day}/${picked.month}/${picked.year}";
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('profile').doc(user.uid).set({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'license_number': _licenseNumber.text.trim(),
        'licence_created': _licenceCreated.text.trim(),
        'licence_expired': _licenceExpired.text.trim(),
        'x': _x.text.trim(),
        'instagram': _instagram.text.trim(),
        'snapchat': _snapchat.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث البيانات بنجاح')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('حصل خطأ أثناء الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 4, top: 12),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280))),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save, size: 18),
            label: const Text('حفظ'),
          )
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label('الاسم'),
                TextFormField(
                  controller: _name,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'الرجاء إدخال الاسم'
                      : null,
                  decoration: _dec('الاسم الكامل'),
                ),
                _label('رقم الجوال'),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'الرجاء إدخال رقم الجوال'
                      : null,
                  decoration: _dec('05xxxxxxxx'),
                ),
                _label('رقم الرخصة'),
                TextFormField(
                  controller: _licenseNumber,
                  keyboardType: TextInputType.number,
                  decoration: _dec('123456789'),
                ),
                _label('تاريخ إنشاء الرخصة'),
                TextFormField(
                  controller: _licenceCreated,
                  readOnly: true,
                  onTap: () => _pickDate(_licenceCreated),
                  decoration: _dec('DD/MM/YYYY')
                      .copyWith(suffixIcon: const Icon(Icons.calendar_today)),
                ),
                _label('تاريخ انتهاء الرخصة'),
                TextFormField(
                  controller: _licenceExpired,
                  readOnly: true,
                  onTap: () => _pickDate(_licenceExpired,
                      firstDate: DateTime.now(),
                      initialDate:
                          DateTime.now().add(const Duration(days: 365))),
                  decoration: _dec('DD/MM/YYYY')
                      .copyWith(suffixIcon: const Icon(Icons.calendar_today)),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                const Text('روابط التواصل',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                _label('X'),
                TextFormField(
                    controller: _x, decoration: _dec('@username')),
                _label('انستقرام'),
                TextFormField(
                    controller: _instagram, decoration: _dec('username')),
                _label('سناب شات'),
                TextFormField(
                    controller: _snapchat, decoration: _dec('username')),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: Text(_isSaving ? 'جارٍ الحفظ...' : 'حفظ التعديلات'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
