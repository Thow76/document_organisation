import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/document_provider.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final documentProvider = Provider.of<DocumentProvider>(context);

    if (documentProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DocSafe'),
              Text(
                '${documentProvider.documents.length} documents',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.notifications), onPressed: () {}),
            IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Documents'),
              Tab(text: 'Reminders'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDocumentsTab(context, documentProvider),
            _buildRemindersTab(context, documentProvider),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.pushNamed(context, '/camera');
          },
          child: const Icon(Icons.camera_alt),
        ),
      ),
    );
  }

  Widget _buildDocumentsTab(BuildContext context, DocumentProvider provider) {
    return ListView(
      children: ['Banking', 'Medical', 'Other'].map((category) {
        final documents = provider.categoryDocuments(category);
        return ExpansionTile(
          leading: Icon(_getCategoryIcon(category)),
          title: Text(category),
          subtitle: Text('${documents.length} documents'),
          children: documents.map((doc) {
            return ListTile(
              title: Text(
                doc.title,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: Text(
                '${doc.captureDate} · Dated ${doc.letterDate}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(
                    label: Text(doc.priority),
                    backgroundColor: BadgeStyles.getBadgeStyle(
                      doc.priority,
                    )['background'],
                    labelStyle: TextStyle(
                      color: BadgeStyles.getBadgeStyle(doc.priority)['text'],
                    ),
                  ),
                  if (provider.getReminderForDocument(doc.id) != null)
                    Icon(Icons.notifications, color: AppColors.textSecondary),
                ],
              ),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/view',
                  arguments: doc,
                );
              },
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildRemindersTab(BuildContext context, DocumentProvider provider) {
    final reminders = provider.upcomingReminders;

    if (reminders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.calendar_today,
              size: 64,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'No upcoming reminders',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: reminders.length,
      itemBuilder: (context, index) {
        final reminder = reminders[index];
        return ListTile(
          title: Text(
            reminder.contextReason,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          subtitle: Text(
            '${reminder.actionableDate} · Reminder: ${reminder.notifyDaysBefore} days before',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          trailing: Checkbox(
            value: reminder.isCompleted,
            onChanged: (value) {
              provider.markReminderCompleted(reminder.id);
            },
          ),
          onTap: () {
            final doc = provider.documents
                .where((d) => d.id == reminder.documentId)
                .firstOrNull;
            if (doc != null) {
              Navigator.pushNamed(context, '/view', arguments: doc);
            }
          },
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Banking':
        return Icons.account_balance;
      case 'Medical':
        return Icons.local_hospital;
      default:
        return Icons.folder;
    }
  }
}
