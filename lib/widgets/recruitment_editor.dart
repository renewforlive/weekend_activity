import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
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
    _title = TextEditingController(text: a == null ? '' : '一起去「${a.title}」');
    _content = TextEditingController(text: a == null ? '' : '${a.city} · ${a.venue},有興趣的一起來!');
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
      const SnackBar(content: Text('招募已發布!到招募版看看吧 📣')),
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
                const Text('發起招募', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('填寫標題與內容,揪對活動有興趣的人一起!', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 18),
                _Label('標題'),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(hintText: '例如:週末陽明山健行揪團'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '請輸入標題' : null,
                ),
                const SizedBox(height: 14),
                _Label('內容'),
                TextFormField(
                  controller: _content,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: '說明集合時間、路線、注意事項…'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '請輸入內容' : null,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label('招募人數'),
                          TextFormField(
                            controller: _headcount,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(suffixText: '人'),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n < 1) return '至少 1 人';
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
                          _Label('每人花費'),
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
                _Label('性別限制'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final g in GenderPref.values)
                      ChoiceChip(
                        label: Text(g.label),
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
                    label: const Text('發布招募'),
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