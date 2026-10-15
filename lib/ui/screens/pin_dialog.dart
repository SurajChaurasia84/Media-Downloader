import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/security/pin_service.dart';

class PinScreen extends StatefulWidget {
  final bool isSettingPin;
  final VoidCallback onSuccess;

  const PinScreen({
    super.key,
    this.isSettingPin = false,
    required this.onSuccess,
  });

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final List<String> _digits = [];
  String? _errorMessage;
  bool _isSubmitting = false;

  void _onKeyPress(String digit) {
    if (_isSubmitting || _digits.length >= 4) return;

    HapticFeedback.lightImpact();
    setState(() {
      _digits.add(digit);
      _errorMessage = null;
    });

    if (_digits.length == 4) {
      _submit();
    }
  }

  void _onBackspace() {
    if (_isSubmitting || _digits.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _digits.removeLast();
      _errorMessage = null;
    });
  }

  void _onClear() {
    if (_isSubmitting) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _digits.clear();
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    final pin = _digits.join();
    setState(() => _isSubmitting = true);

    if (widget.isSettingPin) {
      await PinService.setPin(pin);
      HapticFeedback.mediumImpact();
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } else {
      final isValid = await PinService.verifyPin(pin);
      if (isValid) {
        HapticFeedback.mediumImpact();
        if (mounted) {
          Navigator.pop(context);
          widget.onSuccess();
        }
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage = 'Incorrect PIN';
          _digits.clear();
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isSettingPin ? 'Set Security PIN' : 'Security PIN',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),
            // Header Icon with Glow
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                widget.isSettingPin ? Icons.lock_reset_rounded : Icons.lock_outline_rounded,
                size: 36,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.isSettingPin ? 'Create Security PIN' : 'Enter Security PIN',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isSettingPin
                  ? 'Set 4 digits to protect your private downloads'
                  : 'Enter your 4-digit PIN to access private files',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // 4 PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _digits.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: isFilled ? 18 : 16,
                  height: isFilled ? 18 : 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? primaryColor : Colors.transparent,
                    border: Border.all(
                      color: isFilled
                          ? primaryColor
                          : (isDark ? const Color(0xFF3F3F56) : const Color(0xFFD1D5DB)),
                      width: 2,
                    ),
                    boxShadow: isFilled
                        ? [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.4),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),

            // Error Message
            const SizedBox(height: 16),
            SizedBox(
              height: 24,
              child: _errorMessage != null
                  ? Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),

            const Spacer(flex: 2),

            // Numpad Keypad (Full-sized buttons)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                children: [
                  _buildNumpadRow(['1', '2', '3'], isDark),
                  const SizedBox(height: 16),
                  _buildNumpadRow(['4', '5', '6'], isDark),
                  const SizedBox(height: 16),
                  _buildNumpadRow(['7', '8', '9'], isDark),
                  const SizedBox(height: 16),
                  _buildNumpadRow(['C', '0', '⌫'], isDark),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpadRow(List<String> keys, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKey(key, isDark)).toList(),
    );
  }

  Widget _buildKey(String key, bool isDark) {
    final isAction = key == 'C' || key == '⌫';
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (key == 'C') {
            _onClear();
          } else if (key == '⌫') {
            _onBackspace();
          } else {
            _onKeyPress(key);
          }
        },
        borderRadius: BorderRadius.circular(36),
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.2),
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        child: Ink(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isAction
                ? Colors.transparent
                : (isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF3F4F6)),
            border: isAction
                ? null
                : Border.all(
                    color: isDark ? const Color(0xFF2E2E42) : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
          ),
          child: Center(
            child: isAction
                ? (key == '⌫'
                    ? Icon(
                        Icons.backspace_outlined,
                        size: 24,
                        color: theme.colorScheme.onSurface,
                      )
                    : Text(
                        'C',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ))
                : Text(
                    key,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// Backwards compatibility alias
typedef PinDialog = PinScreen;
