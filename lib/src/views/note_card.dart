import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:keep_app/src/notes.dart';

class NoteCard extends StatelessWidget {
  final int? _maxlines;
  final Note _note;
  final bool showTitle;
  final bool showHtml;
  final Function? onTapped;

  const NoteCard(this._note, this._maxlines, {this.onTapped, this.showTitle = true, this.showHtml = false, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
        color: Colors.yellow[200],
        child: InkWell(
          onTap: () {
            print("NoteCard.onTap");
            onTapped?.call();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Visibility(
                visible: showTitle & (_note.title != null),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _note.title ?? "Untitled",
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              Visibility(
                visible: _note.comment != null && _note.comment!.isNotEmpty,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    // maxLines: _maxlines,
                    overflow: TextOverflow.ellipsis,
                    _note.comment ?? "",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              Visibility(
                visible: (!showHtml) & (_note.snippet != null),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    maxLines: _maxlines,
                    overflow: TextOverflow.ellipsis,
                    _note.snippet ?? "",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              Visibility(
                visible: (showHtml) & (_note.snippet ?? "").isNotEmpty,
                child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.yellow[100]),
                      child: Html(data: _note.snippet ?? ""),
                    )),
              ),
              Visibility(
                visible: _note.url != null,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    // maxLines: _maxlines,
                    overflow: TextOverflow.ellipsis,
                    _note.url ?? "",
                    style: TextStyle(fontSize: 16, color: Colors.blue[900], decoration: TextDecoration.underline),
                  ),
                ),
              ),
            ],
          ),
        ));
  }
}
