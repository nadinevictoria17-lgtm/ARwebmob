// lib/features/student/access_code/access_code_sheet.dart
//
// Shared bottom-sheet access-code entry flow (PROJECT_FLOW.md Part 9's "one
// entry flow reused everywhere a code is needed"). Every place a student can
// redeem a code — a locked Learn lesson card, a locked/ineligible Post-Test
// on Lesson Detail, Home's generic entry box — should route through this
// widget (or, for Home's no-specific-target case, call
// `AccessCodeService.redeem` directly the way `_AccessCodeBox` already does)
// rather than re-implementing the form.
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/services/access_code_service.dart';

/// Opens the shared access-code bottom sheet. [targetId]/[targetType] scope
/// the redemption to a specific lesson or quiz (e.g. a locked lesson card
/// passes `targetType: AccessCodeTarget.lesson`; a locked post-test passes
/// `targetType: AccessCodeTarget.quiz`) — both may be left null for a
/// generic, untargeted redemption (only a full-subject code can succeed
/// there).
Future<void> showAccessCodeSheet(
  BuildContext context, {
  required String studentId,
  required AccessCodeService accessCodeService,
  String? targetId,
  AccessCodeTarget? targetType,
  String title = 'Enter code from your teacher',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => AccessCodeSheet(
      studentId: studentId,
      accessCodeService: accessCodeService,
      targetId: targetId,
      targetType: targetType,
      title: title,
    ),
  );
}

class AccessCodeSheet extends StatefulWidget {
  const AccessCodeSheet({
    super.key,
    required this.studentId,
    required this.accessCodeService,
    this.targetId,
    this.targetType,
    this.title = 'Enter code from your teacher',
  });

  final String studentId;
  final AccessCodeService accessCodeService;
  final String? targetId;
  final AccessCodeTarget? targetType;
  final String title;

  @override
  State<AccessCodeSheet> createState() => _AccessCodeSheetState();
}

class _AccessCodeSheetState extends State<AccessCodeSheet> {
  final _controller = TextEditingController();
  String? _message;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;
    setState(() => _loading = true);
    final result = await widget.accessCodeService.redeem(
      studentId: widget.studentId,
      rawCode: raw,
      targetId: widget.targetId,
      targetType: widget.targetType,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _message = result.message;
      if (result.success) _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.keyRound, size: 18, color: scheme.mutedForeground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.title, style: ShadTheme.of(context).textTheme.h4),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ShadInput(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            placeholder: const Text('ENTER CODE HERE'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          ShadButton(
            width: double.infinity,
            onPressed: _loading ? null : _submit,
            child: Text(_loading ? 'Applying...' : 'Apply Code'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(_message!, style: ShadTheme.of(context).textTheme.muted),
          ],
        ],
      ),
    );
  }
}
