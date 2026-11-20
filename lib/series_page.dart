import 'package:material_ui/material_ui.dart';
import 'category_prefs.dart';
import 'favorites_store.dart';
import 'iptv_source.dart';
import 'player_page.dart';
import 'tmdb.dart';

class SeriesPage extends StatefulWidget {
  final IptvSource source;
  final String accountId;
  const SeriesPage({super.key, required this.source, required this.accountId});

  @override
  State<SeriesPage> createState() => _SeriesPageState();
}

class _SeriesPageState extends State<SeriesPage> {
  static const _favCat = '__fav__';

  late final Future<void> _load = _fetch();
  List<Category> _cats = [];
  List<Series> _items = [];
  Set<String> _favs = {};
  CategoryPrefs _catPrefs = CategoryPrefs({}, []);
  String? _cat;
  String _q = '';

  Future<void> _fetch() async {
    final r = await Future.wait([
      widget.source.seriesCategories(),
      widget.source.seriesList(),
    ]);
    _cats = r[0] as List<Category>;
    final l = r[1] as List<Series>;
    l.sort((a, b) => (b.added ?? 0).compareTo(a.added ?? 0));
    _items = l;
    _favs = await FavoritesStore.load(widget.accountId);
    _catPrefs = await CategoryPrefs.load(widget.accountId, 'series');
  }

  Future<void> _manageCats() async {
    final res = await manageCategories(context, _cats, _catPrefs);
    if (res == null) return;
    await res.save(widget.accountId, 'series');
    if (!mounted) return;
    setState(() {
      _catPrefs = res;
      if (_cat != null && res.hidden.contains(_cat)) _cat = null;
    });
  }

  Future<void> _toggleFav(Series s) async {
    final favs = await FavoritesStore.toggle(widget.accountId, 's${s.id}');
    if (mounted) setState(() => _favs = favs);
  }

  Widget _cover(String? url) {
    const placeholder = Center(child: Icon(Icons.tv, size: 40));
    if (url == null) return placeholder;
    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: 300,
      errorBuilder: (context, error, stack) => placeholder,
    );
  }

  void _play(Series s, List<Episode> eps, int i) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          channels: [
            for (final e in eps)
              Channel(
                'e${e.id}',
                '${s.name} · T${e.season}E${e.number} ${e.title}',
                s.id,
                e.url,
              ),
          ],
          startIndex: i,
          accountId: widget.accountId,
        ),
      ),
    );
  }

  // Lista de temporadas y episodios dentro del cuadro de una serie.
  Widget _episodesView(BuildContext ctx, Series s, List<Episode> eps, TmdbInfo? tmdb) {
    eps.sort((a, b) {
      final c = a.season.compareTo(b.season);
      return c != 0 ? c : a.number.compareTo(b.number);
    });
    final seasons = eps.map((e) => e.season).toSet().toList()..sort();

    return ListView(
      children: [
        if (tmdb != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TmdbBlock(tmdb),
          )
        else if (s.plot != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(s.plot!, maxLines: 4, overflow: TextOverflow.ellipsis),
          ),
      ],
    );
  }

  Future<(List<Episode>, TmdbInfo?)> _loadSeries(Series s) async {
    final tf = Tmdb.lookup('tv', s.name);
    final eps = await widget.source.episodes(s);
    return (eps, await tf);
  }

  void _open(Series s) {
    final future = _loadSeries(s);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.name),
        content: SizedBox(
          width: 680,
          height: 420,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 160,
                height: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _cover(s.cover),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FutureBuilder<(List<Episode>, TmdbInfo?)>(
                  future: future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final eps = snap.data?.$1;
                    if (snap.hasError || eps == null || eps.isEmpty) {
                      return const Text('No hay episodios disponibles.');
                    }
                    return _episodesView(ctx, s, eps, snap.data?.$2);
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }  

  Widget _sidebar() {
    final favCount = _favs.where((k) => k.startsWith('s')).length;
    return SizedBox(
      width: 260,
      child: ListView(
        children: [
          ListTile(
            title: const Text('Todas'),
            selected: _cat == null,
            onTap: () => setState(() => _cat = null),
          ),
          ListTile(
            leading: const Icon(Icons.star),
            title: Text('Favoritas ($favCount)'),
            selected: _cat == _favCat,
            onTap: () => setState(() => _cat = _favCat),
          ),
          for (final c in _catPrefs.apply(_cats))
            ListTile(
              title: Text(c.name),
              selected: _cat == c.id,
              onTap: () => setState(() => _cat = c.id),
            ),
        ],
      ),
    );
  }

  // Un cartel con su estrella de favorita y su título.
  Widget _tile(Series s) {
    final fav = _favs.contains('s${s.id}');
    return InkWell(
      onTap: () => _open(s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _cover(s.cover),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: IconButton(
                      iconSize: 20,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                      icon: Icon(
                        fav ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                      onPressed: () => _toggleFav(s),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _grid(List<Series> visible) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        childAspectRatio: 0.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: visible.length,
      itemBuilder: (context, i) => _tile(visible[i]),
    );
  }

  Widget _content() {
    final q = _q.toLowerCase();
    final visible = _items.where((s) {
      final inCat = _cat == null
          ? !_catPrefs.hidden.contains(s.categoryId)
          : _cat == _favCat
              ? _favs.contains('s${s.id}')
              : s.categoryId == _cat;
      return inCat && s.name.toLowerCase().contains(q);
    }).toList();

    return Row(
      children: [
        _sidebar(),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar serie',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
              Expanded(child: _grid(visible)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Series'),
        actions: [
          IconButton(
            tooltip: 'Gestionar categorías',
            icon: const Icon(Icons.tune),
            onPressed: _manageCats,
          ),
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
          if (_items.isEmpty) {
            return const Center(child: Text('Esta cuenta no tiene series.'));
          }
          return _content();
        },
      ),
    );
  }
}