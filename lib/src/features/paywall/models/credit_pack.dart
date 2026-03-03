class CreditPack {
  final String productId;
  final int credits;
  final String title;
  final String description;

  const CreditPack({
    required this.productId,
    required this.credits,
    required this.title,
    required this.description,
  });

  static const pack20 = CreditPack(
    productId: 'com.snaplook.credits20',
    credits: 20,
    title: '20 Credits',
    description: 'Up to 20 garment matches',
  );

  static const pack50 = CreditPack(
    productId: 'com.snaplook.credits50',
    credits: 50,
    title: '50 Credits',
    description: 'Up to 50 garment matches',
  );

  static const pack100 = CreditPack(
    productId: 'com.snaplook.credits100',
    credits: 100,
    title: '100 Credits',
    description: 'Up to 100 garment matches',
  );

  static const List<CreditPack> all = [pack20, pack50, pack100];

  static const List<String> allProductIds = [
    'com.snaplook.credits20',
    'com.snaplook.credits50',
    'com.snaplook.credits100',
  ];

  static CreditPack? byProductId(String productId) {
    try {
      return all.firstWhere((p) => p.productId == productId);
    } catch (_) {
      return null;
    }
  }
}
