import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mediapipe/image_paint.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final channel = const MethodChannel("flutter_mediapipe");
  final picker = ImagePicker();

  XFile? image;

  List<Offset> points = [];
  List<List<Offset>> lines = [];

  Size viewSize = const Size(250, 250);

  void handMarker() async {
    if (image == null) return;

    try {
      var bytes = await image?.readAsBytes();
      var result = await channel.invokeMethod("handMarker", {
        "width": viewSize.width.toInt(),
        "height": viewSize.height.toInt(),
        "bytes": bytes
      });

      var dataPoints = result["points"] as List<dynamic>;
      var dataLines = result["lines"] as List<dynamic>;

      setState(() {
        points = dataPoints.map((point) => Offset(point[0], point[1])).toList();
        lines = dataLines
            .map((lines) => [
                  Offset(lines[0][0], lines[0][1]),
                  Offset(lines[1][0], lines[1][1]),
                ])
            .toList();
      });
    } catch (e) {
      print(e);
    }
  }

  void onPickImage() async {
    // Request storage permission before picking image
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Storage permission is required to pick images.')),
      );
      return;
    }
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      setState(() {
        image = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: viewSize.width,
              height: viewSize.height,
              decoration: BoxDecoration(border: Border.all()),
              margin: const EdgeInsets.all(20.0),
              child: image == null
                  ? null
                  : Builder(
                      builder: (context) {
                        try {
                          return Image(image: FileImage(File(image!.path)));
                        } catch (e) {
                          return Center(child: Text('Failed to load image.'));
                        }
                      },
                    ),
            ),
            ElevatedButton(
              onPressed: onPickImage,
              child: const Text("LOAD"),
            ),
            Container(
              width: viewSize.width,
              height: viewSize.height,
              decoration: BoxDecoration(border: Border.all()),
              margin: const EdgeInsets.all(20.0),
              child: CustomPaint(
                painter: ImagePainter(points: points, lines: lines),
              ),
            ),
            ElevatedButton(
              onPressed: handMarker,
              child: const Text("MARKER"),
            ),
          ],
        ),
      ),
    );
  }
}
