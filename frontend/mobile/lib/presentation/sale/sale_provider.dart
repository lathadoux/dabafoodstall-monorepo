import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/article_model.dart'; // 🛠️ Remplacement de product_model par article_model
import '../../data/models/order_model.dart';

/// Structure d'état pour le panier en cours de vente
class SalesCartState {
  final List<OrderItemModel> items;
  SalesCartState({this.items = const []});

  // Calcul du montant total cumulé basé sur le catalogue d'articles V1
  double get totalAmount => items.fold(0, (sum, item) => sum + (item.qteVendue * item.prixFacture));

  SalesCartState copyWith({List<OrderItemModel>? items}) {
    return SalesCartState(items: items ?? this.items);
  }
}

class SalesCartNotifier extends StateNotifier<SalesCartState> {
  SalesCartNotifier() : super(SalesCartState());

  void setInitialItems(List<OrderItemModel> itemsFromPending) {
    state = state.copyWith(items: itemsFromPending);
  }
  /// Ajoute un article au panier ou augmente sa quantité (Spécifications Caisse V1)
  void addArticle(ArticleModel article) {
    // 🛠️ Match strict entre l'id de la table order_items et la clé primaire id_article
    final existingIndex = state.items.indexWhere((item) => item.idArticle == article.idArticle);
    
    if (existingIndex >= 0) {
      final updatedItems = List<OrderItemModel>.from(state.items);
      final currentItem = updatedItems[existingIndex];
      
      updatedItems[existingIndex] = OrderItemModel(
        idArticle: currentItem.idArticle,
        nomArticle: currentItem.nomArticle,
        qteVendue: currentItem.qteVendue + 1,
        prixFacture: currentItem.prixFacture,
      );
      state = state.copyWith(items: updatedItems);
    } else {
      state = state.copyWith(items: [
        ...state.items,
        OrderItemModel(
          idArticle: article.idArticle!,
          nomArticle: article.nomArticle,
          qteVendue: 1,
          prixFacture: article.prixUnitaire!, // 🛠️ Utilisation de la propriété prixUnitaire de la V1
        )
      ]);
    }
  }
// À intégrer dans votre SalesCartNotifier
void decollerLigne(int idArticle) {
  state = state.copyWith(
    items: state.items.where((item) => item.idArticle != idArticle).toList(),
  );
}

  /// Retire une unité d'un article ou le supprime si la quantité tombe à zéro
  void removeArticle(ArticleModel article) {
    final existingIndex = state.items.indexWhere((item) => item.idArticle == article.idArticle);
    if (existingIndex < 0) return;

    final updatedItems = List<OrderItemModel>.from(state.items);
    final currentItem = updatedItems[existingIndex];

    if (currentItem.qteVendue > 1) {
      updatedItems[existingIndex] = OrderItemModel(
        idArticle: currentItem.idArticle,
        nomArticle: currentItem.nomArticle,
        qteVendue: currentItem.qteVendue - 1,
        prixFacture: currentItem.prixFacture,
      );
      state = state.copyWith(items: updatedItems);
    } else {
      updatedItems.removeAt(existingIndex);
      state = state.copyWith(items: updatedItems);
    }
  }

  /// Réinitialise complètement le panier de vente de manière étanche
  void clearCart() {
    // 🛠️ FIX COMPLET : On retire le mot-clé 'const' et on ne passe que le paramètre valide 'items'
    state = SalesCartState(
      items: [],
    );
  }
}

final salesCartProvider = StateNotifierProvider<SalesCartNotifier, SalesCartState>((ref) {
  return SalesCartNotifier();
});
