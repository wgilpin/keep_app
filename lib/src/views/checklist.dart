import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/utils/layout.dart';

class CheckList extends StatefulWidget {
  const CheckList({super.key, this.onChanged, required this.note, required this.showChecked});
  final Function()? onChanged;
  final Note note;
  final bool showChecked;

  @override
  State<CheckList> createState() => _CheckListState();
}

class _CheckListState extends State<CheckList> {
  late List<CheckItem> unchecked;
  late List<CheckItem> checked;

  @override
  void initState() {
    super.initState();
    unchecked = widget.note.checklist.where((element) => !element.checked).toList();
    checked = widget.note.checklist.where((element) => element.checked).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.note.url != null && widget.note.url!.startsWith("https://www.youtube.com"))
          Container(
              decoration: const BoxDecoration(color: Colors.black),
              child: Center(child: Image.network(getYtThumbnail(widget.note.url), fit: BoxFit.fitWidth))),
        if (widget.note.comment != null && widget.note.comment!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              // maxLines: _maxlines,
              overflow: TextOverflow.ellipsis,
              widget.note.comment ?? "",
              style: const TextStyle(fontSize: 16),
            ),
          ),
        if (widget.note.checklist.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 8.0),
              child: Column(children: [
                getChecklist(unchecked, 'unch'),
                if (widget.showChecked)
                  const Divider(
                    height: 8,
                    thickness: 2,
                  ),
                if (widget.showChecked) getChecklist(checked, 'ch'),
              ])),
      ],
    );
  }

  getChecklist(list, keyPrefix) {
    return ReorderableListView.builder(
      onReorder: (oldIndex, newIndex) => {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final item = list.removeAt(oldIndex);
          list.insert(newIndex, item);
          saveChecklist();
        })
      },
      shrinkWrap: true,
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return CheckboxListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          key: Key("$keyPrefix-${item.key.toString()}"),
          title: Text(item.title ?? ""),
          value: item.checked,
          onChanged: (newValue) async {
            debugPrint("checklist onChanged $newValue");
            setState(() {
              item.checked = newValue!;
              if (newValue) {
                checked.add(item);
                unchecked.remove(item);
              } else {
                checked.remove(item);
                unchecked.add(item);
              }
            });
            await saveChecklist();
          },
          controlAffinity: ListTileControlAffinity.leading, //  <-- leading Checkbox
        );
      },
    );
  }

  saveChecklist() async {
    widget.note.checklist = unchecked + checked;
    return FirebaseFirestore.instance
        .collection('notes')
        .doc(widget.note.id)
        .update({"checklist": widget.note.checklist.map((e) => e.toJson()).toList()}).then((value) {
      debugPrint('checklist on change');
      widget.onChanged?.call();
    });
  }
}
