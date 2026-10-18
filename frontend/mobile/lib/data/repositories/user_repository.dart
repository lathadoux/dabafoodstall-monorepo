// path: frontend/mobile/lib/data/repositories/user_repository.dart
import '../database/database_helper.dart';

class UserRepository {
  const UserRepository._();
  static const UserRepository instance = UserRepository._();

  Future<Map<String, dynamic>?> verifierPinUtilisateur(String pinSaisi) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> res = await db.query('users', where: 'pin_user = ?', whereArgs: [pinSaisi], limit: 1);
    return res.firstOrNull;
  }


  Future<bool> estPinUnique(String pin, {int? idUserAExclure}) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> res = await db.query('users', where: idUserAExclure != null ? 'pin_user = ? AND id_user != ?' : 'pin_user = ?', whereArgs: idUserAExclure != null ? [pin, idUserAExclure] : [pin]);
    return res.isEmpty;
  }
}
