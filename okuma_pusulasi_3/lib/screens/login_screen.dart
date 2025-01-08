import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:ui';
import 'home_screen.dart';
import 'student_test_screen.dart';
import 'teacher_test_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool isLogin = true;
  bool isTeacherMode = true;
  bool isScanning = false;

  void toggleFormType() {
    setState(() {
      isLogin = !isLogin;
    });
  }

  void toggleMode() {
    setState(() {
      isTeacherMode = !isTeacherMode;
      isScanning = false;
    });
  }

  void startScanning() {
    setState(() {
      isScanning = true;
    });
  }

  Future<void> _submit() async {
    try {
      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email ve şifre alanları boş bırakılamaz'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (isLogin) {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await _auth.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildQRScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: MobileScannerController(),
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && barcodes[0].rawValue != null) {
              final String qrData = barcodes[0].rawValue!;
              final List<String> parts = qrData.split(':');
              if (parts.length == 3) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentTestScreen(
                      classId: parts[0],
                      studentId: parts[1],
                      testId: parts[2],
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Geçersiz QR kod'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.black54,
            padding: const EdgeInsets.all(16),
            child: const Text(
              'QR kodu kamera görüş alanına getirin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          child: FloatingActionButton(
            onPressed: () {
              setState(() {
                isScanning = false;
              });
            },
            backgroundColor: Colors.pink,
            child: const Icon(Icons.arrow_back),
          ),
        ),
      ],
    );
  }

  Widget _buildTeacherForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Giriş Yap',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black, // Başlık rengi yeşil
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.email, color: Colors.green),
              labelText: 'Email',
              labelStyle: const TextStyle(
                color: Colors.black54, // Yazı rengi yeşil
                fontWeight: FontWeight.bold,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white38, // TextField arka plan rengi bej
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock, color: Colors.green),
              labelText: 'Şifre',
              labelStyle: const TextStyle(
                color: Colors.black54, // Yazı rengi yeşil
                fontWeight: FontWeight.bold,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white38, // TextField arka plan rengi bej
            ),
            obscureText: true,
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(150, 40), // Buton boyutunu küçült
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: Colors.white38, // Buton rengi bej
              ),
              child: const Text(
                'Giriş Yap',
                style: TextStyle(
                  color: Colors.black54, // Buton üzerindeki yazı rengi yeşil
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: toggleFormType,
            child: Text(
              isLogin
                  ? 'Hesabın yok mu? Kayıt ol'
                  : 'Hesabın var mı? Giriş yap',
              style: const TextStyle(
                color: Colors.black, // Yazı rengi yeşil
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentView() {
    if (isScanning) {
      return _buildQRScanner();
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // QR Kod İkonu Kare Buton İçerisinde
            Container(
              width: 150, // Kare görünümü için genişlik ve yükseklik eşit
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white, // Arka plan rengi
                borderRadius:
                    BorderRadius.circular(16), // Kenarların yuvarlanması
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.qr_code_scanner,
                size: 100,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sınava başlamak için QR kodu okutun',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: startScanning,
              icon: const Icon(Icons.qr_code_2),
              label: const Text(
                'QR Kod Okut',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(240, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                backgroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/kiz.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Column(
            children: [
              AppBar(
                title: Text(
                  isTeacherMode ? 'Öğretmen Girişi' : 'Öğrenci Girişi',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: [
                  TextButton.icon(
                    onPressed: toggleMode,
                    icon: Icon(
                      isTeacherMode ? Icons.school : Icons.person,
                      color: Colors.black,
                    ),
                    label: Text(
                        isTeacherMode ? 'Öğrenci Modu' : 'Öğretmen Modu',
                        style: const TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              Expanded(
                child:
                    isTeacherMode ? _buildTeacherForm() : _buildStudentView(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
