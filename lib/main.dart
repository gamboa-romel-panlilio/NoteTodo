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
 void _deleteArchivedNote(dynamic note) {
    final originalIndex = _allNotes.indexOf(note);
    if (originalIndex != -1) {
      setState(() {
        _moveToTrash(note);
        _saveNotes();
      });
      Navigator.pop(context); // return to notes after deletion.
    }
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
            child: const Text('Close', style: TextStyle(fontSize: 18)),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // Trash handling functions
  void _moveToTrash(dynamic note) {
    final originalIndex = _allNotes.indexOf(note);
    if (originalIndex != -1) {
      setState(() {
        _allNotes[originalIndex]['isArchived'] = true;
        _trashedNotes.insert(0, _allNotes.removeAt(originalIndex));
        _filterNotes();
        _saveNotes();
      });
    }
  }

  void _restoreFromTrash(dynamic note) {
    setState(() {
      note['isArchived'] = false;
      _allNotes.insert(0, note);
      _trashedNotes.remove(note);
      _filterNotes();
      _saveNotes();
    });
    Navigator.pop(context); // Close the trash page after restore
  }

  void _deleteFromTrash(dynamic note) {
    setState(() {
      _trashedNotes.remove(note);
      _saveNotes();
    });
    Navigator.pop(context); // Close the trash page after permanent deletion
  }

  void _showTrashPage(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => TrashPage(
          trashedNotes: _trashedNotes,
          restoreFromTrash: _restoreFromTrash,
          deleteFromTrash: _deleteFromTrash,
        ),
      ),
    );
  }

  Widget _buildNoteItem(BuildContext context, dynamic note) {
    if (note['isArchived'] == true) {
      return const SizedBox.shrink();
    }
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
            color: widget.isDarkMode ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isDarkMode ? CupertinoColors.white : CupertinoColors.black,
              width: 1.5,
            ),
          ),
          child: CupertinoListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    note['title'].isEmpty ? "(No Title)" : note['title'],
                    style: TextStyle(fontSize: 18, color: widget.isDarkMode ? CupertinoColors.white : CupertinoColors.black),
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
              style: TextStyle(color: widget.isDarkMode ? CupertinoColors.systemGrey : CupertinoColors.black),
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

  void _showContextMenu(BuildContext context, dynamic note) {
    final isPinned = note['isPinned'] as bool? ?? false;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          note['title'].isEmpty ? "(No Title)" : note['title'],
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        message: Text(
          note['content'],
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: CupertinoColors.secondaryLabel),
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _archiveNote(note);
            },
            child: const Text('Archive', style: TextStyle(fontSize: 18)),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              if (isPinned) {
                _unpinNote(note);
              } else {
                _pinNote(note);
              }
            },
            child: Text(isPinned ? 'Unpin' : 'Pin', style: TextStyle(fontSize: 18)),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              deleteNote(note);
            },
            child: const Text('Delete', style: TextStyle(fontSize: 18)),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel', style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Notes'),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.tray),
              onPressed: () => _showArchivePage(context),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.trash),
              onPressed: () => _showTrashPage(context),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(
                  widget.isDarkMode ? CupertinoIcons.sun_max : CupertinoIcons.moon_stars),
              onPressed: () => widget.toggleTheme(),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.settings_solid),
              onPressed: () => _showDevelopersDialog(context),
            ),
          ],
        ),
      ),
