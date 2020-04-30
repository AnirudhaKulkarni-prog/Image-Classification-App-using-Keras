import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'package:tflite/tflite.dart';

List<CameraDescription> cameras;
String res;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  res = await Tflite.loadModel(
      model: "assets/model.tflite", labels: "assets/labels.txt", numThreads: 4);
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  CameraController my_controller;
  bool isDetecting = false;
  List<dynamic> predictions = [];

  @override
  void initState() {
    super.initState();
    my_controller = CameraController(cameras[0], ResolutionPreset.ultraHigh);

    my_controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      my_controller.startImageStream((CameraImage img) {
        if (!isDetecting) {
          isDetecting = true;
          Tflite.runModelOnFrame(
            bytesList: img.planes.map((plane) {
              return plane.bytes;
            }).toList(), // required
            imageHeight: img.height,
            imageWidth: img.width,
          ).then((recognitions) {
            setState(() {
              predictions = recognitions;
            });
            print(recognitions);
            isDetecting = false;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    my_controller?.dispose();
    Tflite.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text("Image Classifier"),
        ),
        body: my_controller.value.isInitialized
            ? MainScreen(my_controller: my_controller, predictions: predictions)
            : Container(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
      ),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({
    Key key,
    @required this.my_controller,
    @required this.predictions,
  }) : super(key: key);

  final CameraController my_controller;
  final List predictions;

  @override
  Widget build(BuildContext context) {
    var deviceData = MediaQuery.of(context);
    return SafeArea(
        child: Column(
      children: <Widget>[
        SizedBox(
          height: deviceData.size.height * 0.7,
          child: AspectRatio(
              aspectRatio: my_controller.value.aspectRatio,
              child: CameraPreview(my_controller)),
        ),
        predictions.length > 0
            ? Expanded(
                child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: predictions.length,
                    itemBuilder: (BuildContext context, int index) {
                      return Container(
                        height: 50,
                        color: Colors.blue,
                        child: Center(
                            child: Text(
                          '${predictions[index]['label']} ${predictions[index]['confidence']}',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              wordSpacing: 25),
                        )),
                      );
                    }))
            : Center(
                child: Text('Loading'),
              )
      ],
    ));
  }
}
