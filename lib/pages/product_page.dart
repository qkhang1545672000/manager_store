import 'dart:io';

import 'package:flutter/material.dart';
import 'package:manager_store/database_helper/database_helper.dart';
import 'package:manager_store/pages/product_add.dart';
import 'package:intl/intl.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({Key? key}) : super(key: key);

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late Future<List<Map<String, dynamic>>> _productList;

  @override
  void initState() {
    super.initState();
    _refreshProducts();
  }

  // Tải lại danh sách sản phẩm từ SQLite
  void _refreshProducts() {
    if (mounted) {
      setState(() {
        _productList = DatabaseHelper.instance.getAllProducts();
      });
    }
  }

  // Mở màn hình Thêm sản phẩm - Tự động reload khi quay về
  void _navigateToAddProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddProductScreen()),
    ).then((_) {
      // Tự động chạy lại hàm load DB bất kể người dùng đóng trang bằng cách nào
      _refreshProducts();
    });
  }

  // Mở màn hình Sửa sản phẩm - Tự động reload khi quay về
  void _navigateToEditProduct(Map<String, dynamic> product) {
    final Map<String, dynamic> editableProduct = Map<String, dynamic>.from(
      product,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductScreen(product: editableProduct),
      ),
    ).then((_) {
      // Hàm này luôn tự động chạy khi màn hình AddProductScreen bị đóng (pop)
      _refreshProducts();
    });
  }

  // Hàm hiển thị hộp thoại xác nhận xóa
  Future<void> _confirmDelete(int id, String productName) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc chắn muốn xóa sản phẩm "$productName" không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('XÓA', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await DatabaseHelper.instance.deleteProduct(id);
      _refreshProducts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa "$productName" thành công!')),
        );
      }
    }
  }

  // Widget hiển thị Ảnh sản phẩm
  Widget _buildProductImage(String? imagePath) {
    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.file(
            file,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image, color: Colors.grey, size: 40),
          ),
        );
      }
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách sản phẩm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshProducts,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _productList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Lỗi tải dữ liệu: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Chưa có sản phẩm nào.'));
          }

          final products = snapshot.data!;

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final item = products[index];
              final String? imagePath = item['image_path'];
              final int productId = item['id'];
              final String productName = item['name'] ?? 'Không có tên';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  onTap: () => _navigateToEditProduct(item),
                  leading: _buildProductImage(imagePath),
                  title: Text(
                    productName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mã vạch: ${item['barcode'] ?? "Không có"}'),
                      Text(
                        '${NumberFormat.currency(locale: 'vi_VN', symbol: '', decimalDigits: 0).format(item['price'] ?? 0).trim()} VNĐ',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(productId, productName),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddProduct,
        child: const Icon(Icons.add),
      ),
    );
  }
}
