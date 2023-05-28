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
  final Function(String, bool)? onPinned;

  const NoteCard(this._note, this._maxlines,
      {this.onTapped, this.onPinned, this.showTitle = true, this.showHtml = false, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1200, minHeight: 100),
      child: Card(
        color: Colors.yellow[200],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flex(
              direction: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_note.title != null)
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        debugPrint("NoteCard.onTap");
                        onTapped?.call();
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, right: 0, top: 8, bottom: 8),
                        child: Text(
                          _note.title ?? "Untitled",
                          style: const TextStyle(fontSize: 24, fontFamily: "RobotoSlab"),
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () => doPinned(),
                  icon: Icon(_note.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                )
              ],
            ),
            InkWell(
              onTap: () {
                debugPrint("NoteCard.onTap");
                onTapped?.call();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_note.url != null && _note.url!.startsWith("https://www.youtube.com"))
                    Container(
                        decoration: const BoxDecoration(color: Colors.black),
                        child: Center(child: Image.network(getYtThumbnail(_note.url), fit: BoxFit.fitWidth))),
                  if (_note.comment != null && _note.comment!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        // maxLines: _maxlines,
                        overflow: TextOverflow.ellipsis,
                        _note.comment ?? "",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  if ((!showHtml) & (_note.snippet != null))
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        maxLines: _maxlines,
                        overflow: TextOverflow.ellipsis,
                        _note.snippet ?? "",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  if ((showHtml) & (_note.snippet ?? "").isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          decoration: BoxDecoration(color: Colors.yellow[100]),
                          child: Html(data: _note.snippet ?? ""),
                        )),
                ],
              ),
            ),
            if (_note.url != null)
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
      ),
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

  doPinned() {
    debugPrint("doPinned ${_note.id}, ${!_note.isPinned}");
    onPinned?.call(_note.id!, !_note.isPinned);
  }

  String getYtThumbnail(String? url) {
    final uri = Uri.parse(url!);
    final videoId = uri.queryParameters["v"];
    return "https://img.youtube.com/vi/$videoId/sddefault.jpg";
  }
}
