import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:attandence_v3/view_saved_files_screen.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class BranchSemesterSelectionScreen extends StatefulWidget {
  BranchSemesterSelectionScreen({super.key});

  @override
  _BranchSemesterSelectionScreenState createState() =>
      _BranchSemesterSelectionScreenState();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
}
class TimeRange {
  final DateTime startTime;
  final DateTime endTime;

  TimeRange(this.startTime, this.endTime);
}

class _BranchSemesterSelectionScreenState extends State<BranchSemesterSelectionScreen> {
  List<Map<String, dynamic>> classes = [];
  String? facultyName;
  String? employeeId;
  String? email;
  List<File> excelFiles = [];
  bool isLoading = true;
  String? errorMessage;
  String? Regular;
  String? selectedTime;
  TimeOfDay? selectedStartTime;
  TimeOfDay? selectedEndTime;


  String selectedDay = ''; // Default to an empty string
  String? selectedBranch; // Default to an empty string
  String? selectedSemester; // Default to an empty string
  List<Map<String, dynamic>> fetchedSubjects = [];
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  StreamSubscription<DocumentSnapshot>? _classSubscription;
  String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  @override
  void initState() {
    super.initState();
    // Initialize the FlutterLocalNotificationsPlugin
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/attendance_bg'),
    );
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Initialize timezone data
    tz.initializeTimeZones();

    selectedDay = DateFormat('EEEE').format(DateTime.now());


