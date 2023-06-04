import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:keep_app/pageNotFound.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/views/display_shared_note.dart';
import 'package:keep_app/src/views/edit.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';

import 'src/controllers/bindings/app_binding.dart';
import 'src/theme.dart';
import 'src/views/root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // set emulator ports if necessary
  if (const String.fromEnvironment('EMULATOR') == 'true') {
    try {
      debugPrint('Using local Firestore emulators');
      FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
      await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
      FirebaseFunctions.instance.useFunctionsEmulator('127.0.0.1', 5001);
    } catch (e) {
      debugPrint('Failed to use local Firestore emulator: $e');
      // ignore: avoid_print
      debugPrint(e.toString());
    }
  } else {
    debugPrint('Using remote Firestore');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // This widget is the root of your application.
  late StreamSubscription _intentDataStreamSubscription;

  /// Opens the edit page with the given text
  void openEditPage(value) {
    if (value != null) {
      // urls are treated differently
      final bool isUrl = (value ?? "").toLowerCase().startsWith("http");
      debugPrint('Got shared ${isUrl ? "url" : "text"}: $value');

      Get.to(EditNoteForm(
        null,
        snippet: isUrl ? null : value,
        url: isUrl ? value : null,
      ));
    }
  }

  @override
  void initState() {
    super.initState();

    // For sharing or opening urls/text coming from outside the app while the app is in the memory
    if (!kIsWeb) {
      _intentDataStreamSubscription = ReceiveSharingIntent.getTextStream().listen((String value) {
        openEditPage(value);
      }, onError: (err) {
        debugPrint("getLinkStream error: $err");
      });

      // For sharing or opening urls/text coming from outside the app while the app is closed
      ReceiveSharingIntent.getInitialText().then((String? value) {
        openEditPage(value);
      });
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Get.changeTheme(makeTheme());
    return GetMaterialApp(
      title: 'Doofer',
      initialBinding: AppBindings(),
      theme: makeTheme(),
      scrollBehavior: MyCustomScrollBehavior(),
      // static routes
      routes: {},
      onGenerateRoute: generateRoute,
      onUnknownRoute: (settings) {
        return MaterialPageRoute(builder: (_) => const PageNotFound());
      },
    );
  }

  var generateRoute = (RouteSettings settings) {
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
      return MaterialPageRoute(
          // Pass it to EditNoteForm.
          builder: (_) => EditNoteForm(
                null,
                title: args["title"],
                snippet: args["snippet"],
                comment: args["comment"],
                url: args["url"],
              ));
    }
    if ((settings.name ?? "").startsWith('/share?')) {
      // extract query params from URI
      final args = Uri.parse(settings.name ?? "").queryParameters;
      // return MaterialPageRoute(builder: (_) => DisplaySharedNoted(args["id"] ?? ""));
      return MaterialPageRoute(builder: (context) {
        return FutureBuilder(
            future: FirebaseFirestore.instance.collection('notes').doc(args["id"] ?? "").get(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                Note note = Note.fromSnapshot(snapshot.data!);
                return DisplaySharedNoted(note);
              }
              return const Center(child: CircularProgressIndicator());
            });
      });
    }
    return null; //
  };
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  // Override behavior methods and getters like dragDevices
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}
