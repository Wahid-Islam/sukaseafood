import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

/// Firebase Auth + Firestore profile persistence.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<UserProfile> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final String trimmedName = name.trim();
    final String trimmedEmail = email.trim().toLowerCase();

    final UserCredential credential = await _auth.createUserWithEmailAndPassword(
      email: trimmedEmail,
      password: password,
    );
    final User user = credential.user!;

    await user.updateDisplayName(trimmedName);
    await user.reload();

    final UserProfile profile = UserProfile(
      uid: user.uid,
      name: trimmedName,
      email: trimmedEmail,
      createdAt: DateTime.now().toUtc(),
    );

    await _users.doc(user.uid).set(<String, dynamic>{
      'name': profile.name,
      'email': profile.email,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return profile;
  }

  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    final UserCredential credential = await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    return loadProfile(credential.user!.uid);
  }

  Future<void> signOut() => _auth.signOut();

  Future<UserProfile> loadProfile(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await _users.doc(uid).get();

    if (snap.exists && snap.data() != null) {
      return UserProfile.fromMap(uid, snap.data()!);
    }

    final User? user = _auth.currentUser;
    final String name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : 'Friend';
    final String email = user?.email ?? '';

    final UserProfile profile = UserProfile(
      uid: uid,
      name: name,
      email: email,
      createdAt: DateTime.now().toUtc(),
    );

    await _users.doc(uid).set(<String, dynamic>{
      'name': profile.name,
      'email': profile.email,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return profile;
  }
}
