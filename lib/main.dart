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
  TextEditingController _searchController = TextEditingController();

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
      _filteredNotes = List.from(_allNotes);
      _isLoaded = true;
    });
  }

  void _filterNotes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredNotes = List.from(_allNotes);
      } else {
        _filteredNotes = _allNotes.where((note) {
          final title = (note['title'] as String?)?.toLowerCase() ?? '';
          final content = (note['content'] as String?)?.toLowerCase() ?? '';
          return title.contains(query) || content.contains(query);
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

  void deleteNote(int index) {
    final noteToDelete = _filteredNotes[index];
    final originalIndex = _allNotes.indexOf(noteToDelete);
    setState(() {
      if (originalIndex != -1) {
        _allNotes.removeAt(originalIndex);
      }
      _filterNotes();
      _saveNotes();
    });
  }

  void editNote(int index, String newTitle, String newContent) {
    final noteToEdit = _filteredNotes[index];
    final originalIndex = _allNotes.indexOf(noteToEdit);
    if (originalIndex != -1) {
      setState(() {
        _allNotes[originalIndex]['title'] = newTitle;
        _allNotes[originalIndex]['content'] = newContent;
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
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
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
 String _getCategoryForDate(String date) {
    final noteDate = DateFormat('MMMM d, y • h:mm a').parse(date);
    final now = DateTime.now();
    final difference = now.difference(noteDate);

    if (difference.inDays == 1) {
      return "Yesterday";
    } else if (difference.inDays <= 7) {
      return "Previous 7 Days";
    } else if (difference.inDays <= 30) {
      return "Previous 30 Days";
    } else {
      return "Older";
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Notes'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.settings_solid),
          onPressed: () => _showDevelopersDialog(context),
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
                  : ListView.builder(
                itemCount: _filteredNotes.length,
                itemBuilder: (context, index) {
                  var note = _filteredNotes[index];
                  String category = _getCategoryForDate(note['date']);
                  return Dismissible(
                    key: Key(note['title'] ?? ''),
                    background: Container(
                      color: CupertinoColors.destructiveRed,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(CupertinoIcons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) => deleteNote(index),
                    child: Column(
                      children: [
                        Container(
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
                            title: Text(
                              note['title'].isEmpty ? "(No Title)" : note['title'],
                              style: const TextStyle(fontSize: 18),
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
                                      title: _allNotes[originalIndex]['title'] ?? '',
                                      content: _allNotes[originalIndex]['content'] ?? '',
                                      date: _allNotes[originalIndex]['date'] ?? '',
                                      onSave: (newTitle, newContent) => editNote(index, newTitle, newContent),
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredNotes.fold<int>(0, (prev, section) => prev + 1)} ${_filteredNotes.isEmpty ? 'No Notes' : 'Notes'}',
                    style: const TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 14,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: addNote,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: CupertinoColors.activeBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        CupertinoIcons.pen,
                        color: Colors.white,
                        size: 24,
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
            const SizedBox(height: 12),
            const Text(
              "Title:",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 6),
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
            Expanded(
              child: CupertinoTextField(
                controller: contentController,
                placeholder: "Start typing...",
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
