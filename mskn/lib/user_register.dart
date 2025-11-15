import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mskn/home_page.dart';

class BuyerRegister extends StatefulWidget {
  const BuyerRegister({super.key});

  @override
  State<BuyerRegister> createState() => _BuyerRegisterState();
}

class _BuyerRegisterState extends State<BuyerRegister>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  TextEditingController full_name = TextEditingController();
  TextEditingController email = TextEditingController();
  TextEditingController phone = TextEditingController();
  TextEditingController password = TextEditingController();
  TextEditingController confirm_password = TextEditingController();

  GlobalKey<FormState> formstate = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400;
    final isMediumScreen = screenSize.width >= 400 && screenSize.width < 600;

    final horizontalPadding = isSmallScreen ? 16.0 : 24.0;
    final verticalSpacing = isSmallScreen ? 16.0 : 20.0;

    final headingSize = isSmallScreen ? 24.0 : (isMediumScreen ? 28.0 : 30.0);
    final subheadingSize = isSmallScreen ? 14.0 : 16.0;

    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: isSmallScreen ? 16.0 : 24.0),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 80),
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
                                    border:
                                        Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.arrow_back_ios,
                                        color: Colors.grey[700], size: 18),
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'إنشاء حساب جديد | مشتري',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 18 : 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[800],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 44),
                              ],
                            ),
                            SizedBox(height: verticalSpacing * 1.5),

                            // Main content
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'انشاء حساب جديد',
                                  style: TextStyle(
                                    fontSize: headingSize,
                                    color: const Color(0xFF6B7280),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'ادخل بياناتك لانشاء حسابك',
                                  style: TextStyle(
                                    fontSize: subheadingSize,
                                    color: const Color(0xFF6B7280),
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                                SizedBox(height: verticalSpacing * 2),
                                Form(
                                  key: formstate,
                                  child: Column(
                                    children: [
                                      buildInputField(
                                        controller: full_name,
                                        label: 'الاسم الكامل',
                                        hint: 'محمد احمد',
                                        validator: (val) {
                                          if (val == '') {
                                            return 'الرجاء ادخال الاسم الكامل';
                                          }
                                          return null;
                                        },
                                        keyboardType: TextInputType.name,
                                      ),
                                      SizedBox(height: verticalSpacing),
                                      buildInputField(
                                        controller: email,
                                        label: 'البريد الالكتروني',
                                        hint: 'example@email.com',
                                        validator: (val) {
                                          if (val == '') {
                                            return 'الرجاء ادخال البريد الالكتروني';
                                          }
                                          return null;
                                        },
                                        keyboardType:
                                            TextInputType.emailAddress,
                                      ),
                                      SizedBox(height: verticalSpacing),
                                      buildInputField(
                                        controller: phone,
                                        label: 'رقم الجوال',
                                        hint: '966500000000',
                                        validator: (val) {
                                          if (val == '') {
                                            return 'الرجاء ادخال رقم الجوال';
                                          }
                                          return null;
                                        },
                                        keyboardType: TextInputType.phone,
                                      ),
                                      SizedBox(height: verticalSpacing),
                                      buildInputField(
                                        controller: password,
                                        label: 'كلمة المرور',
                                        hint: '**********',
                                        obscureText: true,
                                        validator: (val) {
                                          if (val == '') {
                                            return 'الرجاء ادخال كلمة المرور';
                                          } else if (val!.length < 8) {
                                            return 'كلمة المرور يجب الا تقل عن ٨ رموز ';
                                          }
                                          return null;
                                        },
                                      ),
                                      SizedBox(height: verticalSpacing),
                                      buildInputField(
                                        controller: confirm_password,
                                        label: 'اعادة كلمة المرور',
                                        hint: '**********',
                                        obscureText: true,
                                        validator: (val) {
                                          if (val == '') {
                                            return 'الرجاء ادخال اعادة كلمة المرور';
                                          } else if (val!.length < 8) {
                                            return 'اعادة كلمة المرور يجب الا تقل عن ٨ رموز ';
                                          } else if (val != password.text) {
                                            return 'كلمتا المرور غير متطابقتين';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // زر إنشاء الحساب
                  Positioned(
                    left: horizontalPadding,
                    right: horizontalPadding,
                    bottom: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: MaterialButton(
                        onPressed: () async {
                          if (formstate.currentState!.validate()) {
                            try {
                              final credential = await FirebaseAuth.instance
                                  .createUserWithEmailAndPassword(
                                email: email.text,
                                password: password.text,
                              );

                              final uid = credential.user!.uid;

                              await FirebaseFirestore.instance
                                  .collection('profile')
                                  .doc(uid)
                                  .set({
                                'name': full_name.text.trim(),
                                'phone': phone.text.trim(),
                                'license_number': '',
                                'licence_created': '',
                                'licence_expired': '',
                                'x': '',
                                'instagram': '',
                                'snapchat': '',
                                'rank': 'buyer',
                                'created_at': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));

                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                      builder: (_) => const HomePage()),
                                  (Route<dynamic> route) =>
                                      false, // هذا سيمسح كل الصفحات السابقة
                                );
                              }
                            } on FirebaseAuthException catch (e) {
                              String errorMessage = 'فشل في انشاء الحساب.';
                              if (e.code == 'weak-password') {
                                errorMessage = 'كلمة المرور ضعيفه جدا.';
                              } else if (e.code == 'email-already-in-use') {
                                errorMessage =
                                    'يوجد حساب مسجل مسبقا بنفس البريد الالكتروني.';
                              }
                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('خطأ'),
                                    content: Text(errorMessage),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(),
                                        child: const Text('موافق'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            }
                          }
                        },
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        color: Colors.blue,
                        elevation: 2,
                        padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 12 : 15),
                        child: Text('انشاء الحساب',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 14 : 16,
                            )),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText = false,
    required FormFieldValidator<String> validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
              fontSize: 14,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
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
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
          keyboardType: keyboardType,
        ),
      ],
    );
  }
}
