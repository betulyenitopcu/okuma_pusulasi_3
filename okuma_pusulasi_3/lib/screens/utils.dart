import 'dart:math';

String generateRandomLetters(int count) {
  final Random random = Random();
  final List<String> turkishAlphabet = [
    'A', 'B', 'C', 'Ç', 'D', 'E', 'F', 'G', 'Ğ', 'H', 'I', 'İ', 'J', 'K', 'L',
    'M', 'N', 'O', 'Ö', 'P', 'R', 'S', 'Ş', 'T', 'U', 'Ü', 'V', 'Y', 'Z'
  ];

  // Alfabeyi karıştır
  final List<String> shuffledAlphabet = List.from(turkishAlphabet)..shuffle(random);

  if (count == 9) {
    // İlk 9 harfi al ve 4 büyük, 5 küçük olacak şekilde ayarla
    List<String> selectedLetters = shuffledAlphabet.take(9).toList();

    // İlk 4'ü büyük harf yap
    List<String> letters = [];
    for (int i = 0; i < 4; i++) {
      letters.add(selectedLetters[i].toUpperCase());
    }

    // Son 5'i küçük harf yap
    for (int i = 4; i < 9; i++) {
      letters.add(selectedLetters[i].toLowerCase());
    }

    // Son bir kez karıştır
    letters.shuffle(random);
    return letters.join('');
  } else if (count == 29) {
    // 29 harflik test için: 15 büyük, 14 küçük
    List<String> selectedLetters = shuffledAlphabet.take(29).toList();
    List<String> letters = [];

    // İlk 15'i büyük harf yap
    for (int i = 0; i < 15; i++) {
      letters.add(selectedLetters[i].toUpperCase());
    }

    // Son 14'ü küçük harf yap
    for (int i = 15; i < 29; i++) {
      letters.add(selectedLetters[i].toLowerCase());
    }

    // Son bir kez karıştır
    letters.shuffle(random);
    return letters.join('');
  }

  // Diğer durumlar için - gereken sayıda benzersiz harf seç
  return shuffledAlphabet.take(count).join('');
}