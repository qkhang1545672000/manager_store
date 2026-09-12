import 'package:flutter/material.dart';
import 'package:manager_store/pages/index.dart';

import 'package:manager_store/pages/product_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,

      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Hàm hỗ trợ chuyển về tab Danh sách sản phẩm (Tab 1)
  void _switchToListTab() {
    FocusManager.instance.primaryFocus?.unfocus(); // Ẩn bàn phím an toàn
    setState(() {
      _currentIndex = 1; // Chuyển sang Tab "Danh sách / Tìm kiếm"
    });
  }

  @override
  Widget build(BuildContext context) {
    // Khai báo danh sách trang bên trong build() để truyền Callback thành công
    final List<Widget> pages = [
      const SearchProductScreen(),

      // Tab 1: Màn hình Danh sách sản phẩm
      const ProductListScreen(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ứng dụng quản lý'), centerTitle: true),

      // Sử dụng IndexedStack để giữ nguyên trạng thái UI và tránh destroy View Surface của Android
      body: IndexedStack(index: _currentIndex, children: pages),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          FocusManager.instance.primaryFocus
              ?.unfocus(); // Tắt bàn phím khi bấm đổi tab
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Sản phẩm',
          ),
        ],
      ),
    );
  }
}
