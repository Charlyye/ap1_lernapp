import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const AP1LernApp());
}

/// ----------------------
/// Models
/// ----------------------

class Flashcard {
  final String id;
  String question;
  String answer;
  bool learned;

  Flashcard({
    required this.id,
    required this.question,
    required this.answer,
    this.learned = false,
  });

  factory Flashcard.create({required String question, required String answer}) {
    return Flashcard(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      question: question,
      answer: answer,
      learned: false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'answer': answer,
        'learned': learned,
      };

  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
        id: json['id'] as String,
        question: json['question'] as String,
        answer: json['answer'] as String,
        learned: (json['learned'] as bool?) ?? false,
      );
}

class NotePage {
  final String id;
  String title;
  String content;
  DateTime lastEdited;

  NotePage({
    required this.id,
    required this.title,
    required this.content,
    required this.lastEdited,
  });

  factory NotePage.create({required String title}) {
    return NotePage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      content: '',
      lastEdited: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'lastEdited': lastEdited.toIso8601String(),
      };

  factory NotePage.fromJson(Map<String, dynamic> json) => NotePage(
        id: json['id'] as String,
        title: json['title'] as String,
        content: (json['content'] as String?) ?? '',
        lastEdited: DateTime.tryParse((json['lastEdited'] as String?) ?? '') ??
            DateTime.now(),
      );
}

/// ----------------------
/// Storage
/// ----------------------

class AppStorage {
  static const _cardsKey = 'ap1_cards_v1';
  static const _notesKey = 'ap1_notes_v1';

  static Future<List<Flashcard>> loadCards() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cardsKey);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(Flashcard.fromJson).toList();
  }

  static Future<List<NotePage>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notesKey);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(NotePage.fromJson).toList();
  }

  static Future<void> saveCards(List<Flashcard> cards) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(cards.map((c) => c.toJson()).toList());
    await prefs.setString(_cardsKey, raw);
  }

  static Future<void> saveNotes(List<NotePage> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(notes.map((n) => n.toJson()).toList());
    await prefs.setString(_notesKey, raw);
  }
}

/// ----------------------
/// App + State
/// ----------------------

class AP1LernApp extends StatelessWidget {
  const AP1LernApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AP1 LernApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;

  List<Flashcard> cards = [];
  List<NotePage> notes = [];

  bool loaded = false;
  bool onlyOpenCards = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final loadedCards = await AppStorage.loadCards();
    final loadedNotes = await AppStorage.loadNotes();

    if (loadedCards.isEmpty && loadedNotes.isEmpty) {
      loadedCards.addAll([
        Flashcard.create(
          question: 'Was ist ein Primärschlüssel?',
          answer: 'Attribut(e), das einen Datensatz eindeutig identifiziert.',
        ),
        Flashcard.create(
          question: 'Was bedeutet HTTP?',
          answer: 'Hypertext Transfer Protocol.',
        ),
      ]);
      loadedNotes.add(NotePage.create(title: 'AP1 Plan'));
      loadedNotes[0].content =
          'Woche 1: SQL\nWoche 2: OOP\nWoche 3: Netzwerke\n';
      await AppStorage.saveCards(loadedCards);
      await AppStorage.saveNotes(loadedNotes);
    }

