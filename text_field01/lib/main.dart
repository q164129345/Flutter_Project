import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  // 内部
  final TextEditingController _accountController =
      TextEditingController(); // 账号
  final TextEditingController _passwordController =
      TextEditingController(); // 密码

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text("text fild例程01"),
          centerTitle: true,
          backgroundColor: Colors.blue,
        ),
        body: Container(
          padding: EdgeInsets.all(30),
          color: Colors.white, // 颜色
          child: Column(
            children: [
              TextField(
                controller: _accountController,
                decoration: InputDecoration(
                  hintText: "请输入账号", // 提示的字体内容
                  fillColor: const Color.fromARGB(255, 204, 196, 175),
                  filled: true,
                  border: OutlineInputBorder(
                    // 边框
                    borderSide: BorderSide.none, // 没有边框
                    borderRadius: BorderRadius.circular(20), // 边框圆角
                  ),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                obscureText: true, // 不显示实际内容（一般在密码框场景使用）
                controller: _passwordController,
                decoration: InputDecoration(
                  hintText: "请输入密码", // 提示的字体内容
                  fillColor: const Color.fromARGB(255, 204, 196, 175),
                  filled: true,
                  border: OutlineInputBorder(
                    // 边框
                    borderSide: BorderSide.none, // 没有边框
                    borderRadius: BorderRadius.circular(20), // 边框圆角
                  ),
                ),
              ),
              SizedBox(height: 10),
              Container(
                height: 40,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20), // 边框圆角
                ),
                child: TextButton(
                  onPressed: () {
                    print(
                      "账号:${_accountController.text},密码:${_passwordController.text}",
                    );
                  },
                  child: Text("登录", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
