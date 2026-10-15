import 'package:flutter/material.dart';
import '../../core/security/pin_service.dart';

class PinDialog extends StatefulWidget {
  final bool isSettingPin;
  final VoidCallback onSuccess;

  const PinDialog({
    super.key,
    this.isSettingPin = false,
    required this.onSuccess,
  });

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorMessage;

  void _onKeyPress(String digit) {
    if (_controller.text.length < 6) {
      setState(() {
        _controller.text += digit;
        _errorMessage = null;
      });
      if (_controller.text.length >= 4) {
        // can submit or submit on 4 if standard
      }
    }
  }

  void _onBackspace() {
    if (_controller.text.isNotEmpty) {
      setState(() {
        _controller.text = _controller.text.substring(0, _controller.text.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _submit() async {
    final pin = _controller.text.trim();
    if (pin.length < 4) {
      setState(() => _errorMessage = 'Enter 4-6 digits');
      return;
    }

    if (widget.isSettingPin) {
      await PinService.setPin(pin);
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } else {
      final isValid = await PinService.verifyPin(pin);
      if (isValid) {
        if (mounted) {
          Navigator.pop(context);
          widget.onSuccess();
        }
      } else {
        setState(() {
          _errorMessage = 'Incorrect PIN';
          _controller.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF161622) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.isSettingPin ? Icons.lock_reset : Icons.lock_outline,
              size: 32,
              color: const Color(0xFF7925F6),
            ),
            const SizedBox(height: 12),
            Text(
              widget.isSettingPin ? 'Set Vault PIN' : 'Enter PIN',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            // Pin indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _controller.text.length
                        ? const Color(0xFF7925F6)
                        : (isDark ? const Color(0xFF26263A) : const Color(0xFFE5E7EB)),
                  ),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            // Num pad
            for (var row in [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['C', '0', '⌫']
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: row.map((key) {
                    return SizedBox(
                      width: 60,
                      height: 48,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: isDark
                              ? const Color(0xFF1D1D2D)
                              : const Color(0xFFF3F4F6),
                        ),
                        onPressed: () {
                          if (key == 'C') {
                            setState(() => _controller.clear());
                          } else if (key == '⌫') {
                            _onBackspace();
                          } else {
                            _onKeyPress(key);
                          }
                        },
                        child: Text(
                          key,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7925F6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _submit,
                child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
