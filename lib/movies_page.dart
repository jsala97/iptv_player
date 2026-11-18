import 'package:flutter/material.dart';
import 'iptv_source.dart';
import 'player_page.dart';

class MoviesPage extends StatefulWidget {
  final IptvSource source;
  final String accountId;

  const MoviesPage({super.key, required this.source, required this.accountId});

  @override
  State<MoviesPage> createState() => _MoviesPageState();
}

class _MoviesPageState extends State<MoviesPage> {
  late final Future<void> _load = _fetch();
  List<Category> _categories = [];
  List<Movie> _movies = [];
  String? _selectedCat;
  String _search = '';

  Future<void> _fetch() async {
    final results = await Future.wait([
      widget.source.vodCategories(),
      widget.source.movies(),
    ]);
    _categories = results[0] as List<Category>;
    final movies = results[1] as List<Movie>;
    // Lo más reciente primero.
    movies.sort((a, b) => (b.added ?? 0).compareTo(a.added ?? 0));
    _movies = movies;
  }

  Widget _poster(String? url) {
    const placeholder = Center(child: Icon(Icons.movie, size: 40));
    if (url == null) return placeholder;
    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: 300,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }

  void _play(Movie m) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          channels: [Channel('m${m.id}', m.name, m.categoryId, m.url)],
          startIndex: 0,
          accountId: widget.accountId,
        ),
      ),
    );
  }

  void _open(Movie m) {
    final infoFuture = widget.source.movieInfo(m);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(m.name),
        content: SizedBox(
          width: 640,
          height: 360,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 180,
                height: 270,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _poster(m.icon),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: FutureBuilder<MovieInfo?>(
                  future: infoFuture,
                  builder: (_, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final i = snap.data;
                    if (snap.hasError || i == null) {
                      return const Text(
                        'No hay más información de esta película.',
                      );
                    }
                    final meta = [
                      i.releaseDate,
                      i.duration,
                      if (m.rating != null) '★ ${m.rating}',
                      i.genre,
                    ].whereType<String>().where((s) => s.isNotEmpty).join('  ·  ');
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (meta.isNotEmpty) Text(meta),
                          if (i.plot != null) ...[
                            const SizedBox(height: 12),
                            Text(i.plot!),
                          ],
                          if (i.director != null) ...[
                            const SizedBox(height: 12),
                            Text('Director: ${i.director}'),
                          ],
                          if (i.cast != null) ...[
                            const SizedBox(height: 8),
                            Text('Reparto: ${i.cast}'),
                          ],
                        ],
                      ),
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
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Reproducir'),
            onPressed: () {
              Navigator.pop(ctx);
              _play(m);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Películas')),
      body: FutureBuilder<void>(
        future: _load,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (_movies.isEmpty) {
            return const Center(
              child: Text('Esta cuenta no tiene películas.'),
            );
          }

          final q = _search.toLowerCase();
          final visible = _movies.where((m) {
            final inCat = _selectedCat == null || m.categoryId == _selectedCat;
            return inCat && m.name.toLowerCase().contains(q);
          }).toList();

          return Row(
            children: [
              SizedBox(
                width: 260,
                child: ListView(
                  children: [
                    ListTile(
                      title: const Text('Todas'),
                      selected: _selectedCat == null,
                      onTap: () => setState(() => _selectedCat = null),
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
                          hintText: 'Buscar película',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => _search = v),
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
                          final m = visible[i];
                          return InkWell(
                            onTap: () => _open(m),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox.expand(
                                      child: _poster(m.icon),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  m.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
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