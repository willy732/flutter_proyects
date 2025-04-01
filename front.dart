import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/cupertino.dart';
import 'package:jueves/OpenrouterService/open_router_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Entrada de Voz',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SpeechScreen(),
    );
  }
}

class SpeechScreen extends StatefulWidget {
  @override
  _SpeechScreenState createState() => _SpeechScreenState();
}

class _SpeechScreenState extends State<SpeechScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = 'Inicio';
  String _listeningMessage = 'Toque el micrófono y mantenga presionado';
  String _openRouterResponse = '';
  bool _isLoading = false;
  late FlutterTts flutterTts;
  late OpenRouterService openRouterService;
  String _manualInput = ''; // Variable to store manual input

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    flutterTts = FlutterTts();
    openRouterService = OpenRouterService(
      apiKey:
          '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', // Reemplaza con tu API key
      siteUrl: 'http://example.com',
      siteName: 'Mi App',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Deep Seek')),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: GestureDetector(
        onLongPress: _startListening,
        onLongPressUp: _stopListening,
        child: FloatingActionButton(onPressed: () {}, child: Icon(Icons.mic)),
      ),
      body: SingleChildScrollView(
        reverse: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(30.0, 30.0, 30.0, 150.0),
          child: Column(
            children: [
              SizedBox(height: 20),
              // Input field for manual text entry
              TextField(
                onChanged: (value) {
                  _manualInput = value;
                },
                decoration: InputDecoration(
                  labelText: 'Escribe tu pregunta',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  if (_manualInput.isNotEmpty) {
                    setState(() {
                      _isLoading = true;
                      _openRouterResponse = '';
                    });
                    await _sendToOpenRouter(_manualInput);
                  }
                },
                child: Text('Enviar'),
              ),
              SizedBox(height: 20),
              // Mostrar el texto ingresado por voz
              if (_text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Texto ingresado por voz:',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              SelectableText(
                _text,
                style: TextStyle(fontSize: 16.0, color: Colors.black),
              ),
              SizedBox(height: 20),
              // Mostrar el mensaje de estado
              if (_listeningMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _listeningMessage,
                    style: TextStyle(
                      fontSize: 15.0,
                      color: const Color.fromARGB(255, 189, 52, 52),
                    ),
                  ),
                ),
              SizedBox(height: 20),
              // Mostrar el indicador de carga o la respuesta de OpenRouter
              if (_isLoading)
                CupertinoActivityIndicator()
              else if (_openRouterResponse.isNotEmpty)
                Text(_openRouterResponse, style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  void _startListening() async {
    var status = await Permission.microphone.request();

    if (status.isGranted) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('estado: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() {
          _isListening = true;
          _listeningMessage = 'Escuchando...';
        });
        _speech.listen(
          onResult:
              (val) => setState(() {
                _text = val.recognizedWords;
              }),
        );
      } else {
        setState(() {
          _listeningMessage = 'Reconocimiento de voz no disponible';
        });
      }
    } else if (status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Permiso de micrófono denegado permanentemente. Habilítalo en la configuración.',
          ),
          action: SnackBarAction(
            label: 'Configuración',
            onPressed: () {
              openAppSettings();
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Permiso de micrófono denegado. Habilítalo en la configuración.',
          ),
          action: SnackBarAction(
            label: 'Configuración',
            onPressed: () {
              openAppSettings();
            },
          ),
        ),
      );
    }
  }

  void _stopListening() async {
    setState(() {
      _isListening = false;
      _listeningMessage = 'Toque el micrófono y mantenga presionado';
      _isLoading = true;
    });
    _speech.stop();
    await _sendToOpenRouter(_text);
  }

  Future<void> _sendToOpenRouter(String prompt) async {
    final url = Uri.parse(
      'http://10.0.2.2:8000/query',
    ); // Para emuladores de Android // Reemplaza con tu IP local // URL de la API
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'pregunta': prompt});

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['respuesta'] != null) {
          setState(() {
            _openRouterResponse = data['respuesta'];
            _isLoading = false;
          });
          await flutterTts.speak(data['respuesta']);
        } else {
          setState(() {
            _openRouterResponse = 'Error: ${data['error']}';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _openRouterResponse = 'Error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _openRouterResponse = 'Error: $e';
        _isLoading = false;
      });
    }
  }
}
