import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MaterialApp(
    home: CropSelectionScreen(),
  ));
}

class CropSelectionScreen extends StatefulWidget {
  @override
  _CropSelectionScreenState createState() => _CropSelectionScreenState();
}

class _CropSelectionScreenState extends State<CropSelectionScreen> {
  final List<Map<String, dynamic>> crops = [
    {'name': 'Apple', 'icon': 'apple_icon.png'},
    {'name': 'Bell Pepper', 'icon': 'bellpepper_icon.png'},
    {'name': 'Corn', 'icon': 'corn_icon.png'},
    {'name': 'strawberry', 'icon': 'strawberry_icon.png'},
    {'name': 'Potato', 'icon': 'potato_icon.png'},
    {'name': 'Peach', 'icon': 'peach_icon.png'},
    {'name': 'Tomato', 'icon': 'tomato_icon.png'},
    {'name': 'Grapes', 'icon': 'grapes_icon.jpg'},
    {'name': 'Orange', 'icon': 'orange_icon.png'},
    {'name': 'Squash', 'icon': 'squash_icon.png'},
    {'name': 'Cherry', 'icon': 'cherry_icon.jpg'},

    // Add more crops as needed
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Available List Of Crops'),
        backgroundColor: Colors.green,
      ),
      backgroundColor: Colors.lightGreen[100],
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: crops.length,
              itemBuilder: (context, index) {
                final crop = crops[index];
                return Card(
                  elevation: 8.0,
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ListTile(
                    contentPadding: EdgeInsets.all(16),
                    title: Row(
                      children: [
                        _buildCropImage(crop['icon']),
                        SizedBox(width: 16),
                        _buildCropName(crop['name']),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            color: Colors.green,
            child: ListTile(
              title: ElevatedButton(
                onPressed: () {
                  _showPredictDiseasePopup();
                },
                style: ElevatedButton.styleFrom(
                  primary: Colors.green,
                  onPrimary: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                child: Text('Predict the disease'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropImage(String iconPath) {
    return Container(
      height: 60,
      width: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(
          image: AssetImage('assets/images/$iconPath'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildCropName(String cropName) {
    return Text(
      cropName,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  void _showPredictDiseasePopup() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return PredictDiseasePopup();
      },
    );
  }
}

class PredictDiseasePopup extends StatefulWidget {
  @override
  _PredictDiseasePopupState createState() => _PredictDiseasePopupState();
}

class _PredictDiseasePopupState extends State<PredictDiseasePopup> {
  File? _selectedImage;
  String? detectedDisease;
  double? confidenceScore;
  String? possibleTreatment;
  List<String>? treatments;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      physics: ClampingScrollPhysics(),
      children: [
        Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              _isLoading ? CircularProgressIndicator() : Container(),
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
                        if (treatments != null && treatments!.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Possible Treatments:'),
                              for (String treatment in treatments!)
                                Text(treatment),
                            ],
                          ),
                      ],
                    )
                  : Container(),
            ],
          ),
        ),
      ],
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
            treatments = List<String>.from(result['treatments'] ?? []);
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
          treatments = List<String>.from(result['treatments'] ?? []);
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
              if (possibleTreatment != null)
                Text('Treatment: $possibleTreatment'),
              if (treatments != null && treatments!.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Possible Treatments:'),
                    for (var treatment in treatments!) Text(treatment),
                  ],
                ),
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
                  treatments = null;
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
}
