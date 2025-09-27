import 'package:flutter/material.dart';
import 'package:mskn/seller_register.dart';

class RegisterMenu extends StatefulWidget {
  const RegisterMenu({super.key});

  @override
  State<RegisterMenu> createState() => _RegisterMenuState();
}

class _RegisterMenuState extends State<RegisterMenu> with TickerProviderStateMixin {
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: EdgeInsets.symmetric(vertical: 40),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // شريط علوي مودرن
                    Container(
                      padding: EdgeInsets.only(top: 20, bottom: 30),
                      child: Row(
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
                          Expanded(
                            child: Text(
                              'إنشاء حساب جديد',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[800],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(width: 44), 
                        ],
                      ),
                    ),
                    
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'images/logo.png',
                                fit: BoxFit.contain,
                                width: 120,

                              )
                        ),
                          
                          SizedBox(height: 32),
                          
                          Text(
                            'اختر نوع الحساب',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'حدد طريقة الدخول المناسبة لك',
                            style: TextStyle(
                              fontSize: 16, 
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          SizedBox(height: 48),
                          
                          // بطاقة الأزرار المودرن
                          Container(
                            padding: EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey[200]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF111827).withOpacity(0.04),
                                  blurRadius: 32,
                                  offset: Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // زر مشتري مودرن
                                _buildUserTypeButton(
                                  text: 'انشاء الحساب كمشتري',
                                  icon: Icons.shopping_bag_outlined,
                                  color: Color(0xFF6366F1),
                                  backgroundColor: Color(0xFF6366F1).withOpacity(0.08),
                                  onPressed: () {
                                  },
                                ),
                                
                                SizedBox(height: 16),
                                
                                // خط فاصل مودرن
                                Row(
                                  children: [
                                    Expanded(child: Container(height: 1, color: Color(0xFFE5E7EB))),
                                    Container(
                                      margin: EdgeInsets.symmetric(horizontal: 16),
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),

                                      child: Text(
                                        'أو',
                                        style: TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Container(height: 1, color: Color(0xFFE5E7EB))),
                                  ],
                                ),
                                
                                SizedBox(height: 16),
                                
                                // زر بائع مودرن
                                _buildUserTypeButton(
                                  text: 'انشاء الحساب كبائع',
                                  icon: Icons.storefront_outlined,
                                  color: Color(0xFFF59E0B),
                                  backgroundColor: Color(0xFFF59E0B).withOpacity(0.08),
                                  onPressed: () {
                                    Navigator.of(context).push(MaterialPageRoute(builder: (context)=> SellerRegister()));
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // نص في الأسفل مودرن
                    Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Text(
                        'بالمتابعة، فإنك توافق على شروط الخدمة وسياسة الخصوصية',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
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
  
  Widget _buildUserTypeButton({
    required String text,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                    textAlign: TextAlign.center,
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