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
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search notes...',
                onChanged: (_) => _filterNotes(),
              ),
            ),
            Expanded(
              child: !_isLoaded
                  ? const Center(child: CupertinoActivityIndicator())
                  : _filteredNotes.isEmpty
                  ? const Center(
                child: Text(
                  "No Notes Found",
                  style: TextStyle(
                    fontSize: 18,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              )
                  : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_pinnedNotes.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Pinned Notes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: CupertinoColors.activeOrange,
                          ),
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _pinnedNotes.length,
                        itemBuilder: (context, index) =>
                            _buildNoteItem(context, _pinnedNotes[index]),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(
                          color: CupertinoColors.separator,
                        ),
                      ),
                    ],
                    if (_unpinnedNotes.isNotEmpty) ...[
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _unpinnedNotes.length,
                        itemBuilder: (context, index) =>
                            _buildNoteItem(context, _unpinnedNotes[index]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredNotes.where((note) => note['isArchived'] == false).length} ${_filteredNotes.where((note) => note['isArchived'] == false).isEmpty ? 'No Notes' : 'Notes'}',
                    style: const TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: addNote,
                    child: const Icon(
                      CupertinoIcons.pencil_outline,
                      color: CupertinoColors.activeBlue,
                      size: 28,
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

class EditNotePage extends StatefulWidget {
  final String title;
  final String content;
  final String date;
  final Function(String, String) onSave;

  const EditNotePage({
    super.key,
    required this.title,
    required this.content,
    required this.date,
    required this.onSave,
  });

  @override
  State<EditNotePage> createState() => _EditNotePageState();
}

class _EditNotePageState extends State<EditNotePage> {
  late TextEditingController titleController;
  late TextEditingController contentController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.title);
    contentController = TextEditingController(text: widget.content);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text("Edit Note"),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text(
            "Save",
            style: TextStyle(color: CupertinoColors.activeBlue),
          ),
          onPressed: () {
            widget.onSave(titleController.text, contentController.text);
            Navigator.pop(context);
          },
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.date,
              style: const TextStyle(
                color: CupertinoColors.systemGrey2,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Title:",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: titleController,
              placeholder: "Enter title",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Notes:",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 6),
            CupertinoTextField(
              controller: contentController,
              placeholder: "Type here...",
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              padding: const EdgeInsets.all(12),
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class ArchivePage extends StatelessWidget {
  final List<dynamic> archivedNotes;
  final Function(dynamic) deleteArchivedNote;
  final Function(dynamic) unarchiveNote;

  const ArchivePage({
    super.key,
    required this.archivedNotes,
    required this.deleteArchivedNote,
    required this.unarchiveNote,
  });

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = CupertinoTheme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Archived Notes'),
      ),
      child: SafeArea(
        child: archivedNotes.isEmpty
            ? const Center(
          child: Text(
            "No Archived Notes",
            style: TextStyle(
              fontSize: 18,
              color: CupertinoColors.systemGrey,
            ),
          ),
        )
            : ListView.builder(
          itemCount: archivedNotes.length,
          itemBuilder: (context, index) {
            final note = archivedNotes[index];
            return GestureDetector(
              onLongPress: () {
                _showContextMenu(context, note);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode ? CupertinoColors.white : CupertinoColors.black,
                    width: 1.5,
                  ),
                ),
                child: CupertinoListTile(
                  title: Text(
                    note['title'].isEmpty ? "(No Title)" : note['title'],
                    style: TextStyle(fontSize: 18, color: isDarkMode ? CupertinoColors.white : CupertinoColors.black),
                  ),
                  subtitle: Text(
                    '${note['date']} — ${note['content']}',
                    style: TextStyle(color: isDarkMode ? CupertinoColors.systemGrey : CupertinoColors.black),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, dynamic note) {
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
              unarchiveNote(note);
            },
            child: const Text('Unarchive', style: TextStyle(fontSize: 18)),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              deleteArchivedNote(note);
            },
            child: const Text('Move to Trash', style: TextStyle(fontSize: 18)),
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
}

class TrashPage extends StatelessWidget {
  final List<dynamic> trashedNotes;
  final Function(dynamic) restoreFromTrash;
  final Function(dynamic) deleteFromTrash;

  const TrashPage({
    super.key,
    required this.trashedNotes,
    required this.restoreFromTrash,
    required this.deleteFromTrash,
  });

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = CupertinoTheme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Trash'),
      ),
      child: SafeArea(
        child: trashedNotes.isEmpty
            ? const Center(
          child: Text(
            "Trash is empty",
            style: TextStyle(
              fontSize: 18,
              color: CupertinoColors.systemGrey,
            ),
          ),
        )
            : ListView.builder(
          itemCount: trashedNotes.length,
          itemBuilder: (context, index) {
            final note = trashedNotes[index];
            return GestureDetector(
              onLongPress: () {
                _showContextMenu(context, note);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode ? CupertinoColors.white : CupertinoColors.black,
                    width: 1.5,
                  ),
                ),
                child: CupertinoListTile(
                  title: Text(
                    note['title'].isEmpty ? "(No Title)" : note['title'],
                    style: TextStyle(fontSize: 18, color: isDarkMode ? CupertinoColors.white : CupertinoColors.black),
                  ),
                  subtitle: Text(
                    '${note['date']} — ${note['content']}',
                    style: TextStyle(color: isDarkMode ? CupertinoColors.systemGrey : CupertinoColors.black),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, dynamic note) {
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
              restoreFromTrash(note);
            },
            child: const Text('Restore', style: TextStyle(fontSize: 18)),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              deleteFromTrash(note);
            },
            child: const Text('Delete permanently', style: TextStyle(fontSize: 18)),
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
}