import 'dart:math';
import 'package:firebase_database/firebase_database.dart';

/// Config for loyalty points
class LoyaltyConfig {
  static const int orderBonusThresholdCents = 1000; // $10 order
  static const int orderBonusPoints = 500; // Flat points for eligible orders
  static const int dailyGrantPoints = 10;

  /// Convert points -> discount cents (1000 pts = $1)
  static int discountCentsFromPoints(int points) => (points / 10).floor();

  /// Convert cents -> points needed
  static int pointsNeededForDiscountCents(int cents) => cents * 10;
}

/// Model representing a user’s points account
class LoyaltyAccount {
  final int pointsBalance;
  final int lifetimeEarned;
  final String? lastDailyAwardUtc;

  LoyaltyAccount({
    required this.pointsBalance,
    required this.lifetimeEarned,
    required this.lastDailyAwardUtc,
  });

  LoyaltyAccount copyWith({
    int? pointsBalance,
    int? lifetimeEarned,
    String? lastDailyAwardUtc,
  }) {
    return LoyaltyAccount(
      pointsBalance: pointsBalance ?? this.pointsBalance,
      lifetimeEarned: lifetimeEarned ?? this.lifetimeEarned,
      lastDailyAwardUtc: lastDailyAwardUtc ?? this.lastDailyAwardUtc,
    );
  }

  factory LoyaltyAccount.initial() =>
      LoyaltyAccount(pointsBalance: 0, lifetimeEarned: 0, lastDailyAwardUtc: null);

  factory LoyaltyAccount.fromJson(Map data) {
    return LoyaltyAccount(
      pointsBalance: data['points_balance'] ?? 0,
      lifetimeEarned: data['lifetime_earned'] ?? 0,
      lastDailyAwardUtc: data['last_daily_award_utc'],
    );
  }

  Map<String, dynamic> toJson() => {
        "points_balance": pointsBalance,
        "lifetime_earned": lifetimeEarned,
        "last_daily_award_utc": lastDailyAwardUtc,
      };
}

/// Abstract repository — defines the API for points
abstract class PointsRepository {
  Future<LoyaltyAccount> getAccount(String userId);

  Future<void> awardPoints(
    String userId,
    int points, {
    required String reason,
    String? orderId,
    int? amountCents,
  });

  Future<void> setLastDailyAward(String userId, String ymd);

  Future<int> getBalance(String userId);

  Future<void> ensureDailyGrant(String userId);

  /// Awards FLAT 500 pts for orders >= $10, otherwise 0.
  Future<int> awardForOrder({
    required String userId,
    required int amountCents,
    String? orderId,
  });

  int maxDiscountCentsForOrder(int balancePoints, int orderCents);
}

/// ✅ In-memory implementation (fallback if no Firebase)
class LocalPointsRepository implements PointsRepository {
  final Map<String, LoyaltyAccount> _store = {};
  final Map<String, List<Map<String, dynamic>>> _history = {};

  @override
  Future<LoyaltyAccount> getAccount(String userId) async {
    return _store[userId] ?? LoyaltyAccount.initial();
  }

  @override
  Future<void> awardPoints(
    String userId,
    int points, {
    required String reason,
    String? orderId,
    int? amountCents,
  }) async {
    final acct = await getAccount(userId);
    final newBalance = acct.pointsBalance + points;
    final newLifetime = acct.lifetimeEarned + (points > 0 ? points : 0);
    _store[userId] = acct.copyWith(
      pointsBalance: newBalance,
      lifetimeEarned: newLifetime,
    );

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    _history.putIfAbsent(userId, () => []);
    _history[userId]!.add({
      'ts_ms': now,
      'delta': points,
      'reason': reason,
      if (orderId != null) 'orderId': orderId,
      if (amountCents != null) 'amount_cents': amountCents,
    });
  }

