import 'dart:convert';
import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:image_picker/image_picker.dart';

class PeachScreen extends StatefulWidget {
  @override
  _PeachScreenState createState() => _PeachScreenState();
}

class _PeachScreenState extends State<PeachScreen> {
  int _selectedImageIndex = 0;
  File? _selectedImage;
  String? detectedDisease;
  double? confidenceScore;
  String? possibleTreatment;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Peach Details'),
        backgroundColor: Colors.green,
      ),
      backgroundColor: Colors.lightGreen[100],
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  _buildImageSelector(),
                  SizedBox(height: 16),
                  CarouselSlider(
                    items: [
                      _buildImage('assets/images/peachplant.png'),
                      _buildImage('assets/images/peachleaf.png'),
                    ],
                    options: CarouselOptions(
                      height: 200,
                      autoPlay: true,
                      enlargeCenterPage: true,
                      onPageChanged: (index, _) {
                        setState(() {
                          _selectedImageIndex = index;
                        });
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Peach',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Description about Peach and its diseases.',
                    style: TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => _takePhoto(context),
                        child: Text('Click a Photo'),
                      ),
                      ElevatedButton(
                        onPressed: () => _pickImage(context),
                        child: Text('Upload a Photo'),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _selectedImage != null
                      ? ElevatedButton(
                          onPressed: () => _predictDisease(context),
                          child: Text('Predict Disease'),
                        )
                      : Container(),
                  SizedBox(height: 16),
                  detectedDisease != null && confidenceScore != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.file(_selectedImage!),
                            SizedBox(height: 16),
                            Text('Predicted Disease: $detectedDisease'),
                            Text('Confidence Score: $confidenceScore'),
                            if (possibleTreatment != null)
                              Text('Treatment: $possibleTreatment'),
                          ],
                        )
                      : Container(),
                  SizedBox(height: 16),
                  _isLoading ? CircularProgressIndicator() : Container(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _takePhoto(BuildContext context) async {
    final imagePicker = ImagePicker();
    final image = await imagePicker.pickImage(source: ImageSource.camera);

    if (image != null) {
      _showLoader();

      List<int> imageBytes = await image.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://national-moth-neatly.ngrok-free.app/api/predict'),
      );
      request.files.add(http.MultipartFile.fromString('image', base64Image));

      try {
        var response = await request.send();
        if (response.statusCode == 200) {
          var jsonResponse = await response.stream.bytesToString();
          var result = json.decode(jsonResponse);

          setState(() {
            detectedDisease = result['detected_class'];
            confidenceScore = result['confidence'];
            possibleTreatment = result['possible_treatment'];
            _selectedImage = File(image.path);
          });

          _hideLoader();
          _showPredictionDialog();
        } else {
          _hideLoader();
          print('Error: ${response.statusCode} - ${response.reasonPhrase}');
        }
      } catch (error) {
        _hideLoader();
        print('Error: $error');
      }
    }
  }

  void _pickImage(BuildContext context) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  void _predictDisease(BuildContext context) async {
    if (_selectedImage == null) {
      // Add a check to ensure an image is selected
      return;
    }

    _showLoader();

    final apiUrl = 'https://national-moth-neatly.ngrok-free.app/api/predict';

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      List<int> imageBytes = await _selectedImage!.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      request.files.add(http.MultipartFile.fromString('image', base64Image));

      var response = await request.send();
      if (response.statusCode == 200) {
        var jsonResponse = await response.stream.bytesToString();
        var result = json.decode(jsonResponse);

        setState(() {
          detectedDisease = result['detected_class'];
          confidenceScore = result['confidence'];
          possibleTreatment = result['possible_treatment'];
        });

        _hideLoader();
        _showPredictionDialog();
      } else {
        _hideLoader();
        print('Error: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      _hideLoader();
      print('Error: $e');
    }
  }

  void _showLoader() {
    setState(() {
      _isLoading = true;
    });
  }

  void _hideLoader() {
    setState(() {
      _isLoading = false;
    });
  }

  void _showPredictionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Prediction Result'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.file(_selectedImage!),
              SizedBox(height: 16),
              Text('Predicted Disease: $detectedDisease'),
              Text('Confidence Score: $confidenceScore'),
              if (possibleTreatment != null &&
                  possibleTreatment !=
                      "No specific treatment information available.")
                Text('Treatment: $possibleTreatment'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedImage = null;
                  detectedDisease = null;
                  confidenceScore = null;
                  possibleTreatment = null;
                });
                Navigator.pop(context);
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImageSelector() {
    return Container(
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildImageThumbnail('assets/images/peachleaf.png', 0),
          _buildImageThumbnail('assets/images/peach_icon.png', 1),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(String imagePath, int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedImageIndex = index;
        });
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: _selectedImageIndex == index ? Colors.green : Colors.grey,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String imagePath) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 3,
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
