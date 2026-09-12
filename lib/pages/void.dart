import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceSearchScreen extends StatefulWidget {
  const VoiceSearchScreen({super.key});

  @override
  State<VoiceSearchScreen> createState() => _VoiceSearchScreenState();
}

class _VoiceSearchScreenState extends State<VoiceSearchScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _wordsSpoken = '';
  String _statusText = 'Đang khởi tạo Micro...';

  @override
  void initState() {
    super.initState();
    _startListeningAutomatically();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  /// Khởi tạo và tự động kích hoạt thu âm ngay khi mở màn hình
  Future<void> _startListeningAutomatically() async {
    try {
      bool available = await _speech.initialize(
        onError: _onError,
        onStatus: (status) {
          if (status == 'listening') {
            setState(() => _statusText = 'Đang nghe... Hãy nói tên sản phẩm');
          } else if (status == 'notListening' || status == 'done') {
            setState(() {
              _isListening = false;
              _statusText = 'Đã hoàn tất!';
            });
            // Tự động trả về kết quả nếu đã nhận diện được từ khóa
            if (_wordsSpoken.trim().isNotEmpty) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) Navigator.pop(context, _wordsSpoken);
              });
            }
          }
        },
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: 'vi_VN',
          onResult: (result) {
            setState(() {
              _wordsSpoken = result.recognizedWords;
            });
          },
        );
      } else {
        setState(() {
          _statusText = 'Thiết bị không hỗ trợ nhận diện giọng nói';
        });
      }
    } catch (e) {
      setState(() {
        _statusText = 'Lỗi kết nối Micro: $e';
      });
    }
  }

  void _onError(SpeechRecognitionError error) {
    setState(() {
      _isListening = false;
      _statusText = 'Không nghe rõ, vui lòng thử lại';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm bằng giọng nói'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _statusText,
                style: TextStyle(
                  fontSize: 16,
                  color: _isListening ? Colors.blue : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),

              // Hiệu ứng nút Mic
              GestureDetector(
                onTap: () {
                  if (!_isListening) {
                    _startListeningAutomatically();
                  } else {
                    _speech.stop();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? Colors.red.shade100
                        : Colors.blue.shade50,
                    boxShadow: _isListening
                        ? [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 10,
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 70,
                    color: _isListening ? Colors.red : Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Hiển thị văn bản nhận diện được
              Container(
                constraints: const BoxConstraints(minHeight: 80),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _wordsSpoken.isEmpty
                      ? 'Nói nội dung cần tìm...'
                      : _wordsSpoken,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              if (_wordsSpoken.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, _wordsSpoken),
                  icon: const Icon(Icons.search),
                  label: const Text('Tìm kiếm từ này'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