  @override
  Future<void> setLastDailyAward(String userId, String ymd) async {
    final acct = await getAccount(userId);
    _store[userId] = acct.copyWith(lastDailyAwardUtc: ymd);
  }

  @override
  Future<int> getBalance(String userId) async {
    return (await getAccount(userId)).pointsBalance;
  }

  @override
  Future<void> ensureDailyGrant(String userId) async {
    final acct = await getAccount(userId);
    final today = DateTime.now().toUtc();
    final todayStr = '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    if (acct.lastDailyAwardUtc != todayStr) {
      await awardPoints(userId, LoyaltyConfig.dailyGrantPoints, reason: 'daily_grant');
      await setLastDailyAward(userId, todayStr);
    }
  }

  @override
  Future<int> awardForOrder({
    required String userId,
    required int amountCents,
    String? orderId,
  }) async {
    int points = 0;
    if (amountCents >= LoyaltyConfig.orderBonusThresholdCents) {
      points = LoyaltyConfig.orderBonusPoints;
    }
    await awardPoints(
      userId,
      points,
      reason: 'order',
      orderId: orderId,
      amountCents: amountCents,
    );
    return points;
  }

  @override
  int maxDiscountCentsForOrder(int balancePoints, int orderCents) {
    final discountFromPoints = LoyaltyConfig.discountCentsFromPoints(balancePoints);
    return min(discountFromPoints, orderCents);
  }
}

/// ✅ Firebase-backed repository — persists data to Realtime Database
class FirebasePointsRepository implements PointsRepository {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  @override
  Future<LoyaltyAccount> getAccount(String userId) async {
    final snap = await _db.child("users/$userId/loyalty").get();
    if (!snap.exists) return LoyaltyAccount.initial();
    return LoyaltyAccount.fromJson(Map<String, dynamic>.from(snap.value as Map));
  }

  @override
  Future<void> awardPoints(
    String userId,
    int points, {
    required String reason,
    String? orderId,
    int? amountCents,
  }) async {
    final acct = await getAccount(userId);
    final newBalance = acct.pointsBalance + points;
    final newLifetime = acct.lifetimeEarned + (points > 0 ? points : 0);

    await _db.child("users/$userId/loyalty").update({
      "points_balance": newBalance,
      "lifetime_earned": newLifetime,
    });

    await _db.child("users/$userId/loyalty_history").push().set({
      "ts_ms": DateTime.now().millisecondsSinceEpoch,
      "delta": points,
      "reason": reason,
      if (orderId != null) "order_id": orderId,
      if (amountCents != null) "amount_cents": amountCents,
    });
  }

  @override
  Future<void> setLastDailyAward(String userId, String ymd) async {
    await _db.child("users/$userId/loyalty").update({
      "last_daily_award_utc": ymd,
    });
  }

  @override
  Future<int> getBalance(String userId) async {
    final acct = await getAccount(userId);
    return acct.pointsBalance;
  }

  @override
  Future<void> ensureDailyGrant(String userId) async {
    final acct = await getAccount(userId);
    final today = DateTime.now().toUtc();
    final todayStr = '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    if (acct.lastDailyAwardUtc != todayStr) {
      await awardPoints(userId, LoyaltyConfig.dailyGrantPoints, reason: 'daily_grant');
      await setLastDailyAward(userId, todayStr);
    }
  }

  @override
  Future<int> awardForOrder({
    required String userId,
    required int amountCents,
    String? orderId,
  }) async {
    int points = 0;
    if (amountCents >= LoyaltyConfig.orderBonusThresholdCents) {
      points = LoyaltyConfig.orderBonusPoints;
    }
    await awardPoints(
      userId,
      points,
      reason: "order",
      orderId: orderId,
      amountCents: amountCents,
    );
    return points;
  }

  @override
  int maxDiscountCentsForOrder(int balancePoints, int orderCents) {
    final discountFromPoints = LoyaltyConfig.discountCentsFromPoints(balancePoints);
    return min(discountFromPoints, orderCents);
  }
}
