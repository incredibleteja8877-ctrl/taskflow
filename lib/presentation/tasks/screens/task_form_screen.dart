import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../shared/widgets/state_views.dart';
import '../providers/task_providers.dart';

/// The Create/Edit Task screen required by Task 09.
///
/// One screen serves both paths: [taskId] null means create, non-null means
/// edit. Two near-identical screens would drift apart the first time a field
/// is added to one and not the other.
///
/// On edit it resolves the task through [taskDetailProvider], so opening
/// `/task/<some-other-org-id>/edit` by hand fails with NotFoundException at
/// the usecase layer and renders as an ErrorView rather than a blank form.
class TaskFormScreen extends ConsumerWidget {
  const TaskFormScreen({super.key, this.taskId, this.projectId});

  /// Null when creating.
  final String? taskId;

  /// Pre-selects (and hides) the project when creating from inside one.
  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (taskId == null) {
      return _Scaffold(
        title: 'New task',
        child: _TaskForm(fixedProjectId: projectId),
      );
    }

    final task = ref.watch(taskDetailProvider(taskId!));

    return _Scaffold(
      title: 'Edit task',
      child: task.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(taskDetailProvider(taskId!)),
        ),
        data: (data) => _TaskForm(task: data),
      ),
    );
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: child),
    );
  }
}

class _TaskForm extends ConsumerStatefulWidget {
  const _TaskForm({this.task, this.fixedProjectId});

  final Task? task;
  final String? fixedProjectId;

  @override
  ConsumerState<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<_TaskForm> {
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
    final router = GoRouter.of(context);

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
      if (router.canPop()) router.pop();
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
    final projects =
        ref.watch(projectListProvider).valueOrNull ?? const <Project>[];
    final members = ref.watch(orgMembersProvider).valueOrNull ?? const <User>[];
    final showProjectPicker = widget.fixedProjectId == null && !_isEditing;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
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
            minLines: 3,
            maxLines: 6,
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
                      : (value) => setState(() => _status = value ?? _status),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DropdownButtonFormField<TaskPriority>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: [
                    for (final priority in TaskPriority.values)
                      DropdownMenuItem(
                        value: priority,
                        child: Text(priority.label),
                      ),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (value) =>
                          setState(() => _priority = value ?? _priority),
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
                    onPressed:
                        _isSaving ? null : () => setState(() => _dueDate = null),
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
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
