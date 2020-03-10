import 'package:flutter/services.dart';
import 'package:tflite/tflite.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class Controller {
  String message;
  bool busy = true;
  // ByteBuffer imageBuffer;
  Uint8List image;
  Map recognition;
  File imageFile;

  int kWidth = 250;
  int kHeight = 250;

  Controller() {
    Tflite.loadModel(
      model: "assets/models/model_13.tflite",
      labels: "assets/models/labels.txt",
    ).then((res) async {
      busy = false;
    });
  }

  Future<File> getImageFileFromAssets(String path,
      {bool fromExternal = false}) async {
    Uint8List byteData;
    var tempPath;
    var file;
    if (fromExternal) {
      // byteData = await rootBundle.load('$path');
      byteData = File(path).readAsBytesSync();

      file = File('$path');
    } else {
      final byte = await rootBundle.load('assets/$path');
      byteData = byte.buffer.asUint8List();
      tempPath = await getTemporaryDirectory();
      file = File('${tempPath.path}/$path');
    }
    await file.writeAsBytes(byteData.buffer
        .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    // imageBuffer = byteData.buffer;
    return file;
  }

  Uint8List imageToByteListFloat32(
      img.Image image, int inputSize, double mean, double std) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 1);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex] = (img.getRed(pixel) - mean) / std;
        buffer[pixelIndex] = (img.getGreen(pixel) - mean) / std;
        buffer[pixelIndex] = (img.getBlue(pixel) - mean) / std;
        pixelIndex++;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  Future<Uint8List> fileToBuffer(String path) async {
    final byteData = File(path);
    return byteData.readAsBytesSync();
  }

  Uint8List processImage(Uint8List input) {
    img.Image oriImage = img.decodeImage(input);
    img.Image resizedImage =
        img.copyResize(oriImage, height: kHeight, width: kWidth);

    return imageToByteListFloat32(resizedImage, kWidth, 1, 1);
  }

  Future<List> predictWithByte() async {
    try {
      var recognitions = await Tflite.runModelOnBinary(
        binary: processImage(image), // required
        numResults: 7, // defaults to 5
        threshold: 0.05, // defaults to 0.1
        asynch: true, // defaults to true
      );
      print(recognitions);
      return recognitions;
    } on PlatformException catch (err) {
      print(err);
      message = err.message;

      return [
        {'confidence': 0, 'index': '-1', 'label': 'Not Found'}
      ];
    } catch (err) {
      print(err);
      return [
        {'confidence': 0, 'index': '-1', 'label': 'Not Found'}
      ];
    }
  }

  // Future<List> predictWithFile() async {
  //   try {
  //     var recognitions = await Tflite.runModelOnImage(
  //       path: image.path, // required
  //       numResults: 7, // defaults to 5
  //     );
  //     print(recognitions);
  //     return recognitions;
  //   } on PlatformException catch (err) {
  //     print(err);
  //     message = err.message;

  //     return [
  //       {'confidence': 0, 'index': '-1', 'label': 'Not Found'}
  //     ];
  //   }
  // }

  void dispose() {
    Tflite.close();
  }
}

class ImagesModel {
  Uint8List bufferImage;
  File fileImage;

  ImagesModel(this.bufferImage, this.fileImage);
}
