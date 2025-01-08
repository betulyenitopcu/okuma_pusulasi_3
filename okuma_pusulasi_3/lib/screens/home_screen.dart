import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'class_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _classNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  int? _selectedGrade;

  @override
  void dispose() {
    _classNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createClass(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        backgroundColor: Colors.purple.shade50, // Pastel tonunda bir arka plan
        title: Row(
          children: [
            const Icon(
              Icons.school,
              color: Colors.pink,
              size: 28,
            ),
            const SizedBox(width: 10),
            const Text(
              "Sınıf Oluştur",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.pinkAccent,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _classNameController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.edit,
                    color: Colors.purple,
                  ),
                  labelText: 'Sınıf Adı',
                  labelStyle: const TextStyle(color: Colors.purple),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.pink.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.description,
                    color: Colors.pink,
                  ),
                  labelText: 'Açıklama (Opsiyonel)',
                  labelStyle: const TextStyle(color: Colors.pink),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: DropdownButtonFormField<int>(
                value: _selectedGrade,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.grade,
                    color: Colors.teal,
                  ),
                  labelText: 'Kaçıncı Sınıf?',
                  labelStyle: const TextStyle(color: Colors.teal),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [1, 2, 3, 4].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(
                      '$value. Sınıf',
                      style: const TextStyle(color: Colors.black),
                    ),
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  setState(() {
                    _selectedGrade = newValue;
                  });
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () async {
              final User? user = _auth.currentUser;
              if (user != null && _classNameController.text.isNotEmpty) {
                try {
                  setState(() => _isLoading = true);
                  await _firestore.collection('classes').add({
                    'name': _classNameController.text.trim(),
                    'description': _descriptionController.text.trim(),
                    'teacherId': user.uid,
                    'createdAt': FieldValue.serverTimestamp(),
                    'grade': _selectedGrade,
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sınıf başarıyla oluşturuldu'),
                        backgroundColor: Colors.green,
                      ),
                    );
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
                } finally {
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sınıf adı boş bırakılamaz'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pink,
        title: const Text(
          "Sınıflarım",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _signOut(context),
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.pink,
        onPressed: _isLoading ? null : () => _createClass(context),
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Sınıf Oluştur',
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/word2.jpg'), // Arka plan resmi
            fit: BoxFit.cover,
          ),
        ),
        child: StreamBuilder(
          stream: _firestore
              .collection('classes')
              .where('teacherId', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Bir hata oluştu: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final classes = snapshot.data!.docs;

            if (classes.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.class_outlined,
                        size: 80,
                        color: Colors.purple,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Henüz sınıf oluşturmadınız',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Sağ alt köşedeki + butonuna tıklayarak sınıf oluşturabilirsiniz',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.purple),
                      ),
                    ],
                  ),
                ),
              );
            }

            final sortedClasses = List.from(classes);
            sortedClasses.sort((a, b) {
              final aTime = (a.data() as Map)['createdAt'] as Timestamp?;
              final bTime = (b.data() as Map)['createdAt'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });

            return ListView.builder(
              itemCount: sortedClasses.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final classData = sortedClasses[index];
                final Map<String, dynamic> data =
                    classData.data() as Map<String, dynamic>;

                return Card(
                  color: Colors.green.shade50,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  margin:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: Colors.pink,
                      radius: 25,
                      child: const Icon(Icons.school,
                          color: Colors.white, size: 30),
                    ),
                    title: Text(
                      data['name'] ?? 'İsimsiz Sınıf',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: data['description']?.isNotEmpty ?? false
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              data['description'],
                              style: const TextStyle(fontSize: 14),
                            ),
                          )
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _isLoading
                          ? null
                          : () => _deleteClass(
                              classData.id, data['name'] ?? 'İsimsiz Sınıf'),
                      tooltip: 'Sınıfı Sil',
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ClassScreen(classId: classData.id),
                      ),
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

  Future<void> _deleteClass(String classId, String className) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$className sınıfını sil'),
        content: const Text(
          'Bu sınıfı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz ve tüm öğrenci verileri silinecektir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmDelete != true) return;

    try {
      setState(() => _isLoading = true);

      // Yükleme göstergesini göster
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Önce sınıftaki tüm öğrencilerin testlerini sil
      final studentsSnapshot = await _firestore
          .collection('classes')
          .doc(classId)
          .collection('students')
          .get();

      for (var student in studentsSnapshot.docs) {
        // Öğrencinin tüm testlerini al ve sil
        final testsSnapshot = await _firestore
            .collection('classes')
            .doc(classId)
            .collection('students')
            .doc(student.id)
            .collection('tests')
            .get();

        for (var test in testsSnapshot.docs) {
          await test.reference.delete();
        }

        // Öğrenciyi sil
        await student.reference.delete();
      }

      // Son olarak sınıfı sil
      await _firestore.collection('classes').doc(classId).delete();

      // Yükleme göstergesini kaldır ve başarı mesajı göster
      if (context.mounted) {
        Navigator.pop(context); // Loading dialog'u kapat
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$className sınıfı başarıyla silindi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Hata durumunda
      if (context.mounted) {
        Navigator.pop(context); // Loading dialog'u kapat
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sınıf silinirken hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    // (Kodun devamı aynı kalacak)
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Çıkış yapılırken hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget buildi(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sınıflarım"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : () => _createClass(context),
        child: const Icon(Icons.add),
        tooltip: 'Sınıf Oluştur',
      ),
      body: StreamBuilder(
        stream: _firestore
            .collection('classes')
            .where('teacherId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Bir hata oluştu: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final classes = snapshot.data!.docs;

          if (classes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.class_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Henüz sınıf oluşturmadınız',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Sağ alt köşedeki + butonuna tıklayarak sınıf oluşturabilirsiniz',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          final sortedClasses = List.from(classes);
          sortedClasses.sort((a, b) {
            final aTime = (a.data() as Map)['createdAt'] as Timestamp?;
            final bTime = (b.data() as Map)['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime); // Yeniden eskiye sıralama
          });

          return ListView.builder(
            itemCount: sortedClasses.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final classData = sortedClasses[index];
              final Map<String, dynamic> data =
                  classData.data() as Map<String, dynamic>;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const CircleAvatar(
                    child: Icon(Icons.class_),
                  ),
                  title: Text(
                    data['name'] ?? 'İsimsiz Sınıf',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: data['description']?.isNotEmpty ?? false
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(data['description']),
                        )
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _isLoading
                        ? null
                        : () => _deleteClass(
                            classData.id, data['name'] ?? 'İsimsiz Sınıf'),
                    tooltip: 'Sınıfı Sil',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ClassScreen(classId: classData.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
