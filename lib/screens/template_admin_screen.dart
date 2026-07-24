import 'package:flutter/material.dart';
import '../models/story_template.dart';
import '../services/api_service.dart';
import 'template_page_editor_screen.dart';

class TemplateAdminScreen extends StatefulWidget {
  const TemplateAdminScreen({super.key});

  @override
  State<TemplateAdminScreen> createState() => _TemplateAdminScreenState();
}

class _TemplateAdminScreenState extends State<TemplateAdminScreen> {
  final _apiService = ApiService();
  late Future<List<StoryTemplate>> _templatesFuture;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  void _loadTemplates() {
    _templatesFuture = _apiService.getStoryTemplates();
  }

  void _refresh() {
    setState(() {
      _loadTemplates();
    });
  }

  Future<void> _createTemplate() async {
    final titleController = TextEditingController();
    final themeController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Story Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. David and Goliath'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: themeController,
              decoration: const InputDecoration(labelText: 'Theme', hintText: 'e.g. Bible story'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (titleController.text.trim().isEmpty) return;

    try {
      final template = await _apiService.createStoryTemplate(
        title: titleController.text.trim(),
        theme: themeController.text.trim(),
      );
      _refresh();
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TemplatePageEditorScreen(templateId: template.id, templateTitle: template.title)),
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create template: $e')),
        );
      }
    }
  }

  Future<void> _deleteTemplate(String templateId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "$title"?'),
        content: const Text('This deletes the template and all its pages. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _apiService.deleteStoryTemplate(templateId: templateId);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Story Templates')),
      body: FutureBuilder<List<StoryTemplate>>(
        future: _templatesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final templates = snapshot.data ?? [];
          if (templates.isEmpty) {
            return const Center(child: Text('No templates yet. Tap + to create one.'));
          }
          return ListView.builder(
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return ListTile(
                title: Text(template.title),
                subtitle: Text('${template.theme} - ${template.pages.length} pages'),
                leading: const Icon(Icons.auto_stories),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteTemplate(template.id, template.title),
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TemplatePageEditorScreen(templateId: template.id, templateTitle: template.title),
                    ),
                  );
                  _refresh();
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTemplate,
        child: const Icon(Icons.add),
      ),
    );
  }
}
