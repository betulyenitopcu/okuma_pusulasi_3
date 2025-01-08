import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:just_audio/just_audio.dart';

class StudentTestHistoryScreen extends StatefulWidget {
  final String classId;
  final String studentId;
  final String studentName;

  const StudentTestHistoryScreen({
    Key? key,
    required this.classId,
    required this.studentId,
    required this.studentName,
  }) : super(key: key);

  @override
  State<StudentTestHistoryScreen> createState() =>
      _StudentTestHistoryScreenState();
}

class _StudentTestHistoryScreenState extends State<StudentTestHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingPath;
  Map<String, bool> _expandedDates = {};

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio(String filePath) async {
    try {
      if (_currentlyPlayingPath == filePath && _audioPlayer.playing) {
        await _audioPlayer.stop();
        setState(() => _currentlyPlayingPath = null);
        return;
      }

      await _audioPlayer.stop();
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.play();
      setState(() => _currentlyPlayingPath = filePath);

      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed && mounted) {
          setState(() => _currentlyPlayingPath = null);
        }
      });
    } catch (e) {
      print('Ses çalma hatası: $e');
      if (mounted) {
        setState(() => _currentlyPlayingPath = null);
      }
    }
  }

  // Test türünü belirleme fonksiyonu güncellendi
  String _getTestType(Map<String, dynamic> testData) {
    if (testData['isWordTest'] == true) return 'Kelime Testi';

    final letters = testData['letters'] as String?;
    if (letters != null) {
      if (letters.length == 9) return 'Deneme Testi';
      if (letters.length == 29) return 'Ana Test';
    }
    return 'Bilinmeyen Test';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildTestCard(Map<String, dynamic> testData) {
    final score = testData['score'] ?? 0.0;
    final correctCount = testData['correctCount'] ?? 0;
    final letters = testData['letters'] as String?;
    final totalQuestions = letters?.length ?? testData['totalQuestions'] ?? 0;
    final timestamp = testData['timestamp'] as Timestamp;
    final time = _formatTime(timestamp.toDate());
    final testType = _getTestType(testData);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  testType,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '$score%',
                  style: TextStyle(
                    color: score >= 80 ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Saat: $time'),
            Text('Doğru: $correctCount/$totalQuestions'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                score >= 80 ? Colors.green : Colors.orange,
              ),
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingCard(Map<String, dynamic> recordingData) {
    final timestamp = recordingData['timestamp'] as Timestamp;
    final time = _formatTime(timestamp.toDate());
    final filePath = recordingData['filePath'] as String;
    final isPlaying = _currentlyPlayingPath == filePath;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(
          isPlaying ? Icons.stop_circle : Icons.play_circle,
          color: isPlaying ? Colors.red : Colors.green,
          size: 32,
        ),
        title: Text('Kayıt Saati: $time'),
        onTap: () => _playAudio(filePath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.studentName} - Test Geçmişi'),
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('classes')
            .doc(widget.classId)
            .collection('students')
            .doc(widget.studentId)
            .collection('tests')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, testSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('classes')
                .doc(widget.classId)
                .collection('students')
                .doc(widget.studentId)
                .collection('recordings')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, recordingSnapshot) {
              if (!testSnapshot.hasData || !recordingSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (testSnapshot.hasError || recordingSnapshot.hasError) {
                return const Center(
                    child: Text('Veri yüklenirken hata oluştu'));
              }

              Map<String, List<Map<String, dynamic>>> groupedTests = {};
              Map<String, List<Map<String, dynamic>>> groupedRecordings = {};

              // Testleri grupla
              for (var doc in testSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['timestamp'] != null) {
                  final date =
                      _formatDate((data['timestamp'] as Timestamp).toDate());
                  groupedTests[date] ??= [];
                  groupedTests[date]!.add({...data, 'id': doc.id});
                }
              }

              // Kayıtları grupla
              for (var doc in recordingSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['timestamp'] != null) {
                  final date =
                      _formatDate((data['timestamp'] as Timestamp).toDate());
                  groupedRecordings[date] ??= [];
                  groupedRecordings[date]!.add({...data, 'id': doc.id});
                }
              }

              final allDates = {...groupedTests.keys, ...groupedRecordings.keys}
                  .toList()
                ..sort((a, b) => b.compareTo(a));

              if (allDates.isEmpty) {
                return const Center(
                  child: Text(
                    'Henüz test veya kayıt bulunmuyor',
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }

              return ListView.builder(
                itemCount: allDates.length,
                padding: const EdgeInsets.all(8),
                itemBuilder: (context, index) {
                  final date = allDates[index];
                  final isExpanded = _expandedDates[date] ?? false;

                  // O güne ait testleri türlerine göre ayır
                  final dayTests = groupedTests[date] ?? [];
                  final demoTests = dayTests
                      .where((test) => _getTestType(test) == 'Deneme Testi')
                      .toList();
                  final mainTests = dayTests
                      .where((test) => _getTestType(test) == 'Ana Test')
                      .toList();
                  final wordTests = dayTests
                      .where((test) => _getTestType(test) == 'Kelime Testi')
                      .toList();

                  final dayRecordings = groupedRecordings[date] ?? [];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          title: Text(
                            date,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          trailing: Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                          ),
                          onTap: () {
                            setState(() {
                              _expandedDates[date] = !isExpanded;
                            });
                          },
                        ),
                        if (isExpanded) ...[
                          // Deneme Testleri
                          if (demoTests.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Deneme Testleri',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            ...demoTests.map(_buildTestCard),
                          ],

                          // Ana Testler
                          if (mainTests.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Ana Testler',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            ...mainTests.map(_buildTestCard),
                          ],

                          // Kelime Testleri
                          if (wordTests.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Kelime Testleri',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            ...wordTests.map(_buildTestCard),
                          ],

                          // Ses Kayıtları
                          if (dayRecordings.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Ses Kayıtları',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            ...dayRecordings.map(_buildRecordingCard),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
