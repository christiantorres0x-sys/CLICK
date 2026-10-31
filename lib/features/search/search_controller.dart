import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/entities/track.dart';

enum SearchStatus { idle, loading, success, error }

class SearchState {
  const SearchState({
    this.query = '',
    this.status = SearchStatus.idle,
    this.results = const [],
    this.errorMessage,
  });

  final String query;
  final SearchStatus status;
  final List<Track> results;
  final String? errorMessage;
}

/// Search goes through the provider adapter, never straight from widgets
/// (FR-SEARCH-02), and is debounced (FR-SEARCH-05).
class SearchNotifier extends Notifier<SearchState> {
  static const debounceDuration = Duration(milliseconds: 400);

  Timer? _debounce;
  int _token = 0;
  bool _disposed = false;

  @override
  SearchState build() {
    ref.onDispose(() {
      _disposed = true;
      _debounce?.cancel();
    });
    return const SearchState();
  }

  /// Called on every keystroke; only the last value within the debounce
  /// window triggers a request.
  void onQueryChanged(String raw) {
    _debounce?.cancel();
    final query = raw.trim();
    if (query.isEmpty) {
      _token++; // discard any in-flight request
      state = const SearchState();
      return;
    }
    // Metered providers (YouTube: ~100 searches/day) search only on submit.
    if (ref.read(musicProviderProvider).searchIsMetered) return;
    _debounce = Timer(debounceDuration, () => search(query));
  }

  Future<void> search(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      state = const SearchState();
      return;
    }
    final token = ++_token;
    state = SearchState(query: clean, status: SearchStatus.loading);
    try {
      final results = await ref.read(musicProviderProvider).searchTracks(clean);
      if (_disposed || token != _token) return;
      state = SearchState(query: clean, status: SearchStatus.success, results: results);
    } on AppException catch (e) {
      if (_disposed || token != _token) return;
      state = SearchState(query: clean, status: SearchStatus.error, errorMessage: e.userMessage);
    } catch (_) {
      if (_disposed || token != _token) return;
      state = SearchState(
        query: clean,
        status: SearchStatus.error,
        errorMessage: 'Something went wrong while searching. Please try again.',
      );
    }
  }

  void retry() => search(state.query);
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);
