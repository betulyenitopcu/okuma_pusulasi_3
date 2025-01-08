import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:okuma_pusulasi_3/screens/word_test_screen.dart';
import 'test_results_screen.dart';
import 'class_screen.dart';
import 'utils.dart'; // Yeni import

class TeacherTestScreen extends StatefulWidget {
  final String classId;
  final String studentId;
  final String testId;

  const TeacherTestScreen({
    Key? key,
    required this.classId,
    required this.studentId,
    required this.testId,
  }) : super(key: key);

  @override
  _TeacherTestScreenState createState() => _TeacherTestScreenState();
}

class _TeacherTestScreenState extends State<TeacherTestScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  int? _currentLetterIndex;
  bool _isSubmitting = false;
  bool _loading = true;
  String _studentName = '';
  String? _currentWordTestId;

  int _currentWordIndex = 0; // Kelime listesindeki mevcut konum

  @override
  void initState() {
    super.initState();
    _loadStudentName();
  }

  Future<void> _loadNextWords() async {
    try {
      final String wordData = await rootBundle.loadString('assets/word.txt');
      final List<String> allWords = wordData
          .split('\n')
          .where((word) => word.trim().isNotEmpty)
          .map((word) => word.trim())
          .toList();

      // Calculate next index
      final nextIndex = _currentWordIndex + 10;

      // Check if we have enough words
      if (nextIndex >= allWords.length) {
        throw Exception('Tüm kelimeler tamamlandı');
      }

      // Get next batch of words
      final nextWords = allWords.sublist(
        nextIndex,
        min(nextIndex + 10, allWords.length),
      );

      // Update Firestore with new words
      await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('word_tests')
          .doc(widget.testId) // Use the same test ID
          .update({
        'currentWordIndex': nextIndex,
        'words': nextWords,
      });

      setState(() {
        _currentWordIndex = nextIndex;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadStudentName() async {
    try {
      final studentDoc = await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .get();

      if (mounted && studentDoc.exists) {
        setState(() {
          _studentName = studentDoc.data()?['name'] ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _startWordTest() async {
    try {
      // Önce mevcut word test'i kontrol et
      final existingWordTests = await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('word_tests')
          .where('completed', isEqualTo: false)
          .get();

      // Eğer tamamlanmamış bir word test varsa, onu kullan
      if (existingWordTests.docs.isNotEmpty) {
        _currentWordTestId = existingWordTests.docs.first.id;
      } else {
        // Yeni word test oluştur
        final String wordData = await rootBundle.loadString('assets/word.txt');
        final List<String> allWords = wordData
            .split('\n')
            .where((word) => word.trim().isNotEmpty)
            .map((word) => word.trim())
            .toList();

        final selectedWords = allWords.sublist(0, 10);

        final wordTestRef = await _firestore
            .collection('classes')
            .doc(widget.classId)
            .collection('students')
            .doc(widget.studentId)
            .collection('word_tests')
            .add({
          'words': selectedWords,
          'createdAt': FieldValue.serverTimestamp(),
          'completed': false,
          'results': Map.fromIterable(selectedWords, value: (_) => null),
          'currentIndex': 0,
        });

        _currentWordTestId = wordTestRef.id;
      }

      // Ana test dokümanını güncelle
      await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('tests')
          .doc(widget.testId)
          .update({
        'isWordTest': true,
        'currentWordTestId': _currentWordTestId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Öğrenci için bildirim dokümanı oluştur
      await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('notifications')
          .add({
        'type': 'word_test',
        'wordTestId': _currentWordTestId,
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WordTestScreen(
              classId: widget.classId,
              studentId: widget.studentId,
              testId: _currentWordTestId!,
              isTeacher: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateLetterStatus(int index, bool isCorrect) async {
    try {
      final docRef = _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('tests')
          .doc(widget.testId);

      final doc = await docRef.get();
      if (!doc.exists) {
        throw Exception('Test bulunamadı');
      }

      final data = doc.data()!;
      final List<dynamic> status = List<dynamic>.from(data['status'] ?? []);

      // Durumu güncelle
      status[index] = isCorrect;

      // Firestore güncelle
      await docRef.update({
        'status': status,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _finishTest() async {
    if (_isSubmitting) return;

    try {
      final testDoc = await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('tests')
          .doc(widget.testId)
          .get();

      if (!testDoc.exists) {
        throw Exception('Test bulunamadı');
      }

      final testData = testDoc.data()!;
      final List<dynamic> status = List<dynamic>.from(testData['status'] ?? []);

      // Tüm harflerin değerlendirildiğinden emin ol
      if (status.any((s) => s == null)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Lütfen tüm harfleri değerlendirdikten sonra testi bitiriniz.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      setState(() {
        _isSubmitting = true;
      });

      // Test verilerini al
      final int attemptCount = testData['attemptCount'] ?? 1;
      final String letters = testData['letters'] ?? '';
      final bool isWordTest = testData['isWordTest'] ?? false;
      final bool isAdvancedTest = testData['isAdvancedTest'] ?? false;

      // Puanları ve sonuçları hesapla
      final correctCount = status.where((s) => s == true).length;
      final wrongCount = status.where((s) => s == false).length;
      final totalQuestions = status.length;
      final score = (correctCount / totalQuestions) * 100;

      // Doğru ve yanlış harfleri kaydet
      List<Map<String, dynamic>> letterResults = [];
      for (int i = 0; i < letters.length; i++) {
        letterResults.add({
          'letter': letters[i],
          'isCorrect': status[i],
          'index': i,
        });
      }

      // Yanlış okunan harfleri listele
      final List<String> wrongLetters = letterResults
          .where((result) => result['isCorrect'] == false)
          .map((result) => result['letter'].toString())
          .toList();

      // Test tipini belirle
      String testType;
      if (letters.length == 9) {
        testType = 'deneme_testi';
      } else if (letters.length == 29) {
        testType = 'ana_test';
      } else {
        testType = 'kelime_testi';
      }

      // Test sonuç verileri - timestamp'i Firestore'un eklemesine izin ver
      final Map<String, dynamic> resultData = {
        'completed': true,
        'score': score,
        'correctCount': correctCount,
        'wrongCount': wrongCount,
        'totalQuestions': totalQuestions,
        'attemptCount': attemptCount,
        'letters': letters,
        'status': status,
        'letterResults': letterResults,
        'wrongLetters': wrongLetters,
        'isWordTest': isWordTest,
        'isAdvancedTest': isAdvancedTest,
        'testType': testType,
        'originalTestId': widget.testId,
      };

      // Timestamp'leri ayrı ayrı ekle
      final Map<String, dynamic> updateData = {
        ...resultData,
        'completedAt': FieldValue.serverTimestamp(),
      };

      // Mevcut testi güncelle
      await testDoc.reference.update(updateData);

      // Test geçmişine kaydet
      final historyData = {
        ...resultData,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('test_history')
          .add(historyData);

      // Günlük test koleksiyonuna kaydet
      final DateTime now = DateTime.now();
      final String dateKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final Map<String, dynamic> dailyTest = {
        ...resultData,
        'timestamp': now.toIso8601String(), // String olarak timestamp
      };

      await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('daily_tests')
          .doc(dateKey)
          .set({
        'date': dateKey,
        'tests': FieldValue.arrayUnion([dailyTest]),
      }, SetOptions(merge: true));

      // Yanlış harflerin analizini kaydet
      if (wrongLetters.isNotEmpty) {
        final analysisData = {
          'date': dateKey,
          'wrongLetters': wrongLetters,
          'testResults': [
            {
              'testType': testType,
              'timestamp': now.toIso8601String(),
              'wrongLetters': wrongLetters,
              'letterResults': letterResults,
              'testId': widget.testId,
            }
          ],
        };

        await _firestore
            .collection('classes')
            .doc(widget.classId)
            .collection('students')
            .doc(widget.studentId)
            .collection('letter_analysis')
            .doc(dateKey)
            .set(analysisData, SetOptions(merge: true));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _startNewTest(int correctCount, int attemptCount) async {
    try {
      if (correctCount == 0 && attemptCount == 1) {
        // Use the imported generateRandomLetters function
        final newLetters = generateRandomLetters(9);
        await _firestore
            .collection('classes')
            .doc(widget.classId)
            .collection('students')
            .doc(widget.studentId)
            .collection('tests')
            .doc(widget.testId)
            .update({
          'letters': newLetters,
          'status': List.generate(9, (_) => null),
          'completed': false,
          'timestamp': FieldValue.serverTimestamp(),
          'attemptCount': 2,
        });
      } else if (correctCount >= 1) {
        try {
          await _audioPlayer.seek(Duration.zero);
          await _audioPlayer.play();
        } catch (e) {
          print("Ses çalınırken hata oluştu: $e");
        }
        // Use the imported generateRandomLetters function here too
        final newLetters = generateRandomLetters(29);
        await _firestore
            .collection('classes')
            .doc(widget.classId)
            .collection('students')
            .doc(widget.studentId)
            .collection('tests')
            .doc(widget.testId)
            .update({
          'letters': newLetters,
          'status': List.generate(29, (_) => null),
          'completed': false,
          'timestamp': FieldValue.serverTimestamp(),
          'isAdvancedTest': true,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yeni test başlatılamadı: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

// ... existing code ...
  Future<void> _resetTest() async {
    try {
      final testDoc = _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('tests')
          .doc(widget.testId);

      final snapshot = await testDoc.get();
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final String letters = data['letters'] ?? generateRandomLetters(9);

      await testDoc.update({
        'status': List.filled(letters.length, null),
        'completed': false,
        'score': 0,
        'correctCount': 0,
        'resetAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test sıfırlama hatası: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isSubmitting) return false;
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_loading
              ? 'Test Değerlendirme'
              : '$_studentName - Test Değerlendirme'),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFFBBDEFB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: StreamBuilder<DocumentSnapshot>(
            stream: _firestore
                .collection('classes')
                .doc(widget.classId)
                .collection('students')
                .doc(widget.studentId)
                .collection('tests')
                .doc(widget.testId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Hata: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: Text('Test bulunamadı'));
              }

              final testData = snapshot.data!.data() as Map<String, dynamic>;
              final bool completed = testData['completed'] ?? false;

              if (completed) {
                final int correctCount = testData['correctCount'] ?? 0;
                final bool isAdvancedTest = testData['isAdvancedTest'] ?? false;
                final int attemptCount = testData['attemptCount'] ?? 1;

                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (correctCount == 0 && attemptCount == 2) ...[
                        const Text(
                          'Öğrenciye sıfır puan verildi.',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: [
                            SizedBox(
                              width: 140,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text(
                                  'Testi Bitir',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 140,
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context)
                                    .popUntil((route) => route.isFirst),
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.blue,
                                ),
                                child: const Text(
                                  'Ana Ekrana Dön',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (!isAdvancedTest)
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: [
                            SizedBox(
                              width: 140,
                              child: ElevatedButton(
                                onPressed: () =>
                                    _startNewTest(correctCount, attemptCount),
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.white,
                                ),
                                child: Text(
                                  correctCount > 0
                                      ? 'Sıradaki Test\n(29 Harf)'
                                      : 'Sıradaki Test\n(9 Harf)',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 140,
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context)
                                    .popUntil((route) => route.isFirst),
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.blue,
                                ),
                                child: const Text(
                                  'Ana Ekrana\nDön',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else if (correctCount > 0) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: [
                            SizedBox(
                              width: 140,
                              child: ElevatedButton(
                                onPressed: () =>
                                    _startNewTest(correctCount, attemptCount),
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.white,
                                ),
                                child: const Text(
                                  'Harf Listesinden\nDevam Et',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 140,
                              child: ElevatedButton(
                                onPressed: _startWordTest,
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.green,
                                ),
                                child: const Text(
                                  'Kelime Listesine\nGeç',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 140,
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context)
                                    .popUntil((route) => route.isFirst),
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.blue,
                                ),
                                child: const Text(
                                  'Ana Ekrana\nDön',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (correctCount == 0)
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: [
                            SizedBox(
                              width: 140,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text(
                                  'Testi Bitir',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 140,
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context)
                                    .popUntil((route) => route.isFirst),
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.blue,
                                ),
                                child: const Text(
                                  'Ana Ekrana\nDön',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              }
              return _buildTestEvaluationScreen(testData);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTestEvaluationScreen(Map<String, dynamic> testData) {
    final String letters = testData['letters'] ?? '';
    final List<dynamic> status = List<dynamic>.from(testData['status'] ?? []);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              const Text(
                'Test Harfleri:',
                style: TextStyle(
                  fontFamily: 'TemelYazi',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                letters,
                style: const TextStyle(
                  fontFamily: 'TemelYazi',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: status.where((s) => s != null).length / letters.length,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.blue.shade300,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${status.where((s) => s != null).length}/${letters.length} harf değerlendirildi',
                style: TextStyle(
                  fontFamily: 'TemelYazi',
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: letters.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final letter = letters[index];
              final currentStatus = status[index];

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: currentStatus == null
                        ? Colors.grey.shade200
                        : currentStatus
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontFamily: 'TemelYazi',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: currentStatus == null
                            ? Colors.grey.shade700
                            : currentStatus
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                      ),
                    ),
                  ),
                  title: Text(
                    'Harf ${index + 1}',
                    style: const TextStyle(
                      fontFamily: 'TemelYazi',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: currentStatus == null
                      ? const Text('Değerlendirilmedi')
                      : Text(
                          currentStatus ? 'Doğru' : 'Yanlış',
                          style: TextStyle(
                            color: currentStatus ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.check_circle,
                          color: currentStatus == true
                              ? Colors.green
                              : Colors.grey.shade300,
                          size: 32,
                        ),
                        onPressed: () => _updateLetterStatus(index, true),
                        tooltip: 'Doğru',
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.cancel,
                          color: currentStatus == false
                              ? Colors.red
                              : Colors.grey.shade300,
                          size: 32,
                        ),
                        onPressed: () => _updateLetterStatus(index, false),
                        tooltip: 'Yanlış',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _resetTest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Testi Sıfırla'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _finishTest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check_circle),
                      const SizedBox(width: 8),
                      Text(_isSubmitting ? 'İşleniyor...' : 'Testi Bitir'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Temizlik işlemleri burada yapılabilir
    super.dispose();
  }
}
