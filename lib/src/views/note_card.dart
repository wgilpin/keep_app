import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/notes.dart';
import 'package:url_launcher/url_launcher.dart';

class SmallNoteCard extends StatelessWidget {
  final String title;
  final Function? onTapped;

  const SmallNoteCard(this.title, {this.onTapped, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300, minHeight: 100),
      child: Card(
          color: Colors.yellow[200],
          child: InkWell(
            onTap: () {
              onTapped?.call();
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                title,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          )),
    );
  }
}

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
                if (_note.title != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _note.title ?? "Untitled",
                      style: TextStyle(fontSize: isSmall ? 18 : 24),
                    ),
                  ),
                if (_note.comment != null && _note.comment!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      // maxLines: _maxlines,
                      overflow: TextOverflow.ellipsis,
                      _note.comment ?? "",
                      style: TextStyle(fontSize: isSmall ? 12 : 16),
                    ),
                  ),
                if ((!showHtml) & (_note.snippet != null) & (!isSmall))
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      maxLines: _maxlines,
                      overflow: TextOverflow.ellipsis,
                      _note.snippet ?? "",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                if ((showHtml) & (_note.snippet ?? "").isNotEmpty & (!isSmall))
                  Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.yellow[100]),
                        child: Html(data: _note.snippet ?? ""),
                      )),
                if ((_note.url != null) & (!isSmall))
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: InkWell(
                      onTap: () => doLaunchUrl(_note.url),
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

  Future<void> doLaunchUrl(url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
    )) {
      Get.snackbar("Could not launch site", url);
    }
  }
}
