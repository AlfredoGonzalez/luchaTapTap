/// The buy selector choice: a fixed number of levels (x1, x10, x100) or MAX.
class BuyAmount {
  const BuyAmount.fixed(int this.count) : assert(count > 0);
  const BuyAmount.max() : count = null;

  /// Levels to buy, or null for MAX.
  final int? count;

  bool get isMax => count == null;

  @override
  bool operator ==(Object other) => other is BuyAmount && other.count == count;

  @override
  int get hashCode => count.hashCode;

  @override
  String toString() => isMax ? 'BuyAmount.max' : 'BuyAmount.fixed($count)';
}
