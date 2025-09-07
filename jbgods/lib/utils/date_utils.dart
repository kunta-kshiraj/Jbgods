int ageFromDob(String dob) {
  final parts = dob.split('-');
  if (parts.length != 3) return 0;
  final birthDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  final today = DateTime.now();
  int age = today.year - birthDate.year;
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    age--;
  }
  return age;
} 