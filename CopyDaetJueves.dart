import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'dart:collection';
import 'package:flutter_tts/flutter_tts.dart';

class OpenRouterWidget extends StatefulWidget {
  final String apiKey;
  final String siteUrl;
  final String siteName;

  OpenRouterWidget({
    required this.apiKey,
    required this.siteUrl,
    required this.siteName,
  });

  @override
  _OpenRouterWidgetState createState() => _OpenRouterWidgetState();
}

class _OpenRouterWidgetState extends State<OpenRouterWidget> {
  final TextEditingController _inputController = TextEditingController(); //o
  final TextEditingController _textController = TextEditingController();
  //text a voz
  final FlutterTts flutterTts = FlutterTts();
  final Queue<String> textQueue = Queue<String>();
  String _response = '';
  bool _isLoading = false;

  //input voice
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = 'Presiona el botón y comienza a hablar';
  String _listeningMessage = ''; // Variable para el mensaje

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initTts();
  }

  Future<String> _getOpenRouterResponse(
    String apiKey,
    String siteUrl,
    String siteName,
    String prompt,
  ) async {
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
        final content = decodedResponse['choices'][0]['message']['content'];
        final cleanedContent =
            RegExp(r'\\boxed\{(.+?)\}').firstMatch(content)?.group(1) ??
            content;
        return cleanedContent;
      } else {
        return 'Error: ${response.statusCode}, ${response.body}';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<void> _sendRequest() async {
    setState(() {
      _isLoading = true;
      _response = ''; // Clear previous response
    });

    final prompt = _inputController.text;

    // Espera a que _getOpenRouterResponse complete y devuelva un valor
    final response = await _getOpenRouterResponse(
      widget.apiKey,
      widget.siteUrl,
      widget.siteName,
      prompt,
    );

    // Este setState se ejecutará después de que la llamada a _getOpenRouterResponse haya completado
    setState(() {
      _response = response;
      _addToQueue(_response);
      _textController.clear();
      _isLoading = false;
    });
  }

  //output
  Future _initTts() async {
    await flutterTts.setLanguage("es-ES"); // Establece el idioma a español
    await flutterTts.setPitch(1);
    await flutterTts.setSpeechRate(0.5);
  }

  Future _speak(String text) async {
    await flutterTts.speak(text);
  }

  void _addToQueue(String text) {
    setState(() {
      textQueue.add(text);
    });
  }

  void _readQueue() {
    if (textQueue.isNotEmpty) {
      String text = textQueue.first;
      _speak(text).then((_) {
        setState(() {
          textQueue.removeFirst();
        });
      });
    }
  }

  void _listen() async {
    if (!_isListening) {
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
            onError: (val) {
              setState(() {
                _isListening = false;
                _listeningMessage = 'Error al escuchar: ${val.errorMsg}';
              });
            },
          );
        } else {
          setState(() {
            _listeningMessage = 'Reconocimiento de voz no disponible.';
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
    } else {
      setState(() {
        _isListening = false;
        _listeningMessage = '';
      });
      _speech.stop();
      if (_text.isNotEmpty) {
        _addToQueue(_text);
        _text = '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _inputController,
            decoration: InputDecoration(
              labelText: 'Enter your prompt',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _sendRequest,
            child: _isLoading ? CircularProgressIndicator() : Text('Send'),
          ),
          SizedBox(height: 16),
          SelectableText('${textQueue.toList()}'),
          ElevatedButton(
            onPressed: _readQueue,
            child: Text('leer la respuesta'),
          ),
          //pres d Burton
          ElevatedButton(
            onPressed: _listen,
            child: Icon(_isListening ? Icons.mic_off : Icons.mic),
          ),
        ],
      ),
    );
  }
}

class MyMainWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('OpenRouter App')),
      //floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // floatingActionButton: FloatingActionButton(
      // onPressed: _listen,
      // child: Icon(_isListening ? Icons.mic_off : Icons.mic),
      //),
      body: Center(
        child: OpenRouterWidget(
          apiKey:
              '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', // Aquí va tu API Key
          siteUrl: 'http://example.com', // Reemplaza con tu URL
          siteName: 'Mi App', // Reemplaza con el nombre de tu sitio
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(home: MyMainWidget()));
}
