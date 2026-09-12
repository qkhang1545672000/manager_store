import 'dart:io';

import 'package:flutter/material.dart';
import 'package:manager_store/database_helper/database_helper.dart';
import 'package:manager_store/pages/void.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SearchProductScreen extends StatefulWidget {
  const SearchProductScreen({super.key});

  @override
  State<SearchProductScreen> createState() => _SearchProductScreenState();
}

class _SearchProductScreenState extends State<SearchProductScreen> {
  final TextEditingController _searchController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isListening = false;
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _speech.stop();
    super.dispose();
  }

  /// Khởi tạo dịch vụ nhận diện giọng nói
  void _initSpeech() async {
    try {
      await _speech.initialize();
    } catch (e) {
      debugPrint('Lỗi khởi tạo giọng nói: $e');
    }
  }

  /// Mở trang Tìm kiếm bằng giọng nói riêng biệt
  void _openVoiceSearchScreen() async {
    final String? result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const VoiceSearchScreen()),
    );

    // Nếu có kết quả trả về -> Điền vào ô tìm kiếm và thực hiện search
    if (result != null && result.isNotEmpty && mounted) {
      _searchController.text = result;
      _performSearch(result);
    }
  }

  /// Thực hiện tìm kiếm
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await DatabaseHelper.instance.searchProducts(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Lỗi khi tìm kiếm: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Bật / Tắt thu âm giọng nói
  void _listenVoice() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onError: (val) => setState(() => _isListening = false),
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: 'vi_VN', // Nhận diện tiếng Việt
          onResult: (val) {
            setState(() {
              _searchController.text = val.recognizedWords;
            });
            // Tự động tìm kiếm ngay khi nhận diện xong câu nói
            if (val.finalResult) {
              _performSearch(val.recognizedWords);
            }
          },
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thiết bị không hỗ trợ nhận diện giọng nói!'),
            ),
          );
        }
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  /// Mở camera Quét mã vạch
  void _openBarcodeScanner() async {
    final String? scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const _SearchBarcodeScannerScreen(),
      ),
    );

    if (scannedCode != null && mounted) {
      _searchController.text = scannedCode;
      _performSearch(scannedCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('Tìm kiếm sản phẩm')),
      body: Column(
        children: [
          // Thanh tìm kiếm + Các nút chức năng
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => _performSearch(val),
                    onSubmitted: (val) => _performSearch(val),
                    decoration: InputDecoration(
                      hintText: 'Nhập tên, tên lóng, mã vạch...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _performSearch('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Nút thu âm Giọng nói
                IconButton.filledTonal(
                  onPressed: _openVoiceSearchScreen,
                  icon: const Icon(Icons.mic, color: Colors.blue),
                  tooltip: 'Tìm bằng giọng nói',
                ),
                // Nút Quét mã vạch
                IconButton.filledTonal(
                  onPressed: _openBarcodeScanner,
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                  tooltip: 'Quét mã vạch',
                ),
              ],
            ),
          ),

          // Hiển thị trạng thái Đang nói
          if (_isListening)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.red.shade50,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.graphic_eq, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'Đang nghe... Hãy nói tên sản phẩm',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // Danh sách kết quả
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                ? Center(
                    child: Text(
                      _hasSearched
                          ? 'Không tìm thấy sản phẩm phù hợp'
                          : 'Nhập từ khóa, đọc giọng nói hoặc quét mã vạch',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final item = _searchResults[index];
                      final String? imagePath = item['image_path'];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child:
                                (imagePath != null &&
                                    imagePath.isNotEmpty &&
                                    File(imagePath).existsSync())
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(imagePath),
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(
                                    Icons.inventory_2,
                                    color: Colors.grey,
                                  ),
                          ),
                          title: Text(
                            item['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item['barcode'] != null &&
                                  item['barcode'].toString().isNotEmpty)
                                Text('Mã: ${item['barcode']}'),
                              Text(
                                'Giá: ${item['price']} đ',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          isThreeLine:
                              item['barcode'] != null &&
                              item['barcode'].toString().isNotEmpty,
                          onTap: () {
                            // Trả về sản phẩm đã chọn nếu mở màn hình dạng Pick
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context, item);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Màn hình Camera Quét mã vạch phụ
class _SearchBarcodeScannerScreen extends StatefulWidget {
  const _SearchBarcodeScannerScreen();

  @override
  State<_SearchBarcodeScannerScreen> createState() =>
      __SearchBarcodeScannerScreenState();
}

class __SearchBarcodeScannerScreenState
    extends State<_SearchBarcodeScannerScreen> {
  late MobileScannerController controller;
  bool isScanned = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quét mã vạch tìm kiếm')),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          if (isScanned) return;

          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
              isScanned = true;
              Navigator.pop(context, barcode.rawValue!);
              break;
            }
          }
        },
      ),
    );
  }
}
