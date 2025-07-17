import 'package:cloud_firestore/cloud_firestore.dart';

class UserNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final String userId;
  final bool isRead;
  final DateTime timestamp;
  final DateTime createdAt;
  final Map<String, dynamic>? additionalData;

  UserNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.userId,
    required this.isRead,
    required this.timestamp,
    required this.createdAt,
    this.additionalData,
  });

  factory UserNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserNotification(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? '',
      userId: data['userId'] ?? '',
      isRead: data['isRead'] ?? data['read'] ?? false,
      timestamp: _safeTimestampToDateTime(data['timestamp']),
      createdAt: _safeTimestampToDateTime(data['createdAt']),
      additionalData: data,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'userId': userId,
      'isRead': isRead,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': Timestamp.fromDate(createdAt),
      ...?additionalData,
    };
  }

  static DateTime _safeTimestampToDateTime(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return DateTime.now();
  }
}

class FeedbackNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final String userId;
  final String feedbackId;
  final String feedbackCategory;
  final String adminReply;
  final bool isRead;
  final DateTime timestamp;
  final DateTime createdAt;

  FeedbackNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.userId,
    required this.feedbackId,
    required this.feedbackCategory,
    required this.adminReply,
    required this.isRead,
    required this.timestamp,
    required this.createdAt,
  });

  factory FeedbackNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeedbackNotification(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? '',
      userId: data['userId'] ?? '',
      feedbackId: data['feedbackId'] ?? '',
      feedbackCategory: data['feedbackCategory'] ?? '',
      adminReply: data['adminReply'] ?? '',
      isRead: data['isRead'] ?? false,
      timestamp: UserNotification._safeTimestampToDateTime(data['timestamp']),
      createdAt: UserNotification._safeTimestampToDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'userId': userId,
      'feedbackId': feedbackId,
      'feedbackCategory': feedbackCategory,
      'adminReply': adminReply,
      'isRead': isRead,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class NotifikasiUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _notificationsCollection = 'notifications';
  final String _feedbackNotificationsCollection = 'notifications_feedback';

  // Singleton pattern
  static final NotifikasiUserService _instance = NotifikasiUserService._internal();
  factory NotifikasiUserService() => _instance;
  NotifikasiUserService._internal();

  // ==================== GENERAL NOTIFICATIONS ====================

  // FIXED: Stream notifikasi umum untuk user tertentu
  Stream<List<UserNotification>> getUserNotificationsStream(String userId) {
    try {
      return _firestore
          .collection(_notificationsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => UserNotification.fromFirestore(doc))
              .toList())
          .handleError((error) {
            print('Error in getUserNotificationsStream: $error');
            // Return empty list on error
            return <UserNotification>[];
          });
    } catch (e) {
      print('Error setting up getUserNotificationsStream: $e');
      // Return empty stream on error
      return Stream.value(<UserNotification>[]);
    }
  }

  // ALTERNATIVE: Get notifications without real-time updates (no index needed)
  Future<List<UserNotification>> getUserNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_notificationsCollection)
          .where('userId', isEqualTo: userId)
          .get();
      
      final notifications = snapshot.docs
          .map((doc) => UserNotification.fromFirestore(doc))
          .toList();
      
      // Sort in memory by createdAt instead of timestamp
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return notifications;
    } catch (e) {
      print('Error getting user notifications: $e');
      return [];
    }
  }

  // Get unread count untuk notifikasi umum
  Future<int> getUnreadNotificationsCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_notificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread notifications count: $e');
      return 0;
    }
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      print('Attempting to mark notification as read: $notificationId');
      
      // Check if document exists first
      final docSnapshot = await _firestore
          .collection(_notificationsCollection)
          .doc(notificationId)
          .get();
      
      if (!docSnapshot.exists) {
        print('Document does not exist: $notificationId');
        return;
      }
      
      // Update the document with current timestamp
      await _firestore
          .collection(_notificationsCollection)
          .doc(notificationId)
          .update({
            'isRead': true,
            'timestamp': Timestamp.fromDate(DateTime.now()),
          });
      
      print('Successfully marked notification as read: $notificationId');
    } catch (e) {
      print('Error marking notification as read: $e');
      // Rethrow to handle in UI
      rethrow;
    }
  }

  // Mark all notifications as read for user
  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection(_notificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      final now = Timestamp.fromDate(DateTime.now());
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'timestamp': now,
        });
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Add general notification
  Future<void> addNotification({
    required String title,
    required String message,
    required String type,
    required String userId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final now = DateTime.now();
      final notification = UserNotification(
        id: '',
        title: title,
        message: message,
        type: type,
        userId: userId,
        isRead: false,
        timestamp: now,
        createdAt: now,
        additionalData: additionalData,
      );

      final docRef = await _firestore
          .collection(_notificationsCollection)
          .add(notification.toFirestore());
          
      print('Notification added with ID: ${docRef.id}');
    } catch (e) {
      print('Error adding notification: $e');
    }
  }

  // Add destination rejection notification
  Future<void> addDestinationRejectionNotification({
    required String userId,
    required String destinationName,
  }) async {
    await addNotification(
      title: 'Rekomendasi Destinasi Ditolak',
      message: 'Maaf, rekomendasi destinasi "$destinationName" Anda telah ditolak.',
      type: 'destination_rejection',
      userId: userId,
    );
  }

  // Add destination approval notification
  Future<void> addDestinationApprovalNotification({
    required String userId,
    required String destinationName,
  }) async {
    await addNotification(
      title: 'Rekomendasi Destinasi Disetujui',
      message: 'Selamat! Rekomendasi destinasi "$destinationName" Anda telah disetujui.',
      type: 'destination_approval',
      userId: userId,
    );
  }

  // Add event rejection notification
  Future<void> addEventRejectionNotification({
    required String userId,
    required String eventName,
  }) async {
    await addNotification(
      title: 'Permintaan Event Ditolak',
      message: 'Maaf, permintaan event "$eventName" Anda telah ditolak.',
      type: 'event_rejection',
      userId: userId,
    );
  }

  // Add event approval notification
  Future<void> addEventApprovalNotification({
    required String userId,
    required String eventName,
  }) async {
    await addNotification(
      title: 'Permintaan Event Disetujui',
      message: 'Selamat! Permintaan event "$eventName" Anda telah disetujui.',
      type: 'event_approval',
      userId: userId,
    );
  }

  // Add role rejection notification
  Future<void> addRoleRejectionNotification({
    required String userId,
    required String roleName,
  }) async {
    await addNotification(
      title: 'Permintaan Peran Ditolak',
      message: 'Maaf, permintaan peran "$roleName" Anda telah ditolak.',
      type: 'role_rejection',
      userId: userId,
    );
  }

  // Add role approval notification
  Future<void> addRoleApprovalNotification({
    required String userId,
    required String roleName,
  }) async {
    await addNotification(
      title: 'Permintaan Peran Disetujui',
      message: 'Selamat! Permintaan peran "$roleName" Anda telah disetujui.',
      type: 'role_approval',
      userId: userId,
    );
  }

  // ==================== FEEDBACK NOTIFICATIONS ====================

  // FIXED: Stream feedback notifications untuk user tertentu
  Stream<List<FeedbackNotification>> getFeedbackNotificationsStream(String userId) {
    try {
      return _firestore
          .collection(_feedbackNotificationsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => FeedbackNotification.fromFirestore(doc))
              .toList())
          .handleError((error) {
            print('Error in getFeedbackNotificationsStream: $error');
            return <FeedbackNotification>[];
          });
    } catch (e) {
      print('Error setting up getFeedbackNotificationsStream: $e');
      return Stream.value(<FeedbackNotification>[]);
    }
  }

  // ALTERNATIVE: Get feedback notifications without real-time updates
  Future<List<FeedbackNotification>> getFeedbackNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_feedbackNotificationsCollection)
          .where('userId', isEqualTo: userId)
          .get();
      
      final notifications = snapshot.docs
          .map((doc) => FeedbackNotification.fromFirestore(doc))
          .toList();
      
      // Sort in memory by createdAt instead of timestamp
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return notifications;
    } catch (e) {
      print('Error getting feedback notifications: $e');
      return [];
    }
  }

  // Get unread count untuk feedback notifications
  Future<int> getUnreadFeedbackNotificationsCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_feedbackNotificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread feedback notifications count: $e');
      return 0;
    }
  }

  // Mark feedback notification as read
  Future<void> markFeedbackNotificationAsRead(String notificationId) async {
    try {
      print('Attempting to mark feedback notification as read: $notificationId');
      
      // Check if document exists first
      final docSnapshot = await _firestore
          .collection(_feedbackNotificationsCollection)
          .doc(notificationId)
          .get();
      
      if (!docSnapshot.exists) {
        print('Feedback document does not exist: $notificationId');
        return;
      }
      
      // Update the document with current timestamp
      await _firestore
          .collection(_feedbackNotificationsCollection)
          .doc(notificationId)
          .update({
            'isRead': true,
            'timestamp': Timestamp.fromDate(DateTime.now()),
          });
      
      print('Successfully marked feedback notification as read: $notificationId');
    } catch (e) {
      print('Error marking feedback notification as read: $e');
      // Rethrow to handle in UI
      rethrow;
    }
  }

  // Mark all feedback notifications as read for user
  Future<void> markAllFeedbackNotificationsAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection(_feedbackNotificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      final now = Timestamp.fromDate(DateTime.now());
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'timestamp': now,
        });
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all feedback notifications as read: $e');
    }
  }

  // Add feedback notification (admin reply)
  Future<void> addFeedbackNotification({
    required String userId,
    required String feedbackId,
    required String feedbackCategory,
    required String adminReply,
  }) async {
    try {
      final now = DateTime.now();
      final notification = FeedbackNotification(
        id: '',
        title: 'Balasan Admin - $feedbackCategory',
        message: 'Admin telah membalas feedback Anda: $adminReply',
        type: 'admin_reply',
        userId: userId,
        feedbackId: feedbackId,
        feedbackCategory: feedbackCategory,
        adminReply: adminReply,
        isRead: false,
        timestamp: now,
        createdAt: now,
      );

      final docRef = await _firestore
          .collection(_feedbackNotificationsCollection)
          .add(notification.toFirestore());
          
      print('Feedback notification added with ID: ${docRef.id}');
    } catch (e) {
      print('Error adding feedback notification: $e');
    }
  }

  // ==================== COMBINED FUNCTIONS ====================

  // UNIVERSAL: Mark any notification as read (auto-detect type)
  Future<void> markAnyNotificationAsRead(String notificationId) async {
    try {
      print('Attempting to mark notification as read: $notificationId');
      
      final now = Timestamp.fromDate(DateTime.now());
      
      // Try general notifications first
      final generalDocSnapshot = await _firestore
          .collection(_notificationsCollection)
          .doc(notificationId)
          .get();
      
      if (generalDocSnapshot.exists) {
        await _firestore
            .collection(_notificationsCollection)
            .doc(notificationId)
            .update({
              'isRead': true,
              'timestamp': now,
            });
        print('Successfully marked general notification as read: $notificationId');
        return;
      }
      
      // Try feedback notifications
      final feedbackDocSnapshot = await _firestore
          .collection(_feedbackNotificationsCollection)
          .doc(notificationId)
          .get();
      
      if (feedbackDocSnapshot.exists) {
        await _firestore
            .collection(_feedbackNotificationsCollection)
            .doc(notificationId)
            .update({
              'isRead': true,
              'timestamp': now,
            });
        print('Successfully marked feedback notification as read: $notificationId');
        return;
      }
      
      print('Notification not found in any collection: $notificationId');
    } catch (e) {
      print('Error marking notification as read: $e');
      rethrow;
    }
  }

  // Get total unread count (both collections)
  Future<int> getTotalUnreadCount(String userId) async {
    try {
      final notificationsCount = await getUnreadNotificationsCount(userId);
      final feedbackCount = await getUnreadFeedbackNotificationsCount(userId);
      return notificationsCount + feedbackCount;
    } catch (e) {
      print('Error getting total unread count: $e');
      return 0;
    }
  }

  // Mark all notifications as read (both collections)
  Future<void> markAllAsRead(String userId) async {
    try {
      await Future.wait([
        markAllNotificationsAsRead(userId),
        markAllFeedbackNotificationsAsRead(userId),
      ]);
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  // FIXED: Get combined notifications (using Future instead of Stream)
  Future<List<dynamic>> getAllNotifications(String userId) async {
    try {
      final notifications = await getUserNotifications(userId);
      final feedbackNotifications = await getFeedbackNotifications(userId);

      // Combine and sort by createdAt
      final combined = <dynamic>[...notifications, ...feedbackNotifications];
      combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return combined;
    } catch (e) {
      print('Error getting all notifications: $e');
      return [];
    }
  }

  // ALTERNATIVE: Get combined stream (requires proper indexes)
  Stream<List<dynamic>> getAllNotificationsStream(String userId) async* {
    try {
      // Get both streams
      final notificationStream = getUserNotificationsStream(userId);
      final feedbackStream = getFeedbackNotificationsStream(userId);
      
      // Combine streams
      await for (final notifications in notificationStream) {
        try {
          final feedbackNotifications = await getFeedbackNotifications(userId);
          final combined = <dynamic>[...notifications, ...feedbackNotifications];
          combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          yield combined;
        } catch (e) {
          print('Error in combined stream: $e');
          yield notifications; // Return just general notifications on error
        }
      }
    } catch (e) {
      print('Error setting up combined stream: $e');
      yield <dynamic>[];
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId, {bool isFeedback = false}) async {
    try {
      final collection = isFeedback ? _feedbackNotificationsCollection : _notificationsCollection;
      await _firestore.collection(collection).doc(notificationId).delete();
      print('Notification deleted successfully.');
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Delete all notifications for user
  Future<void> deleteAllNotifications(String userId) async {
    try {
      final batch = _firestore.batch();
      
      // Delete from notifications collection
      final notificationsSnapshot = await _firestore
          .collection(_notificationsCollection)
          .where('userId', isEqualTo: userId)
          .get();
      
      for (var doc in notificationsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete from feedback notifications collection
      final feedbackSnapshot = await _firestore
          .collection(_feedbackNotificationsCollection)
          .where('userId', isEqualTo: userId)
          .get();
      
      for (var doc in feedbackSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('All notifications deleted for user: $userId');
    } catch (e) {
      print('Error deleting all notifications: $e');
    }
  }
}