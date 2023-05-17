import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:keep_app/src/notes.dart';

class NoteCard extends StatelessWidget {
  final int? _maxlines;
  final Note _note;
  final bool showTitle;
  final bool showHtml;
  final Function? onTapped;
  final bool isSmall;

  const NoteCard(this._note, this._maxlines,
      {this.onTapped, this.showTitle = true, this.showHtml = false, this.isSmall = false, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: isSmall ? 300 : 1200, minHeight: 100),
      child: Card(
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
                      style: TextStyle(fontSize: isSmall ? 18 : 24),
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
                      style: TextStyle(fontSize: isSmall ? 12 : 16),
                    ),
                  ),
                ),
                Visibility(
                  visible: (!showHtml) & (_note.snippet != null) & (!isSmall),
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
                  visible: (showHtml) & (_note.snippet ?? "").isNotEmpty & (!isSmall),
                  child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.yellow[100]),
                        child: Html(data: _note.snippet ?? ""),
                      )),
                ),
                Visibility(
                  visible: (_note.url != null) & (!isSmall),
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
          )),
    );
  }
}
