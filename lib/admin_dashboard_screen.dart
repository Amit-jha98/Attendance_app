import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  bool _isLoading = true;
  int _totalStaff = 0;
  int _presentToday = 0;
  int _absentToday = 0;
  int _monthlyTotalClasses = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Fetch Total Staff count from student_data or staff collection if available
      // Using student_data / staff records as collection source
      final staffSnapshot = await db.collection('student_data').get();
      _totalStaff = staffSnapshot.docs.length;

      // 2. Fetch today's attendance records
      final String todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Query attendance documents matching today's date structure or collection
      final attendanceSnapshot = await db.collection('attendance').get();

      int presentCount = 0;
      int absentCount = 0;
      int monthlyClasses = 0;

      final String currentMonthPrefix = DateFormat('yyyy-MM').format(DateTime.now());

      for (var doc in attendanceSnapshot.docs) {
        final data = doc.data();
        final timestamp = data['date'];

        // Check monthly metrics
        if (timestamp != null) {
          DateTime date;
          if (timestamp is Timestamp) {
            date = timestamp.toDate();
          } else {
            date = DateTime.tryParse(timestamp.toString()) ?? DateTime.now();
          }

          if (DateFormat('yyyy-MM').format(date) == currentMonthPrefix) {
            monthlyClasses++;
          }

          if (DateFormat('yyyy-MM-dd').format(date) == todayKey) {
            final List attendanceList = data['attendance'] ?? [];
            for (var student in attendanceList) {
              if (student['isPresent'] == true) {
                presentCount++;
              } else {
                absentCount++;
              }
            }
          }
        }
      }

      setState(() {
        _presentToday = presentCount;
        _absentToday = absentCount;
        _monthlyTotalClasses = monthlyClasses;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching dashboard data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Saraswati Shiksha Institute – Admin Dashboard'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDashboardData,
            tooltip: 'Refresh Metrics',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overview Statistics',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildMetricCard(
                    title: 'Total Staff / Records',
                    value: '$_totalStaff',
                    icon: Icons.group,
                    color: const Color(0xFF0F172A),
                  ),
                  _buildMetricCard(
                    title: 'Present Today',
                    value: '$_presentToday',
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF10B981), // Emerald Green
                  ),
                  _buildMetricCard(
                    title: 'Absent Today',
                    value: '$_absentToday',
                    icon: Icons.cancel_outlined,
                    color: const Color(0xFFF43F5E), // Rose
                  ),
                  _buildMetricCard(
                    title: 'Monthly Submissions',
                    value: '$_monthlyTotalClasses',
                    icon: Icons.calendar_month,
                    color: const Color(0xFFF59E0B), // Amber
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Quick Management',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(Icons.folder_shared, color: Color(0xFF0F172A)),
                  title: const Text(
                    'View Saved Attendance Reports',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                  subtitle: const Text(
                    'Access exported Excel records and logs',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pushNamed(context, '/view_saved_files_screen');
                  },
                ),
              ),
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  'Powered by Nextgenix Tech',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B), // Slate Gray secondary text
              ),
            ),
          ],
        ),
      ),
    );
  }
}