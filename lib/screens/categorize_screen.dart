import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/document.dart';
import '../models/reminder.dart';
import '../providers/document_provider.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

class CategorizeScreen extends StatefulWidget {
  const CategorizeScreen({super.key});

  @override
  State<CategorizeScreen> createState() => _CategorizeScreenState();
}

class _CategorizeScreenState extends State<CategorizeScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _contextReasonController = TextEditingController();

  String? _selectedCategory;
  String _selectedPriority = 'Informational';
  DateTime? _letterDate;
  DateTime? _actionableDate;
  bool _isAnalysing = false;
  bool _isSaving = false;
  bool _reminderEnabled = false;
  int _notifyDaysBefore = 1;

  final String _aiSummary = '';
  final List<String> _aiTags = [];

  final AiService _aiService = AiService();

  static const _priorities = [
    ('Action Required', AppColors.actionRequiredBadgeText),
    ('Completed', AppColors.completedBadgeText),
    ('Informational', AppColors.informationalBadgeText),
  ];

  static const _categories = [
    ('Banking', Icons.account_balance),
    ('Medical', Icons.local_hospital),
    ('Other', Icons.folder),
  ];

  static const _notifyOptions = [
    (0, 'On the day'),
    (1, '1 day before'),
    (3, '3 days before'),
    (7, '1 week before'),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _contextReasonController.dispose();
    super.dispose();
  }

  Future<void> _runAiAnalysis(String imagePath) async {
    setState(() => _isAnalysing = true);

    try {
      final result = await _aiService.analyseDocument(imagePath);

      if (!mounted) return;

      setState(() {
        // Title (only pre-fill if field is empty)
        final title = result['suggestedTitle'] as String?;
        if (title != null && title.isNotEmpty && _titleController.text.isEmpty) {
          _titleController.text = title;
        }

        // Category
        final category = result['suggestedCategory'] as String?;
        if (category != null && _categories.any((c) => c.$1 == category)) {
          _selectedCategory = category;
        }

        // Priority
        final priority = result['suggestedPriority'] as String?;
        if (priority != null && _priorities.any((p) => p.$1 == priority)) {
          _selectedPriority = priority;
        }

        // Letter date
        final letterDateStr = result['letterDate'] as String?;
        if (letterDateStr != null) {
          _letterDate = DateTime.tryParse(letterDateStr);
        }

        // Actionable date → enable reminder section
        final actionableDateStr = result['actionableDate'] as String?;
        if (actionableDateStr != null) {
          final parsed = DateTime.tryParse(actionableDateStr);
          if (parsed != null) {
            _actionableDate = parsed;
            _reminderEnabled = true;
          }
        }

        // Actionable date context
        final actionableDateContext = result['actionableDateContext'] as String?;
        if (actionableDateContext != null && actionableDateContext.isNotEmpty) {
          _contextReasonController.text = actionableDateContext;
        }

        // Notes
        final notes = result['notes'] as String?;
        if (notes != null && notes.isNotEmpty) {
          _notesController.text = notes;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('AI analysis complete')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI analysis failed — enter details manually'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalysing = false);
    }
  }

  Future<void> _save(String imagePath) async {
    // Validate
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a document title')),
      );
      return;
    }
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final doc = Document(
        title: _titleController.text.trim(),
        category: _selectedCategory!,
        captureDate: DateTime.now(),
        letterDate: _letterDate,
        priority: _selectedPriority,
        notes: _notesController.text.trim(),
        imagePath: imagePath,
        aiSummary: _aiSummary,
        aiTags: _aiTags,
      );

      final provider = Provider.of<DocumentProvider>(context, listen: false);
      await provider.addDocument(doc);

      if (_reminderEnabled && _actionableDate != null) {
        final reminder = Reminder(
          documentId: doc.id,
          actionableDate: _actionableDate!,
          contextReason: _contextReasonController.text.trim(),
          notifyDaysBefore: _notifyDaysBefore,
        );
        await provider.addReminder(reminder, doc.title);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document saved successfully')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save document: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickLetterDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _letterDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _letterDate = picked);
  }

  Future<void> _pickActionableDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _actionableDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _actionableDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = ModalRoute.of(context)!.settings.arguments as String;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBackground,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Save Document',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Categorise and save your document',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Document preview ──
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(imagePath),
                  width: screenWidth * 0.4,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Document title ──
            _sectionLabel('DOCUMENT TITLE'),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter document title',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Category ──
            _sectionLabel('CATEGORY'),
            const SizedBox(height: 8),
            Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat.$1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accentColor
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.topRight,
                              children: [
                                Icon(
                                  cat.$2,
                                  color: isSelected
                                      ? AppColors.accentColor
                                      : AppColors.textSecondary,
                                  size: 28,
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: AppColors.accentColor,
                                    size: 14,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              cat.$1,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Priority ──
            _sectionLabel('PRIORITY'),
            const SizedBox(height: 8),
            ..._priorities.map((p) => _buildPriorityOption(p.$1, p.$2)),
            const SizedBox(height: 24),

            // ── Letter date ──
            _sectionLabel('LETTER DATE'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickLetterDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _letterDate != null
                          ? DateFormat('yyyy-MM-dd').format(_letterDate!)
                          : 'Select date (optional)',
                      style: TextStyle(
                        color: _letterDate != null
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Notes ──
            _sectionLabel('NOTES'),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 4,
              minLines: 2,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Add notes…',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── AI analysis button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isAnalysing
                    ? null
                    : () => _runAiAnalysis(imagePath),
                icon: _isAnalysing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome, color: Colors.white),
                label: Text(
                  _isAnalysing ? 'Analysing...' : 'Analyse with AI',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A3F5C),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Reminder section ──
            _buildReminderSection(),
            const SizedBox(height: 32),

            // ── Save button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : () => _save(imagePath),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Document',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Helper widgets ──

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildPriorityOption(String label, Color dotColor) {
    final isSelected = _selectedPriority == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedPriority = label),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? dotColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? dotColor : AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check, color: dotColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Add Reminder',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: _reminderEnabled,
                onChanged: (v) => setState(() => _reminderEnabled = v),
                activeThumbColor: AppColors.accentColor,
              ),
            ],
          ),
          if (_reminderEnabled) ...[
            const SizedBox(height: 16),

            // Actionable date
            _sectionLabel('ACTIONABLE DATE'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickActionableDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _actionableDate != null
                          ? DateFormat('yyyy-MM-dd').format(_actionableDate!)
                          : 'Select actionable date',
                      style: TextStyle(
                        color: _actionableDate != null
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Context reason
            _sectionLabel('REASON'),
            const SizedBox(height: 8),
            TextField(
              controller: _contextReasonController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. GP appointment, payment deadline',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.primaryBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Notify timing
            _sectionLabel('NOTIFY ME'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _notifyDaysBefore,
                  dropdownColor: AppColors.cardBackground,
                  style: const TextStyle(color: AppColors.textPrimary),
                  isExpanded: true,
                  items: _notifyOptions
                      .map(
                        (opt) => DropdownMenuItem(
                          value: opt.$1,
                          child: Text(opt.$2),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _notifyDaysBefore = v);
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
