import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Removed awesome_dialog to avoid native Rive dependency; using AlertDialog instead
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mskn/home_page.dart';
import 'package:mskn/seller_profile.dart';

class SellerRegister extends StatefulWidget {
  const SellerRegister({super.key});

  @override
  State<SellerRegister> createState() => _SellerRegisterState();
}

class _SellerRegisterState extends State<SellerRegister>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

  TextEditingController full_name = TextEditingController();
  TextEditingController email = TextEditingController();
  TextEditingController phone = TextEditingController();
  TextEditingController password = TextEditingController();
  bool isLoading = false;
  GlobalKey<FormState> formstate = GlobalKey<FormState>();
  TextEditingController confirm_password = TextEditingController();

  TextEditingController license_number = TextEditingController();
  TextEditingController licence_created = TextEditingController();
  TextEditingController licence_expired = TextEditingController();

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
                        padding: EdgeInsets.only(bottom: 80),
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
                                    'إنشاء حساب جديد | بائع',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 18 : 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[800],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(width: 44),
                              ],
                            ),

                            SizedBox(height: verticalSpacing * 1.5),

                            // Main content
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'انشاء حساب جديد',
                                  style: TextStyle(
                                    fontSize: headingSize,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.left,
                                ),
                                Text(
                                  'ادخل بياناتك لانشاء حسابك',
                                  style: TextStyle(
                                    fontSize: subheadingSize,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w300,
                                  ),
                                  textAlign: TextAlign.left,
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
                                            return 'الرجاء ادخال كلمة النرور';
                                          } else if (val!.length < 8) {
                                            return 'كلمة المرور يجب الا تقل عن ٨ رموز ';
                                          }
                                          return null;
                                        },
                                      ),

                                      SizedBox(height: verticalSpacing),

                                      // Confirm password field
                                      buildInputField(
                                        controller: confirm_password,
                                        label: 'اعادة كلمة المرور',
                                        hint: '**********',
                                        obscureText: true,
                                        validator: (val) {
                                          if (val == '') {
                                            return 'الرجاء ادخال اعادة كلمة النرور';
                                          } else if (val!.length < 8) {
                                            return 'اعادة كلمة المرور يجب الا تقل عن ٨ رموز ';
                                          } else if (val != password.text) {
                                            return 'كلمتا المرور غير متطابقتين';
                                          }
                                          return null;
                                        },
                                      ),

                                      SizedBox(height: verticalSpacing * 1.5),

                                      buildLicenseSection(context,
                                          isSmallScreen, verticalSpacing),
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
                            offset: Offset(0, -2),
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
                              if (context.mounted) {
                                final uid = credential.user!.uid;
                                await FirebaseFirestore.instance
                                    .collection('profile')
                                    .doc(uid)
                                    .set({
                                  'name': full_name.text.trim(),
                                  'phone': phone.text.trim(),
                                  'license_number': license_number.text.trim(),
                                  'licence_created':
                                      licence_created.text.trim(),
                                  'licence_expired':
                                      licence_expired.text.trim(),
                                  'x': '',
                                  'instagram': '',
                                  'snapchat': '',
                                  "rank": "seller",
                                  'created_at': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true));

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
                                  builder: (context) => AlertDialog(
                                    title: const Text('خطأ'),
                                    content: Text(errorMessage),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('موافق'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('خطأ'),
                                    content: Text('Error: ${e.toString()}'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
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
            style: TextStyle(
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
              borderSide: BorderSide(color: Colors.blue, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
          keyboardType: keyboardType,
        ),
      ],
    );
  }

  // Helper method to build license section
  Widget buildLicenseSection(
      BuildContext context, bool isSmallScreen, double verticalSpacing) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 16 : 20),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'بيانات رخصة الوساطة العقارية',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                  fontSize: isSmallScreen ? 14 : 16,
                ),
              ),
            ],
          ),
          SizedBox(height: verticalSpacing),
          buildInputField(
            controller: license_number,
            label: 'رقم الرخصة',
            hint: '123456789',
            validator: (val) {
              if (val == '') {
                return 'الرجاء إدخال رقم الرخصة';
              }
              return null;
            },
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: verticalSpacing),
          Column(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
                    child: Text(
                      'تاريخ إنشاء الرخصة',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  TextFormField(
                    controller: licence_created,
                    decoration: InputDecoration(
                      hintText: 'DD/MM/YYYY',
                      filled: true,
                      fillColor: Colors.grey[200],
                      suffixIcon: Icon(Icons.calendar_today, size: 20),
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
                        borderSide: BorderSide(color: Colors.blue, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                    ),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: ColorScheme.light(
                                primary: Colors.blue,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          licence_created.text =
                              "${picked.day}/${picked.month}/${picked.year}";
                        });
                      }
                    },
                    validator: (val) {
                      if (val == '') {
                        return 'الرجاء إدخال تاريخ إنشاء الرخصة';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
                    child: Text(
                      'تاريخ انتهاء الرخصة',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  TextFormField(
                    controller: licence_expired,
                    decoration: InputDecoration(
                      hintText: 'DD/MM/YYYY',
                      filled: true,
                      fillColor: Colors.grey[200],
                      suffixIcon: Icon(Icons.calendar_today, size: 20),
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
                        borderSide: BorderSide(color: Colors.blue, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                    ),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.now().add(const Duration(days: 365)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: ColorScheme.light(
                                primary: Colors.blue,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          licence_expired.text =
                              "${picked.day}/${picked.month}/${picked.year}";
                        });
                      }
                    },
                    validator: (val) {
                      if (val == '') {
                        return 'الرجاء إدخال تاريخ انتهاء الرخصة';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