   Regular = selectedDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (arguments != null) {
        employeeId = arguments['employee_id'];
        email = arguments['email'];
        _fetchUserDetails();
      }
    });
  }

  Future<void> _fetchUserDetails() async {
    try {
      if (employeeId != null || email != null) {
        DocumentSnapshot userDoc;
        userDoc = await FirebaseFirestore.instance
            .collection('user_detail')
            .doc(employeeId)
            .get();

        if (!userDoc.exists && email != null) {
          final emailQuery = await FirebaseFirestore.instance
              .collection('user_detail')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

          if (emailQuery.docs.isNotEmpty) {
            userDoc = emailQuery.docs.first;
          } else {
            setState(() {
              errorMessage = 'User details not found';
              isLoading = false;
            });
            return;
          }
        }

        setState(() {
          facultyName = userDoc['name'];
          employeeId = userDoc['employee_id'];
        });


        await _startListeningForClassUpdates();
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'No employee ID or email provided';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching data: May Be Network Problem';
        isLoading = false;
      });
    }
  }
  Future<List<Map<String, dynamic>>> _fetchSubjects() async {
    if (selectedBranch == null || selectedSemester == null) {
      return  fetchedSubjects = [];
    }

    QuerySnapshot querySnapshot;

    if (selectedBranch == 'CE-A' || selectedBranch == 'CE-B') {
      // Query to fetch subjects where branch is "CE-A, CE-B" and matches the semester
      querySnapshot = await FirebaseFirestore.instance
          .collection('subjects')
          .where('branch', isEqualTo: 'CE-A, CE-B')
          .where('semester', isEqualTo: selectedSemester)
          .get();

      // Filter the results to include only the specific branch (CE-A or CE-B)
      List<Map<String, dynamic>> filteredSubjects = querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .where((data) => data['branch'].contains(selectedBranch!))
          .toList();

      return filteredSubjects;
    } else {
      // Query for other branches
      querySnapshot = await FirebaseFirestore.instance
          .collection('subjects')
          .where('branch', isEqualTo: selectedBranch)
          .where('semester', isEqualTo: selectedSemester)
          .get();

      return querySnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    }
  }


  Future<void> _startListeningForClassUpdates() async {
    final classStream = FirebaseFirestore.instance
        .collection('teacher_data')
        .doc(employeeId!)
        .snapshots();

    _classSubscription = classStream.listen((snapshot) async {
      if (snapshot.exists) {
        final teacherData = snapshot.data();

        if (teacherData != null) {
          setState(() {
            classes = [];
            teacherData.forEach((key, value) {
              // Extract only the classes for the selected day
              if (value['day'] == selectedDay) {
                classes.add(value as Map<String, dynamic>);
              }
            });
            isLoading = false;
          });

          // Save updated classes to SharedPreferences
          await _saveClassesToPrefs();

          // Cancel all previously scheduled notifications
          await flutterLocalNotificationsPlugin.cancelAll();

          // Schedule notifications for updated classes
          await _scheduleAllNotifications();
        }
      } else {
        // If no data exists, clear saved classes and cancel notifications
        setState(() {
          classes.clear();
        });
        await _saveClassesToPrefs();
        await flutterLocalNotificationsPlugin.cancelAll();
      }
    });
  }


  Future<void> _saveClassesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('classes_$employeeId', jsonEncode(classes));
  }

  Future<void> _scheduleAllNotifications() async {
    for (var classData in classes) {
      final classDay = classData['day'];
      final classTime = _parseTime(classData['time']);
      final startTime = classTime.startTime;
      final notificationTime = startTime.subtract(const Duration(minutes: 10));

      final DateTime classDateTime = _getNextClassDateTime(classDay, notificationTime);

      if (classDateTime.isAfter(DateTime.now())) {
        await _showNotification(
          branch: classData['branch'],
          semester: classData['semester'],
          classTime: classDateTime,
          subject: classData['subject'],
          day: classDay,
        );
      }
    }
  }

  DateTime _getNextClassDateTime(String classDay, DateTime time) {
    final DateTime now = DateTime.now();
    final int currentWeekday = now.weekday;
    final int targetWeekday = _dayToWeekday(classDay);

    final int daysDifference = (targetWeekday - currentWeekday + 7) % 7;

    return DateTime(
      now.year,
      now.month,
      now.day + daysDifference,
      time.hour,
      time.minute,
    );
  }

  int _dayToWeekday(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
        return DateTime.monday;
      case 'tuesday':
        return DateTime.tuesday;
      case 'wednesday':
        return DateTime.wednesday;
      case 'thursday':
        return DateTime.thursday;
      case 'friday':
        return DateTime.friday;
      case 'saturday':
        return DateTime.saturday;
      case 'Extra Class':
        return DateTime.sunday;
      default:
        return DateTime.monday;
    }
  }

  Future<void> _showNotification({
    required String branch,
    required String semester,
    required DateTime classTime,
    required String subject,
    required String day,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'class_reminders_channel',
      'Class Reminders',
      channelDescription: 'Notifications for upcoming classes',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
      classTime,
      tz.local,
    );

    if (scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
      final int notificationId =
      DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        'Upcoming Class',
        'class for $branch-$semester is starting in 10 min.',
        scheduledDate,
        platformChannelSpecifics,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.wallClockTime,
        matchDateTimeComponents: DateTimeComponents.time,
      ).catchError((error) {
        print('Error scheduling notification: May Be Network Problem');
      });
    }
  }


  TimeRange _parseTime(String timeString) {
    try {
      // Replace non-breaking spaces and other invisible characters
      timeString = timeString.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF\u00A0]'), '');

      // Replace all types of spaces with regular space and trim the string
      timeString = timeString.replaceAll(RegExp(r'\s+'), ' ').trim();

      // Debugging: Print the cleaned time string
      print('Cleaned time string: $timeString');

      // Split the time string into start and end times
      List<String> timeParts = timeString.split('-');

      if (timeParts.length != 2) {
        throw const FormatException('Invalid time range format.');
      }

      String startTimeString = timeParts[0].trim();
      String endTimeString = timeParts[1].trim();

      // Debugging: Print the start and end times
      print('Start time: $startTimeString');
      print('End time: $endTimeString');

      // Use a more explicit date format if needed
      final DateFormat timeFormat = DateFormat('h:mm a');

      // Use today's date for both start and end times
      DateTime now = DateTime.now();
      DateTime startTime = timeFormat.parse(startTimeString);
      DateTime endTime = timeFormat.parse(endTimeString);

      // Combine the parsed time with today's date
      startTime = DateTime(now.year, now.month, now.day, startTime.hour, startTime.minute);
      endTime = DateTime(now.year, now.month, now.day, endTime.hour, endTime.minute);

      // If end time is before start time, add one day to the end time
      if (endTime.isBefore(startTime)) {
        endTime = endTime.add(const Duration(days: 1));
      }

      // Debugging: Print the parsed start and end times
      print('Parsed start time: $startTime');
      print('Parsed end time: $endTime');

      // Return a TimeRange object containing both times
      return TimeRange(startTime, endTime);
    } catch (e) {
      // Debugging: Print the error
      print('Error parsing time May Be Network Problem');
      throw const FormatException('Error fetching data May Be Network Problem');
    }
  }

  void _navigateToAttendanceScreen(
      String branch, String semester, String session, String subject, String type, String time
      ) {
    // Ensure session is formatted correctly
    String sanitizedSession = session.trim();

    Navigator.pushNamed(context, '/home', arguments: {
      'branch': branch,
      'semester': semester,
      'session': sanitizedSession,  // Pass the sanitized session
      'subject': subject,
      'type': type,
      'time': time,
      'facultyName': facultyName ?? 'Unknown',
      'facultyId': employeeId ?? 'Unknown',
    });

    print("Navigating with session: $sanitizedSession");
  }

  void _navigateToAttendanceScreenex(
      String branch,
      String semester,
      String subject,
      String time,
      String type, {
        String facultyName = 'Unknown',
        String facultyId = 'Unknown',
      }) {
    Navigator.pushNamed(context, '/home', arguments: {
      'branch': branch,
      'semester': semester,
      'subject': subject,
      'time':time,
      'type': type,
      'facultyName': facultyName,
      'facultyId': facultyId,
    });
    print("Navigating with facultyName: $facultyName and facultyId: $facultyId and branch: $branch and semester: $semester and time: $time");
  }

  void _navigateToSavedFilesScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ViewSavedFilesScreen()),
    );
  }
