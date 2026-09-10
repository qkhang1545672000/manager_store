import 'package:flutter/material.dart';
import 'package:manager_store/pages/product_add.dart';

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

// 1. Đổi sang StatefulWidget để lưu vị trí Tab đang chọn
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Biến lưu vị trí tab hiện tại
  int _currentIndex = 0;

  // Danh sách các màn hình tương ứng với từng tab
  final List<Widget> _pages = const [
    Center(child: Text('Trang chủ', style: TextStyle(fontSize: 24))),
    ProductPage(),
    AddProductScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ứng dụng của tôi'), centerTitle: true),
      // 2. Hiển thị màn hình theo chỉ số _currentIndex
      body: _pages[_currentIndex],

      // 3. Sử dụng bottomNavigationBar thay cho TabBar ở trên
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // Cập nhật trạng thái khi chuyển tab
          });
        },
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(
            icon: Icon(Icons.record_voice_over),
            label: 'Tìm kiếm',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.today_outlined),
            label: 'Todo',
          ),
          // BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Bài viết'),
        ],
      ),
    );
  }
}
