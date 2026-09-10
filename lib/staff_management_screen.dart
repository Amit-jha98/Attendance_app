import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  void _showStaffDialog({String? docId, Map<String, dynamic>? existingData}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existingData?['name'] ?? '');
    final employeeIdController = TextEditingController(text: existingData?['employeeId'] ?? '');
    final mobileController = TextEditingController(text: existingData?['mobileNumber'] ?? '');
    final designationController = TextEditingController(text: existingData?['designation'] ?? '');
    String joiningDate = existingData?['joiningDate'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    bool isActive = existingData?['isActive'] ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          title: Text(docId == null ? 'Add Staff Profile' : 'Edit Staff Profile'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Staff Name'),
                    validator: (v) => v!.isEmpty ? 'Enter name' : null,
                  ),
                  TextFormField(
                    controller: employeeIdController,
                    decoration: const InputDecoration(labelText: 'Employee ID'),
                    validator: (v) => v!.isEmpty ? 'Enter Employee ID' : null,
                  ),
                  TextFormField(
                    controller: mobileController,
                    decoration: const InputDecoration(labelText: 'Mobile Number'),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v!.isEmpty ? 'Enter mobile number' : null,
                  ),
                  TextFormField(
                    controller: designationController,
                    decoration: const InputDecoration(labelText: 'Designation'),
                    validator: (v) => v!.isEmpty ? 'Enter designation' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Joining Date: $joiningDate'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.tryParse(joiningDate) ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            dialogSetState(() {
                              joiningDate = DateFormat('yyyy-MM-dd').format(picked);
                            });
                          }
                        },
                        child: const Text('Select Date'),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('Active Status'),
                    value: isActive,
                    onChanged: (val) {
                      dialogSetState(() {
                        isActive = val;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final data = {
                    'name': nameController.text.trim(),
                    'employeeId': employeeIdController.text.trim(),
                    'mobileNumber': mobileController.text.trim(),
                    'designation': designationController.text.trim(),
                    'joiningDate': joiningDate,
                    'isActive': isActive,
                    'updatedAt': FieldValue.serverTimestamp(),
                  };

                  if (docId == null) {
                    await db.collection('staff_profiles').add(data);
                  } else {
                    await db.collection('staff_profiles').doc(docId).update(data);
                  }

                  Navigator.pop(context);
                  setState(() {});
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saraswati Shiksha Institute – Staff Management'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection('staff_profiles').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No staff profiles found. Add one using the button below.'));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final bool isActive = data['isActive'] ?? true;

              return Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(
                    data['name'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  subtitle: Text(
                    'ID: ${data['employeeId']} | Desig: ${data['designation']}\nMobile: ${data['mobileNumber']} | Joined: ${data['joiningDate']}',
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text(isActive ? 'Active' : 'Deactivated'),
                        backgroundColor: isActive ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFFF43F5E).withOpacity(0.2),
                        labelStyle: TextStyle(color: isActive ? const Color(0xFF10B981) : const Color(0xFFF43F5E)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showStaffDialog(docId: doc.id, existingData: data),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0F172A),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showStaffDialog(),
      ),
    );
  }
}