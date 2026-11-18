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

class Movie {
  final String id;
  final String name;
  final String categoryId;
  final String url;
  final String? icon;
  final String? rating;
  final int? added;
  Movie({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.url,
    this.icon,
    this.rating,
    this.added,
  });
}

class MovieInfo {
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? releaseDate;
  final String? duration;
  MovieInfo({
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releaseDate,
    this.duration,
  });
}

abstract class IptvSource {
  bool get supportsVod;
  Future<bool> login();
  Future<List<Category>> liveCategories();
  Future<List<Channel>> liveStreams();
  Future<List<Category>> vodCategories();
  Future<List<Movie>> movies();
  Future<MovieInfo?> movieInfo(Movie m);
  Future<List<Category>> seriesCategories();
  Future<List<Series>> seriesList();
  Future<List<Episode>> episodes(Series s);
}

class Series {
  final String id, name, categoryId;
  final String? cover, plot, rating;
  final int? added;
  Series({required this.id, required this.name, required this.categoryId,
      this.cover, this.plot, this.rating, this.added});
}

class Episode {
  final String id, title, url;
  final int season, number;
  Episode({required this.id, required this.title, required this.url,
      required this.season, required this.number});
}