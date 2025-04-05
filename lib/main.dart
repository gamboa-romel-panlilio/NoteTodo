import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();  // Initialize Hive
  await Hive.openBox('notes'); // Open the notes box to store notes
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
  List<dynamic> notesList = [];
  final box = Hive.box('notes');

  @override
  void initState() {
    super.initState();
    loadNotes(); // Load notes from Hive when the app starts
  }

  // Load notes from Hive storage
  void loadNotes() {
    setState(() {
      // Make sure the notes are read correctly from Hive
      notesList = box.get('notes', defaultValue: []) as List<dynamic>;
    });
  }

  // Add a new note
  void addNote() {
    String now = DateFormat('MMMM d, y • h:mm a').format(DateTime.now());
    setState(() {
      notesList.insert(0, {
        "title": "",
        "content": "",
        "date": now,
      });
      box.put('notes', notesList); // Save the notes list to Hive
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


  // Delete a note
  void deleteNote(int index) {
    setState(() {
      notesList.removeAt(index);
      box.put('notes', notesList); // Save updated list after deletion
    });
  }

  // Edit an existing note
  void editNote(int index, String newTitle, String newContent) {
    setState(() {
      notesList[index]['title'] = newTitle;
      notesList[index]['content'] = newContent;
      box.put('notes', notesList); // Save updated note to Hive
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Notes'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: notesList.isEmpty
                    ? const Center(
                  child: Text(
                    "No Notes",
                    style: TextStyle(
                      fontSize: 18,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                )
   : ListView.builder(
                  itemCount: notesList.length,
                  itemBuilder: (context, index) {
                    var note = notesList[index];
                    return Dismissible(
                      key: Key((note['title'] ?? '') + index.toString()),
                      background: Container(
                        color: CupertinoColors.destructiveRed,
                        alignment: Alignment.centerRight,
                        padding:
                        const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(CupertinoIcons.delete,
                            color: Colors.white),


                      ),
                      onDismissed: (direction) => deleteNote(index),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8), // Dark gray
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: CupertinoColors.white, // White border
                            width: 1.5, // Border width
                          ),
                        ),
                        child: CupertinoListTile(
                          title: Text(
                            note['title'].isEmpty
                                ? "(No Title)"
                                : note['title'],
                            style: const TextStyle(fontSize: 18),
                          ),
                          subtitle: Text(
                            '${note['date'] ?? ''} — ${note['content'].isNotEmpty ? note['content'] : "No additional text"}',
                            style: const TextStyle(
                                color: CupertinoColors.systemGrey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) => EditNotePage(
                                  title: note['title'],
                                  content: note['content'],
                                  date: note['date'] ?? '',
                                  onSave: (newTitle, newContent) =>
                                      editNote(index, newTitle, newContent),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
  Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${notesList.length} ${notesList.length == 1 ? 'Note' : 'Notes'}',
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
