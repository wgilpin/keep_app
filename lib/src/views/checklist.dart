import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/controllers/notes_controller.dart';
import 'package:keep_app/src/notes.dart';

class CheckList extends StatefulWidget {
  const CheckList({super.key, required this.noteId, required this.showChecked, this.showComment = true});

  final bool showComment;
  final String noteId;
  final bool showChecked;

  @override
  State<CheckList> createState() => _CheckListState();
}

class _CheckListState extends State<CheckList> {
  late Note _note;
  late TextEditingController _itemTitleCtl; // controller for the input box
  CheckItem? _editingItem; // if an item is being edited, this is it

  late FocusNode inputFocusNode;

  @override
  void initState() {
    super.initState();
    _note = Get.find<NotesController>().findNoteById(widget.noteId);
    // create the controller for the input box
    _itemTitleCtl = TextEditingController(text: "");
    // focus node for the input box
    inputFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _itemTitleCtl.dispose();
    inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<NotesController>(
      init: Get.find<NotesController>(),
      initState: (_) {},
      builder: (ctl) {
        Note note = ctl.findNoteById(widget.noteId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showComment && _note.comment != null && _note.comment!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  // maxLines: _maxlines,
                  overflow: TextOverflow.ellipsis,
                  _note.comment ?? "",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            if (_note.checklist.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                child: Column(
                  children: [
                    getChecklist(note.unchecked, widget.showChecked, note.id!),
                    if (widget.showChecked) showEditBox(),
                    if (widget.showChecked && note.checked.isNotEmpty)
                      const Divider(
                        height: 8,
                        thickness: 2,
                      ),
                    if (widget.showChecked) getChecklist(note.checked, true, note.id!),
                    if (!widget.showChecked && note.checked.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            '+ ${note.checked.length} checked items',
                            style: const TextStyle(color: Colors.brown),
                          ),
                        ],
                      )
                  ],
                ),
              ),
            if (_note.checklist.isEmpty) showEditBox(),
          ],
        );
      },
    );
  }

  Widget getChecklist(List<CheckItem> list, bool showChecked, String noteId) {
    // return const SizedBox();
    return ReorderableListView.builder(
      // allow moving items around
      onReorder: (oldIndex, newIndex) => {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final item = list.removeAt(oldIndex);
          list.insert(newIndex, item);
          // write to server
          saveChecklist();
        })
      },
      shrinkWrap: true,
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        // if (list.length == 1 && item.title != null && item.title!.isEmpty) {
        //   return SizedBox.shrink(
        //     key: item.key,
        //   );
        // }
        return LabeledCheckbox(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          key: item.key,
          title: item.title ?? "",
          value: item.checked,
          onEdit: onEdit,
          onDelete: showChecked ? deleteItem : null,
          onChanged: (_) async {
            if (widget.showChecked) {
              debugPrint("checklist onChanged");
              setState(() {
                // set the checked state and move the item to the correct list
                final noteController = Get.find<NotesController>();
                Note note = noteController.findNoteById(widget.noteId);
                note.toggleCheckItem(item);
                noteController.update();
              });

              await saveChecklist();
            }
          },
        );
      },
    );
  }

  Future saveChecklist() async {
    // save the checklist to the server
    // first update the checklist in the note
    return Get.find<NotesController>().updateChecklist(_note.id!, _note.checklist).then((value) {
      debugPrint('checklist on change');
      // call the onChanged callback if supplied
      setState(() {});
    });
  }

  // called when item is edited
  onEdit(Key? key) {
    // get the item for this key
    debugPrint("onEdit $key");
    CheckItem item = _note.checklist.firstWhere((element) => element.key == key);
    _itemTitleCtl.text = item.title ?? "";
    _editingItem = item;
  }

  showEditBox() {
    return Stack(
      children: [
        TextField(
          focusNode: inputFocusNode,
          controller: _itemTitleCtl,
          decoration: InputDecoration(
            labelText: 'Add or edit a checklist item',
            fillColor: Colors.yellow[200],
          ),
          onSubmitted: (_) => doSavePressed(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.save),
            onPressed: doSavePressed,
          ),
        ),
      ],
    );
  }

  // edit dialog save btn pressed
  void doSavePressed() {
    debugPrint("onSubmitted");
    setState(() {
      if (_editingItem != null) {
        // editing an existing item
        // get the index of the item
        int index = _note.checklist.indexWhere((element) => element.key == _editingItem!.key);
        _note.checklist[index].title = _itemTitleCtl.text;
      } else {
        // adding a new item
        _note.checklist.add(CheckItem(index: _note.unchecked.length, title: _itemTitleCtl.text, checked: false));
      }
      // post save, clear the input box
      _itemTitleCtl.text = "";

      saveChecklist();
      // focus bck on the input in case they want to add another item
      inputFocusNode.requestFocus();
    });
  }

  // delete an checklist item
  deleteItem(Key? key) {
    // delete the item for this key
    debugPrint("deleteItem $key");
    CheckItem item = _note.checklist.firstWhere((element) => element.key == key);
    setState(() {
      _note.checklist.remove(item);
      _itemTitleCtl.text = "";
      _editingItem = null;
    });
    // save the checklist to the server
    saveChecklist();
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
    // call the delete callback if supplied
    debugPrint('doDelete in LabeledCheckbox');

    widget.onDelete?.call(widget.key!);
  }
}
