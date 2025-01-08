import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

class WordTestScreen extends StatefulWidget {
  final String classId;
  final String studentId;
  final String testId;
  final String? previousTestId;
  final bool isTeacher; // New parameter to determine the role

  const WordTestScreen({
    Key? key,
    this.isTeacher = false, // Default to student view

    required this.classId,
    required this.studentId,
    required this.testId,
    this.previousTestId,
  }) : super(key: key);

  @override
  _WordTestScreenState createState() => _WordTestScreenState();
}

class _WordTestScreenState extends State<WordTestScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<String> allWords = [];
  List<String> currentWords = [];
  Map<String, bool?> results = {};

  bool isLoading = true;
  bool isAudioPlaying = false;
  bool isRecording = false;
  bool isRecorderInitialized = false;
  int currentWordIndex = 0;
  late final DocumentReference testRef;

  @override
  void initState() {
    super.initState();
    testRef = _firestore
        .collection('classes')
        .doc(widget.classId)
        .collection('students')
        .doc(widget.studentId)
        .collection('word_tests')
        .doc(widget.testId);

    if (!widget.isTeacher) {
      _initializeRecorder();
    }
    _initializeTest();
    _listenToTestChanges();
  }

  void _listenToTestChanges() {
    testRef.snapshots().listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final List<dynamic> words = data['words'] ?? [];
      final int newIndex = data['currentIndex'] ?? 0;

      if (mounted && (currentWordIndex != newIndex || currentWords != words)) {
        setState(() {
          currentWords = List<String>.from(words);
          currentWordIndex = newIndex;
          results = Map.fromIterable(currentWords, value: (_) => null);

          // For student view, start audio playback for new words
          if (!widget.isTeacher) {
            _playLocalAudioAndStartRecording();
          }
        });
      }
    });
  }

  Future<void> _initializeTest() async {
    try {
      // Load all words from assets
      final String wordData = await rootBundle.loadString('assets/word.txt');
      allWords = wordData
          .split('\n')
          .where((word) => word.trim().isNotEmpty)
          .map((word) => word.trim())
          .toList();

      // Get existing test data or initialize new test
      final doc = await testRef.get();
      if (!doc.exists) {
        // Get first 10 words for new test
        currentWords = allWords.take(10).toList();
        results = Map.fromIterable(currentWords, value: (_) => null);

        // Initialize Firestore document
        await testRef.set({
          'words': currentWords,
          'currentIndex': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'completed': false,
          'previousTestId': widget.previousTestId,
        });
      } else {
        // Load existing test data
        final data = doc.data() as Map<String, dynamic>;
        currentWords = List<String>.from(data['words'] ?? []);
        currentWordIndex = data['currentIndex'] ?? 0;

        // Load existing results if any
        if (data['results'] != null) {
          results = Map<String, bool?>.from(data['results']);
        } else {
          results = Map.fromIterable(currentWords, value: (_) => null);
        }
      }

      setState(() {
        isLoading = false;
      });

      // Start audio playback for student view
      if (!widget.isTeacher) {
        _playLocalAudioAndStartRecording();
      }
    } catch (e) {
      print('Error initializing test: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _initializeRecorder() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      try {
        await _audioRecorder.openRecorder();
        isRecorderInitialized = true;
      } catch (e) {
        print("Recorder başlatma hatası: $e");
      }
    }
  }

  Future<void> _playLocalAudioAndStartRecording() async {
    try {
      setState(() => isAudioPlaying = true);

      await _audioPlayer.setAsset('assets/word.mp3');
      await _audioPlayer.play();

      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          setState(() => isAudioPlaying = false);
          _startRecording();
        }
      });
    } catch (e) {
      setState(() => isAudioPlaying = false);
      print("Ses çalma hatası: $e");
    }
  }

  Future<void> _startRecording() async {
    if (isRecorderInitialized && !_audioRecorder.isRecording) {
      try {
        String fileName =
            "${widget.studentId}_${DateTime.now().toIso8601String()}.aac";
        await _audioRecorder.startRecorder(
          toFile: fileName,
          codec: Codec.aacADTS,
        );
        setState(() => isRecording = true);
      } catch (e) {
        print("Kayıt başlatma hatası: $e");
      }
    }
  }

  Future<void> _loadNextWords() async {
    try {
      final nextIndex = currentWordIndex + 10;

      // Check if we have enough words
      if (nextIndex >= allWords.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tüm kelimeler tamamlandı')),
        );
        return;
      }

      // Get next batch of words
      final nextWords = allWords.sublist(
        nextIndex,
        nextIndex + 10 > allWords.length ? allWords.length : nextIndex + 10,
      );

      // Update Firestore with new words
      await testRef.update({
        'currentIndex': nextIndex,
        'words': nextWords,
      });

      // State will be updated through the snapshot listener
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Hata: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _finishTest() async {
    if (results.values.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen tüm kelimeleri değerlendirin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final correctWords =
          results.values.where((result) => result == true).length;

      await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('word_tests')
          .doc(widget.testId)
          .update({
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
        'correctWords': correctWords,
        'results': results,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test başarıyla tamamlandı'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!widget.isTeacher && isAudioPlaying) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kelime Testi')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/listening.png', width: 400, height: 400),
              const SizedBox(height: 20),
              const Text(
                'Yönergeleri dinleyin...',
                style: TextStyle(fontSize: 24, fontFamily: 'TemelYazi'),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isTeacher ? 'Kelime Değerlendirme' : 'Kelime Testi'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/wallpaper.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: currentWords.length,
                itemBuilder: (context, index) {
                  final word = currentWords[index];
                  final result = results[word];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      title: Text(
                        word,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'TemelYazi',
                        ),
                      ),
                      trailing: widget.isTeacher
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.check_circle,
                                    color: result == true
                                        ? Colors.green
                                        : Colors.grey.shade300,
                                    size: 32,
                                  ),
                                  onPressed: () =>
                                      setState(() => results[word] = true),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    Icons.cancel,
                                    color: result == false
                                        ? Colors.red
                                        : Colors.grey.shade300,
                                    size: 32,
                                  ),
                                  onPressed: () =>
                                      setState(() => results[word] = false),
                                ),
                              ],
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
            if (widget.isTeacher)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loadNextWords,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Sonraki 10 Kelime',
                            style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _finishTest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Testi Bitir',
                            style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioRecorder.closeRecorder();
    _audioPlayer.dispose();
    super.dispose();
  }
}
