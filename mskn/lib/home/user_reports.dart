import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MyReportsPage extends StatelessWidget {
  const MyReportsPage({super.key});

  Future<List<Map<String, dynamic>>> _fetchUserReports() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('reports')
        .where('reporter_id', isEqualTo: user.uid)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'بلاغاتي',
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchUserReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2575FC),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  const Text('حدث خطأ أثناء تحميل البلاغات'),
                ],
              ),
            );
          }

          final reports = snapshot.data ?? [];
          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                   Text(
                    'لا توجد بلاغات لعرضها',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return _buildReportCard(report);
            },
          );
        },
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final reportType = report['report_type'] ?? 'غير محددة';
    final status = report['status'] ?? 'غير محددة';
    final title = report['property_title'] ?? 'عنوان غير متوفر';
    final description = report['comment'] ?? 'وصف غير متوفر';
    final createdAt = report['created_at'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getReportTypeColor(reportType).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getReportTypeColor(reportType).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getReportTypeIcon(reportType),
                    color: _getReportTypeColor(reportType),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getReportTypeLabel(reportType),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getReportTypeColor(reportType),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      createdAt != null
                          ? _formatDate(createdAt.toDate())
                          : 'غير محدد',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        label = 'قيد المراجعة';
        icon = Icons.pending;
        break;
      case 'resolved':
        color = Colors.green;
        label = 'تم الحل';
        icon = Icons.check_circle;
        break;
      case 'closed':
        color = Colors.grey;
        label = 'مغلق';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        label = 'غير محددة';
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getReportTypeColor(String type) {
    switch (type) {
      case 'fake_property':
        return Colors.orange;
      case 'wrong_info':
        return Colors.blue;
      case 'spam':
        return Colors.red;
      case 'inappropriate':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getReportTypeIcon(String type) {
    switch (type) {
      case 'fake_property':
        return Icons.warning_amber_rounded;
      case 'wrong_info':
        return Icons.info_outline;
      case 'spam':
        return Icons.block;
      case 'inappropriate':
        return Icons.report_outlined;
      default:
        return Icons.more_horiz;
    }
  }

  String _getReportTypeLabel(String type) {
    switch (type) {
      case 'fake_property':
        return 'عقار وهمي';
      case 'wrong_info':
        return 'معلومات خاطئة';
      case 'spam':
        return 'إعلان مزعج';
      case 'inappropriate':
        return 'محتوى غير لائق';
      default:
        return 'أخرى';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'اليوم ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays == 1) {
      return 'أمس ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else {
      return DateFormat('d MMM yyyy').format(date);
    }
  }
}
