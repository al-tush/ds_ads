import 'dart:async';

import 'package:flutter/material.dart';

class DSAdsOverlayScreen extends StatefulWidget {
  const DSAdsOverlayScreen({
    super.key,
    required this.counterDoneCallback,
    required this.delaySec,
  });

  final void Function() counterDoneCallback;
  final int delaySec;

  @override
  State<DSAdsOverlayScreen> createState() => _DSAdsOverlayScreenState();
}

class _DSAdsOverlayScreenState extends State<DSAdsOverlayScreen> {
  late var _counter = widget.delaySec;

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 1), (timer) {
      _counter--;
      if (_counter < 1) {
        // One second delay to show ad
        timer.cancel();
        Navigator.of(context).pop();
        return;
      }
      if (_counter == 1) {
        widget.counterDoneCallback();
      }
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.3),
      body: PopScope(
        canPop: false,
        child: Container(
          constraints: const BoxConstraints.expand(),
          color: const Color(0x99000000),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ad in', // ToDo: localize?
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '$_counter',
                  style: const TextStyle(
                    fontSize: 64,
                    color: Colors.white,
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
