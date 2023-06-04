import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:keep_app/src/notes.dart';

class CheckList extends StatefulWidget {
  const CheckList({super.key, this.onChanged, required this.note, required this.showChecked});
  final Function()? onChanged;
  final Note note;
  final bool showChecked;

  @override
  State<CheckList> createState() => _CheckListState();
}

class _CheckListState extends State<CheckList> {
  late List<CheckItem> _unchecked;
  late List<CheckItem> _checked;
  late TextEditingController _itemTitleCtl;
  CheckItem? _editingItem;

  late FocusNode inputFocusNode;

  @override
  void initState() {
    super.initState();
    splitChecklist();
    _itemTitleCtl = TextEditingController(text: "");
    inputFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _itemTitleCtl.dispose();
    inputFocusNode.dispose();
    super.dispose();
  }

  void splitChecklist() {
    _unchecked = widget.note.checklist.where((element) => !element.checked).toList();
    _checked = widget.note.checklist.where((element) => element.checked).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                getChecklist(_unchecked, widget.showChecked),
                if (widget.showChecked) showEditBox(),
                if (widget.showChecked)
                  const Divider(
                    height: 8,
                    thickness: 2,
                  ),
                if (widget.showChecked) getChecklist(_checked, true),
              ])),
      ],
    );
  }

  getChecklist(List<CheckItem> list, bool showChecked) {
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
        return LabeledCheckbox(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          key: item.key,
          title: item.title ?? "",
          value: item.checked,
          onEdit: onEdit,
          onDelete: showChecked ? deleteItem : null,
          onChanged: (newValue) async {
            if (widget.showChecked) {
              debugPrint("checklist onChanged $newValue");
              setState(() {
                item.checked = newValue;
                if (newValue) {
                  _checked.add(item);
                  _unchecked.remove(item);
                } else {
                  _checked.remove(item);
                  _unchecked.add(item);
                }
              });
              await saveChecklist();
            }
          },
        );
      },
    );
  }

  saveChecklist() async {
    widget.note.checklist = _unchecked + _checked;
    return FirebaseFirestore.instance
        .collection('notes')
        .doc(widget.note.id)
        .update({"checklist": widget.note.checklist.map((e) => e.toJson()).toList()}).then((value) {
      debugPrint('checklist on change');
      widget.onChanged?.call();
    });
  }

  onEdit(Key? key) {
    // get the item for this key
    debugPrint("onEdit $key");
    CheckItem item = widget.note.checklist.firstWhere((element) => element.key == key);
    _itemTitleCtl.text = item.title ?? "";
    _editingItem = item;
  }

  showEditBox() {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: TextField(
              focusNode: inputFocusNode,
              controller: _itemTitleCtl,
              decoration: InputDecoration(
                labelText: 'Add or edit an item',
                fillColor: Colors.yellow[200],
              ),
              onSubmitted: (_) => doPressed(),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.save),
          onPressed: doPressed,
        ),
      ],
    );
  }

  void doPressed() {
    debugPrint("onSubmitted");
    setState(() {
      if (_editingItem != null) {
        // editing an existing item
        // get the index of the item
        int index = widget.note.checklist.indexWhere((element) => element.key == _editingItem!.key);
        widget.note.checklist[index].title = _itemTitleCtl.text;
      } else {
        // adding a new item
        _unchecked.add(CheckItem(index: _unchecked.length, title: _itemTitleCtl.text, checked: false));
      }
      _itemTitleCtl.text = "";

      saveChecklist();
      inputFocusNode.requestFocus();
    });
  }

  deleteItem(Key? key) {
    // delete the item for this key
    debugPrint("deleteItem $key");
    CheckItem item = widget.note.checklist.firstWhere((element) => element.key == key);
    setState(() {
      widget.note.checklist.remove(item);
      _itemTitleCtl.text = "";
    });
    splitChecklist();
    saveChecklist().then(() => widget.onChanged?.call());
  }
}

class LabeledCheckbox extends StatefulWidget {
  const LabeledCheckbox({
    super.key,
    required this.title,
    required this.padding,
    required this.value,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final EdgeInsets padding;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Function(Key)? onEdit;
  final Function(Key)? onDelete;

  @override
  State<LabeledCheckbox> createState() => _LabeledCheckboxState();
}

class _LabeledCheckboxState extends State<LabeledCheckbox> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () {
            widget.onChanged(!widget.value);
          },
          child: Padding(
            padding: widget.padding,
            child: Checkbox(
              value: widget.value,
              onChanged: (bool? newValue) {
                widget.onChanged(newValue!);
              },
            ),
          ),
        ),
        Expanded(
            child: InkWell(
          onTap: () => widget.onEdit?.call(widget.key!),
          child: Row(
            children: [
              Expanded(child: Text(widget.title)),
              if (hover && widget.onDelete != null)
                Padding(
                  padding: const EdgeInsets.only(right: 24.0),
                  child: IconButton(onPressed: doDelete, icon: const Icon(Icons.close)),
                )
            ],
          ),
          onHover: (value) => setState(() {
            hover = value;
          }),
        )),
      ],
    );
  }

  void doDelete() {
    debugPrint('doDelete in LabeledCheckbox');

    widget.onDelete?.call(widget.key!);
  }
}
