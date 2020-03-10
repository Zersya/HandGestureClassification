import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:learn_test/controller.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Demo Trained Model'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Controller controller;

  Future getImage(ImageSource source) async {
    Navigator.of(context).pop();
    var image = await ImagePicker.pickImage(source: source);
    final croppedFile = await ImageCropper.cropImage(
        sourcePath: image.path,
        aspectRatioPresets: [
          CropAspectRatioPreset.square,
        ],
        maxHeight: controller.kHeight,
        maxWidth: controller.kWidth,
        aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 75,
        androidUiSettings: AndroidUiSettings(
            toolbarTitle: 'Cropper',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true),
        iosUiSettings: IOSUiSettings(
          minimumAspectRatio: 1.0,
        ));
    final file = await controller.getImageFileFromAssets(croppedFile.path,
        fromExternal: true);
    final data = await controller.fileToBuffer(file.path);

    setState(() {
      controller.image = data;
    });
  }

  Future<File> cropImageStatic(File image) async {
    final croppedFile = await ImageCropper.cropImage(
      sourcePath: image.path,
      aspectRatioPresets: [
        CropAspectRatioPreset.square,
      ],
      maxHeight: controller.kHeight,
      maxWidth: controller.kWidth,
      aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 75,
      androidUiSettings: AndroidUiSettings(
          toolbarTitle: 'Cropper',
          toolbarColor: Colors.blue,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true),
      iosUiSettings: IOSUiSettings(
        minimumAspectRatio: 1.0,
      ),
    );

    return croppedFile;
  }

  @override
  void initState() {
    super.initState();
    controller = Controller();
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          InkWell(
            onTap: () {
              showDialogPickSource(context);
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Icon(Icons.add_a_photo),
            ),
          )
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          controller.image != null
              ? ChoosedImage(
                  image: controller.image,
                  busy: controller.busy,
                  recognition: controller.recognition,
                )
              : Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Choose Image first'),
                ),
          ImageSliderWidget(
            onTap: (ObjectHand hand) async {
              final file = await controller.getImageFileFromAssets(hand.path);
              final image = await cropImageStatic(file);
              final data = await controller.fileToBuffer(image.path);
              setState(() {
                controller.image = data;
              });
            },
          )
        ],
      ),
      floatingActionButton: controller.image != null && !controller.busy
          ? FloatingActionButton(
              onPressed: () async {
                if (!controller.busy) {
                  setState(() {
                    controller.busy = true;
                  });
                  final data = await controller.predictWithByte();
                  controller.message = '${data[0]}';
                  controller.recognition = data[0];
                  setState(() {
                    controller.busy = false;
                  });
                }
              },
              tooltip: 'Detect Image',
              child: Icon(Icons.hot_tub),
            )
          : Container(),
    );
  }

  Future showDialogPickSource(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Pick Source"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Camera'),
                onTap: () {
                  getImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.image),
                title: Text('Gallery'),
                onTap: () {
                  getImage(ImageSource.gallery);
                },
              )
            ],
          ),
        );
      },
    );
  }
}

class ChoosedImage extends StatelessWidget {
  ChoosedImage({
    Key key,
    @required this.image,
    @required this.busy,
    @required this.recognition,
  }) : super(key: key);
  final image;
  final busy;
  final recognition;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: <Widget>[
          Image.memory(image),
          if (busy) CircularProgressIndicator(),
          if (recognition != null && !busy)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text('Confidence : '),
                      Text('${(recognition['confidence'] * 100).round()} %'),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text('Label : '),
                      Text('${recognition['label']}'),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ImageSliderWidget extends StatefulWidget {
  ImageSliderWidget({Key key, @required this.onTap}) : super(key: key);
  final Function(ObjectHand) onTap;

  @override
  _ImageSliderWidgetState createState() => _ImageSliderWidgetState();
}

class _ImageSliderWidgetState extends State<ImageSliderWidget> {
  Future<List<ObjectHand>> getJson() async {
    final string = await rootBundle.loadString('assets/data.json');
    List data = json.decode(string);
    List<ObjectHand> hands =
        data.map((val) => ObjectHand.fromJson(val)).toList();

    return hands;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: getJson(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        if (snapshot.hasError) return Text('Terjadi kesalahan');

        List<ObjectHand> hands = snapshot.data;
        return SizedBox(
          height: 150,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: hands.length,
            scrollDirection: Axis.horizontal,
            itemBuilder: (_, index) {
              return InkWell(
                onTap: () => widget.onTap(hands[index]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: <Widget>[
                      Flexible(
                          child: Image.asset(
                        'assets/${hands[index].path}',
                      )),
                      Text(hands[index].label)
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class ObjectHand {
  final String path;
  final String label;
  final String handId;

  ObjectHand(this.path, this.label, this.handId);

  factory ObjectHand.fromJson(Map<String, dynamic> json) => ObjectHand(
        json['path'],
        json['label'],
        json['hand_id'],
      );
}
