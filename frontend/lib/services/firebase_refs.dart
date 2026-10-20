// services/firebase_refs.dart
// ============================================================
// Firestore layout — replaces the old MySQL tables.
//
//   users/{uid}                     → profile + streak fields
//   users/{uid}/scans/{scanId}      → scan history
//   users/{uid}/earned_badges/{id}  → earned badge ids
//   challenge_scores/{scoreId}      → leaderboard (shared)
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseRefs {
  static final FirebaseFirestore db   = FirebaseFirestore.instance;
  static final FirebaseAuth      auth = FirebaseAuth.instance;

  /// uid of the signed-in user, or null when signed out.
  static String? get uid => auth.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      db.collection('users').doc(uid);

  static CollectionReference<Map<String, dynamic>> scans(String uid) =>
      userDoc(uid).collection('scans');

  static CollectionReference<Map<String, dynamic>> earnedBadges(String uid) =>
      userDoc(uid).collection('earned_badges');

  static CollectionReference<Map<String, dynamic>> get challengeScores =>
      db.collection('challenge_scores');

  /// Deletes every document a query returns, 400 per batch
  /// (Firestore caps a batch at 500 writes).
  static Future<void> deleteAll(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snap = await query.limit(400).get();
      if (snap.docs.isEmpty) return;
      final batch = db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
