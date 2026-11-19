import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'iptv_source.dart';

class CategoryPrefs {
  final Set<String> hidden;
  final List<String> order;
  CategoryPrefs(this.hidden, this.order);

  static String _h(String acc, String scope) => 'cat_hidden_${scope}_$acc';
  static String _o(String acc, String scope) => 'cat_order_${scope}_$acc';

  static Future<CategoryPrefs> load(String acc, String scope) async {
    final p = await SharedPreferences.getInstance();
    return CategoryPrefs(
      (p.getStringList(_h(acc, scope)) ?? <String>[]).toSet(),
      p.getStringList(_o(acc, scope)) ?? <String>[],
    );
  }

  Future<void> save(String acc, String scope) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_h(acc, scope), hidden.toList());
    await p.setStringList(_o(acc, scope), order);
  }

  /// Ordenadas (las nuevas, al final) y sin las ocultas.
  List<Category> apply(List<Category> all, {bool includeHidden = false}) {
    final pos = {for (var i = 0; i < order.length; i++) order[i]: i};
    final idx = {for (var i = 0; i < all.length; i++) all[i].id: i};
    int key(Category c) => pos[c.id] ?? (100000 + idx[c.id]!);
    final sorted = [...all]..sort((a, b) => key(a).compareTo(key(b)));
    return includeHidden
        ? sorted
        : sorted.where((c) => !hidden.contains(c.id)).toList();
  }
}

Future<CategoryPrefs?> manageCategories(
  BuildContext context,
  List<Category> all,
  CategoryPrefs current,
) {
  final list = current.apply(all, includeHidden: true);
  final hidden = {...current.hidden};
  return showDialog<CategoryPrefs>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Categorías'),
        content: SizedBox(
          width: 420,
          height: 480,
          child: ReorderableListView(
            onReorderItem: (o, n) => setS(() {
              list.insert(n, list.removeAt(o));
            }),
            children: [
              for (final c in list)
                CheckboxListTile(
                  key: ValueKey(c.id),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(c.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  value: !hidden.contains(c.id),
                  onChanged: (v) => setS(() {
                    if (v == true) {
                      hidden.remove(c.id);
                    } else {
                      hidden.add(c.id);
                    }
                  }),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              CategoryPrefs(hidden, [for (final c in list) c.id]),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}