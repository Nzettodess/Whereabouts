import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to detect and manage multiple active sessions
class SessionService {
  final String userId;
  String? _sessionId;
  
  // Getter that throws if accessed before init (should use initialize() pattern or future)
  // For this refactor, we'll keep it simple: assume startSession does the work.
  // Actually, we need to know the ID for references.
  
  String get currentSessionId => _sessionId ?? 'initializing';
  Timer? _heartbeatTimer;
  StreamSubscription? _sessionListener;
  StreamSubscription? _terminationListener;
  bool _isActive = false;
  Function()? _onTerminated;

  SessionService(this.userId);

  CollectionReference get _sessionsCollection => FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('active_sessions');

  Future<String> _getOrGenerateSessionId() async {
    if (_sessionId != null) return _sessionId!;
    
    final prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString('device_session_id');
    
    if (storedId == null) {
      storedId = const Uuid().v4();
      await prefs.setString('device_session_id', storedId);
    }
    
    _sessionId = storedId;
    return storedId;
  }

  DocumentReference get _sessionRef => _sessionsCollection.doc(_sessionId);

  /// Start tracking this session
  Future<void> startSession({
    required Function(List<Map<String, dynamic>> sessions) onMultipleSessions,
    Function()? onSessionTerminated,
  }) async {
    if (_isActive) return;
    _isActive = true;
    _onTerminated = onSessionTerminated;

    // Initialize Session ID
    final sid = await _getOrGenerateSessionId();
    print('[SessionService] Starting session: $sid');

    // First, clean up stale sessions (older than 2 minutes)
    await _cleanupStaleSessions();
    
    // Sync User Groups (Self-Correction for Security Rules)
    // We launch this without awaiting to not block session start, or await it to ensure consistency?
    // Await is safer.
    await FirestoreService().syncUserGroups(userId);

    // Register this session (Update or Create)
    // We use set with merge, so if it exists (refreshed page), we just update timestamp
    final now = DateTime.now();
    try {
      await _sessionRef.set({
        'device': _getDeviceInfo(),
        'lastActive': Timestamp.fromDate(now),
        'createdAt': FieldValue.serverTimestamp(), // Update created if new, but we want to know launch. 
        // Actually, for session tracking, refreshing 'createdAt' on revive is okay, or just keep original.
        // Let's just update lastActive mostly.
      }, SetOptions(merge: true));
      
      // Ensure 'createdAt' exists if it's a fresh doc
      // Check if createdAt is set, if not, set it?
      // Since we use merge, if doc doesn't exist, it creates.
      // We will blindly set createdAt to now on start to indicate "App Launch"
      await _sessionRef.update({'createdAt': Timestamp.fromDate(now)});
      
    } catch (e) {
      print('[SessionService] Error creating session: $e');
      _isActive = false;
      return;
    }

    // Listen for THIS session being deleted (terminated by another device)
    _terminationListener = _sessionRef.snapshots().listen(
      (snapshot) {
        if (!snapshot.exists && _isActive) {
          print('[SessionService] This session was terminated by another device!');
          _isActive = false;
          _heartbeatTimer?.cancel();
          _onTerminated?.call();
        }
      },
      onError: (e) => print('[SessionService] Termination listener error: $e'),
    );

    // Heartbeat every 30 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_isActive) {
        try {
          await _sessionRef.update({'lastActive': Timestamp.fromDate(DateTime.now())});
        } catch (e) {
          print('[SessionService] Heartbeat error: $e');
        }
      }
    });

    // Listen for other sessions (for multi-session warning)
    _sessionListener = _sessionsCollection.snapshots().listen(
      (snapshot) {
        if (!_isActive) return;
        
        final now = DateTime.now();
        final activeSessions = <Map<String, dynamic>>[];
        
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final lastActive = data['lastActive'] as Timestamp?;
          final createdAt = data['createdAt'] as Timestamp?;
          final device = data['device'] ?? 'Unknown';
          
          final activeTime = lastActive ?? createdAt;
          if (activeTime == null) {
            activeSessions.add({
              'id': doc.id,
              'device': device,
              'isCurrentSession': doc.id == _sessionId,
            });
          } else {
            final isActive = now.difference(activeTime.toDate()).inMinutes < 2;
            if (isActive) {
              activeSessions.add({
                'id': doc.id,
                'device': device,
                'isCurrentSession': doc.id == _sessionId,
              });
            }
          }
        }

        if (activeSessions.length > 1) {
          print('[SessionService] Multiple sessions detected: ${activeSessions.length}');
          onMultipleSessions(activeSessions);
        }
      },
      onError: (e) => print('[SessionService] Listener error: $e'),
    );
  }

  /// Clean up stale sessions (older than 2 minutes)
  Future<void> _cleanupStaleSessions() async {
    try {
      final snapshot = await _sessionsCollection.get();
      final now = DateTime.now();
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final lastActive = data['lastActive'] as Timestamp?;
        
        if (lastActive != null) {
          final age = now.difference(lastActive.toDate());
          if (age.inMinutes >= 2) {
            await doc.reference.delete();
            print('[SessionService] Cleaned up stale session: ${doc.id}');
          }
        }
      }
    } catch (e) {
      print('[SessionService] Cleanup error: $e');
    }
  }

  /// Terminate all other sessions except current one
  Future<void> terminateOtherSessions() async {
    try {
      final snapshot = await _sessionsCollection.get();
      for (final doc in snapshot.docs) {
        if (doc.id != _sessionId) {
          await doc.reference.delete();
        }
      }
    } catch (e) {
      print('[SessionService] Terminate error: $e');
    }
  }

  /// End current session
  Future<void> endSession() async {
    _isActive = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _sessionListener?.cancel();
    _sessionListener = null;
    await _terminationListener?.cancel();
    _terminationListener = null;
    
    try {
      await _sessionRef.delete();
    } catch (e) {
      // Ignore
    }
  }

  String _getDeviceInfo() {
    return kIsWeb ? 'Web Browser' : 'Mobile App';
  }
}
