import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/project.dart';
import '../providers/project_list_controller.dart';

/// Create or edit a project.
///
/// One sheet serves both: [project] null means create, non-null means edit.
/// Two nearly-identical screens would drift apart the first time a field is
/// added to one and not the other.
class ProjectFormSheet extends ConsumerStatefulWidget {
  const ProjectFormSheet({super.key, this.project});

  final Project? project;

  /// Opens the sheet. Resolves to true if something was saved.
  static Future<bool> show(BuildContext context, {Project? project}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        // Lifts the sheet above the keyboard instead of letting it cover the
        // Save button.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ProjectFormSheet(project: project),
      ),
    );
    return saved ?? false;
  }

  @override
  ConsumerState<ProjectFormSheet> createState() => _ProjectFormSheetState();
}

class _ProjectFormSheetState extends ConsumerState<ProjectFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  Map<String, String> _serverErrors = const {};
  bool _isSaving = false;

  bool get _isEditing => widget.project != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.project?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _clearServerError(String field) {
    if (!_serverErrors.containsKey(field)) return;
    setState(() => _serverErrors = {..._serverErrors}..remove(field));
  }

  Future<void> _save() async {
    setState(() => _serverErrors = const {});
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final controller = ref.read(projectListProvider.notifier);

    try {
      if (_isEditing) {
        await controller.updateProject(
          widget.project!.copyWith(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
          ),
        );
      } else {
        await controller.createProject(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ValidationException catch (error) {
      // Field-level complaints go back onto the fields.
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _serverErrors = error.fieldErrors;
      });
      _formKey.currentState?.validate();
      if (error.fieldErrors.isEmpty) _showError(error.message);
    } on AppException catch (error) {
      // Everything else — forbidden, offline, timeout — is a whole-form
      // failure, so it belongs in a snackbar.
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError(error.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Edit project' : 'New project',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _nameController,
                enabled: !_isSaving,
                autofocus: !_isEditing,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Website Relaunch',
                ),
                validator: (value) =>
                    Validators.notEmpty(value, field: 'Name') ??
                    _serverErrors['name'],
                onChanged: (_) => _clearServerError('name'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _descriptionController,
                enabled: !_isSaving,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What is this project for?',
                  alignLabelWithHint: true,
                ),
                validator: (_) => _serverErrors['description'],
                onChanged: (_) => _clearServerError('description'),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(_isEditing ? 'Save changes' : 'Create project'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
