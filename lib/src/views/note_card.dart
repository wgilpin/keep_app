import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/utils/layout.dart';
import 'package:keep_app/src/views/checklist.dart';
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
          elevation: 10,
          shadowColor: Colors.black,
          color: Colors.yellow[200],
          child: InkWell(
            onTap: () {
              onTapped?.call();
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                title,
                style: GoogleFonts.robotoSlab(
                  fontSize: 18,
                ),
              ),
            ),
          )),
    );
  }
}

class NoteCard extends StatefulWidget {
  final Note _note;
  final bool showTitle;
  final Function? onTapped;
  final Function(String, bool)? onPinned;
  final Function(int, bool)? onCheck;
  final Function()? onChanged;
  late bool showChecked = false;

  NoteCard(this._note,
      {this.onTapped,
      this.onPinned,
      this.onCheck,
      this.onChanged,
      this.showTitle = true,
      required this.showChecked,
      super.key});

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool showPin = false;

  @override
  void initState() {
    super.initState();
    showPin = widget._note.isPinned;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1200, minHeight: 100),
      child: Card(
        elevation: 10,
        shadowColor: Colors.black,
        color: Colors.yellow[200],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flex(
              direction: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget._note.title != null)
                  Expanded(
                    child: InkWell(
                      hoverColor: Colors.transparent,
                      onHover: (value) => setState(() => showPin = (value || widget._note.isPinned)),
                      onTap: () {
                        debugPrint("NoteCard.onTap");
                        widget.onTapped?.call();
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, right: 0, top: 8, bottom: 8),
                        child: Text(
                          widget._note.title ?? "Untitled",
                          style: GoogleFonts.robotoSlab(
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                InkWell(
                  onTap: () {},
                  onHover: (value) => setState(() => showPin = value),
                  hoverColor: Colors.transparent,
                  child: IconButton(
                    onPressed: () => doPinned(),
                    icon: Icon(
                        color: showPin ? Colors.brown[900] : Colors.transparent,
                        widget._note.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                  ),
                )
              ],
            ),
            InkWell(
              hoverColor: Colors.transparent,
              onTap: () {
                debugPrint("NoteCard.onTap");
                widget.onTapped?.call();
              },
              child: widget._note.checklist.isEmpty
                  ? CardText(widget._note, widget.showChecked)
                  : CheckList(note: widget._note, showChecked: widget.showChecked, onChanged: doChange),
            ),
            if (widget._note.url != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: InkWell(
                  hoverColor: Colors.transparent,
                  onTap: () => doLaunchUrl(widget._note.url),
                  child: Text(
                    // maxLines: _maxlines,
                    overflow: TextOverflow.ellipsis,
                    widget._note.url ?? "",
                    style: TextStyle(fontSize: 16, color: Colors.blue[900], decoration: TextDecoration.underline),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  doPinned() {
    debugPrint("doPinned ${widget._note.id}, ${!widget._note.isPinned}");
    widget.onPinned?.call(widget._note.id!, !widget._note.isPinned);
  }

  doCheck(int itemId, bool newState) {
    debugPrint("doCheck $itemId, $newState");
    widget.onCheck?.call(itemId, newState);
  }

  cardTextWidget(Note note, int? maxlines) {}

  void doChange() {
    debugPrint('noteCard doChange');
    widget.onChanged?.call();
  }
}

Future<void> doLaunchUrl(url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(
    uri,
    mode: LaunchMode.externalNonBrowserApplication,
  )) {
    Get.snackbar("Could not launch site", url);
  }
}

class CardText extends StatelessWidget {
  final Note _note;
  final bool _canOpenVideo;
  const CardText(Note note, bool canOpenVideo, {super.key})
      : _note = note,
        _canOpenVideo = canOpenVideo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_note.url != null && _note.url!.startsWith("https://www.youtube.com"))
          Container(
              decoration: const BoxDecoration(color: Colors.black),
              child: Center(
                  child: Column(
                children: [
                  // for the large card view, clciking the thumbnail will open the video
                  if (_canOpenVideo)
                    InkWell(
                        hoverColor: Colors.transparent,
                        onTap: () => doLaunchUrl(_note.url),
                        child: Image.network(getYtThumbnail(_note.url), fit: BoxFit.fitWidth)),
                  // for the small card view, clciking the thumbnail will open the card not the video
                  if (!_canOpenVideo) Image.network(getYtThumbnail(_note.url), fit: BoxFit.fitWidth),
                ],
              ))),
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
        // if (_note.checklist.isNotEmpty) CheckList(note: _note),
        if ((_note.snippet ?? "").isNotEmpty)
          Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(color: Colors.yellow[100]),
                child: Html(data: _note.snippet ?? ""),
              )),
      ],
    );
  }
}
