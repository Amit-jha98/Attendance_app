import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui'; // Import for BackdropFilter
import 'package:vibration/vibration.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  late String branch;
  late String semester;
  late String session;
  late String subject;
  late String time;
  late String type;
  late String facultyName;
  late String facultyId;
  List<Student> students = [];
  List<Student> filteredStudents = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String searchQuery = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Retrieve arguments passed to this screen
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, String?>;

    // Extract the arguments, providing fallback values
    branch = args['branch'] ?? 'Unknown Branch';
    semester = args['semester'] ?? 'Unknown Semester';
    session = args['session'] ?? 'Unknown Session';
    subject = args['subject'] ?? 'Unknown Subject';
    time = args['time'] ?? 'Unknown Time';
    type = args['type'] ?? 'Unknown Type';
    facultyName = args['facultyName'] ?? 'Unknown Faculty';
    facultyId = args['facultyId'] ?? 'Unknown Faculty ID';

    print('branch: $branch, semester: $semester, session: $session, subject: $subject, time: $time, type: $type');

    // Fetch students based on the arguments
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('Fetching students with branch: $branch, semester: $semester, session: $session');

      // Initialize query
      Query query = db
          .collection('student_data')
          .where('branch', isEqualTo: branch)
          .where('semester', isEqualTo: semester);

      // Conditionally add session filter if session is valid
      if (session.isNotEmpty && session != 'Unknown Session') {
        query = query.where('session', isEqualTo: session);
      }

      // Execute the query
      final QuerySnapshot querySnapshot = await query.get();

      print('Students found: ${querySnapshot.docs.length}');

      if (querySnapshot.docs.isEmpty) {
        print('No students found matching the criteria.');
      }

      // Map the results
      students = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        return Student(
          name: data['name'],
          registration_number: data['registration_number'],
          branch: data['branch'],
          semester: data['semester'],
          session: data['session'] ?? 'Unknown', // Handle missing session
          isPresent: false,
        );
      }).toList();

      filteredStudents = students;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch student data: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _searchStudents(String query) {
    setState(() {
      searchQuery = query.toLowerCase();

      filteredStudents = students.where((student) {
        final nameMatches = student.name.toLowerCase().startsWith(searchQuery);

        final regNumMatches = student.registration_number.endsWith(searchQuery);

        return nameMatches || regNumMatches;
      }).toList();
    });
  }



  Future<void> _exportToExcel() async {
    // // Define a function to get batch year based on registration number
    // String getBatchYear(String registrationNumber) {
    //   // Extract the year prefix based on the format
    //   String yearPrefix;
    //
    //   if (registrationNumber.contains('-')) {
    //     // Handle alphanumeric format (e.g., 24-CS-49)
    //     yearPrefix = registrationNumber.split('-')[0]; // Extract the year part
    //   } else {
    //     // Handle purely numeric format (e.g., 23101150001)
    //     yearPrefix = registrationNumber.substring(0, 2); // Extract the first two digits
    //   }
    //
    //   final startYear = 2000 + int.parse(yearPrefix);
    //   final endYear = startYear + 4;
    //   return '$startYear-$endYear';
    // }


    if (filteredStudents.isEmpty) {
      print('No student data to export.');
      return;
    }

    final firstStudent = filteredStudents.first;
    // final batchYear = getBatchYear(firstStudent.registration_number);

    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'attendance_${branch}_${semester}_${subject}_${facultyName}_$session.xlsx';
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    Excel excel;
    Sheet sheet;

    if (await file.exists()) {
      final existingBytes = await file.readAsBytes();
      excel = Excel.decodeBytes(existingBytes);
      sheet = excel['Sheet1'] ?? excel['Sheet1']; // Use the default sheet named 'Sheet1'

      // If the sheet doesn't exist, create it
      sheet ??= excel['Sheet1'];
    } else {
      // Create a new Excel instance and use 'Sheet1'
      excel = Excel.createExcel();
      sheet = excel['Sheet1'];

      // Add faculty details in a single merged cell
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0),
      );
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        'Faculty: $facultyName\nBranch: $branch\nSemester: $semester\nSubject: $subject',
      );

      // Initialize header row with "Student Name", "Registration Number", and the first date
      sheet.appendRow(['Student Name', 'Registration Number']);
    }

    final date = DateTime.now().toLocal().toString().split(' ')[0];

    // Check if the date column already exists, and add it if not
    int dateColumnIndex = sheet.rows[1].indexWhere((cell) => cell?.value == date);
    if (dateColumnIndex == -1) {
      dateColumnIndex = sheet.rows[1].length;
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: dateColumnIndex, rowIndex: 1),
        date,
      );
    }

    // Create a map to store the row index for each student
    final studentRowMap = <String, int>{};

    // Populate the map with existing students and their row indices
    for (int i = 2; i < sheet.maxRows; i++) {
      final nameCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i)).value;
      final regNumberCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i)).value;
      if (nameCell != null && regNumberCell != null) {
        studentRowMap['$nameCell|$regNumberCell'] = i;
      }
    }

    // Process student data
    for (var student in filteredStudents) {
      final studentKey = '${student.name}|${student.registration_number}'; // Updated field name
      final rowIndex = studentRowMap[studentKey];

      if (rowIndex != null) {
        // Update the attendance for the date under the correct column
        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: dateColumnIndex, rowIndex: rowIndex),
          student.isPresent ? 'P' : 'A',
        );
      } else {
        // If the student does not exist, add a new row with the attendance data
        List<dynamic> newRow = [student.name, student.registration_number]; // Updated field name
        // Fill previous dates with empty values
        for (int j = 2; j < dateColumnIndex; j++) {
          newRow.add('');
        }
        // Add the attendance data under the current date
        newRow.add(student.isPresent ? 'P' : 'A');
        sheet.appendRow(newRow);
      }
    }

    final excelBytes = excel.save();
    if (excelBytes != null) {
      await file.writeAsBytes(excelBytes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel file saved as $fileName'),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      print('Failed to generate Excel file.');
    }
  }


  Future<void> _submitAttendance() async {
    final TextEditingController topicController = TextEditingController();

    // Show confirmation dialog before submitting
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Submission'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total checked students: $_checkedCount'),
              const SizedBox(height: 10),
              TextFormField(
                controller: topicController,
                decoration: const InputDecoration(
                  labelText: 'Topic',
                  hintText: 'Enter topic of the class',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a topic';
                  }
                  return null;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (topicController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a topic')),
                  );
                  if (await Vibration.hasVibrator() ?? false) {
                    Vibration.vibrate(duration: 500); // Vibrate for 500ms
                  }
                  return;
                }

                Navigator.of(context).pop(); // Close the dialog
                await _performSubmission(topicController.text); // Pass the topic to the submission
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performSubmission(String topic) async {
    setState(() {
      _isLoading = true; // Start loading
    });

    try {
      final DateTime now = DateTime.now();
      final String dateKey = DateFormat('yyyy-MM-dd').format(now);
      final String timeKey = DateFormat('dd').format(now);
      final String compositeKey = '${branch}_${semester}_${subject}_${type}_${time}_${dateKey}_$timeKey';

      final DocumentReference docRef = FirebaseFirestore.instance.collection('attendance').doc(compositeKey);

      // Fetch existing document
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        // Document already exists
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance for this class time has already been submitted.')),
        );
        return; // Exit function
      }

      final attendanceData = filteredStudents.map((student) => {
        'name': student.name,
        'registration_number': student.registration_number,
        'isPresent': student.isPresent,
      }).toList();

      await docRef.set({
        'date': DateTime.now(),
        'branch': branch,
        'semester': semester,
        'session': session,
        'subject': subject,
        'time': time,
        'type': type,
        'topic': topic, // Store the entered topic
        'faculty': {
          'name': facultyName,
          'id': facultyId,
        },
        'attendance': attendanceData,
      });

      await _exportToExcel();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance submitted successfully!')),
      );

      Navigator.pop(context); // Navigate back to the previous page

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit attendance: Maybe Network Problem')),
      );
    } finally {
      setState(() {
        _isLoading = false; // Stop loading
      });
    }
  }

  int get _checkedCount {
    return filteredStudents.where((student) => student.isPresent).length;
  }
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        searchQuery = '';
        filteredStudents = students; // Show all students when search is closed
      }
    });
  }

  void _logout() async {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isSearching) {
          _toggleSearch(); // Close search when back navigation is triggered
          return false; // Prevent default back navigation
        }
        return true; // Allow default back navigation
      },
    child:  Scaffold(
      appBar:  AppBar(
        title: Text(
        '$branch - $semester',
        style: const TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.bold,
        fontSize: 20,
    ),
    ),
    backgroundColor: Colors.transparent,
    elevation: 0,
    flexibleSpace: Container(
    decoration: const BoxDecoration(
    gradient: LinearGradient(
    colors: [
    Color(0xFF9ED4EA),
    Color(0xFF64B5F6),
    Color(0xFF99C1E4),
    Color(0xFF64B5F6),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.3, 0.7, 1.0],
    ),
    ),
    ),
    actions: [
    IconButton(
    icon: const Icon(Icons.search, color: Colors.black),
    onPressed: _toggleSearch,
    tooltip: 'Search',
    ),
    IconButton(
    icon: const Icon(Icons.logout, color: Colors.black),
    onPressed: _logout,
    tooltip: 'Log Out',
    ),
    ],
    bottom: _isSearching
    ? PreferredSize(
    preferredSize: const Size.fromHeight(50.0),
    child: Padding(
    padding: const EdgeInsets.all(8.0),
    child: TextField(
    autofocus: true,
    decoration: const InputDecoration(
    hintText: 'Search by name or registration number',
    border: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(10.0)),
    ),
    prefixIcon: Icon(Icons.search),
    ),
    onChanged: _searchStudents,
    ),
    ),
    )
        : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF64B5F6),
                  Color(0xFFE1ECA5),
                  Color(0xFFEC9CC4),
                  Color(0xFF64B5F6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: filteredStudents.isEmpty
                    ? const Center(child: Text('No students found.'))
                    : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80.0),
                  itemCount: filteredStudents.length,
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 4.0),
                      elevation: 8.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15.0),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.9),
                              Colors.grey[200]!.withOpacity(0.9)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10.0,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueAccent,
                            child: Text(
                              student.name[0],
                              style: const TextStyle(
                                  color: Colors.white),
                            ),
                          ),
                          title: Text(
                            student.name,
                            style: const TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Reg No: ${student.registration_number}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          trailing: Checkbox(
                            value: student.isPresent,
                            onChanged: (bool? value) {
                              setState(() {
                                student.isPresent =
                                    value ?? false;
                              });
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Stack(
              alignment: Alignment.center,
              children: [Container(
                color: Colors.transparent,
                height: 70.0,
                padding: const EdgeInsets.symmetric(horizontal: 0.0),
                child: Center(
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: GestureDetector(
                      onTap: _isLoading ? null : _submitAttendance, // Detects touch on both icon and text
                      child: FloatingActionButton.extended(
                        onPressed: _isLoading ? null : _submitAttendance,
                        label: _isLoading
                            ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                            SizedBox(width: 5),
                            Text('Loading...'),
                          ],
                        )
                            : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 0),
                            Icon(Icons.check_circle),
                            SizedBox(width: 2), // Add some space between icon and text
                            Text('Submit'),
                          ],
                        ),
                        backgroundColor: const Color.fromRGBO(82, 162, 244, 1),
                        elevation: 5.0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40.0),
                        ),
                        extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                    ),
                  ),
                ),
              ),

                Positioned(
                  left: 50,
                  right: 150,
                  bottom: 8, // Adjust this value to position the count box properly
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0),
                      borderRadius: BorderRadius.circular(10.0),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.transparent,
                          blurRadius: 5.0,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '$_checkedCount',
                      style: const TextStyle(
                        fontSize: 22.0,
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
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
    );
  }
}

class Student {
  final String name;
  final String registration_number;
  final String branch;
  final String semester;
  final String session;
  bool isPresent;

  Student({
    required this.name,
    required this.registration_number,
    required this.branch,
    required this.semester,
    required this.session,
    required this.isPresent,
  });
}
