import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/project.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/task_repository.dart';
import '../../projects/providers/project_list_controller.dart';
import '../../shared/task_display.dart';
import '../providers/task_providers.dart';

/// Create or edit a task (Task 04's "Create/Edit Task" screen).
///
/// One sheet for both paths. [task] null means create; [fixedProjectId] pins
/// the project when opened from inside a project, hiding the picker.
class TaskFormSheet extends ConsumerStatefulWidget {
  const TaskFormSheet({super.key, this.task, this.fixedProjectId});

  final Task? task;
  final String? fixedProjectId;

  static Future<bool> show(
    BuildContext context, {
    Task? task,
    String? fixedProjectId,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: TaskFormSheet(task: task, fixedProjectId: fixedProjectId),
      ),
    );
    return saved ?? false;
  }

  @override
  ConsumerState<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends ConsumerState<TaskFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  String? _projectId;
  late TaskStatus _status;
  late TaskPriority _priority;
  DateTime? _dueDate;
  String? _assigneeId;

  Map<String, String> _serverErrors = const {};
  bool _isSaving = false;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController =
        TextEditingController(text: task?.description ?? '');
    _projectId = task?.projectId ?? widget.fixedProjectId;
    _status = task?.status ?? TaskStatus.todo;
    _priority = task?.priority ?? TaskPriority.medium;
    _dueDate = task?.dueDate;
    _assigneeId = task?.assigneeId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _clearServerError(String field) {
    if (!_serverErrors.containsKey(field)) return;
    setState(() => _serverErrors = {..._serverErrors}..remove(field));
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    setState(() => _serverErrors = const {});
    if (!_formKey.currentState!.validate()) return;

    final projectId = _projectId;
    if (projectId == null) {
      setState(() => _serverErrors = {'project': 'Choose a project.'});
      _formKey.currentState?.validate();
      return;
    }

    setState(() => _isSaving = true);
    final actions = ref.read(taskActionsProvider);

    try {
      if (_isEditing) {
        await actions.update(
          widget.task!.copyWith(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            status: _status,
            priority: _priority,
            dueDate: _dueDate,
            assigneeId: _assigneeId,
          ),
        );
      } else {
        await actions.create(
          CreateTaskRequest(
            projectId: projectId,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            status: _status,
            priority: _priority,
            dueDate: _dueDate,
            assigneeId: _assigneeId,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ValidationException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _serverErrors = error.fieldErrors;
      });
      _formKey.currentState?.validate();
      if (error.fieldErrors.isEmpty) _showError(error.message);
    } on AppException catch (error) {
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
    final projects =
        ref.watch(projectListProvider).valueOrNull ?? const <Project>[];
    final members = ref.watch(orgMembersProvider).valueOrNull ?? const <User>[];
    final showProjectPicker = widget.fixedProjectId == null && !_isEditing;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEditing ? 'Edit task' : 'New task',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (showProjectPicker) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _projectId,
                    decoration: InputDecoration(
                      labelText: 'Project',
                      errorText: _serverErrors['project'],
                    ),
                    items: [
                      for (final project in projects)
                        DropdownMenuItem(
                          value: project.id,
                          child: Text(project.name),
                        ),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            setState(() => _projectId = value);
                            _clearServerError('project');
                          },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextFormField(
                  controller: _titleController,
                  enabled: !_isSaving,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) =>
                      Validators.notEmpty(value, field: 'Title') ??
                      _serverErrors['title'],
                  onChanged: (_) => _clearServerError('title'),
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
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<TaskStatus>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: [
                          for (final status in TaskStatus.values)
                            DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (value) => setState(
                                  () => _status = value ?? _status,
                                ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DropdownButtonFormField<TaskPriority>(
                        initialValue: _priority,
                        decoration:
                            const InputDecoration(labelText: 'Priority'),
                        items: [
                          for (final priority in TaskPriority.values)
                            DropdownMenuItem(
                              value: priority,
                              child: Text(priority.label),
                            ),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (value) => setState(
                                  () => _priority = value ?? _priority,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String?>(
                  initialValue: _assigneeId,
                  decoration: InputDecoration(
                    labelText: 'Assignee',
                    errorText: _serverErrors['assignee'],
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    for (final member in members)
                      DropdownMenuItem<String?>(
                        value: member.id,
                        child: Text(member.name),
                      ),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() => _assigneeId = value);
                          _clearServerError('assignee');
                        },
                ),
                const SizedBox(height: AppSpacing.md),
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Due date'),
                  child: Row(
                    children: [
                      Expanded(child: Text(Formatters.date(_dueDate))),
                      if (_dueDate != null)
                        IconButton(
                          tooltip: 'Clear due date',
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: _isSaving
                              ? null
                              : () => setState(() => _dueDate = null),
                        ),
                      IconButton(
                        tooltip: 'Pick a date',
                        icon: const Icon(Icons.event_outlined, size: 20),
                        onPressed: _isSaving ? null : _pickDueDate,
                      ),
                    ],
                  ),
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
                      : Text(_isEditing ? 'Save changes' : 'Create task'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
