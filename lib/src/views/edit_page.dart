import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/controllers/auth_controller.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/views/checklist.dart';

// ignore: unused_import

import 'platform_plugin_stub.dart'
    if (dart.library.io) 'platform_plugin_io.dart'
    if (dart.library.html) 'platform_plugin_web.dart';

class EditNoteForm extends StatefulWidget {
  final Note? _initialNote;
  final String? title;
  final String? snippet;
  final String? comment;
  final String? url;
  final bool iFrame;
  final Function()? onChanged;

  /// EditNoteForm constructor
  ///
  /// If the note is not null, then we are editing an existing note.
  /// If the note is null, then we are creating a new note.
  /// If you supply title / comment / snippet / url they will be used as the default values in the form.
  const EditNoteForm(note,
      {this.title, this.comment, this.snippet, this.url, this.iFrame = false, this.onChanged, super.key})
      : _initialNote = note;

  @override
  State<EditNoteForm> createState() => _EditNoteFormState();
}

class _EditNoteFormState extends State<EditNoteForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtl;
  late TextEditingController _commentCtl;
  late TextEditingController _snippetCtl;
  late TextEditingController _urlCtl;
  late Note _note;
  late bool _showChecklist;

  @override
  void initState() {
    super.initState();
    _note = widget._initialNote == null ? Note() : widget._initialNote!;
    // if we are editing an existing note, then populate the form with the existing values
    _titleCtl = TextEditingController(text: _note.title);
    _commentCtl = TextEditingController(text: _note.comment);
    _snippetCtl = TextEditingController(text: replaceBreaksWithNewlines(_note.snippet));
    _urlCtl = TextEditingController(text: _note.url);

    // if we are creating a new note, then populate the form with the supplied values
    _titleCtl.text = widget.title ?? _titleCtl.text;
    _commentCtl.text = widget.comment ?? _commentCtl.text;
    _snippetCtl.text = widget.snippet ?? _snippetCtl.text;
    _urlCtl.text = widget.url ?? _urlCtl.text;

    _showChecklist = _note.checklist.isNotEmpty;
  }

  void _saveNoteToFirebase(Map<String, Object?> note) async {
    // if note has the key "id", add 1
    // else add the note

    late String id;
    if (note.containsKey("id")) {
      // update existing note
      id = note["id"].toString();

      // remove the id from the note, as firebase uses it as a doc reference
      note.remove("id");

      // we are saving so nullify the lockedBy field
      note["lockedBy"] = null;
      note["lockedTime"] = null;
      note = cleanFields(note);
      await FirebaseFirestore.instance.collection('notes').doc(id).update(note);
    } else {
      // add new note
      final uid = Get.find<AuthCtl>().user!.uid;
      note = cleanFields(note);

      // add in the user(owner) and created fields
      note["user"] = FirebaseFirestore.instance.doc("/users/$uid");
      note["created"] = DateTime.now().toUtc();
      var ref = await FirebaseFirestore.instance.collection('notes').add(note);
      id = ref.id;
    }
    // return the id of the note to the caller
    Get.back(result: id);
  }

  /// Clean up the fields before saving
  /// - remove any one-line comment/snippet with just a <br/>
  Map<String, Object?> cleanFields(Map<String, Object?> note) {
    if (note["snippet"] == "<br/>") {
      note["snippet"] = "";
    }
    if (note["comment"] == "<br/>") {
      note["comment"] = "";
    }
    return note;
  }

  /// Replace newlines with <br/> tags
  String replaceNewlinesWithBreaks(String text) {
    if (text.isEmpty) {
      return text;
    }

    List<String> lines = text.split('\n');

    if (lines.last.isEmpty) {
      lines.removeLast(); // This will remove the last empty line if it exists
    }

    if (lines.length == 1) {
      return lines.first;
    }

    return text.replaceAll(RegExp(r'\n'), '<br/>');
  }

  /// Replace all <br/> tags with newlines
  String replaceBreaksWithNewlines(String? text) {
    return (text ?? "").replaceAll(RegExp(r'<br/>'), '\n');
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
    // show back button if we are editing an existing note, or if the showBack flag is set
    bool showLeading = (_note.id != null) || !widget.iFrame;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Note',
          style: TextStyle(fontSize: 16),
        ),
        automaticallyImplyLeading: showLeading,
        leading: showLeading
            ? IconButton(
                icon: const Icon(Icons.arrow_back), // Change this icon to your custom icon
                onPressed: () {
                  // Put your custom function here
                  onBackButton();
                  Navigator.of(context)
                      .pop(); // Optional. This line will navigate back, you can remove this line if you don't want to navigate back immediately.
                },
              )
            : null,
        actions: <Widget>[
          IconButton(
            color: Colors.brown[600],
            onPressed: saveNote,
            icon: const Icon(Icons.save),
            iconSize: 36,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Container(
          padding: const EdgeInsets.all(16.0),
          constraints: const BoxConstraints(maxHeight: 800),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextFormField(
                        controller: _titleCtl,
                        decoration: InputDecoration(
                          hintText: 'A title for the note',
                          labelText: 'Title',
                          fillColor: Colors.yellow[50],
                        ),
                      ),
                    ),
                  ),
                  // only show the add checklist button if there is no checklist. Never show in iFrame
                  if (_note.checklist.isEmpty && !_showChecklist && !widget.iFrame)
                    Tooltip(
                      message: 'Add a checklist',
                      child: IconButton(
                        onPressed: doAddCheck,
                        icon: const Icon(Icons.add_box_outlined),
                      ),
                    ),
                ],
              ),
              if ((_note.id != null && _note.checklist.isNotEmpty) || _showChecklist)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    color: Colors.yellow[50],
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CheckList(
                        note: _note,
                        showChecked: true,
                        onChanged: doChangeCheck,
                        showComment: false,
                      ),
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
                    decoration: InputDecoration(
                      hintText: 'Comment',
                      labelText: 'Comment',
                      fillColor: Colors.yellow[50],
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
                    decoration: InputDecoration(
                      hintText: 'Snippet of text from a web page',
                      labelText: 'Snippet',
                      fillColor: Colors.yellow[50],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: _urlCtl,
                  decoration: InputDecoration(
                    hintText: 'URL of a web page',
                    labelText: 'URL',
                    fillColor: Colors.yellow[50],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Save the note
  /// and clean up the fields before saving
  void saveNote() {
    // Validate returns true if the form is valid, or false otherwise.
    if (_formKey.currentState!.validate()) {
      final htmlSnippet = replaceNewlinesWithBreaks(_snippetCtl.text);
      _saveNoteToFirebase({
        if (_note.id != null) 'id': _note.id!,
        'title': _titleCtl.text,
        'comment': _commentCtl.text,
        'snippet': htmlSnippet,
        'url': _urlCtl.text
      });
      platformPluginMethod();
    }
  }

  Future<void> onBackButton() async {
    // clear the lock on the note, if present. No need to wait for async
    if (_note.id != null) {
      FirebaseFirestore.instance.collection('notes').doc(_note.id).update({
        "lockedBy": null,
        "lockedTime": null,
      });
    }
  }

  void doAddCheck() {
    setState(() {
      _showChecklist = true;
    });
  }

  doChangeCheck() {
    // notify parent
    widget.onChanged?.call();
  }
}
