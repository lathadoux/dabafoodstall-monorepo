class OrderItemModel {
  final int idArticle;
  final String? nomArticle; // Optionnel, pour l'affichage UI
  final int qteVendue;
  final double prixFacture;

  OrderItemModel({
    required this.idArticle,
    this.nomArticle,
    required this.qteVendue,
    required this.prixFacture,
  });

  factory OrderItemModel.fromSql(Map<String, dynamic> map) {
    return OrderItemModel(
      idArticle: map['id_article'] as int,
      nomArticle: map['nom_article'] as String?,
      qteVendue: map['qte_vendue'] as int,
      prixFacture: (map['prix_facture'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toSql(int idCde) {
    return {
      'id_cde': idCde,
      'id_article': idArticle,
      'qte_vendue': qteVendue,
      'prix_facture': prixFacture,
    };
  }

  /// Format JSON strict pour le serveur Node.js (MLC raccordé à la V1)
  Map<String, dynamic> toJson() {
    return {
      'id_article': idArticle,
      'qte_vendue': qteVendue,
      'prix_facture': prixFacture,
    };
  }
}

class OrderModel {
  final int? idCde;
  final int idSession;
  final int idUser; // 🔒 Intégration de l'identifiant de l'utilisateur connecté
  final String? dateHeureCde;
  final int statutSync; // 0 ou 1
  final List<OrderItemModel> items;

  OrderModel({
    this.idCde,
    required this.idSession,
    required this.idUser,
    this.dateHeureCde,
    this.statutSync = 0,
    required this.items,
  });

  factory OrderModel.fromSql(Map<String, dynamic> map, List<OrderItemModel> items) {
    return OrderModel(
      idCde: map['id_cde'] as int?,
      idSession: map['id_session'] as int,
      idUser: map['id_user'] as int? ?? 1, // Repli sécurisé pour l'amorçage
      dateHeureCde: map['date_heure_cde'] as String?,
      statutSync: map['statut_sync'] as int? ?? 0,
      items: items,
    );
  }

  Map<String, dynamic> toSql() {
    return {
      if (idCde != null) 'id_cde': idCde,
      'id_session': idSession,
      'id_user': idUser, // Persistance du vendeur physique dans Sqflite
      'statut_sync': statutSync,
      'date_heure_cde': dateHeureCde ?? DateTime.now().toIso8601String(),
    };
  }

  /// Format JSON Global (Payload) pour le canal cloud raccordé au backend Node.js
  Map<String, dynamic> toJson() {
    return {
      'id_cde_local': idCde,
      'id_session_local': idSession,
      'id_user': idUser, // Transmission au serveur multi-POS
      'date_heure_cde': dateHeureCde,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}
