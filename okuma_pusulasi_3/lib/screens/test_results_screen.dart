import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okuma_pusulasi_3/screens/word_test_screen.dart';

class TestResultsScreen extends StatelessWidget {
  final String classId;
  final String studentId;
  final String testId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TestResultsScreen({
    Key? key,
    required this.classId,
    required this.studentId,
    required this.testId,
  }) : super(key: key);

  void _navigateToWordTest(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WordTestScreen(
          classId: classId,
          studentId: studentId,
          previousTestId: testId,
          testId: '',
        ),
      ),
    );
  }

  Future<void> _restartTest(BuildContext context) async {
    try {
      await _firestore
          .collection('classes')
          .doc(classId)
          .collection('students')
          .doc(studentId)
          .collection('tests')
          .doc(testId)
          .update({
        'completed': false,
        'status': List.filled(29, null), // 29 harf için null statüsü
        'score': 0,
        'correctCount': 0,
        'resetAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.pop(context);
      }
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
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Test Sonuçları'),
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('classes')
              .doc(classId)
              .collection('students')
              .doc(studentId)
              .collection('tests')
              .orderBy('completedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Hata: ${snapshot.error}'));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final tests = snapshot.data!.docs;

            if (tests.isEmpty) {
              return const Center(
                child: Text('Henüz test sonucu bulunmuyor'),
              );
            }

            return ListView.builder(
              itemCount: tests.length,
              padding: const EdgeInsets.all(16.0),
              itemBuilder: (context, index) {
                final testData = tests[index].data() as Map<String, dynamic>;
                final timestamp = testData['completedAt'] as Timestamp?;
                final score = testData['score'] ?? 0.0;
                final type = testData['type'] as String?;
                final completed = testData['completed'] ?? false;
                final letters = testData['letters'] as String?;
                final words = testData['words'] as List<dynamic>?;

                if (!completed) return const SizedBox.shrink();

                String testTypeText = _getTestTypeText(type ?? '');
                if (letters != null) {
                  testTypeText =
                      letters.length == 9 ? '9 Harf Testi' : '29 Harf Testi';
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ExpansionTile(
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          testTypeText,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Tarih: ${timestamp?.toDate().toString().split('.')[0] ?? 'Tarih Yok'}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: score / 100,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  score >= 80 ? Colors.green : Colors.orange,
                                ),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${score.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    score >= 80 ? Colors.green : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    _buildStatRow(
                                      'Toplam Soru',
                                      (letters?.length ?? words?.length ?? 0)
                                          .toString(),
                                    ),
                                    _buildStatRow(
                                      'Doğru Cevap',
                                      testData['correctCount']?.toString() ??
                                          '0',
                                    ),
                                    _buildStatRow(
                                      'Yanlış Cevap',
                                      ((letters?.length ?? words?.length ?? 0) -
                                              (testData['correctCount'] ?? 0))
                                          .toString(),
                                    ),
                                    _buildStatRow(
                                      'Başarı Durumu',
                                      score >= 80 ? 'Başarılı' : 'Başarısız',
                                      textColor: score >= 80
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (letters != null) ...[
                              const Text(
                                'Harf Detayları',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildLetterResults(testData),
                            ] else if (words != null) ...[
                              const Text(
                                'Kelime Detayları',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildWordResults(testData),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildLetterResults(Map<String, dynamic> testData) {
    final letters = testData['letters'] as String;
    final List<dynamic> status = List<dynamic>.from(testData['status'] ?? []);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: letters.length,
      itemBuilder: (context, index) {
        final isCorrect = status[index] == true;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isCorrect ? Colors.green : Colors.red,
              child: Icon(
                isCorrect ? Icons.check : Icons.close,
                color: Colors.white,
              ),
            ),
            title: Text(
              'Harf ${index + 1}: ${letters[index]}',
              style: const TextStyle(fontSize: 16),
            ),
            trailing: Text(
              isCorrect ? 'Doğru' : 'Yanlış',
              style: TextStyle(
                color: isCorrect ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWordResults(Map<String, dynamic> testData) {
    final words = testData['words'] as List<dynamic>;
    final results = Map<String, dynamic>.from(testData['results'] ?? {});

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: words.length,
      itemBuilder: (context, index) {
        final word = words[index];
        final isCorrect = results[word] == true;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isCorrect ? Colors.green : Colors.red,
              child: Icon(
                isCorrect ? Icons.check : Icons.close,
                color: Colors.white,
              ),
            ),
            title: Text(
              'Kelime ${index + 1}: $word',
              style: const TextStyle(fontSize: 16),
            ),
            trailing: Text(
              isCorrect ? 'Doğru' : 'Yanlış',
              style: TextStyle(
                color: isCorrect ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  String _getTestTypeText(String type) {
    switch (type) {
      case 'word_test':
        return 'Kelime Testi';
      case '9_letter_test':
        return '9 Harf Testi';
      case '29_letter_test':
        return '29 Harf Testi';
      default:
        return 'Bilinmeyen Test';
    }
  }

  Widget _buildStatRow(String label, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
