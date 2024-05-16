import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/routes/home_page.dart';

class FetchDataPage extends ConsumerStatefulWidget {
  const FetchDataPage({super.key, required this.isSetup});
  final bool isSetup;

  @override
  ConsumerState<FetchDataPage> createState() => _FetchDataPageState();
}

class _FetchDataPageState extends ConsumerState<FetchDataPage> {
  int page = 0;

  @override
  Widget build(BuildContext context) {
    if (page == 0) {
      return FetchDataPage1(
        isSetup: widget.isSetup,
        onNext: () {
          ref.read(cachedDataProgressProvider.notifier).fetchDataFromApi();
          setState(() {
            page = 1;
          });
        },
      );
    } else {
      return FetchDataPage2(
          isSetup: widget.isSetup,
          onFinish: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => const HomePage()));
            }
          });
    }
  }
}

class FetchDataPage1 extends StatelessWidget {
  const FetchDataPage1(
      {super.key, required this.isSetup, required this.onNext});

  final bool isSetup;
  final Function() onNext;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isSetup ? 'Welcome to Stops' : 'Re-fetch cached data',
                style: Theme.of(context).textTheme.displaySmall),
            Text(
                isSetup
                    ? 'Let\'s get started'
                    : 'Press next to re-fetch all latest bus stops and services',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    )),
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next')),
            )
          ],
        ),
      ),
    );
  }
}

class FetchDataPage2 extends ConsumerWidget {
  const FetchDataPage2(
      {super.key, required this.isSetup, required this.onFinish});

  final bool isSetup;
  final Function() onFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(cachedDataProgressProvider).value ?? 0;
    ref.watch(busStopListProvider);
    ref.watch(busServiceListProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                isSetup
                    ? (progress < 1 ? 'Setting up' : 'Set-up finished')
                    : (progress < 1
                        ? 'Re-fetching data'
                        : 'Re-fetching finished'),
                style: Theme.of(context).textTheme.displaySmall),
            const Spacer(),
            LinearProgressIndicator(
              value: progress,
              minHeight: 16.0,
              borderRadius: BorderRadius.circular(16.0),
            ),
            Text('${(progress * 100).toInt()}%'),
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                  onPressed: progress == 1 ? onFinish : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Finish')),
            )
          ],
        ),
      ),
    );
  }
}
