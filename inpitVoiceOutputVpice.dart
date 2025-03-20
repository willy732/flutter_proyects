import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    flutterTts = FlutterTts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Entrada de Voz')),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerTop,
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
              Text(
                _text,
                style: TextStyle(
                  fontSize: 32.0,
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (_listeningMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _listeningMessage,
                    style: TextStyle(
                      fontSize: 18.0,
                      color: const Color.fromARGB(255, 245, 170, 8),
                    ),
                  ),
                ),
              SizedBox(height: 20),
              if (_isLoading)
                CircularProgressIndicator()
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
    final apiKey =
        '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'; // Reemplaza con tu API key
    final siteUrl = 'http://example.com';
    final siteName = 'Mi App';

    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'HTTP-Referer': siteUrl,
      'X-Title': siteName,
    };
    final body = jsonEncode({
      'model': 'deepseek/deepseek-r1-zero:free',
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        String content = decodedResponse['choices'][0]['message']['content'];

        // Decodificar la respuesta (asegúrate de que esté en UTF-8)
        content = utf8.decode(utf8.encode(content));

        // Normalizar la respuesta
        content = removeDiacritics(content);
        setState(() {
          _openRouterResponse = content;
          _isLoading = false;
        });
        await flutterTts.speak(content);
      } else {
        setState(() {
          _openRouterResponse =
              'Error: ${response.statusCode}, ${response.body}';
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

  String removeDiacritics(String str) {
    const withDiacritics =
        'áàäâãåçéèëêíìïîñóòöôõúùüûýÿÁÀÄÂÃÅÇÉÈËÊÍÌÏÎÑÓÒÖÔÕÚÙÜÛÝ';
    const withoutDiacritics =
        'aaaaaaceeeeiiiinooooouuuuyyAAAAAACEEEEIIIINOOOOOUUUUY';

    for (int i = 0; i < withDiacritics.length; i++) {
      str = str.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }

    return str;
  }
}
