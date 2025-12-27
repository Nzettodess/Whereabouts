import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/logger.dart';

/// Base class for all Firestore services providing common functionality.
/// Handles Firestore instance access, caching patterns, and error handling.
abstract class BaseFirestoreService {
  /// Firestore database instance
  final FirebaseFirestore db = FirebaseFirestore.instance;
  
  /// Logger for debugging
  AppLogger get log;
  
  /// Helper to create a broadcast stream with proper cache invalidation
  /// 
  /// [cacheKey] - Key used to store/remove the stream from cache
  /// [cache] - The cache map to manage
  /// [sourceStream] - The source stream to broadcast
  Stream<T> createCachedBroadcastStream<T>({
    required String cacheKey,
    required Map<String, Stream<T>> cache,
    required Stream<T> sourceStream,
  }) {
    if (cache.containsKey(cacheKey)) {
      return cache[cacheKey]!;
    }

    late Stream<T> broadcastStream;
    broadcastStream = sourceStream.asBroadcastStream(
      onCancel: (subscription) {
        subscription.cancel();
        cache.remove(cacheKey);
        log.debug('Stream removed from cache: $cacheKey');
      },
    );
    
    cache[cacheKey] = broadcastStream;
    return broadcastStream;
  }
  
  /// Helper to safely execute Firestore operations with error logging
  Future<T?> safeExecute<T>(
    String operation,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } catch (e, stackTrace) {
      log.error('Failed to $operation', e, stackTrace);
      return null;
    }
  }
  
  /// Helper to emit cached value first, then yield from stream
  Stream<T> cacheFirstStream<T>({
    required T? cachedValue,
    required Stream<T> liveStream,
  }) async* {
    if (cachedValue != null) {
      yield cachedValue;
    }
    yield* liveStream;
  }
}
