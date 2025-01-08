import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'teacher_test_screen.dart';
import 'student_test_history_screen.dart';
import 'utils.dart';

class ClassScreen extends StatelessWidget {
  final String classId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ClassScreen({Key? key, required this.classId}) : super(key: key);

  final List<String> turkishLetters = [
    'A',
    'B',
    'C',
    'Ç',
    'D',
    'E',
    'F',
    'G',
    'Ğ',
    'H',
    'I',
    'İ',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'Ö',
    'P',
    'R',
    'S',
    'Ş',
    'T',
    'U',
    'Ü',
    'V',
    'Y',
    'Z'
  ];

  String _generateRandomLetters(int count) {
    return List.generate(count, (_) {
      final randomLetter =
          turkishLetters[Random().nextInt(turkishLetters.length)];
      return randomLetter;
    }).join();
  }

  Future<void> _addStudent(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController infoController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        backgroundColor: Colors.lightBlue.shade50,
        title: Row(
          children: [
            Image.asset('assets/add_icon.png', width: 32, height: 32),
            const SizedBox(width: 10),
            const Text(
              "Öğrenci Ekle",
              style: TextStyle(
                fontFamily: 'ComicSans',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child:
                      Image.asset('assets/ogrenci4.jpg', width: 24, height: 24),
                ),
                labelText: 'Öğrenci Adı',
                labelStyle: TextStyle(
                    color: Colors.purple,
                    fontFamily: 'ComicSans',
                    fontWeight: FontWeight.bold),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.purple),
                  borderRadius: BorderRadius.circular(20),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blueAccent),
                  borderRadius: BorderRadius.circular(20),
                ),
                filled: true,
                fillColor: Colors.purple.shade50,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: infoController,
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset('assets/info_icon.png',
                      width: 24, height: 24),
                ),
                labelText: 'Ek Bilgi (Opsiyonel)',
                labelStyle: TextStyle(
                    color: Colors.purple,
                    fontFamily: 'ComicSans',
                    fontWeight: FontWeight.bold),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.purple),
                  borderRadius: BorderRadius.circular(20),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blueAccent),
                  borderRadius: BorderRadius.circular(20),
                ),
                filled: true,
                fillColor: Colors.purple.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal',
                style: TextStyle(
                    color: Colors.red,
                    fontFamily: 'ComicSans',
                    fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                try {
                  await _firestore
                      .collection('classes')
                      .doc(classId)
                      .collection('students')
                      .add({
                    'name': nameController.text,
                    'info': infoController.text,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hata oluştu: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Öğrenci adı boş bırakılamaz'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Ekle',
                style: TextStyle(
                    fontFamily: 'ComicSans', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _startExam(
      BuildContext context, String studentId, String studentName) async {
    try {
      final testId = _firestore.collection('tests').doc().id;
      // utils.dart'taki fonksiyonu kullanıyoruz
      final letters = generateRandomLetters(9);

      await _firestore
          .collection('classes')
          .doc(classId)
          .collection('students')
          .doc(studentId)
          .collection('tests')
          .doc(testId)
          .set({
        'letters': letters,
        'status': List.generate(9, (_) => null),
        'timestamp': FieldValue.serverTimestamp(),
        'completed': false,
      });

      if (!context.mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          final screenHeight = MediaQuery.of(context).size.height;
          final screenWidth = MediaQuery.of(context).size.width;

          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(20),
                color: Colors.lightGreen.shade50,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$studentName için Sınav QR Kodu',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontFamily: 'ComicSans',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.green, width: 4),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: QrImageView(
                        data: '$classId:$studentId:$testId',
                        version: QrVersions.auto,
                        size: screenWidth * 0.5,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    const Text(
                      'Öğrencinin QR kodu taramasını bekleyin',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'ComicSans',
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TeacherTestScreen(
                                  classId: classId,
                                  studentId: studentId,
                                  testId: testId,
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'Değerlendirme ekranı',
                            style: TextStyle(
                              fontFamily: 'ComicSans',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'İptal',
                            style: TextStyle(
                              color: Colors.red,
                              fontFamily: 'ComicSans',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata oluştu: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('classes').doc(classId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.exists) {
              return Text(
                snapshot.data!.get('name'),
                style: const TextStyle(
                    fontFamily: 'ComicSans', color: Colors.white),
              );
            }
            return const Text(
              "Sınıf Detayları",
              style: TextStyle(fontFamily: 'ComicSans', color: Colors.white),
            );
          },
        ),
        backgroundColor: Colors.pink,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addStudent(context),
        backgroundColor: Colors.pink,
        child: Image.asset('assets/add_icon.png', width: 24, height: 24),
        tooltip: 'Öğrenci Ekle',
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
                'assets/ogrenci7.jpg'), // Hareketli bir arka plan resmi
            fit: BoxFit.cover,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('classes')
              .doc(classId)
              .collection('students')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Hata: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final students = snapshot.data!.docs;

            if (students.isEmpty) {
              return const Center(
                child: Text(
                  'Henüz öğrenci bulunmuyor\nSağ alt köşedeki + butonuna tıklayarak öğrenci ekleyebilirsiniz',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'ComicSans', color: Colors.blue),
                ),
              );
            }

            return ListView.builder(
              itemCount: students.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final studentData =
                    students[index].data() as Map<String, dynamic>;
                final studentId = students[index].id;
                final studentName =
                    studentData['name'] as String? ?? 'İsimsiz Öğrenci';

                return Card(
                  color: Colors.primaries[index % Colors.primaries.length],
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Image.asset(
                        'assets/avatar_${index % 5 + 1}.png', // 5 farklı avatar resmi
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(
                      studentName,
                      style: const TextStyle(
                        fontFamily: 'ComicSans',
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      studentData['info']?.toString() ?? '',
                      style: const TextStyle(color: Colors.yellowAccent),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Image.asset('assets/qr_code.png',
                              width: 24, height: 24),
                          onPressed: () =>
                              _startExam(context, studentId, studentName),
                          tooltip: 'Sınav QR Kodu Oluştur',
                        ),
                        IconButton(
                          icon: Image.asset('assets/icon_history.png',
                              width: 24, height: 24),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StudentTestHistoryScreen(
                                  classId: classId,
                                  studentId: studentId,
                                  studentName: studentName,
                                ),
                              ),
                            );
                          },
                          tooltip: 'Önceki Testleri Gör',
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
