import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/views/edit.dart';
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
      print(e);
    }
  } else {
    debugPrint('Using remote Firestore');
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    Get.changeTheme(makeTheme());
    return GetMaterialApp(
      title: 'rKyv',
      initialBinding: AppBindings(),
      theme: makeTheme(),
      scrollBehavior: MyCustomScrollBehavior(),
      // static routes
      routes: {
        '/': (_) => const Root(),
      },
      onGenerateRoute: generateRoute,
    );
  }

  var generateRoute = (RouteSettings settings) {
    // iframe goes to edit form
    if (settings.name == '/iframe') {
      return MaterialPageRoute(builder: (_) => const EditNoteForm(null)); // Pass it to BarPage.
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
