class ArticleModel {
  final int? idArticle; // null lors de la création locale brute avant synchro
  final int idTenant; // Isolation multi-tenant
  final int? idFamille;
  final String nomArticle;
  final String typeArticle; // 🛠️ FIX : Ajout de la propriété de flux ('vente' ou 'achat')
  final double? prixUnitaire; // 🛠️ CORRECTIF : Désormais nullable pour gérer le "au montant"
  final String uniteMesure;

  ArticleModel({
    this.idArticle,
    required this.idTenant,
    this.idFamille,
    required this.nomArticle,
    required this.typeArticle, // 🛠️ Ajout au constructeur
    this.prixUnitaire, // Retrait du mot-clé required
    required this.uniteMesure,
  });

  factory ArticleModel.fromSql(Map<String, dynamic> map) {
    return ArticleModel(
      idArticle: map['id_article'] as int?,
      idTenant: map['id_tenant'] as int,
      idFamille: map['id_famille'] as int?,
      nomArticle: map['nom_article'] as String,
      // 🛠️ FIX : Mapping depuis la colonne SQLite 'type_article'
      typeArticle: map['type_article'] as String? ?? 'vente',
      // 🛠️ CORRECTIF : Lecture sécurisée qui tolère l'absence de prix (NULL en SQLite)
      prixUnitaire: map['prix_unitaire'] != null 
          ? (map['prix_unitaire'] as num).toDouble() 
          : null,
      uniteMesure: map['unite_mesure'] as String,
    );
  }

  Map<String, dynamic> toSql() {
    return {
      if (idArticle != null) 'id_article': idArticle,
      'id_tenant': idTenant,
      if (idFamille != null) 'id_famille': idFamille,
      'nom_article': nomArticle,
      'type_article': typeArticle, // 🛠️ Inclusion dans l'écriture SQLite
      'prix_unitaire': prixUnitaire, // Enregistre correctement null ou la valeur double
      'unite_mesure': uniteMesure,
    };
  }
}
