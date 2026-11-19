import 'package:material_ui/material_ui.dart';
import 'iptv_source.dart';
import 'player_page.dart';
import 'category_prefs.dart';

class SeriesPage extends StatefulWidget {
  final IptvSource source;
  final String accountId;
  const SeriesPage({super.key, required this.source,required this.accountId});
  
  

  @override
  State<SeriesPage> createState() => _SeriesPageState();
}

class _SeriesPageState extends State<SeriesPage> {
  late final Future<void> _load = _fetch();
  List<Category> _cats = [];
  List<Series> _items = [];
  String? _cat;
  String _q = '';
  CategoryPrefs _catPrefs = CategoryPrefs({}, []);

  Future<void> _fetch() async {
    final r = await Future.wait([
      widget.source.seriesCategories(),
      widget.source.seriesList(),
    ]);
    _cats = r[0] as List<Category>;
    final l = r[1] as List<Series>;
    l.sort((a, b) => (b.added ?? 0).compareTo(a.added ?? 0));
    _items = l;
    _catPrefs = await CategoryPrefs.load(widget.accountId, 'series');
  }

  Future<void> _manageCats() async {
    final res = await manageCategories(context, _cats, _catPrefs);
    if (res == null) return;
    await res.save(widget.accountId, 'series');
    if (!mounted) return;
    setState(() {
      _catPrefs = res;
      if (_cat != null && res.hidden.contains(_cat)) {
        _cat = null;
      }
    });
  }

  Widget _cover(String? url) {
    const ph = Center(child: Icon(Icons.tv, size: 40));
    if (url == null) return ph;
    return Image.network(url,
        fit: BoxFit.cover, cacheWidth: 300, errorBuilder: (_, _, _) => ph);
  }

  void _play(Series s, List<Episode> eps, int i) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerPage(
        channels: [
          for (final e in eps)
            Channel(e.id, '${s.name} · T${e.season}E${e.number} ${e.title}',
                s.id, e.url),
        ],
        startIndex: i,
      ),
    ));
  }

  void _open(Series s) {
    final f = widget.source.episodes(s);
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
                child: FutureBuilder<List<Episode>>(
                  future: f,
                  builder: (_, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final eps = snap.data;
                    if (snap.hasError || eps == null || eps.isEmpty) {
                      return const Text('No hay episodios disponibles.');
                    }
                    eps.sort((a, b) {
                      final c = a.season.compareTo(b.season);
                      return c != 0 ? c : a.number.compareTo(b.number);
                    });
                    final seasons = eps.map((e) => e.season).toSet().toList()
                      ..sort();
                    return ListView(
                      children: [
                        if (s.plot != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(s.plot!,
                                maxLines: 4, overflow: TextOverflow.ellipsis),
                          ),
                        for (final n in seasons)
                          ExpansionTile(
                            title: Text('Temporada $n'),
                            initiallyExpanded: seasons.length == 1,
                            children: [
                              for (final e in eps.where((e) => e.season == n))
                                ListTile(
                                  dense: true,
                                  leading: Text('${e.number}'),
                                  title: Text(e.title),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _play(s, eps, eps.indexOf(e));
                                  },
                                ),
                            ],
                          ),
                      ],
                    );
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
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (_items.isEmpty) {
            return const Center(child: Text('Esta cuenta no tiene series.'));
          }
          final q = _q.toLowerCase();
          final visible = _items
              .where((s) =>
                  (_cat == null ? !_catPrefs.hidden.contains(s.categoryId) : s.categoryId == _cat) &&
                  s.name.toLowerCase().contains(q))
              .toList();
          return Row(
            children: [
              SizedBox(
                width: 260,
                child: ListView(
                  children: [
                    ListTile(
                      title: const Text('Todas'),
                      selected: _cat == null,
                      onTap: () => setState(() => _cat = null),
                    ),
                    for (final c in _catPrefs.apply(_cats))
                      ListTile(
                        title: Text(c.name),
                        selected: _cat == c.id,
                        onTap: () => setState(() => _cat = c.id),
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
                          hintText: 'Buscar serie',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => _q = v),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 170,
                          childAspectRatio: 0.6,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: visible.length,
                        itemBuilder: (context, i) {
                          final s = visible[i];
                          return InkWell(
                            onTap: () => _open(s),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox.expand(
                                        child: _cover(s.cover)),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(s.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13)),
                              ],
                            ),
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