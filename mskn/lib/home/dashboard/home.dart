import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mskn/home/dashboard/notifications_dashboard.dart';
import 'package:mskn/home/dashboard/reports.dart';
import 'package:mskn/home/dashboard/delete_users_page.dart';
import 'package:mskn/home/dashboard/delete_sellers_page.dart';

class DashboardHomeWidget extends StatefulWidget {
  const DashboardHomeWidget({super.key});

  @override
  State<DashboardHomeWidget> createState() => _DashboardHomeWidgetState();
}

class _DashboardHomeWidgetState extends State<DashboardHomeWidget> {
  int _totalUsers = 0;
  int _totalMarketers = 0;
  int _totalReports = 0;
  int _totalNotifications = 0;
  int _totalProperties = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('profile').get();
      final marketersSnapshot = await FirebaseFirestore.instance
          .collection('profile')
          .where('rank', isEqualTo: 'marketer')
          .get();
      final reportsSnapshot =
          await FirebaseFirestore.instance.collection('reports').get();
      final notificationsSnapshot =
          await FirebaseFirestore.instance.collection('notifications').get();
      final propertiesSnapshot =
          await FirebaseFirestore.instance.collection('property').get();

      if (mounted) {
        setState(() {
          _totalUsers = usersSnapshot.docs.length;
          _totalMarketers = marketersSnapshot.docs.length;
          _totalReports = reportsSnapshot.docs.length;
          _totalNotifications = notificationsSnapshot.docs.length;
          _totalProperties = propertiesSnapshot.docs.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading statistics: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'لوحة التحكم',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2575FC),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              color: const Color(0xFF2575FC),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome header
                    Row(
                      children: [
                        Container(
                          width: 4.w,
                          height: 30.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2575FC),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'نظرة عامة',
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'الإحصائيات الرئيسية للنظام',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 24.h),

                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildModernStatCard(
                                title: 'اجمالي المستخدمين',
                                value: _totalUsers.toString(),
                                icon: Icons.people_alt_outlined,
                                primaryColor: const Color(0xFF2575FC),
                                secondaryColor: const Color(0xFF6A11CB),
                                isPositive: true,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildModernStatCard(
                                title: 'اجمالي العقارات',
                                value: _totalProperties.toString(),
                                icon: Icons.home_rounded,
                                primaryColor: const Color(0xFF00C9FF),
                                secondaryColor: Colors.lightGreen,
                                isPositive: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Bottom three cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildCompactStatCard(
                                title: 'المسوقين',
                                value: _totalMarketers.toString(),
                                icon: Icons.business_center_rounded,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildCompactStatCard(
                                title: 'البلاغات',
                                value: _totalReports.toString(),
                                icon: Icons.flag_rounded,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildCompactStatCard(
                                title: 'الإشعارات',
                                value: _totalNotifications.toString(),
                                icon: Icons.notifications_rounded,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Management Section
                    Row(
                      children: [
                        Container(
                          width: 4.w,
                          height: 24.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2575FC),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'الادارة والتحكم',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // --- (1) Management Card: قائمة المستخدمين ---
                    _buildManagementCard(
                      context,
                      icon: Icons.people_alt_outlined,
                      title: 'قائمة المستخدمين',
                      description: 'عرض وإدارة جميع المستخدمين',
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2575FC),
                          const Color(0xFF6A11CB),
                        ],
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context) => const DeleteUsersPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // --- (2) Management Card: قائمة المسوقين (تم التعديل) ---
                    _buildManagementCard(
                      context,
                      icon: Icons.business_center_rounded,
                      title: 'قائمة المسوقين',
                      description: 'إدارة حسابات المسوقين والوكلاء',
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.shade400,
                          Colors.green.shade600,
                        ],
                      ),
                      onPressed: () {
                        // الانتقال لصفحة المسوقين
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context) => const DeleteSellersPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // --- (3) Management Card: نظام الاشعارات ---
                    _buildManagementCard(
                      context,
                      icon: Icons.notifications_active_outlined,
                      title: 'نظام الاشعارات',
                      description: 'إرسال وإدارة الاشعارات',
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.shade400,
                          Colors.purple.shade600,
                        ],
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const NotificationsDashboardWidget(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // --- (4) Management Card: بلاغات المستخدمين ---
                    _buildManagementCard(
                      context,
                      icon: Icons.flag_outlined,
                      title: 'بلاغات المستخدمين',
                      description: 'مراجعة ومعالجة البلاغات',
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade600,
                          Colors.orange.shade800,
                        ],
                      ),
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) =>
                                const ReportsDashboardWidget()));
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildModernStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color primaryColor,
    required Color secondaryColor,
    required bool isPositive,
  }) {
    return Container(
      height: 140.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100.w,
              height: 100.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: Container(
              width: 120.w,
              height: 120.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 36.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      height: 100.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Gradient gradient,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60.w,
              height: 50.h,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: gradient.colors.first.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
