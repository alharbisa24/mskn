import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mskn/home_page.dart';

class EmailPasswordLogin extends StatefulWidget {
  const EmailPasswordLogin({super.key});

  @override
  State<EmailPasswordLogin> createState() => _EmailPasswordLoginState();
}

class _EmailPasswordLoginState extends State<EmailPasswordLogin> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

 Future<void> _signIn() async {
  if (!_formKey.currentState!.validate()) return;

  if (!mounted) return;
  setState(() => _isLoading = true);

  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final profileDoc = await FirebaseFirestore.instance
        .collection('profile')
        .doc(user.uid)
        .get();

    if (!mounted) return;

    if (profileDoc.exists) {



      if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (Route<dynamic> route) => false, 
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المستخدم غير موجود في النظام')),
      );
      await FirebaseAuth.instance.signOut();
    }
  } on FirebaseAuthException catch (e) {
    if (!mounted) return;

    String message = 'حدث خطأ أثناء تسجيل الدخول';
    if (e.code == 'user-not-found') message = 'لا يوجد مستخدم بهذا البريد';
    if (e.code == 'wrong-password') message = 'كلمة المرور غير صحيحة';
    if (e.code == 'invalid-email') message = 'البريد الإلكتروني غير صالح';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('خطأ غير متوقع: $e')),
    );
  } finally {
    if (!mounted) return;
    setState(() => _isLoading = false);
  }
}

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال البريد الإلكتروني أولاً')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'حدث خطأ أثناء إرسال رابط إعادة التعيين';
      if (e.code == 'user-not-found') {
        message = 'لا يوجد مستخدم بهذا البريد';
      } else if (e.code == 'invalid-email') {
        message = 'البريد الإلكتروني غير صالح';
      } else if (e.code == 'too-many-requests') {
        message = 'تم إرسال طلبات كثيرة، حاول مرة أخرى لاحقاً';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ غير متوقع: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios, color: Colors.grey[700], size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'تسجيل الدخول',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
              const SizedBox(height: 32),
              // Logo image at the top
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'images/logo.png',
                    fit: BoxFit.contain,
                    width: 120,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
                        child: Text(
                          'البريد الإلكتروني',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'الرجاء إدخال البريد الإلكتروني';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'example@email.com',
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
                        child: Text(
                          'كلمة المرور',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'الرجاء إدخال كلمة المرور';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: '********',
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Forgot password button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _resetPassword,
                        child: Text(
                          'نسيت كلمة المرور؟',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('دخول'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


