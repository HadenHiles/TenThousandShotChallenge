import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/services/AccountSwitcherService.dart';

// ── Entry point ────────────────────────────────────────────────────────────

/// Shows the Instagram-style account switcher as a modal bottom sheet.
/// Triggered by long-pressing or double-tapping the "Me" bottom nav tab.
void showAccountSwitcherSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AccountSwitcherSheet(),
  );
}

// ── Sheet widget ──────────────────────────────────────────────────────────

class _AccountSwitcherSheet extends StatefulWidget {
  const _AccountSwitcherSheet();

  @override
  State<_AccountSwitcherSheet> createState() => _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends State<_AccountSwitcherSheet> {
  List<SavedAccount>? _accounts;
  String? _switchingToUid;
  bool _preparingAddAccount = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await AccountSwitcherService.loadAccounts();
    if (mounted) setState(() => _accounts = accounts);
  }

  Future<void> _onAccountTap(SavedAccount account) async {
    final currentUid = Provider.of<FirebaseAuth>(context, listen: false).currentUser?.uid;
    if (account.uid == currentUid) {
      // Already on this account.
      Navigator.of(context).pop();
      return;
    }

    // All providers go through _performSwitch; email accounts will try
    // cached credentials first and only show a dialog if needed.
    await _performSwitch(account);
  }

  Future<void> _performSwitch(SavedAccount account, {String? password}) async {
    if (!mounted) return;
    setState(() {
      _switchingToUid = account.uid;
      _errorMessage = null;
    });

    final result = await AccountSwitcherService.switchToAccount(
      account,
      emailPassword: password,
    );

    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pop();
      return;
    }

    if (result.userCancelled) {
      setState(() => _switchingToUid = null);
      return;
    }

    if (result.needsPassword) {
      // No cached credentials yet (or they went stale) – ask for the password.
      setState(() => _switchingToUid = null);
      _showEmailPasswordDialog(account);
      return;
    }

    setState(() {
      _switchingToUid = null;
      _errorMessage = result.errorMessage;
    });
  }

  void _showEmailPasswordDialog(SavedAccount account) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Enter password',
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 20,
            color: Theme.of(ctx).colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account.email ?? '',
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                Navigator.of(ctx).pop();
                _performSwitch(account, password: controller.text);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).primaryColor,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _performSwitch(account, password: controller.text);
            },
            child: const Text(
              'Switch',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onAddAccount() async {
    if (!mounted) return;
    setState(() => _preparingAddAccount = true);
    Navigator.of(context).pop();
    await AccountSwitcherService.prepareAddAccount();
    // Auth state change will trigger the router to navigate to /login
    // automatically via AuthChangeNotifier.
  }

  Future<void> _onRemoveAccount(SavedAccount account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove account?'),
        content: Text(
          'Remove ${account.displayName ?? account.email ?? 'this account'} from the switcher? You will need to log back in to access it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).primaryColor,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await AccountSwitcherService.removeAccount(account.uid);
    await _loadAccounts();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUid = Provider.of<FirebaseAuth>(context, listen: false).currentUser?.uid;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ─────────────────────────────────────────────
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'SWITCH ACCOUNT',
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Error banner ─────────────────────────────────────────────
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.primaryColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: theme.primaryColor, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 4),

            // ── Account list ─────────────────────────────────────────────
            if (_accounts == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(),
              )
            else if (_accounts!.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                child: Text(
                  'No saved accounts.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _accounts!.length,
                itemBuilder: (context, i) {
                  final account = _accounts![i];
                  final isActive = account.uid == currentUid;
                  final isSwitching = _switchingToUid == account.uid;
                  // Apple Sign-In is unavailable on non-Apple platforms.
                  final isUnavailable = account.authProvider == 'apple' && !Platform.isIOS && !Platform.isMacOS;
                  return _AccountRow(
                    account: account,
                    isActive: isActive,
                    isSwitching: isSwitching,
                    isUnavailable: isUnavailable,
                    onTap: (_switchingToUid != null || isUnavailable) ? null : () => _onAccountTap(account),
                    onRemove: isActive ? null : () => _onRemoveAccount(account),
                  );
                },
              ),

            // ── Divider & Add account ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            ListTile(
              enabled: _switchingToUid == null && !_preparingAddAccount,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.add,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  size: 22,
                ),
              ),
              title: Text(
                'Add account',
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 17,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              onTap: _onAddAccount,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Individual account row ─────────────────────────────────────────────────

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.isActive,
    required this.isSwitching,
    required this.isUnavailable,
    required this.onTap,
    required this.onRemove,
  });

  final SavedAccount account;
  final bool isActive;
  final bool isSwitching;
  final bool isUnavailable;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryName = account.displayName?.trim().isNotEmpty == true ? account.displayName! : (account.email ?? 'Unknown');
    final String? subtitle = isUnavailable ? 'Apple Sign-In is not available on this device' : (account.displayName?.trim().isNotEmpty == true ? account.email : null);

    return Opacity(
      opacity: isUnavailable ? 0.45 : 1.0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        onTap: onTap,
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            _AccountAvatar(photoUrl: account.photoUrl, displayName: primaryName),
            if (isActive)
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xff4CAF50),
                    border: Border.all(color: theme.colorScheme.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          primaryName,
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 17,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            color: theme.colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: isSwitching
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                ),
              )
            : isActive
                ? Icon(Icons.check_rounded, color: theme.primaryColor, size: 22)
                : onRemove != null
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                          size: 18,
                        ),
                        onPressed: onRemove,
                        splashRadius: 18,
                      )
                    : null,
      ),
    );
  }
}

// ── Avatar with fallback ───────────────────────────────────────────────────

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({this.photoUrl, required this.displayName});

  final String? photoUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.contains('http')) {
      return CircleAvatar(
        radius: 23,
        backgroundImage: NetworkImage(photoUrl!),
        backgroundColor: Colors.transparent,
      );
    }
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 23,
        backgroundImage: AssetImage(photoUrl!),
        backgroundColor: Colors.transparent,
      );
    }
    // Initials fallback
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 23,
      backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.8),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'NovecentoSans',
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
