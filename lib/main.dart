import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('notes');
  runApp(const CupertinoApp(
    debugShowCheckedModeBanner: false,
    home: NotesApp(),
  ));
}

class NotesApp extends StatefulWidget {
  const NotesApp({super.key});

  @override
  State<NotesApp> createState() => _NotesAppState();
}

class _NotesAppState extends State<NotesApp> {
  List<dynamic> _allNotes = [];
  List<dynamic> _filteredNotes = [];
  final box = Hive.box('notes');
  bool _isLoaded = false;
  final TextEditingController _searchController = TextEditingController();

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
        _filteredNotes = List.from(notes);
      } else {
        _filteredNotes = notes.where((note) {
          final title = (note['title'] as String?)?.toLowerCase() ?? '';
          final content = (note['content'] as String?)?.toLowerCase() ?? '';
          return title.contains(lowerCaseQuery) || content.contains(lowerCaseQuery);
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
        content: const Text('Note deleted'),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('OK'),
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
      _filterNotes();
      _saveNotes();
    });
  }

  void _pinNote(dynamic note) {
    final originalIndex = _allNotes.indexOf(note);
    if (originalIndex != -1) {
      setState(() {
        _allNotes[originalIndex]['isPinned'] = true;
        // To visually update the order, trigger a re-filter
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
        // To visually update the order, trigger a re-filter
        _filterNotes();
        _saveNotes();
      });
    }
  }

  void _saveNotes() {
    box.put('notes', _allNotes);
  }

  void _showDevelopersDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text(
          'Developers',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Arpon Jolas\n'
              'Carreon Monica\n'
              'Gamboa Romel\n'
              'Gomez Dexter\n'
              'Larin Kayle',
          style: TextStyle(fontSize: 18),
        ),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('Close'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
 Widget _buildNoteItem(BuildContext context, dynamic note) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          return true;
        }
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          deleteNote(note);
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        color: CupertinoColors.destructiveRed,
        child: const Icon(
          CupertinoIcons.trash,
          color: CupertinoColors.white,
        ),
      ),
      child: GestureDetector(
        onLongPress: () {
          _showContextMenu(context, note);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: CupertinoColors.white,
              width: 1.5,
            ),
          ),
          child: CupertinoListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    note['title'].isEmpty ? "(No Title)" : note['title'],
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                if (note['isPinned'] == true)
                  const Icon(
                    CupertinoIcons.pin_fill,
                    color: CupertinoColors.activeOrange,
                    size: 16,
                  ),
              ],
            ),
            subtitle: Text(
              '${note['date']} — ${note['content']}',
              style: const TextStyle(color: CupertinoColors.systemGrey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              final originalIndex = _allNotes.indexOf(note);
              if (originalIndex != -1) {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => EditNotePage(
                      title: note['title'],
                      content: note['content'],
                      date: note['date'],
                      onSave: (newTitle, newContent) =>
                          editNote(originalIndex, newTitle, newContent),
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }
