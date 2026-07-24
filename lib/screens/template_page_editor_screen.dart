import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TemplatePageEditorScreen extends StatefulWidget {
  final String templateId;
  final String templateTitle;

  const TemplatePageEditorScreen({
    super.key,
    required this.templateId,
    required this.templateTitle,
  });

  @override
  State<TemplatePageEditorScreen> createState() => _TemplatePageEditorScreenState();
}

class _TemplatePageEditorScreenState extends State<TemplatePageEditorScreen> {
  final _apiService = ApiService();
  late Future<List<dynamic>> _pagesFuture;

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  void _loadPages() {
    _pagesFuture = _apiService.getStoryTemplates().then((templates) {
      final match = templates.firstWhere((t) => t.id == widget.templateId);
      final pages = match.pages;
      pages.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
      return pages;
    });
  }

  void _refresh() {
    setState(() {
      _loadPages();
    });
  }

  Future<void> _addOrEditPage({String? pageId, int? existingPageNumber, String? existingText}) async {
    final textController = TextEditingController(text: existingText ?? '');
    final numberController = TextEditingController(
      text: existingPageNumber?.toString() ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(pageId == null ? 'Add Page' : 'Edit Page'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pageId == null)
              TextField(
                controller: numberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Page Number'),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Page Text',
                hintText: 'Use {roleName} for character names, e.g. {child}, {grandparent}',
                border: OutlineInputBorder(),
              ),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (textController.text.trim().isEmpty) return;

    try {
      if (pageId == null) {
        final pageNumber = int.tryParse(numberController.text.trim()) ?? 1;
        await _apiService.addTemplatePage(
          templateId: widget.templateId,
          pageNumber: pageNumber,
          templateText: textController.text.trim(),
        );
      } else {
        await _apiService.updateTemplatePage(
          pageId: pageId,
          templateText: textController.text.trim(),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save page: $e')),
        );
      }
    }
  }

  Future<void> _deletePage(String pageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this page?'),
        content: const Text('This cannot be undone.'),
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
      await _apiService.deleteTemplatePage(pageId: pageId);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete page: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.templateTitle)),
      body: FutureBuilder<List<dynamic>>(
        future: _pagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final pages = snapshot.data ?? [];
          if (pages.isEmpty) {
            return const Center(child: Text('No pages yet. Tap + to add one.'));
          }
          return ListView.builder(
            itemCount: pages.length,
            itemBuilder: (context, index) {
              final page = pages[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(child: Text('${page.pageNumber}')),
                  title: Text(page.templateText),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _addOrEditPage(
                          pageId: page.id,
                          existingPageNumber: page.pageNumber,
                          existingText: page.templateText,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deletePage(page.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditPage(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
