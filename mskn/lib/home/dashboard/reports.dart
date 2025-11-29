import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mskn/home/models/property.dart';
import 'package:mskn/home/property_details.dart';

class ReportsDashboardWidget extends StatefulWidget {
  const ReportsDashboardWidget({super.key});

  @override
  State<ReportsDashboardWidget> createState() => _ReportsDashboardWidgetState();
}

class _ReportsDashboardWidgetState extends State<ReportsDashboardWidget> {
  String _selectedFilter = 'all'; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'بلاغات المستخدمين',
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
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('الكل', 'all', Icons.list_alt),
                  const SizedBox(width: 8),
                  _buildFilterChip('قيد المراجعة', 'pending', Icons.pending_outlined),
                  const SizedBox(width: 8),
                  _buildFilterChip('تم الحل', 'resolved', Icons.check_circle_outline),
                  const SizedBox(width: 8),
                  _buildFilterChip('مغلق', 'closed', Icons.cancel_outlined),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getReportsStream(),
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
                        Text('حدث خطأ في تحميل البلاغات: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                final reports = snapshot.data?.docs ?? [];

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
                          'لا توجد بلاغات',
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
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return _buildReportCard(report);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getReportsStream() {
    Query query = FirebaseFirestore.instance.collection('reports');

    if (_selectedFilter != 'all') {
      query = query.where('status', isEqualTo: _selectedFilter);
    }

    return query.snapshots();
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF2575FC) 
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF2575FC) 
                : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(QueryDocumentSnapshot report) {
    final data = report.data() as Map<String, dynamic>;
    final reportType = data['report_type'] ?? 'other';
    final status = data['status'] ?? 'pending';
    final createdAt = data['created_at'] as Timestamp?;
    final propertyTitle = data['property_title'] ?? 'غير محدد';
    final propertyId = data['property_id'] ?? '';
    final comment = data['comment'];
    final reporterId = data['reporter_id'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                        propertyTitle,
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

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('profile')
                      .doc(reporterId)
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final reporterData = snapshot.data!.data() as Map<String, dynamic>;
                      final reporterName = reporterData['name'] ?? 'مستخدم';
                      final reporterPhone = reporterData['phone'] ?? 'غير متوفر';
                      
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_outline, size: 18, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Text(
                                  'مقدم البلاغ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF2575FC).withOpacity(0.1),
                                  child: Text(
                                    reporterName[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF2575FC),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        reporterName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        reporterPhone,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, size: 18, color: Colors.grey[400]),
                          const SizedBox(width: 8),
                          Text(
                            'جاري تحميل بيانات المستخدم...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _viewPropertyDetails(propertyId),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('عرض العقار'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2575FC),
                      side: const BorderSide(color: Color(0xFF2575FC)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                if (comment != null && comment.toString().isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.comment_outlined, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          comment,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

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

                if (status == 'pending') ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          label: 'إغلاق',
                          icon: Icons.cancel_outlined,
                          color: Colors.grey,
                          onPressed: () => _showCloseReportDialog(report.id),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          label: 'تم الحل',
                          icon: Icons.check_circle_outline,
                          color: Colors.green,
                          onPressed: () => _showResolveReportDialog(report.id),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          label: 'حذف العقار',
                          icon: Icons.delete_outline,
                          color: Colors.red,
                          onPressed: () => _showDeletePropertyDialog(
                            report.id,
                            propertyId,
                            propertyTitle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
        label = 'غير محدد';
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

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
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

  Future<void> _updateReportStatus(String reportId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({
        'status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
  AwesomeDialog(
    context: context,
    dialogType: DialogType.success,
    animType: AnimType.bottomSlide,
    title: 'تم التحديث',
    desc: 'تم تحديث حالة البلاغ إلى: ${_getStatusLabel(newStatus)}',
    btnOkText: 'حسناً',
    btnOkOnPress: () {},
  ).show();
      }
    } catch (e) {
      if (mounted) {
  AwesomeDialog(
    context: context,
    dialogType: DialogType.error,
    animType: AnimType.bottomSlide,
    title: 'حدث خطأ',
    desc: 'فشل في تحديث حالة البلاغ: $e',
    btnOkText: 'حسناً',
    btnOkOnPress: () {},
  ).show();
      }
    }
  }

  void _showDeletePropertyDialog(String reportId, String propertyId, String propertyTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('تاكيد الحذف'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'هل انت متاكد من حذف هذا العقار؟',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                propertyTitle,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'لا يمكن التراجع عن هذا الإجراء.',
              style: TextStyle(
                color: Colors.red,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteProperty(reportId, propertyId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('حذف العقار'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProperty(String reportId, String propertyId) async {
    try {
      await FirebaseFirestore.instance
          .collection('property')
          .doc(propertyId)
          .delete();

      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({
        'status': 'resolved',
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
  AwesomeDialog(
    context: context,
    dialogType: DialogType.success,
    animType: AnimType.bottomSlide,
    title: 'تم الحذف',
    desc: 'تم حذف العقار بنجاح !',
    btnOkText: 'حسناً',
    btnOkOnPress: () {},
  ).show();
      }
    } catch (e) {
      if (mounted) {
     showDialog(
  context: context,
  builder: (context) {
    return AlertDialog(
      title: Text("حدث خطا"),
      content: Text('حدث خطا $e'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("حسناً"),
        )
      ],
    );
  },
);
      }
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'قيد المراجعة';
      case 'resolved':
        return 'تم الحل';
      case 'closed':
        return 'مغلق';
      default:
        return 'غير محدد';
    }
  }

  Future<void> _viewPropertyDetails(String propertyId) async {
    try {
   

      final doc = await FirebaseFirestore.instance
          .collection('property')
          .doc(propertyId)
          .get();



      if (doc.exists) {
        final property = Property.fromFirestore(doc);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PropertyDetails(property: property),
          ),
        );
      } else {
  AwesomeDialog(
    context: context,
    dialogType: DialogType.error,
    animType: AnimType.bottomSlide,
    title: 'حدث خطأ',
    desc: 'العقار غير موجود',
    btnOkText: 'حسناً',
    btnOkOnPress: () {},
  ).show();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
  AwesomeDialog(
    context: context,
    dialogType: DialogType.error,
    animType: AnimType.bottomSlide,
    title: 'حدث خطأ',
    desc:' حدث خطا $e',
    btnOkText: 'حسناً',
    btnOkOnPress: () {},
  ).show();
        
      }
    }
  }

  void _showCloseReportDialog(String reportId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.grey[700], size: 28),
            const SizedBox(width: 12),
            const Text('إغلاق البلاغ'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل تريد إغلاق هذا البلاغ؟',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'سيتم وضع علامة على البلاغ كمغلق دون اتخاذ إجراء.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateReportStatus(reportId, 'closed');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[700],
            ),
            child: const Text('إغلاق البلاغ'),
          ),
        ],
      ),
    );
  }

  void _showResolveReportDialog(String reportId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('تأكيد الحل'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل تم حل مشكلة هذا البلاغ؟',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'سيتم وضع علامة على البلاغ كمحلول.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateReportStatus(reportId, 'resolved');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('تأكيد الحل'),
          ),
        ],
      ),
    );
  }
}