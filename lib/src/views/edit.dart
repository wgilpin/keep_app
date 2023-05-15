import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/controllers/auth_controller.dart';
import 'package:keep_app/src/notes.dart';

class EditNoteForm extends StatefulWidget {
  final Note _note;

  const EditNoteForm(this._note, {super.key});

  @override
  State<EditNoteForm> createState() => _EditNoteFormState();
}

class _EditNoteFormState extends State<EditNoteForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtl;
  late TextEditingController _commentCtl;
  late TextEditingController _snippetCtl;
  late TextEditingController _urlCtl;

  @override
  void initState() {
    super.initState();
    _titleCtl = TextEditingController(text: widget._note.title);
    _commentCtl = TextEditingController(text: widget._note.comment);
    _snippetCtl = TextEditingController(text: widget._note.snippet);
    _urlCtl = TextEditingController(text: widget._note.url);
  }

  void _onSave(Map<String, Object> note) async {
    // if note has the key "id", add 1
    // else add the note

    late String id;
    if (note.containsKey("id")) {
      id = note["id"].toString();
      note.remove("id");
      await FirebaseFirestore.instance.collection('notes').doc(id).update(note);
    } else {
      final uid = Get.find<AuthCtl>().user!.uid;
      note["user"] = FirebaseFirestore.instance.doc("/users/$uid");
      note["created"] = DateTime.now().toUtc();
      var ref = await FirebaseFirestore.instance.collection('notes').add(note);
      id = ref.id;
    }
    Get.back(result: id);
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is removed from the
    // widget tree.
    _titleCtl.dispose();
    _commentCtl.dispose();
    _snippetCtl.dispose();
    _urlCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Note')),
      body: Form(
        key: _formKey,
        child: Container(
          padding: const EdgeInsets.all(16.0),
          constraints: const BoxConstraints(maxHeight: 800),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: _titleCtl,
                  decoration: const InputDecoration(
                    hintText: 'A title for the note',
                    labelText: 'Title',
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    controller: _commentCtl,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'Comment',
                      labelText: 'Comment',
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    controller: _snippetCtl,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'Snippet of text from a web page',
                      labelText: 'Snippet',
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: _urlCtl,
                  decoration: const InputDecoration(
                    hintText: 'URL of a web page',
                    labelText: 'URL',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    // Validate returns true if the form is valid, or false otherwise.
                    if (_formKey.currentState!.validate()) {
                      final htmlSnippet = _snippetCtl.text.split('\n').map((line) => '$line<br/>').join();
                      _onSave({
                        if (widget._note.id != null) 'id': widget._note.id!,
                        'title': _titleCtl.text,
                        'comment': _commentCtl.text,
                        'snippet': htmlSnippet,
                        'url': _urlCtl.text
                      });
                    }
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
