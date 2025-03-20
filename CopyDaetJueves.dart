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
  String _text = '';

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
        return content;
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
    final response = await _getOpenRouterResponse(
      widget.apiKey,
      widget.siteUrl,
      widget.siteName,
      prompt,
    );
    setState(() {
      _response = response;
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

  //inpit
  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult:
              (val) => setState(() {
                _text = val.recognizedWords;
              }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      _addToQueue(_text);
      _text = ''; // Limpia el texto después de agregarlo a la cola.
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
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(_response),
              ),
            ),
          ),
          //[ output
          TextField(
            controller: _textController,
            decoration: InputDecoration(labelText: 'Enter text'),
          ),
          ElevatedButton(
            onPressed: () {
              _addToQueue(_textController.text);
              _textController.clear();
            },
            child: Text('Add to Queue'),
          ),
          ElevatedButton(onPressed: _readQueue, child: Text('Read Queue')),
          Text('Queue: ${textQueue.toList()}'),
          // ] added

          //pres d Burton
          ElevatedButton(
            onPressed: _listen,
            child: Text(_isListening ? 'Stop Listening' : 'Start Listening'),
          ),
          Text('Queue: ${textQueue.toList()}'),
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
