import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mskn/firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mskn/home_page.dart';
import 'package:mskn/register_menu.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مسكن',
      locale: const Locale('ar'),
      theme: ThemeData(
        primaryColor: const Color(0xFF1A73E8),
        scaffoldBackgroundColor: Colors.white,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A73E8),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
        textTheme: GoogleFonts.tajawalTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: _handleAppStartup(),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );
  }

  Widget _handleAppStartup() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Check if user is logged in
        final isLoggedIn = snapshot.hasData && snapshot.data != null;

        if (isLoggedIn) {
          return const HomePage();
        } else {
          return const OnboardingScreen();
        }
      },
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _onboardingItems = [
    OnboardingItem(
      title: 'مرحباً بك في مسكن',
      description: 'تطبيقك الأمثل للعثور على العقار المناسب بكل سهولة وذكاء',
      color: const Color(0xFF1A73E8),
      imageIcon: Icons.home_rounded,
    ),
    OnboardingItem(
      title: 'خريطة تفاعلية متطورة',
      description:
          'استعرض أنسب الخيارات العقارية مباشرة على الخريطة بطريقة تفاعلية',
      color: const Color(0xFF34A853),
      imageIcon: Icons.map_rounded,
    ),
    OnboardingItem(
      title: 'المساعد الذكي',
      description:
          'استفد من مساعدنا الذكي للحصول على أفضل النصائح والتوصيات العقارية',
      color: const Color(0xFFEA4335),
      imageIcon: Icons.assistant_rounded,
    ),
    OnboardingItem(
      title: 'حاسبة القروض',
      description:
          'احسب قروضك العقارية بسهولة ودقة عالية وحدد الخيار الأمثل لك',
      color: const Color(0xFFFBBC04),
      imageIcon: Icons.calculate_rounded,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, const Color(0xFFEDF5FF)],
          ),
        ),
        child: Stack(
          children: [
            // Background design elements
            Positioned(
              top: -size.height * 0.1,
              right: -size.width * 0.2,
              child: Container(
                width: size.width * 0.7,
                height: size.width * 0.7,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -size.height * 0.05,
              left: -size.width * 0.1,
              child: Container(
                width: size.width * 0.5,
                height: size.width * 0.5,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Skip button
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextButton(
                        onPressed: () => _navigateToMainPage(),
                        child: Text(
                          'تخطي',
                          style: TextStyle(
                            color: const Color(0xFF1A73E8),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Page content
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _onboardingItems.length,
                      onPageChanged: (int page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                      itemBuilder: (context, index) {
                        return _buildOnboardingPage(_onboardingItems[index]);
                      },
                    ),
                  ),

                  // Indicator and buttons
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Page indicators
                        Row(
                          children: List.generate(
                            _onboardingItems.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(right: 6),
                              height: 8,
                              width: _currentPage == index ? 24 : 8,
                              decoration: BoxDecoration(
                                color: _currentPage == index
                                    ? const Color(0xFF1A73E8)
                                    : const Color(0xFFD1D5DB),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),

                        // Next or Start button
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: _currentPage == _onboardingItems.length - 1
                              ? 140
                              : 56,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_currentPage < _onboardingItems.length - 1) {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeInOut,
                                );
                              } else {
                                _navigateToMainPage();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            child: _currentPage == _onboardingItems.length - 1
                                ? Text('ابدأ الآن',
                                    style: TextStyle(fontSize: 16))
                                : Icon(Icons.arrow_forward,
                                    size: 24, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(OnboardingItem item) {
    final Size size = MediaQuery.of(context).size;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: size.width * 0.7,
            height: size.width * 0.7,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                item.imageIcon,
                size: size.width * 0.25,
                color: item.color,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            item.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            item.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _navigateToMainPage() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => _handleAuthState()),
    );
  }

  Widget _handleAuthState() {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return const HomePage();
        }
        return const RootMainPage();
      },
    );
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final Color color;
  final IconData imageIcon;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.color,
    required this.imageIcon,
  });
}

class RootMainPage extends StatefulWidget {
  const RootMainPage({super.key});

  @override
  State<RootMainPage> createState() => _RootMainPageState();
}

class _RootMainPageState extends State<RootMainPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, const Color(0xFFEDF5FF)],
          ),
        ),
        child: Container(
          child: Stack(
            children: [
              Positioned(
                top: -size.height * 0.05,
                right: -size.width * 0.1,
                child: Container(
                  width: size.width * 0.6,
                  height: size.width * 0.6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A73E8).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -size.height * 0.1,
                left: -size.width * 0.15,
                child: Container(
                  width: size.width * 0.7,
                  height: size.width * 0.7,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A73E8).withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Main content
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Padding(
                      padding: EdgeInsets.only(bottom: size.height * 0.06),
                      child: Center(
                        child: Image.asset(
                          'images/logo.png',
                          width: size.width * 0.5,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    // App name
                    Text(
                      'مسكن',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A73E8),
                      ),
                    ),

                    SizedBox(height: 16),

                    // App description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        'تطبيقك الذكي للعقارات وأفضل الخيارات السكنية',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),

                    SizedBox(height: size.height * 0.08),

                    // Login button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            // TODO: Navigate to login screen
                          },
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                          ),
                          child: Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Register button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) => RegisterMenu()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: const Color(0xFF1A73E8)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'إنشاء حساب',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A73E8),
                            ),
                          ),
                        ),
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
