import 'package:flutter/material.dart';
import 'favorites_store.dart';
import 'iptv_source.dart';
import 'player_page.dart';
import 'recents_store.dart';

class ChannelsPage extends StatefulWidget {
  final IptvSource source;
  final String accountId;
  const ChannelsPage({
    super.key,
    required this.source,
    required this.accountId,
  });

  @override
  State<ChannelsPage> createState() => _ChannelsPageState();
}

class _ChannelsPageState extends State<ChannelsPage> {
  static const _favCat = '__fav__';
  static const _recentCat = '__recent__';

  late Future<void> _load;
  List<Category> _categories = [];
  List<Channel> _channels = [];
  Set<String> _favs = {};
  List<String> _recents = [];
  String? _selectedCat;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load = _fetch();
  }

  Future<void> _fetch() async {
    final results = await Future.wait([
      widget.source.liveCategories(),
      widget.source.liveStreams(),
    ]);
    _categories = results[0] as List<Category>;
    _channels = results[1] as List<Channel>;
    _favs = await FavoritesStore.load(widget.accountId);
    _recents = await RecentsStore.load(widget.accountId);
  }

  Future<void> _toggleFav(Channel ch) async {
    setState(() {
      if (!_favs.add(ch.id)) _favs.remove(ch.id);
    });
    await FavoritesStore.save(widget.accountId, _favs);
  }

  Future<void> _play(Channel ch) async {
    _recents.remove(ch.id);
    _recents.insert(0, ch.id);
    if (_recents.length > RecentsStore.maxItems) {
      _recents = _recents.sublist(0, RecentsStore.maxItems);
    }
    await RecentsStore.save(widget.accountId, _recents);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerPage(title: ch.name, url: ch.url),
      ),
    );
    if (mounted) setState(() {});
  }

  bool _inSelectedCategory(Channel c) {
    if (_selectedCat == null) return true;
    if (_selectedCat == _favCat) return _favs.contains(c.id);
    if (_selectedCat == _recentCat) return _recents.contains(c.id);
    return c.categoryId == _selectedCat;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Canales en directo')),
      body: FutureBuilder<void>(
        future: _load,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final visible = _channels.where((c) {
            final matches = c.name.toLowerCase().contains(_search.toLowerCase());
            return _inSelectedCategory(c) && matches;
          }).toList();

          if (_selectedCat == _recentCat) {
            visible.sort(
              (a, b) => _recents.indexOf(a.id).compareTo(_recents.indexOf(b.id)),
            );
          }

          return Row(
            children: [
              SizedBox(
                width: 260,
                child: ListView(
                  children: [
                    ListTile(
                      title: const Text('Todos'),
                      selected: _selectedCat == null,
                      onTap: () => setState(() => _selectedCat = null),
                    ),
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('Recientes'),
                      selected: _selectedCat == _recentCat,
                      onTap: () => setState(() => _selectedCat = _recentCat),
                    ),
                    ListTile(
                      leading: const Icon(Icons.star),
                      title: Text('Favoritos (${_favs.length})'),
                      selected: _selectedCat == _favCat,
                      onTap: () => setState(() => _selectedCat = _favCat),
                    ),
                    for (final cat in _categories)
                      ListTile(
                        title: Text(cat.name),
                        selected: _selectedCat == cat.id,
                        onTap: () => setState(() => _selectedCat = cat.id),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Buscar canal',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, i) {
                          final ch = visible[i];
                          final isFav = _favs.contains(ch.id);
                          return ListTile(
                            leading: const Icon(Icons.tv),
                            title: Text(ch.name),
                            trailing: IconButton(
                              icon: Icon(isFav ? Icons.star : Icons.star_border),
                              onPressed: () => _toggleFav(ch),
                            ),
                            onTap: () => _play(ch),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}