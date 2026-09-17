import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/user_management_provider.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  // Available sections dictionary
  static const Map<String, ({String label, IconData icon, Color color})> availableSections = {
    'dashboard': (
      label: 'Dashboard',
      icon: Icons.dashboard_rounded,
      color: Color(0xFF3B82F6),
    ),
    'pantry': (
      label: 'My Pantry',
      icon: Icons.inventory_2_rounded,
      color: Color(0xFF10B981),
    ),
    'expenses': (
      label: 'Expense Detail',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFFF59E0B),
    ),
    'reports': (
      label: 'Saved PDF Reports',
      icon: Icons.picture_as_pdf_rounded,
      color: Color(0xFFE11D48),
    ),
    'shopping_list': (
      label: 'Shopping List',
      icon: Icons.shopping_cart_rounded,
      color: Color(0xFF8B5CF6),
    ),
  };

  void _openCreateOrEditDialog({UserModel? existingUser}) {
    final isEditing = existingUser != null;
    final nameController = TextEditingController(text: existingUser?.name ?? '');
    final emailController = TextEditingController(text: existingUser?.email ?? '');
    final passwordController = TextEditingController();
    String role = existingUser?.role ?? 'user';
    String accessMode = existingUser?.accessMode ?? 'view_only';
    String shiftType = existingUser?.shiftType ?? 'all_day';
    String shiftStartTime = existingUser?.shiftStartTime ?? (shiftType == 'morning' ? '06:00' : '16:00');
    String shiftEndTime = existingUser?.shiftEndTime ?? (shiftType == 'morning' ? '16:00' : '23:59');
    final selectedSections = Set<String>.from(
      existingUser?.allowedSections ?? ['shopping_list'],
    );
    bool obscurePassword = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          actionsPadding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEditing ? Icons.manage_accounts_rounded : Icons.person_add_alt_1_rounded,
                  color: AppColors.primaryDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Edit User & Permissions' : 'Create New User ID & Access',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEditing
                          ? 'Update sections this user is allowed to access'
                          : 'Set custom credentials and section visibility',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(ctx).size.height * 0.76,
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),

                  // Name Field
                  const Text(
                    'Staff / User Name *',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'e.g. Grocery Helper / Ali',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceMuted,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // User ID / Email Field
                  const Text(
                    'User ID / Email / Username *',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: emailController,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'e.g. user_grocery1 or staff@pantry.com',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.account_circle_outlined, size: 20, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceMuted,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Password Field
                  Text(
                    isEditing ? 'New Password (Optional)' : 'Password *',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: isEditing ? 'Enter new password (optional)' : 'Enter access password',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.textSecondary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceMuted,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  if (isEditing) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Leave blank to keep existing password',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Role selector
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 18, color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Text(
                              'Account Type (Role):',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            style: SegmentedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              selectedBackgroundColor: AppColors.primaryLight,
                              selectedForegroundColor: AppColors.primaryDark,
                            ),
                            segments: const [
                              ButtonSegment(
                                value: 'user',
                                label: Text('Restricted User', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                icon: Icon(Icons.person_outline, size: 16),
                              ),
                              ButtonSegment(
                                value: 'admin',
                                label: Text('Admin (All)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                icon: Icon(Icons.admin_panel_settings_outlined, size: 16),
                              ),
                            ],
                            selected: {role},
                            onSelectionChanged: (newSelection) {
                              setDialogState(() {
                                role = newSelection.first;
                                if (role == 'admin') {
                                  selectedSections.addAll(availableSections.keys);
                                  accessMode = 'can_edit';
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (role != 'admin') ...[
                    const SizedBox(height: 14),

                    // Access Mode Selector (Just View vs Can Edit)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accessMode == 'view_only'
                            ? const Color(0xFFFFFBEB)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accessMode == 'view_only'
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                accessMode == 'view_only'
                                    ? Icons.visibility_rounded
                                    : Icons.edit_note_rounded,
                                size: 18,
                                color: accessMode == 'view_only'
                                    ? const Color(0xFFB45309)
                                    : const Color(0xFF047857),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Access Permission (Access Mode):',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Option 1: Just View
                          _buildAccessOptionCard(
                            title: 'Just View (Sirf Dekh Saky)',
                            subtitle: 'User shopping list & pantry sirf dekh saky ga. Koi item add, edit, delete nahi kar sake ga.',
                            icon: Icons.visibility_rounded,
                            isSelected: accessMode == 'view_only',
                            activeColor: const Color(0xFFB45309),
                            activeBg: const Color(0xFFFEF3C7),
                            onTap: () => setDialogState(() => accessMode = 'view_only'),
                          ),
                          const SizedBox(height: 6),
                          // Option 2: Can Edit
                          _buildAccessOptionCard(
                            title: 'Can Edit (Full Access)',
                            subtitle: 'User items add, edit, delete aur shopping checks toggle kar saky ga.',
                            icon: Icons.edit_rounded,
                            isSelected: accessMode == 'can_edit',
                            activeColor: const Color(0xFF15803D),
                            activeBg: const Color(0xFFDCFCE7),
                            onTap: () => setDialogState(() => accessMode = 'can_edit'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Expense Detail Sheet Shift Timing Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.schedule_rounded, size: 17, color: Color(0xFF4F46E5)),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Expense Sheet Shift Access (Timing):',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'User is shift ke waqt expense sheet me data enter kar sake ga',
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildShiftChip(
                                label: '☀️ Morning Shift',
                                isSelected: shiftType == 'morning',
                                color: const Color(0xFFD97706),
                                bg: const Color(0xFFFEF3C7),
                                onTap: () => setDialogState(() {
                                  shiftType = 'morning';
                                  shiftStartTime = '06:00';
                                  shiftEndTime = '16:00';
                                }),
                              ),
                              _buildShiftChip(
                                label: '🌙 Evening Shift',
                                isSelected: shiftType == 'evening',
                                color: const Color(0xFF4338CA),
                                bg: const Color(0xFFEEF2FF),
                                onTap: () => setDialogState(() {
                                  shiftType = 'evening';
                                  shiftStartTime = '16:00';
                                  shiftEndTime = '23:59';
                                }),
                              ),
                              _buildShiftChip(
                                label: '⏰ Custom Hours',
                                isSelected: shiftType == 'custom',
                                color: const Color(0xFF0D9488),
                                bg: const Color(0xFFCCFBF1),
                                onTap: () => setDialogState(() {
                                  shiftType = 'custom';
                                  if (shiftStartTime.isEmpty) shiftStartTime = '17:00';
                                  if (shiftEndTime.isEmpty) shiftEndTime = '22:00';
                                }),
                              ),
                              _buildShiftChip(
                                label: '🔄 24h Any Time',
                                isSelected: shiftType == 'all_day',
                                color: const Color(0xFF475569),
                                bg: const Color(0xFFF1F5F9),
                                onTap: () => setDialogState(() {
                                  shiftType = 'all_day';
                                }),
                              ),
                            ],
                          ),

                          if (shiftType != 'all_day') ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Text(
                                    'Allowed Window:',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(width: 8),
                                  // Start Time Chip
                                  InkWell(
                                    onTap: () async {
                                      final picked = await _pickTime(ctx, shiftStartTime);
                                      if (picked != null) {
                                        setDialogState(() => shiftStartTime = picked);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.login_rounded, size: 12, color: Color(0xFF047857)),
                                          const SizedBox(width: 4),
                                          Text(
                                            UserModel.formatTimeDisplay(shiftStartTime),
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                                          ),
                                          const SizedBox(width: 2),
                                          const Icon(Icons.arrow_drop_down, size: 14, color: AppColors.textSecondary),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6),
                                    child: Text('to', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  ),
                                  // End Time Chip
                                  InkWell(
                                    onTap: () async {
                                      final picked = await _pickTime(ctx, shiftEndTime);
                                      if (picked != null) {
                                        setDialogState(() => shiftEndTime = picked);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.logout_rounded, size: 12, color: Color(0xFFB91C1C)),
                                          const SizedBox(width: 4),
                                          Text(
                                            UserModel.formatTimeDisplay(shiftEndTime),
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C)),
                                          ),
                                          const SizedBox(width: 2),
                                          const Icon(Icons.arrow_drop_down, size: 14, color: AppColors.textSecondary),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Allowed Sections Header & Quick Buttons
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      const Text(
                        'Allowed App Sections:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () {
                              setDialogState(() {
                                selectedSections.clear();
                                selectedSections.add('shopping_list');
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.shopping_cart_outlined, size: 12, color: Color(0xFF8B5CF6)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Shopping Only',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              setDialogState(() {
                                selectedSections.clear();
                                selectedSections.addAll(availableSections.keys);
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.select_all_rounded, size: 12, color: AppColors.primaryDark),
                                  SizedBox(width: 4),
                                  Text(
                                    'Select All',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Jab ya user login kary ga, to bus wahi sections show hon gy jinko aap select karen gy.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Section Selection Checkbox Cards
                  ...availableSections.entries.map((entry) {
                    final isChecked = selectedSections.contains(entry.key);
                    final sec = entry.value;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isChecked ? sec.color.withValues(alpha: 0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isChecked ? sec.color.withValues(alpha: 0.4) : AppColors.borderLight,
                          width: isChecked ? 1.5 : 1,
                        ),
                      ),
                      child: CheckboxListTile(
                        value: isChecked,
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        activeColor: sec.color,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        title: Row(
                          children: [
                            Icon(sec.icon, size: 18, color: sec.color),
                            const SizedBox(width: 8),
                            Text(
                              sec.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                                color: isChecked ? AppColors.textPrimary : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        onChanged: role == 'admin'
                            ? null
                            : (val) {
                                setDialogState(() {
                                  if (val == true) {
                                    selectedSections.add(entry.key);
                                  } else {
                                    if (selectedSections.length > 1) {
                                      selectedSections.remove(entry.key);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('At least one section must be granted!'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                  }
                                });
                              },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final email = emailController.text.trim();
                      final password = passwordController.text.trim();

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a user name')),
                        );
                        return;
                      }
                      if (email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter User ID or Email')),
                        );
                        return;
                      }
                      if (!isEditing && password.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a password')),
                        );
                        return;
                      }
                      if (selectedSections.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select at least 1 allowed section')),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      try {
                        if (isEditing) {
                          await ref.read(usersListProvider.notifier).updateUser(
                                existingUser.id!,
                                name: name,
                                email: email,
                                password: password.isNotEmpty ? password : null,
                                role: role,
                                allowedSections: selectedSections.toList(),
                                accessMode: role == 'admin' ? 'can_edit' : accessMode,
                                shiftType: role == 'admin' ? 'all_day' : shiftType,
                                shiftStartTime: (role != 'admin' && shiftType != 'all_day') ? shiftStartTime : null,
                                shiftEndTime: (role != 'admin' && shiftType != 'all_day') ? shiftEndTime : null,
                              );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('User permissions updated successfully!')),
                            );
                          }
                        } else {
                          await ref.read(usersListProvider.notifier).createUser(
                                name: name,
                                email: email,
                                password: password,
                                role: role,
                                allowedSections: selectedSections.toList(),
                                accessMode: role == 'admin' ? 'can_edit' : accessMode,
                                shiftType: role == 'admin' ? 'all_day' : shiftType,
                                shiftStartTime: (role != 'admin' && shiftType != 'all_day') ? shiftStartTime : null,
                                shiftEndTime: (role != 'admin' && shiftType != 'all_day') ? shiftEndTime : null,
                              );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('New User created successfully!')),
                            );
                          }
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isEditing ? 'Save Changes' : 'Create User'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteUser(UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Text('Delete User'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${user.name}" (${user.email})? This user will no longer be able to log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(usersListProvider.notifier).deleteUser(user.id!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete user: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required Color activeBg,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? activeColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? activeColor : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 15, color: isSelected ? activeColor : AppColors.textSecondary),
                        const SizedBox(width: 5),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? activeColor : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isSelected ? activeColor.withValues(alpha: 0.9) : AppColors.textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _pickTime(BuildContext context, String currentHhmm) async {
    final parts = currentHhmm.split(':');
    final initialH = int.tryParse(parts[0]) ?? 12;
    final initialM = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialH, minute: initialM),
    );
    if (picked != null) {
      final hStr = picked.hour.toString().padLeft(2, '0');
      final mStr = picked.minute.toString().padLeft(2, '0');
      return '$hStr:$mStr';
    }
    return null;
  }

  Widget _buildShiftChip({
    required String label,
    required bool isSelected,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? bg : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? color : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersListProvider);
    final currentUserAsync = ref.watch(authControllerProvider);
    final currentUser = currentUserAsync.valueOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'User Management & Permissions',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.read(usersListProvider.notifier).fetchUsers(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'New User ID & Access',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        onPressed: () => _openCreateOrEditDialog(),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width < 600 ? 12 : 24,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informational Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryDark.withValues(alpha: 0.95),
                    AppColors.primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Access Control & Custom Accounts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Yahan sy aap new User ID or Password bana kar specific section ki access de sakty hain. '
                          'User ko sirf wahi section show hoga jiska permission aap select karen gy (jaise Shopping List).',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section Title
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Created Users & Section Access',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openCreateOrEditDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Users List
            usersAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(48.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Failed to load users: $err',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.read(usersListProvider.notifier).fetchUsers(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (users) {
                if (users.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.group_outlined,
                          size: 56,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'No Additional Users Created Yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Click the "+ Add User" button above to generate a User ID & Password with custom section access.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final user = users[i];
                    final isCurrent = user.id == currentUser?.id;
                    final isAdmin = user.isAdmin;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: LayoutBuilder(
                        builder: (context, cardConstraints) {
                          final isCompact = cardConstraints.maxWidth < 600;

                          final avatar = CircleAvatar(
                            radius: 20,
                            backgroundColor: isAdmin
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                            child: Icon(
                              isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                              color: isAdmin ? AppColors.primaryDark : const Color(0xFF8B5CF6),
                              size: 22,
                            ),
                          );

                          final badges = Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isAdmin
                                      ? AppColors.primaryLight
                                      : AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isAdmin
                                        ? AppColors.primary.withValues(alpha: 0.3)
                                        : AppColors.border,
                                  ),
                                ),
                                child: Text(
                                  isAdmin ? 'ADMIN' : 'RESTRICTED USER',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isAdmin
                                        ? AppColors.primaryDark
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (!isAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: user.accessMode == 'can_edit'
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: user.accessMode == 'can_edit'
                                          ? const Color(0xFF86EFAC)
                                          : const Color(0xFFFCD34D),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        user.accessMode == 'can_edit'
                                            ? Icons.edit_note_rounded
                                            : Icons.visibility_rounded,
                                        size: 11,
                                        color: user.accessMode == 'can_edit'
                                            ? const Color(0xFF15803D)
                                            : const Color(0xFFB45309),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        user.accessMode == 'can_edit'
                                            ? 'Can Edit'
                                            : 'Just View (Sirf Dekh Saky)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: user.accessMode == 'can_edit'
                                              ? const Color(0xFF15803D)
                                              : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (!isAdmin && user.isShiftRestricted)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: user.shiftType == 'morning'
                                        ? const Color(0xFFFEF3C7)
                                        : const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: user.shiftType == 'morning'
                                          ? const Color(0xFFFCD34D)
                                          : const Color(0xFFC7D2FE),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        user.shiftType == 'morning'
                                            ? Icons.wb_sunny_rounded
                                            : Icons.nightlight_round,
                                        size: 11,
                                        color: user.shiftType == 'morning'
                                            ? const Color(0xFFB45309)
                                            : const Color(0xFF4338CA),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        user.shiftDisplayLabel,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: user.shiftType == 'morning'
                                              ? const Color(0xFFB45309)
                                              : const Color(0xFF4338CA),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (isCurrent)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'You',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                            ],
                          );

                          final actions = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_note_rounded, color: AppColors.primaryDark),
                                tooltip: 'Edit permissions',
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                                onPressed: () => _openCreateOrEditDialog(existingUser: user),
                              ),
                              if (!isCurrent) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                  tooltip: 'Delete user',
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _confirmDeleteUser(user),
                                ),
                              ],
                            ],
                          );

                          final allowedChips = Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: user.allowedSections.map((secKey) {
                              final sec = availableSections[secKey];
                              if (sec == null) return const SizedBox.shrink();
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: sec.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: sec.color.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(sec.icon, size: 14, color: sec.color),
                                    const SizedBox(width: 4),
                                    Text(
                                      sec.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: sec.color,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );

                          if (isCompact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    avatar,
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.name,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'ID / Email: ${user.email}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions,
                                  ],
                                ),
                                const SizedBox(height: 8),
                                badges,
                                const SizedBox(height: 10),
                                const Divider(height: 1, color: AppColors.borderLight),
                                const SizedBox(height: 8),
                                Text(
                                  'Accessible Sections (${user.allowedSections.length}):',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                allowedChips,
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  avatar,
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              user.name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            badges,
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'ID / Email: ${user.email}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  actions,
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1, color: AppColors.borderLight),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Accessible Sections (${user.allowedSections.length}):',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: allowedChips),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
