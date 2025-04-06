import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('notes');
  runApp(const NotesAppWrapper());
}

class NotesAppWrapper extends StatefulWidget {
  const NotesAppWrapper({super.key});

  @override
  State<NotesAppWrapper> createState() => _NotesAppWrapperState();
}

class _NotesAppWrapperState extends State<NotesAppWrapper> {
  bool _isDarkMode = false;

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      ),
      home: NotesApp(isDarkMode: _isDarkMode, toggleTheme: _toggleTheme),
    );
  }
}

class NotesApp extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback toggleTheme;

  const NotesApp({super.key, required this.isDarkMode, required this.toggleTheme});

  @override
  State<NotesApp> createState() => _NotesAppState();
}

class _NotesAppState extends State<NotesApp> {
  List<dynamic> _allNotes = [];
  List<dynamic> _filteredNotes = [];
  final box = Hive.box('notes');
  bool _isLoaded = false;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _trashedNotes = [];

  List<dynamic> get _pinnedNotes =>
      _filteredNotes.where((note) => note['isPinned'] == true).toList();

  List<dynamic> get _unpinnedNotes =>
      _filteredNotes.where((note) => note['isPinned'] != true).toList();

  @override
  void initState() {
    super.initState();
    _loadNotesOnStartup();
    _searchController.addListener(_filterNotes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotesOnStartup() async {
    final storedNotes = box.get('notes', defaultValue: []) as List<dynamic>;
    setState(() {
      _allNotes = storedNotes;
      _filterNotesInternal(storedNotes, _searchController.text);
      _isLoaded = true;
    });
  }

  void _filterNotes() {
    _filterNotesInternal(_allNotes, _searchController.text);
  }

  void _filterNotesInternal(List<dynamic> notes, String query) {
    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      if (lowerCaseQuery.isEmpty) {
        _filteredNotes = notes.where((note) => note['isArchived'] == false).toList();
      } else {
        _filteredNotes = notes.where((note) {
          final title = (note['title'] as String?)?.toLowerCase() ?? '';
          final content = (note['content'] as String?)?.toLowerCase() ?? '';
          return (title.contains(lowerCaseQuery) || content.contains(lowerCaseQuery)) && note['isArchived'] == false;
        }).toList();
      }
    });
  }
 void addNote() {
    String now = DateFormat('MMMM d, y • h:mm a').format(DateTime.now());
    final newNote = {
      "title": "",
      "content": "",
      "date": now,
      "isPinned": false,
      "isArchived": false,
    };

    setState(() {
      _allNotes.insert(0, newNote);
      _filterNotes();
      _saveNotes();
    });

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => EditNotePage(
          title: "",
          content: "",
          date: now,
          onSave: (newTitle, newContent) {
            editNote(0, newTitle, newContent);
          },
        ),
      ),
    );
  }

  void deleteNote(dynamic noteToDelete) {
    final originalIndex = _allNotes.indexOf(noteToDelete);
    if (originalIndex != -1) {
      setState(() {
        _allNotes.removeAt(originalIndex);
        _filterNotes();
        _saveNotes();
      });
      _showDeleteConfirmation();
    }
  }

  void _showDeleteConfirmation() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        content: const Text(
          'Note deleted',
          style: TextStyle(fontSize: 18),
        ),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('OK', style: TextStyle(fontSize: 18)),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void editNote(int index, String newTitle, String newContent) {
    final noteToEdit = _allNotes[index];
    setState(() {
      noteToEdit['title'] = newTitle;
      noteToEdit['content'] = newContent;
      noteToEdit['date'] = DateFormat('MMMM d, y • h:mm a').format(DateTime.now());
      _filterNotes();
      _saveNotes();
    });
  }

  void _pinNote(dynamic note) {
    final originalIndex = _allNotes.indexOf(note);
    if (originalIndex != -1) {
      setState(() {
        _allNotes[originalIndex]['isPinned'] = true;
        _filterNotes();
        _saveNotes();
      });
    }
  }

  void _unpinNote(dynamic note) {
    final originalIndex = _allNotes.indexOf(note);
    if (originalIndex != -1 && _allNotes[originalIndex]['isPinned'] == true) {
      setState(() {
        _allNotes[originalIndex]['isPinned'] = false;
        _filterNotes();
        _saveNotes();
      });
    }
  }

  void _archiveNote(dynamic note) {
    final originalIndex = _allNotes.indexOf(note);
    if (originalIndex != -1) {
      setState(() {
        _allNotes[originalIndex]['isArchived'] = true;
        _filterNotes();
        _saveNotes();
      });
    }
  }

  void _saveNotes() {
    box.put('notes', _allNotes);
  }

  void _showArchivePage(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => ArchivePage(
          archivedNotes: _allNotes.where((note) => note['isArchived'] == true).toList(),
          deleteArchivedNote: _deleteArchivedNote,
          unarchiveNote: _unarchiveNote,
        ),
      ),
    );
  }
  void _unarchiveNote(dynamic note) {
    final originalIndex = _allNotes.indexOf(note);
    if (originalIndex != -1) {
      setState(() {
        _allNotes[originalIndex]['isArchived'] = false;
        _filterNotes();
        _saveNotes();
      });
      Navigator.pop(context); // Return to main notes page after unarchiving
    }
  }
