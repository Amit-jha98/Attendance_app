import 'package:flutter/material.dart';
import 'package:share/share.dart';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ViewSavedFilesScreen extends StatefulWidget {
  const ViewSavedFilesScreen({super.key});

  @override
  _ViewSavedFilesScreenState createState() => _ViewSavedFilesScreenState();
}

class _ViewSavedFilesScreenState extends State<ViewSavedFilesScreen> {
  List<File> excelFiles = [];
  List<File> selectedFiles = [];

  Future<void> _loadSavedExcelFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dirPath = directory.path;
      final dir = Directory(dirPath);

      if (dir.existsSync()) {
        final files = dir
            .listSync()
            .where((file) => file.path.endsWith('.xlsx'))
            .map((file) => File(file.path))
            .toList();
        setState(() {
          excelFiles = files;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading files: May be Network Problem')),
      );
    }
  }

  Future<void> _shareSelectedFiles() async {
    if (selectedFiles.isNotEmpty) {
      try {
        final filePaths = selectedFiles.map((file) => file.path).toList();
        await Share.shareFiles(filePaths);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error sharing files: May be Network Problem')),
        );
      }
    }
  }

  Future<void> _deleteSelectedFiles() async {
    bool confirmed = await _showDeleteConfirmationDialog();
    if (confirmed) {
      try {
        for (var file in selectedFiles) {
          await file.delete();
        }
        setState(() {
          excelFiles.removeWhere((file) => selectedFiles.contains(file));
          selectedFiles.clear();
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error deleting files: May be Network Problem')),
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Files'),
          content: const Text('Are you sure you want to delete the selected files?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ??
        false;
  }

  void _toggleSelection(File file) {
    setState(() {
      if (selectedFiles.contains(file)) {
        selectedFiles.remove(file);
      } else {
        selectedFiles.add(file);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSavedExcelFiles();
  }

  String _extractBranchAndSemester(String fileName) {
    final segments = fileName.split('_');
    if (segments.length >= 3) {
      final branch = segments[1];
      final semester = segments[2];
      return 'Branch: $branch, Semester: $semester';
    }
    return 'Branch & Semester: Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Excel Files'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF00B0FF), // Bright Green
                Color(0xFF64B5F6), // Light Green
                Color(0xFF00B0FF), // Bright Blue
                Color(0xFF64B5F6), // Light Blue
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.3, 0.7, 1.0], // Smooth gradient transitions
            ),
          ),
        ),
        actions: selectedFiles.isNotEmpty
            ? [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareSelectedFiles,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteSelectedFiles,
          ),
        ]
            : null,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF64B5F6), // Bright Green
              Color(0xFF00B0FF), // Light Green
              Color(0xFF00B0FF), // Bright Blue
              Color(0xFF64B5F6), // Light Blue
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.3, 0.7, 1.0], // Smooth gradient transitions
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: excelFiles.isNotEmpty
              ? ListView.builder(
            itemCount: excelFiles.length,
            itemBuilder: (context, index) {
              final file = excelFiles[index];
              final branchAndSemester = _extractBranchAndSemester(path.basename(file.path));
              final isSelected = selectedFiles.contains(file);
              return Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                color: isSelected ? Colors.blue.withValues(alpha: 0.2) : Colors.white,
                child: ListTile(
                  onTap: () => _toggleSelection(file),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                  leading: const Icon(Icons.insert_drive_file, color: Colors.blueAccent, size: 40),
                  title: Text(
                    path.basename(file.path),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.blueAccent, // Add color to title text
                    ),
                  ),
                  subtitle: Text(
                    '$branchAndSemester\nSize: ${_formatBytes(file.lengthSync(), 2)}\nLast Modified: ${_formatDate(file.lastModifiedSync())}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.blueAccent)
                      : null,
                ),
              );
            },
          )
              : const Center(
            child: Text(
              'No saved files found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes, int decimals) {
    if (bytes == 0) return '0 B';
    const k = 1024;
    const dm = 2;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(k)).floor();
    return '${(bytes / pow(k, i)).toStringAsFixed(dm)} ${sizes[i]}';
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}";
  }
}
