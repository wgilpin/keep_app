import 'package:flutter/foundation.dart';
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
  final Note _note; // the note to display
  final Function? onTapped; // called when the card is tapped
  final Function(String, bool)? onPinned; // called when the pinned state changes
  final Function(int, bool)? onCheck; // called when a checklist item is checked
  final Function()? onChanged; // called when the note is changed
  late final bool
      interactable; // respond to taps on checklist or image - set to true for full view, false for grid view

  NoteCard(this._note,
      {this.onTapped, this.onPinned, this.onCheck, this.onChanged, required this.interactable, super.key});

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool showPin = false;
  final platform = defaultTargetPlatform;

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
                      onHover: (value) => setState(() => showPin = shouldShowPin()),
                      onTap: () {
                        debugPrint("NoteCard.onTap");
                        widget.onTapped?.call();
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, right: 0, top: 8, bottom: 8),
                        child: Text(
                          widget._note.title ?? "Untitled",
                          style: GoogleFonts.robotoSlab(
                            fontSize: 20,
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
                        color: shouldShowPin() ? Colors.brown[900] : Colors.transparent,
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
                  ? CardText(widget._note, widget.interactable)
                  : CheckList(note: widget._note, showChecked: widget.interactable, onChanged: doChange),
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

  // callback for when the pin is pressed
  doPinned() {
    debugPrint("doPinned ${widget._note.id}, ${!widget._note.isPinned}");
    widget.onPinned?.call(widget._note.id!, !widget._note.isPinned);
  }

  // callback for when a checklist item is (un)checked
  doCheck(int itemId, bool newState) {
    debugPrint("doCheck $itemId, $newState");
    widget.onCheck?.call(itemId, newState);
  }

  // callback for when the note changes
  void doChange() {
    debugPrint('noteCard doChange');
    widget.onChanged?.call();
  }

  // work out if there is likely to be a mouse, as no mouse for onHover on mobile
  bool shouldShowPin() {
    // always show pin when pinned
    if (widget._note.isPinned) return true;

    // show when interactable, i.e. large view
    if (widget.interactable) return true;

    // if on mobile, show pins
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.android) return true;

    // always show pins on apps as no mouse for onHover
    if (!kIsWeb) return true;

    // if on web a small screen width suggests mobile
    double width = MediaQuery.of(context).size.width;
    debugPrint('width $width');

    return width < 450;
  }
}

// open the note url, in the appropriate app
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
