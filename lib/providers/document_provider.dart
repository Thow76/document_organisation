import 'package:flutter/foundation.dart';

import '../models/document.dart';
import '../models/reminder.dart';
import '../services/database_service.dart';
import '../services/image_service.dart';
import '../services/notification_service.dart';

class DocumentProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final ImageService _imageService = ImageService();
  final NotificationService _notificationService = NotificationService.instance;

  List<Document> _documents = [];
  List<Reminder> _reminders = [];
  String? _selectedCategory;
  String _sortBy = 'captureDate';
  bool _sortAscending = false;
  bool _isLoading = false;
  String _searchQuery = '';

  List<Document> get documents => _documents;
  List<Reminder> get reminders => _reminders;
  String? get selectedCategory => _selectedCategory;
  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  // ──────────────────── DOCUMENT METHODS ────────────────────

  Future<void> loadDocuments() async {
    _isLoading = true;
    notifyListeners();

    try {
      _documents = await _db.getAllDocuments();
      _reminders = await _db.getAllActiveReminders();
      await _notificationService.rescheduleAllReminders(_reminders, _documents);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addDocument(Document doc) async {
    await _db.insertDocument(doc);
    await loadDocuments();
  }

  Future<void> updateDocument(Document doc) async {
    await _db.updateDocument(doc);
    await loadDocuments();
  }

  Future<void> deleteDocument(String id, String imagePath) async {
    // Cancel and delete any associated reminder
    final reminder = getReminderForDocument(id);
    if (reminder != null) {
      await _notificationService.cancelReminder(reminder.id);
      await _db.deleteReminder(reminder.id);
    }

    await _db.deleteDocument(id);
    await _imageService.deleteImage(imagePath);
    await loadDocuments();
  }

  void setCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSortBy(String field) {
    _sortBy = field;
    notifyListeners();
  }

  void toggleSortDirection() {
    _sortAscending = !_sortAscending;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // ──────────────────── REMINDER METHODS ────────────────────

  Future<void> addReminder(Reminder reminder, String documentTitle) async {
    await _db.insertReminder(reminder);
    await _notificationService.scheduleReminder(reminder, documentTitle);
    _reminders = await _db.getAllActiveReminders();
    notifyListeners();
  }

  Future<void> updateReminder(Reminder reminder, String documentTitle) async {
    await _db.updateReminder(reminder);
    await _notificationService.rescheduleReminder(reminder, documentTitle);
    _reminders = await _db.getAllActiveReminders();
    notifyListeners();
  }

  Future<void> deleteReminder(String reminderId) async {
    await _notificationService.cancelReminder(reminderId);
    await _db.deleteReminder(reminderId);
    _reminders = await _db.getAllActiveReminders();
    notifyListeners();
  }

  Future<void> markReminderCompleted(String reminderId) async {
    final reminder = _reminders.firstWhere((r) => r.id == reminderId);
    final updated = reminder.copyWith(isCompleted: true);
    await _db.updateReminder(updated);
    await _notificationService.cancelReminder(reminderId);
    _reminders = await _db.getAllActiveReminders();
    notifyListeners();
  }

  Reminder? getReminderForDocument(String documentId) {
    try {
      return _reminders.firstWhere((r) => r.documentId == documentId);
    } catch (_) {
      return null;
    }
  }

  // ──────────────────── COMPUTED GETTERS ────────────────────

  List<Document> get filteredDocuments {
    var result = List<Document>.from(_documents);

    // Filter by category
    if (_selectedCategory != null) {
      result = result.where((d) => d.category == _selectedCategory).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((d) {
        return d.title.toLowerCase().contains(query) ||
            d.notes.toLowerCase().contains(query) ||
            d.aiSummary.toLowerCase().contains(query) ||
            d.aiTags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    // Sort
    result.sort((a, b) {
      DateTime? dateA;
      DateTime? dateB;

      if (_sortBy == 'letterDate') {
        dateA = a.letterDate;
        dateB = b.letterDate;
      } else {
        dateA = a.captureDate;
        dateB = b.captureDate;
      }

      // Null dates go to the end
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      return _sortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });

    return result;
  }

  List<Document> categoryDocuments(String category) {
    return filteredDocuments.where((d) => d.category == category).toList();
  }

  int categoryCount(String category) {
    return categoryDocuments(category).length;
  }

  List<Reminder> get upcomingReminders {
    final active = _reminders.where((r) => !r.isCompleted).toList();
    active.sort((a, b) => a.actionableDate.compareTo(b.actionableDate));
    return active;
  }
}
