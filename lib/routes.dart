import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/controllers/auth_controller.dart';
import 'package:keep_app/src/controllers/notes_controller.dart';
import 'package:keep_app/src/views/display_shared_note.dart';
import 'package:keep_app/src/views/edit_page.dart';
import 'package:keep_app/src/views/login/login_page.dart';
import 'package:keep_app/src/views/root.dart';

MaterialPageRoute? generateRoute(RouteSettings settings) {
  if (settings.name == '/') {
    return MaterialPageRoute(builder: (_) => const Root());
  }
  // iframe goes to edit form
  if (settings.name == '/iframe') {
    return MaterialPageRoute(builder: (_) => const EditNoteForm(null));
  }

  // iframe with query params goes to edit form with query params as default values
  if ((settings.name ?? "").startsWith('/iframe?')) {
    // extract query params from URI
    final args = Uri.parse(settings.name ?? "").queryParameters;
    final uid = Get.find<AuthCtl>().user?.uid;
    if (uid == null) {
      return MaterialPageRoute(
          // Pass it to EditNoteForm.
          builder: (_) => LoginPage(editArgs: args));
    }
    return MaterialPageRoute(
        // Pass it to EditNoteForm.
        builder: (_) => EditNoteForm(
              null,
              title: args["title"],
              snippet: args["snippet"],
              comment: args["comment"],
              url: args["url"],
              iFrame: true,
            ));
  }
  if ((settings.name ?? "").startsWith('/share?')) {
    // extract query params from URI
    final args = Uri.parse(settings.name ?? "").queryParameters;
    // return MaterialPageRoute(builder: (_) => DisplaySharedNoted(args["id"] ?? ""));
    return MaterialPageRoute(builder: (context) {
      final note = Get.find<NotesController>().findNoteById(args["id"] ?? "");
      return DisplaySharedNoted(note);
    });
  }
  return null; //
}
