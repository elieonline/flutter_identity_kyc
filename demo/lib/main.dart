import 'package:flutter/material.dart';
import 'package:flutter_identity_kyc/flutter_identity_kyc.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  Future<void> requestPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) {
            return Center(
              child: ElevatedButton(
                style: null,
                onPressed: () {
                  FlutterIdentityKyc.showWidget(
                    InputParameters(
                      context: c,
                      merchantKey: "",
                      firstName: "John",
                      lastName: "Doe",
                      email: "johndoe@example.com",
                      userRef: "1234",
                      config: "",
                      onCancel: (response) {
                        debugPrint(response?.toString());
                      },
                      onVerified: (response) {
                        debugPrint(response?.toString());
                      },
                      onError: (error) => debugPrint(error?.toString()),
                    ),
                  );
                },
                child: Text('Verify My Identity'),
              ),
            );
          },
        ),
      ),
    );
  }
}
