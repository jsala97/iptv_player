class Category {
  final String id;
  final String name;
  Category(this.id, this.name);
}

class Channel {
  final String id;
  final String name;
  final String categoryId;
  final String url;
  final String? epgId;
  Channel(this.id, this.name, this.categoryId, this.url, {this.epgId});
}

abstract class IptvSource {
  Future<bool> login();
  Future<List<Category>> liveCategories();
  Future<List<Channel>> liveStreams();
}