import 'package:flutter/material.dart';
import 'channels_page.dart';
import 'iptv_source.dart';
import 'movies_page.dart';
import 'series_page.dart';
import 'continue_page.dart';

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
  bool _seriesOpened = false;

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
              if (i == 2) _seriesOpened = true;
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
              NavigationRailDestination(
                icon: Icon(Icons.tv),
                label: Text('Series'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history),
                label: Text('Continuar'),
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
                    ? MoviesPage(source: widget.source, accountId: widget.accountId)
                    : const SizedBox.shrink(),
                _seriesOpened
                    ? SeriesPage(source: widget.source, accountId: widget.accountId)
                    : const SizedBox.shrink(),
                _index == 3
                    ? ContinuePage(accountId: widget.accountId)
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}