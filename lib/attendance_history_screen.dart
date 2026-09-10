import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  String? selectedEmployeeId;
  String selectedFilterType = 'Date-wise';
  DateTime selectedDate = DateTime.now();

  void _showOverrideDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final remarkController = TextEditingController();
    String selectedStatus = 'Present';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Administrative Override Correction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Correcting record for: ${data['subject'] ?? 'General Session'}'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: const InputDecoration(labelText: 'New Attendance Status'),
              items: ['Present', 'Absent', 'Half-Day', 'Leave', 'Late']
                  .map((status) => DropdownMenuItem(value: status, child: Text(status)))
                  .toList(),
              onChanged: (val) => selectedStatus = val!,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarkController,
              decoration: const InputDecoration(
                labelText: 'Mandatory Audit Remark',
                hintText: 'Reason for manual correction...',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (remarkController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Audit remark is mandatory for administrative overrides.')),
                );
                return;
              }

              await db.collection('attendance_logs').doc(doc.id).update({
                'status': selectedStatus,
                'overrideByAdmin': true,
                'auditRemark': remarkController.text.trim(),
                'overrideTimestamp': FieldValue.serverTimestamp(),
              });

              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Save Override'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saraswati Shiksha Institute – History & Corrections'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text('Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: db.collection('attendance').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No attendance history logs found.'));
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text('Subject: ${data['subject'] ?? 'N/A'} (Branch: ${data['branch']})'),
                        subtitle: Text(
                            'Topic: ${data['topic'] ?? 'N/A'}\nFaculty: ${data['faculty']?['name'] ?? 'N/A'}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_note, color: Colors.orange),
                          tooltip: 'Manual Correction Override',
                          onPressed: () => _showOverrideDialog(doc),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}