class Product {
  final int idProduit;
  final int idTenant;
  final String nomProduit;
  final double prixVente;

  const Product({
    required this.idProduit,
    required this.idTenant,
    required this.nomProduit,
    required this.prixVente,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          runtimeType == other.runtimeType &&
          idProduit == other.idProduit;

  @override
  int get hashCode => idProduit.hashCode;
}