// Function to select custom time
  Future<TimeOfDay?> selectCustomTime(BuildContext context, String label) async {
    TimeOfDay selectedCustomTime = const TimeOfDay(hour: 10, minute: 0); // Initialized

    return showDialog<TimeOfDay>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Select $label Time'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Hour Dropdown
                  DropdownButton<int>(
                    value: selectedCustomTime.hour,
                    items: List.generate(8, (index) => 10 + index).map((hour) {
                      return DropdownMenuItem<int>(
                        value: hour,
                        child: Text(hour == 12
                            ? '12 PM'
                            : hour > 12
                            ? '${hour - 12} PM'
                            : '$hour AM'),
                      );
                    }).toList(),
                    onChanged: (int? newHour) {
                      if (newHour != null) {
                        setState(() {
                          selectedCustomTime = TimeOfDay(hour: newHour, minute: selectedCustomTime.minute);
                        });
                      }
                    },
                  ),

                  // Minute Dropdown
                  DropdownButton<int>(
                    value: selectedCustomTime.minute,
                    items: [0, 30].map((minute) {
                      return DropdownMenuItem<int>(
                        value: minute,
                        child: Text(minute.toString().padLeft(2, '0')),
                      );
                    }).toList(),
                    onChanged: (int? newMinute) {
                      if (newMinute != null) {
                        setState(() {
                          selectedCustomTime = TimeOfDay(hour: selectedCustomTime.hour, minute: newMinute);
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, null); // Cancel the dialog
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, selectedCustomTime); // Return the selected time
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  Future<void> _logout() async {
    try {
      // Clear local data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Navigate to login screen
      Navigator.pushReplacementNamed(context, '/login_screen');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error logging out: May Be Network Problem')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'उपस्थित्यम् GECM',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Log Out',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent, Colors.cyanAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else if (errorMessage != null)
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ),
                  ),
                )
              else
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  color: Colors.white,
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.person, color: Colors.blueAccent, size: 28),
                                SizedBox(width: 8),
                                Text(
                                  'Faculty Name:',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent),
                                ),
                              ],
                            ),
                            Text(
                              facultyName ?? 'Unknown',
                              style: const TextStyle(fontSize: 16, color: Colors.black87),
                            ),
                            const SizedBox(height: 12),
                            const Row(
                              children: [
                                Icon(Icons.badge, color: Colors.blueAccent, size: 28),
                                SizedBox(width: 8),
                                Text(
                                  'Faculty ID:',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent),
                                ),
                              ],
                            ),
                            Text(
                              employeeId ?? 'Unknown',
                              style: const TextStyle(fontSize: 16, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 16,
                        top: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Date :         ',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                            ),
                            Text(
                              currentDate,
                              style: const TextStyle(fontSize: 16, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
,
              const SizedBox(height: 20),
              DropdownButton<String?>(
                value: selectedDay.isNotEmpty ? selectedDay : null,
                items: {Regular,'Extra Class'}.map((day) {
                  return DropdownMenuItem<String?>(
                    value: day,
                    child: Text(day!),
                  );
                }).toList(),
                onChanged: (newDay) async {
                  setState(() {
                    selectedDay = newDay ?? '';
                    if (employeeId != null && selectedDay != 'Sunday') {
                      _fetchUserDetails();
                    }
                  });

                  if (selectedDay == 'Extra Class') {
                    if (selectedBranch != null && selectedSemester != null) {
                      fetchedSubjects = await _fetchSubjects(); // Fetch data based on selected branch and semester
                      setState(() {}); // Update UI to reflect fetched subjects
                    }
                  } else {
                    fetchedSubjects.clear(); // Clear fetched subjects when a regular day is selected
                    setState(() {}); // Ensure UI updates
                  }
                },
                style: const TextStyle(color: Colors.black, fontSize: 16),
                iconEnabledColor: Colors.black,
                underline: Container(
                  height: 2,
                  color: Colors.black,
                ),
              ),


// UI logic based on selectedDay
              if (selectedDay == 'Extra Class') ...[
                // Dropdown for a single time
                DropdownButton<String?>(
                  hint: const Text('Select time'),
                  value: selectedTime,
                  items: [
                    DropdownMenuItem<String?>(
                      value: selectedStartTime != null && selectedEndTime != null
                          ? 'time (${selectedStartTime!.format(context)} - ${selectedEndTime!.format(context)})'
                          : 'time',
                      child: Text(
                        selectedStartTime != null && selectedEndTime != null
                            ? 'time (${selectedStartTime!.format(context)} - ${selectedEndTime!.format(context)})'
                            : 'time',
                      ),
                    ),
                  ],
                  onChanged: (newtime) async {
                    // Prompt to select start time using custom time picker
                    TimeOfDay? startTime = await selectCustomTime(context, 'Start');

                    if (startTime != null) {
                      // Prompt to select end time using custom time picker
                      TimeOfDay? endTime = await selectCustomTime(context, 'End');

                      if (endTime != null) {
                        setState(() {
                          selectedTime = 'time (${startTime.format(context)} - ${endTime.format(context)})';
                          selectedStartTime = startTime;
                          selectedEndTime = endTime;
                        });
                      }
                    }
                  },
                ),
                DropdownButton<String?>(
                  hint: const Text('Select Branch'),
                  value: selectedBranch,
                  items: ['CSE', 'CSE-IOT', 'CE-A', 'CE-B', 'ME', 'EE'].map((branch) {
                    return DropdownMenuItem<String?>(
                      value: branch,
                      child: Text(branch),
                    );
                  }).toList(),
                  onChanged: (newBranch) {
                    setState(() {
                      selectedBranch = newBranch;
                    });

                    if (selectedBranch != null && selectedSemester != null) {
                      _fetchSubjects().then((subjects) {
                        setState(() {
                          // Add "Mentor" as a permanent subject
                          fetchedSubjects = [...subjects,
                            {
                              'subject_name': 'Mentor',
                              'subject_code': '',
                            }];
                        });
                      });
                    }
                  },
                 ),
                DropdownButton<String?>(
                  hint: const Text('Select Semester'),
                  value: selectedSemester,
                  items: ['Sem-1', 'Sem-2', 'Sem-3', 'Sem-4', 'Sem-5', 'Sem-6', 'Sem-7', 'Sem-8'].map((semester) {
                    return DropdownMenuItem<String?>(
                      value: semester,
                      child: Text(semester),
                    );
                  }).toList(),
                  onChanged: (newSemester) {
                    setState(() {
                      selectedSemester = newSemester;
                    });

                    if (selectedBranch != null && selectedSemester != null) {
                      _fetchSubjects().then((subjects) {
                        setState(() {
                          // Add "Mentor" as a permanent subject
                          fetchedSubjects = [...subjects,
                            {
                              'subject_name': 'Mentor',
                              'subject_code': '',
                            }];
                        });
                      });
                    }
                  },
                ),
              //   // DropdownButton<String?>(
              //   //   hint: const Text('Select Subject'),
              //   //   value: selectedSubject,
              //   //   items: fetchedSubjects.map((subject) {
              //   //     return DropdownMenuItem<String?>(
              //   //       value: subject,
              //   //       child: Text(subject),
              //   //     );
              //   //   }).toList(),
              //   //   onChanged: (newSubject) {
              //   //     setState(() {
              //   //       selectedSubject = newSubject;
              //   //     });
              //   //   },
              //   // ),
               ],

              if (selectedDay != 'Extra Class' && selectedDay.isNotEmpty) ...[
                Expanded(
                  child: ListView.builder(
                    itemCount: classes.length,
                    itemBuilder: (context, index) {
                      final classData = classes[index];
                      if (classData['day'] != selectedDay) return Container(); // Only show classes for the selected day
                      return InkWell(
                        onTap: () {
                          _navigateToAttendanceScreen(
                            classData['branch'] ?? 'Unknown Branch',
                            classData['semester'] ?? 'Unknown Semester',
                            classData['session'] ?? 'session',
                            classData['subject'] ?? 'Unknown Subject',
                            classData['type'] ?? 'Theory',
                              classData['time'] ?? 'Unknown Time',
                          );
                        },
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: const Icon(Icons.class_, color: Colors.blueAccent, size: 24),
                            title: Text(
                              classData['subject'] ?? 'Unknown Subject',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${classData['branch'] ?? 'Unknown Branch'} - ${classData['semester'] ?? 'Unknown Semester'}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Day: ${classData['day'] ?? 'Unknown Day'}',
                                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                ),
                                Text(
                                  'Time: ${classData['time'] ?? 'Unknown Time'}',
                                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              if (selectedDay == 'Extra Class' && fetchedSubjects.isNotEmpty) ...[
                Expanded(
                  child: ListView.builder(
                    itemCount: fetchedSubjects.length,
                    itemBuilder: (context, index) {
                      final subjectData = fetchedSubjects[index];
                      return ListTile(
                        title: Text(subjectData['subject_name'] ?? 'Unknown Name'),
                        subtitle: Text(subjectData['subject_code'] ?? 'Unknown Code'),
                        onTap: () {
                          _navigateToAttendanceScreenex(
                            selectedBranch ?? 'Unknown Branch',
                            selectedSemester ?? 'Unknown Semester',

                            subjectData['subject_name'] ?? 'Unknown Name',

                           selectedTime ?? 'Unknown time',
                            'Theory', // Replace with the appropriate value if available
                            facultyName: facultyName ?? 'Unknown',
                            facultyId: employeeId ?? 'Unknown',
                          );
                        },
                      );
                    },
                  ),
                ),
              ],




              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _navigateToSavedFilesScreen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent, // Background color
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // Rounded corners
                  ),
                  elevation: 5, // Shadow effect
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                icon: const Icon(
                  Icons.folder, // Icon for the button
                  size: 24,
                  color: Colors.white,
                ),
                label: const Text(
                  'View Attendance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