    setState(() {
      cards = loadedCards;
      notes = loadedNotes;
      loaded = true;
    });
  }

  Future<void> _persist() async {
    await AppStorage.saveCards(cards);
    await AppStorage.saveNotes(notes);
  }

  Future<void> addCard(String q, String a) async {
    setState(() {
      cards.insert(0, Flashcard.create(question: q, answer: a));
    });
    await _persist();
  }

  Future<void> toggleLearned(Flashcard c) async {
    setState(() {
      c.learned = !c.learned;
    });
    await _persist();
  }

  Future<void> deleteCard(Flashcard c) async {
    setState(() {
      cards.removeWhere((x) => x.id == c.id);
    });
    await _persist();
  }

  Future<void> addNote(String title) async {
    setState(() {
      notes.insert(0, NotePage.create(title: title));
    });
    await _persist();
  }

  Future<void> updateNote(NotePage updated) async {
    setState(() {
      final idx = notes.indexWhere((n) => n.id == updated.id);
      if (idx != -1) notes[idx] = updated;
    });
    await _persist();
  }

  Future<void> deleteNote(NotePage note) async {
    setState(() {
      notes.removeWhere((n) => n.id == note.id);
    });
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cardList =
        onlyOpenCards ? cards.where((c) => !c.learned).toList() : cards;

    return Scaffold(
      appBar: AppBar(
        title: Text(tab == 0 ? 'Karteikarten' : 'Notizen'),
        actions: [
          if (tab == 0)
            Row(
              children: [
                const Text('Nur offen'),
                Switch(
                  value: onlyOpenCards,
                  onChanged: (v) => setState(() => onlyOpenCards = v),
                ),
                const SizedBox(width: 8),
              ],
            ),
        ],
      ),
      body: tab == 0
          ? FlashcardsTab(
              cards: cardList,
              onToggleLearned: toggleLearned,
              onDelete: deleteCard,
            )
          : NotesTab(
              notes: notes,
              onUpdate: updateNote,
              onDelete: deleteNote,
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.style), label: 'Karten'),
          NavigationDestination(icon: Icon(Icons.note_alt), label: 'Notizen'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (tab == 0) {
            final res = await showDialog<_CardDialogResult>(
              context: context,
              builder: (_) => const AddCardDialog(),
            );
            if (res != null) await addCard(res.question, res.answer);
          } else {
            final title = await showDialog<String>(
              context: context,
              builder: (_) => const AddNoteDialog(),
            );
            if (title != null && title.trim().isNotEmpty) {
              await addNote(title.trim());
            }
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// ----------------------
/// Cards UI
/// ----------------------

class FlashcardsTab extends StatelessWidget {
  final List<Flashcard> cards;
  final Future<void> Function(Flashcard c) onToggleLearned;
  final Future<void> Function(Flashcard c) onDelete;

  const FlashcardsTab({
    super.key,
    required this.cards,
    required this.onToggleLearned,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const Center(child: Text('Noch keine Karten. Tippe auf +'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: cards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = cards[i];
        return Card(
          child: ListTile(
            title: Text(
              c.question,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(c.learned ? 'Gelernt' : 'Offen'),
            leading: Icon(
              c.learned ? Icons.check_circle : Icons.circle_outlined,
              color: c.learned ? Colors.green : null,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => onDelete(c),
            ),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FlashcardDetailScreen(
                    card: c,
                    onToggleLearned: onToggleLearned,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class FlashcardDetailScreen extends StatefulWidget {
  final Flashcard card;
  final Future<void> Function(Flashcard c) onToggleLearned;

  const FlashcardDetailScreen({
    super.key,
    required this.card,
    required this.onToggleLearned,
  });

  @override
  State<FlashcardDetailScreen> createState() => _FlashcardDetailScreenState();
}

class _FlashcardDetailScreenState extends State<FlashcardDetailScreen> {
  bool showAnswer = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    return Scaffold(
      appBar: AppBar(title: const Text('Karte')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Frage', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(c.question, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Antwort', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => showAnswer = !showAnswer),
                  child: Text(showAnswer ? 'Verbergen' : 'Anzeigen'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (showAnswer)
              Text(c.answer, style: Theme.of(context).textTheme.titleLarge)
            else
              const Text('Tippe auf „Anzeigen“.'),
            const Spacer(),
            FilledButton.tonal(
              onPressed: () async {
                await widget.onToggleLearned(c);
                setState(() {});
              },
              child: Text(c.learned ? 'Als offen markieren' : 'Als gelernt markieren'),
            ),
          ],
        ),
      ),
    );
  }
}

/// ----------------------
/// Notes UI
/// ----------------------

class NotesTab extends StatelessWidget {
  final List<NotePage> notes;
  final Future<void> Function(NotePage note) onUpdate;
  final Future<void> Function(NotePage note) onDelete;

  const NotesTab({
    super.key,
    required this.notes,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const Center(child: Text('Noch keine Notizen. Tippe auf +'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final n = notes[i];
        return Card(
          child: ListTile(
            title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('Bearbeitet: ${_formatDate(n.lastEdited)}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => onDelete(n),
            ),
            onTap: () async {
              final updated = await Navigator.of(context).push<NotePage>(
                MaterialPageRoute(builder: (_) => NoteEditorScreen(note: n)),
              );
              if (updated != null) await onUpdate(updated);
            },
          ),
        );
      },
    );
  }

  static String _formatDate(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}

class NoteEditorScreen extends StatefulWidget {
  final NotePage note;

  const NoteEditorScreen({super.key, required this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController titleCtrl;
  late TextEditingController contentCtrl;

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.note.title);
    contentCtrl = TextEditingController(text: widget.note.content);
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notiz bearbeiten'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              final updated = NotePage(
                id: widget.note.id,
                title: titleCtrl.text.trim().isEmpty
                    ? 'Ohne Titel'
                    : titleCtrl.text.trim(),
                content: contentCtrl.text,
                lastEdited: DateTime.now(),
              );
              Navigator.of(context).pop(updated);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Titel'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: contentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Inhalt',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ----------------------
/// Dialogs
/// ----------------------

class _CardDialogResult {
  final String question;
  final String answer;
  _CardDialogResult(this.question, this.answer);
}

class AddCardDialog extends StatefulWidget {
  const AddCardDialog({super.key});

  @override
  State<AddCardDialog> createState() => _AddCardDialogState();
}

class _AddCardDialogState extends State<AddCardDialog> {
  final qCtrl = TextEditingController();
  final aCtrl = TextEditingController();

  @override
  void dispose() {
    qCtrl.dispose();
    aCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neue Karte'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qCtrl,
              decoration: const InputDecoration(labelText: 'Frage'),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: aCtrl,
              decoration: const InputDecoration(labelText: 'Antwort'),
              minLines: 1,
              maxLines: 4,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            final q = qCtrl.text.trim();
            final a = aCtrl.text.trim();
            if (q.isEmpty || a.isEmpty) return;
            Navigator.of(context).pop(_CardDialogResult(q, a));
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

class AddNoteDialog extends StatefulWidget {
  const AddNoteDialog({super.key});

  @override
  State<AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<AddNoteDialog> {
  final titleCtrl = TextEditingController();

  @override
  void dispose() {
    titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neue Notiz'),
      content: TextField(
        controller: titleCtrl,
        decoration: const InputDecoration(labelText: 'Titel'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(titleCtrl.text.trim()),
          child: const Text('Anlegen'),
        ),
      ],
    );
  }
}
