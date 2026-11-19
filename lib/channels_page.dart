import 'package:flutter/material.dart';
import 'epg.dart';
import 'favorites_store.dart';
import 'iptv_source.dart';
import 'player_page.dart';
import 'recents_store.dart';
import 'settings.dart';
import 'category_prefs.dart';

String _hhmm(DateTime d) {
  final l = d.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// Quita las direcciones del texto del error, porque llevan tu usuario y contraseña.
String _safeError(Object e) =>
    '$e'.replaceAll(RegExp(r'https?://\S+'), '[url]');


class ChannelsPage extends StatefulWidget {
  final IptvSource source;
  final String accountId;
  final String? epgUrl;
  const ChannelsPage({
    super.key,
    required this.source,
    required this.accountId,
    this.epgUrl,
  });

  @override
  State<ChannelsPage> createState() => _ChannelsPageState();
}

class _ChannelsPageState extends State<ChannelsPage> {
  static const _favCat = '__fav__';
  static const _recentCat = '__recent__';

  CategoryPrefs _catPrefs = CategoryPrefs({}, []);

  late Future<void> _load;
  List<Category> _categories = [];
  List<Channel> _channels = [];
  Set<String> _favs = {};
  List<String> _recents = [];
  String? _selectedCat;
  String _search = '';

  Epg? _epg;
  bool _epgLoading = false;
  String? _epgError;

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
    learnPrefixes(_channels.map((c) => c.name));
    _favs = await FavoritesStore.load(widget.accountId);
    _recents = await RecentsStore.load(widget.accountId);
    _startEpg();
    _catPrefs = await CategoryPrefs.load(widget.accountId, 'live');
  }

  String? _epgInfo;

  void _startEpg({bool force = false}) {
    _epgInfo = null;
    final url = widget.epgUrl;
    if (url == null || url.isEmpty) {
      _epgInfo =
          'Guía: sin configurar. Edita la cuenta y pega la URL de la guía.';
      return;
    }
    final ids = {
      for (final c in _channels)
        if (c.epgId != null && c.epgId!.isNotEmpty) c.epgId!,
    };
    final names = {
      for (final c in _channels)
        if (normalizeName(c.name).isNotEmpty) normalizeName(c.name),
    };

    () async {
      if (mounted) {
        setState(() {
          _epgLoading = true;
          _epgError = null;
        });
      }
      try {
        Epg? epg = force ? null : await EpgService.loadCached(widget.accountId);
        epg ??= await EpgService.download(widget.accountId, url, ids, names);
        if (!mounted) return;
        setState(() => _epg = epg);
      } catch (e) {
        if (mounted) setState(() => _epgError = _safeError(e));
      } finally {
        if (mounted) setState(() => _epgLoading = false);
      }
    }();
  }

  String? _epgStatus() {
    if (_epgLoading) {
      return 'Guía: descargando... (la primera vez puede tardar)';
    }
    if (_epgError != null) return 'Guía: error — $_epgError';
    if (_epgInfo != null) return _epgInfo;
    final epg = _epg;
    if (epg == null) return null;
    final matched = _channels.where((c) => epg.hasData(c)).length;
    if (matched == 0) {
      return 'Guía descargada, pero ningún canal coincide con su programación.';
    }
    return 'Guía: $matched de ${_channels.length} canales con programación';
  }

  Future<void> _toggleFav(Channel ch) async {
    setState(() {
      if (!_favs.add(ch.id)) _favs.remove(ch.id);
    });
    await FavoritesStore.save(widget.accountId, _favs);
  }

  Future<void> _markRecent(Channel ch) async {
    _recents.remove(ch.id);
    _recents.insert(0, ch.id);
    if (_recents.length > RecentsStore.maxItems) {
      _recents = _recents.sublist(0, RecentsStore.maxItems);
    }
    await RecentsStore.save(widget.accountId, _recents);
  }

  Future<void> _play(Channel ch, List<Channel> list) async {
    await _markRecent(ch);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          channels: list,
          startIndex: list.indexOf(ch),
          onChannelChanged: _markRecent,
          epgProvider: () => _epg,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _manageCats() async {
    final res = await manageCategories(context, _categories, _catPrefs);
    if (res == null) return;
    await res.save(widget.accountId, 'live');
    if (!mounted) return;
    setState(() {
      _catPrefs = res;
      if (_selectedCat != null && res.hidden.contains(_selectedCat)) {
        _selectedCat = null;
      }
    });
  }



  bool _inSelectedCategory(Channel c) {
    if (_selectedCat == null) return !_catPrefs.hidden.contains(c.categoryId);
    //if (_selectedCat == null) return true;
    if (_selectedCat == _favCat) return _favs.contains(c.id);
    if (_selectedCat == _recentCat) return _recents.contains(c.id);
    return c.categoryId == _selectedCat;
  }

  Widget? _epgSubtitle(Channel ch) {
    final epg = _epg;
    if (epg == null) return null;
    final now = epg.nowOn(ch);
    if (now == null) return null;
    final next = epg.nextOn(ch);
    final text = '${_hhmm(now.start)} ${now.title}'
        '${next != null ? '  ·  Luego ${_hhmm(next.start)} ${next.title}' : ''}';
    return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  Widget _logo(Channel ch) {
    const icon = Icon(Icons.tv);
    final url = ch.logo;
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: url == null
          ? icon
          : Image.network(
              url,
              fit: BoxFit.contain,
              cacheWidth: 88,
              errorBuilder: (_, __, ___) => icon,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Canales en directo'),
        actions: [
          IconButton(
            tooltip: 'Gestionar categorías',
            icon: const Icon(Icons.tune),
            onPressed: _manageCats,
          ),
          if (widget.epgUrl != null) ...[
            if (_epgLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            IconButton(
              tooltip: _epgError ?? 'Actualizar guía',
              icon: const Icon(Icons.refresh),
              onPressed: _epgLoading ? null : () => _startEpg(force: true),
            ),
          ],
        ],
      ),
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
                    for (final cat in _catPrefs.apply(_categories))
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
                    if (_epgStatus() != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _epgStatus()!,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, i) {
                          final ch = visible[i];
                          final isFav = _favs.contains(ch.id);
                          return ListTile(
                            leading: _logo(ch),
                            title: Text(displayName(ch.name)),
                            subtitle: _epgSubtitle(ch),
                            trailing: IconButton(
                              icon: Icon(isFav ? Icons.star : Icons.star_border),
                              onPressed: () => _toggleFav(ch),
                            ),
                            onTap: () => _play(ch, visible),
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