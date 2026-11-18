import 'package:flutter/material.dart';
import 'channels_page.dart';
import 'iptv_source.dart';
import 'movies_page.dart';

class AccountHomePage extends StatefulWidget {
  final IptvSource source;
  final String accountId;
  final String? epgUrl;

  const AccountHomePage({
    super.key,
    required this.source,
    required this.accountId,
    this.epgUrl,
  });

  @override
  State<AccountHomePage> createState() => _AccountHomePageState();
}

class _AccountHomePageState extends State<AccountHomePage> {
  int _index = 0;
  bool _moviesOpened = false;

  @override
  Widget build(BuildContext context) {
    final channels = ChannelsPage(
      source: widget.source,
      accountId: widget.accountId,
      epgUrl: widget.epgUrl,
    );
    if (!widget.source.supportsVod) return channels;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (i) => setState(() {
              _index = i;
              if (i == 1) _moviesOpened = true;
            }),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.live_tv),
                label: Text('En directo'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.movie),
                label: Text('Películas'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                channels,
                _moviesOpened
                    ? MoviesPage(source: widget.source)
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}