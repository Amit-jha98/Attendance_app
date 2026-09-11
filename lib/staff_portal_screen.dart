import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StaffPortalScreen extends StatelessWidget {
  final String staffId;
  final String staffName;

  const StaffPortalScreen({super.key, required this.staffId, required this.staffName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $staffName (Staff Portal)'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Attendance Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: const Icon(Icons.login),
              label: const Text('Record Daily Check-In / Check-Out'),
              onPressed: () {
                Navigator.pushNamed(context, '/home');
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'My Personal Attendance History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('attendance')
                    .where('faculty.id', isEqualTo: staffId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No personal attendance history recorded yet.'));
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text('Subject: ${data['subject'] ?? 'N/A'}'),
                          subtitle: Text('Topic: ${data['topic'] ?? 'N/A'}\nDate: ${data['date'].toString()}'),
                          trailing: const Chip(
                            label: Text('Logged'),
                            backgroundColor: Color(0xFF10B981),
                            labelStyle: TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 12.0),
                child: Text(
                  'Powered by Nextgenix Tech',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}// TODO Implement this library.