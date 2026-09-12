import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // THÊM IMPORT THƯ VIỆN INTL
import 'package:manager_store/database_helper/database_helper.dart';
import 'package:manager_store/util/InputFormatter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? product;
  final VoidCallback?
  onSaveSuccess; // Callback chuyển tab nếu dùng BottomNavigationBar

  const AddProductScreen({super.key, this.product, this.onSaveSuccess});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _barcodeController;
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _aliasInputController;

  File? _imageFile;
  String? _existingImagePath;
  final List<String> _aliases = [];
  bool _isSaving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController(
      text: widget.product?['barcode']?.toString() ?? '',
    );
    _nameController = TextEditingController(
      text: widget.product?['name']?.toString() ?? '',
    );

    // =========================================================
    // 1. FORMAT GIÁ BAN ĐẦU KHI NẠP DỮ LIỆU SỬA SẢN PHẨM (VD: 25000 -> 25.000)
    // =========================================================
    final double rawPrice =
        double.tryParse(widget.product?['price']?.toString() ?? '0') ?? 0;
    final String initialFormattedPrice = rawPrice > 0
        ? NumberFormat.decimalPattern('vi_VN').format(rawPrice)
        : '';

    _priceController = TextEditingController(text: initialFormattedPrice);
    _aliasInputController = TextEditingController();

    _existingImagePath = widget.product?['image_path']?.toString();

    if (_isEditing && widget.product!['id'] != null) {
      _loadExistingAliases(widget.product!['id']);
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _aliasInputController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingAliases(int productId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query(
        'product_aliases',
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      if (mounted) {
        setState(() {
          _aliases.clear();
          for (var item in res) {
            if (item['alias_name'] != null) {
              _aliases.add(item['alias_name'].toString());
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Lỗi nạp tên lóng: $e');
    }
  }

  /// Nén ảnh và lưu vào bộ nhớ ứng dụng
  Future<String?> _compressAndSaveImage(File imageFile) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final String fileName =
          'prod_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String targetPath = p.join(appDir.path, fileName);

      final XFile? compressedFile =
          await FlutterImageCompress.compressAndGetFile(
            imageFile.absolute.path,
            targetPath,
            quality: 80,
            minWidth: 800,
            minHeight: 800,
            format: CompressFormat.jpeg,
          );

      if (compressedFile != null) {
        return compressedFile.path;
      }

      final File savedFile = await imageFile.copy(targetPath);
      return savedFile.path;
    } catch (e) {
      debugPrint('Lỗi nén/lưu ảnh: $e');
      return imageFile.path;
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Chọn từ thư viện ảnh'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.green),
                title: const Text('Chụp ảnh mới từ máy ảnh'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );

    if (pickedFile != null && mounted) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  void _openBarcodeScanner() async {
    final String? scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const _BarcodeScannerScreen()),
    );

    if (scannedCode != null && mounted) {
      setState(() {
        _barcodeController.text = scannedCode;
      });
    }
  }

  void _addAlias() {
    final text = _aliasInputController.text.trim();
    if (text.isNotEmpty && !_aliases.contains(text)) {
      setState(() {
        _aliases.add(text);
        _aliasInputController.clear();
      });
    }
  }

  void _resetForm() {
    _barcodeController.clear();
    _nameController.clear();
    _priceController.clear();
    _aliasInputController.clear();
    setState(() {
      _imageFile = null;
      _existingImagePath = null;
      _aliases.clear();
      _isSaving = false;
    });
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      String? finalImagePath = _existingImagePath;

      if (_imageFile != null) {
        finalImagePath = await _compressAndSaveImage(_imageFile!);
      }

      // =========================================================
      // 2. XÓA TẤT CẢ DẤU CHẤM TRƯỚC KHÍ CHUYỂN SANG DOUBLE ĐỂ LƯU VÀO DB
      // =========================================================
      final String cleanPriceText = _priceController.text
          .replaceAll('.', '')
          .trim();
      final double parsedPrice = double.tryParse(cleanPriceText) ?? 0.0;

      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        if (_isEditing) {
          final int productId = widget.product!['id'];
          await txn.update(
            'products',
            {
              'barcode': _barcodeController.text.trim(),
              'name': _nameController.text.trim(),
              'price': parsedPrice, // Sử dụng giá đã lọc sạch dấu chấm
              'image_path': finalImagePath,
            },
            where: 'id = ?',
            whereArgs: [productId],
          );
          await txn.delete(
            'product_aliases',
            where: 'product_id = ?',
            whereArgs: [productId],
          );
          for (String alias in _aliases) {
            await txn.insert('product_aliases', {
              'product_id': productId,
              'alias_name': alias.toLowerCase().trim(),
            });
          }
        } else {
          int productId = await txn.insert('products', {
            'barcode': _barcodeController.text.trim(),
            'name': _nameController.text.trim(),
            'price': parsedPrice, // Sử dụng giá đã lọc sạch dấu chấm
            'image_path': finalImagePath,
          });
          for (String alias in _aliases) {
            await txn.insert('product_aliases', {
              'product_id': productId,
              'alias_name': alias.toLowerCase().trim(),
            });
          }
        }
      });

      if (!mounted) return;

      FocusManager.instance.primaryFocus?.unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Đã cập nhật sản phẩm!'
                : 'Đã thêm sản phẩm thành công!',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // 1. Gọi callback nếu dùng dạng Tab/BottomNavigationBar
      if (widget.onSaveSuccess != null) {
        widget.onSaveSuccess!();
      }

      // 2. Nếu mở qua Navigator (chuyển trang), Pop và trả về giá trị true
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu dữ liệu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildImagePreview() {
    if (_imageFile != null) {
      return Image.file(_imageFile!, fit: BoxFit.cover);
    }
    if (_existingImagePath != null &&
        _existingImagePath!.isNotEmpty &&
        File(_existingImagePath!).existsSync()) {
      return Image.file(File(_existingImagePath!), fit: BoxFit.cover);
    }
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
        SizedBox(height: 8),
        Text('Thêm ảnh SP', style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(_isEditing ? 'Cập nhật sản phẩm' : 'Thêm sản phẩm mới'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _showImagePickerModal,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildImagePreview(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  labelText: 'Mã vạch (Barcode)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                    onPressed: _openBarcodeScanner,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên sản phẩm chuẩn *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Vui lòng nhập tên SP'
                    : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, // Chỉ cho nhập số
                  ThousandsSeparatorInputFormatter(), // Tự động định dạng dấu chấm 25.000
                ],
                decoration: const InputDecoration(
                  labelText: 'Giá bán (VNĐ) *',
                  border: OutlineInputBorder(),
                  suffixText: 'đ',
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Vui lòng nhập giá'
                    : null,
              ),
              const SizedBox(height: 20),

              const Text(
                'Tên gọi phụ / Tên lóng (khách hay kêu):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _aliasInputController,
                      decoration: const InputDecoration(
                        hintText: 'VD: bạc, thuốc bạc...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addAlias(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addAlias,
                    child: const Text('Thêm'),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Wrap(
                spacing: 8.0,
                children: _aliases.map((alias) {
                  return Chip(
                    label: Text(alias),
                    deleteIcon: const Icon(Icons.cancel, size: 18),
                    onDeleted: () {
                      setState(() {
                        _aliases.remove(alias);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveProduct,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(_isEditing ? Icons.edit : Icons.save),
                  label: Text(
                    _isSaving
                        ? 'ĐANG LƯU...'
                        : (_isEditing ? 'CẬP NHẬT SẢN PHẨM' : 'LƯU SẢN PHẨM'),
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isEditing ? Colors.orange : Colors.blue,
                    foregroundColor: Colors.white,
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

class _BarcodeScannerScreen extends StatefulWidget {
  const _BarcodeScannerScreen();

  @override
  State<_BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<_BarcodeScannerScreen> {
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
      appBar: AppBar(
        title: const Text('Quét mã vạch'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          if (isScanned) return;

          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
              isScanned = true;
              final String code = barcode.rawValue!;
              Navigator.pop(context, code);
              break;
            }
          }
        },
      ),
    );
  }
}
