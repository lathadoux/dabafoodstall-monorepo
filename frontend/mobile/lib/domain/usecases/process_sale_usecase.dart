//import '../../data/datasources/local_data_source.dart';
import '../../data/datasources/sales_data_source.dart';

class ProcessSaleUseCase {
  //final LocalDataSource _localDataSource;
  final SalesDataSource _salesDataSource;

  ProcessSaleUseCase( this._salesDataSource);

  Future<bool> call({
    required int idCde,
    required int idSession,
    required int idUser, // 🔒 FIX : Ajout du paramètre requis dans la signature de la méthode
    required double montantTotal,
    required List<dynamic> cartItems,
      }) async {
      if (montantTotal <= 0) {
      throw Exception("Le montant total de la commande doit être supérieur à 0 F.");
    }

    if (cartItems.isEmpty) {
      throw Exception("Impossible de valider un panier vide.");
    }
  // 🛠️ RE-ALIGNEMENT SÉCURISÉ : Passage de la signature atomique requise par SQLite
await _salesDataSource.finalizePaymentAndService(
  sessionId: idSession,
  idUser: idUser, // � REQUIS : ID de l'opérateur physique connecté
  totalAmount: montantTotal,  // 🟢 Mappe le total net calculé par Riverpod
  cartItems: cartItems,     // 🟢 Mappe la liste des articles du panier (List<dynamic> ou List<CartItem>)
);
    return true;
  }
}