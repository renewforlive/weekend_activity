import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// 彈出「發起招募」表單(討論版發文):標題、內容、人數、性別、花費。
Future<void> showRecruitmentEditor(BuildContext context, {Activity? relatedActivity}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RecruitmentEditorSheet(relatedActivity: relatedActivity),
  );
}

class _RecruitmentEditorSheet extends StatefulWidget {
  const _RecruitmentEditorSheet({this.relatedActivity});
  final Activity? relatedActivity;

  @override
  State<_RecruitmentEditorSheet> createState() => _RecruitmentEditorSheetState();
}

class _RecruitmentEditorSheetState extends State<_RecruitmentEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _content;
  final _headcount = TextEditingController(text: '4');
  final _cost = TextEditingController(text: '0');
  GenderPref _gender = GenderPref.any;

  @override
  void initState() {
    super.initState();
    final a = widget.relatedActivity;
    _title = TextEditingController(text: a == null ? '' : AppStrings.togetherGo(a.title));
    _content = TextEditingController(text: a == null ? '' : AppStrings.recruitmentContentPrefill(a.city, a.venue));
    if (a != null) _cost.text = a.cost.toString();
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _headcount.dispose();
    _cost.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AppState>().createRecruitment(
          title: _title.text.trim(),
          content: _content.text.trim(),
          headcount: int.parse(_headcount.text),
          genderPref: _gender,
          cost: int.tryParse(_cost.text) ?? 0,
          relatedActivity: widget.relatedActivity,
        );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.publishedSnack)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44, height: 4,
                    decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(AppStrings.startRecruitment, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(AppStrings.recruitmentEditorSubtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 18),
                _Label(AppStrings.fieldTitle),
                TextFormField(
                  controller: _title,
                  decoration: InputDecoration(hintText: AppStrings.titleHint),
                  validator: (v) => (v == null || v.trim().isEmpty) ? AppStrings.titleRequired : null,
                ),
                const SizedBox(height: 14),
                _Label(AppStrings.fieldContent),
                TextFormField(
                  controller: _content,
                  maxLines: 4,
                  decoration: InputDecoration(hintText: AppStrings.contentHint),
                  validator: (v) => (v == null || v.trim().isEmpty) ? AppStrings.contentRequired : null,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label(AppStrings.headcountField),
                          TextFormField(
                            controller: _headcount,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(suffixText: AppStrings.peopleUnit),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n < 1) return AppStrings.atLeastOnePerson;
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label(AppStrings.costPerPerson),
                          TextFormField(
                            controller: _cost,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(prefixText: 'NT\$ '),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _Label(AppStrings.genderLimit),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final g in GenderPref.values)
                      ChoiceChip(
                        label: Text(AppStrings.genderLabel(g)),
                        selected: _gender == g,
                        onSelected: (_) => setState(() => _gender = g),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _gender == g ? Colors.white : AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: AppColors.soft,
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.campaign),
                    label: Text(AppStrings.publishRecruitment),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    );
  }
}