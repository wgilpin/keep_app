import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/pageNotFound.dart';
import 'package:keep_app/routes.dart';
import 'package:keep_app/src/views/edit_page.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'firebase_options.dart';
import 'src/controllers/bindings/app_binding.dart';
import 'src/theme.dart';

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
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    print('presentError ${details.toString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    print('PlatformDispatcher error ${error.toString()}');
    return true;
  };
  print('App started');
  runApp(
    const MyApp(), // Wrap your app
  );
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

      Get.to(() => EditNoteForm(
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
      builder: (BuildContext context, Widget? widget) {
        // ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
        //   return CustomError(errorDetails: errorDetails);
        // };
        return widget!;
      },
      // static routes
      routes: const {},
      onGenerateRoute: generateRoute,
      onUnknownRoute: (settings) {
        return MaterialPageRoute(builder: (_) => const PageNotFound());
      },
    );
  }
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  // Override behavior methods and getters like dragDevices
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}
