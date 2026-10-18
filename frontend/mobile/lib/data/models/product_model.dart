class ProductModel {
  final int? idProduit;
  final int idTenant;
  final String nomProduit;
  final double prixVente;

  ProductModel({
    this.idProduit,
    required this.idTenant,
    required this.nomProduit,
    required this.prixVente,
  });

  /// Convertit une ligne SQLite (Map) en objet Dart ProductModel
  factory ProductModel.fromSql(Map<String, dynamic> map) {
    return ProductModel(
      idProduit: map['id_produit'] as int?,
      idTenant: map['id_tenant'] as int,
      nomProduit: map['nom_produit'] as String,
      prixVente: (map['prix_vente'] as num).toDouble(),
    );
  }

  /// Convertit un objet Dart ProductModel en Map pour insertion SQLite
  Map<String, dynamic> toSql() {
    return {
      if (idProduit != null) 'id_produit': idProduit,
      'id_tenant': idTenant,
      'nom_produit': nomProduit,
      'prix_vente': prixVente,
    };
  }
}
