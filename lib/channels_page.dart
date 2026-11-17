import 'package:flutter/material.dart';
import 'xtream_api.dart';

class ChannelsPage extends StatefulWidget {
  final XtreamApi api;
  const ChannelsPage({super.key, required this.api});

  @override
  State<ChannelsPage> createState() => _ChannelsPageState();
}

class _ChannelsPageState extends State<ChannelsPage> {
  late Future<void> _load;
  List<Category> _categories = [];
  List<Channel> _channels = [];
  String? _selectedCat;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load = _fetch();
  }

  Future<void> _fetch() async {
    final results = await Future.wait([
      widget.api.liveCategories(),
      widget.api.liveStreams(),
    ]);
    _categories = results[0] as List<Category>;
    _channels = results[1] as List<Channel>;
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
            final inCat = _selectedCat == null || c.categoryId == _selectedCat;
            final matches = c.name.toLowerCase().contains(_search.toLowerCase());
            return inCat && matches;
          }).toList();

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
                          return ListTile(
                            leading: const Icon(Icons.tv),
                            title: Text(ch.name),
                            onTap: () => debugPrint(widget.api.streamUrl(ch.id)),
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