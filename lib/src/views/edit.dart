import 'dart:html';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/controllers/auth_controller.dart';
import 'package:keep_app/src/notes.dart';

class EditNoteForm extends StatefulWidget {
  final Note? _note;
  final String? title;
  final String? snippet;
  final String? comment;
  final String? url;

  /// EditNoteForm constructor
  ///
  /// If the note is not null, then we are editing an existing note.
  /// If the note is null, then we are creating a new note.
  /// If you supply title / comment / snippet / url they will be used as the default values in the form.
  const EditNoteForm(this._note, {this.title, this.comment, this.snippet, this.url, super.key});

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
    // if we are editing an existing note, then populate the form with the existing values
    _titleCtl = TextEditingController(text: widget._note?.title);
    _commentCtl = TextEditingController(text: widget._note?.comment);
    _snippetCtl = TextEditingController(text: widget._note?.snippet);
    _urlCtl = TextEditingController(text: widget._note?.url);

    // if we are creating a new note, then populate the form with the supplied values
    _titleCtl.text = widget.title ?? _titleCtl.text;
    _commentCtl.text = widget.comment ?? _commentCtl.text;
    _snippetCtl.text = widget.snippet ?? _snippetCtl.text;
    _urlCtl.text = widget.url ?? _urlCtl.text;
  }

  void _saveNoteToFirebase(Map<String, Object> note) async {
    // if note has the key "id", add 1
    // else add the note

    late String id;
    if (note.containsKey("id")) {
      // update existing note
      id = note["id"].toString();

      // remove the id from the note, as firebase uses it as a doc reference
      note.remove("id");
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
  Map<String, Object> cleanFields(Map<String, Object> note) {
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

    // Join all lines with <br/>, excluding the last line
    String newText = lines.sublist(0, lines.length - 1).join('<br/>');

    // Add the last line without <br/>
    return '$newText<br/>${lines.last}';
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
      appBar: AppBar(
        title: const Text(
          'Edit Note',
          style: TextStyle(fontSize: 16),
        ),
        automaticallyImplyLeading: widget._note != null,
        actions: <Widget>[
          IconButton(
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
              Padding(
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
        if (widget._note?.id != null) 'id': widget._note!.id!,
        'title': _titleCtl.text,
        'comment': _commentCtl.text,
        'snippet': htmlSnippet,
        'url': _urlCtl.text
      });
      print("postMessage closePopup");
      window.postMessage("closePopup", "*");

      IFrameElement element = document.getElementById('iframe') as IFrameElement;
      element.contentWindow?.postMessage("closePopup", '*');
    }
  }
}
