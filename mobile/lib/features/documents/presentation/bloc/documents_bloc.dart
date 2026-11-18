import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/api_error.dart';
import '../../data/models/document_model.dart';
import '../../data/repositories/documents_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class DocumentsEvent extends Equatable {
  const DocumentsEvent();
  @override
  List<Object?> get props => [];
}

class LoadDocumentsEvent extends DocumentsEvent {
  final String? folderId;
  final String? folderName;
  final String? search;

  /// Keeps the loaded content on screen while the request runs.
  final bool silent;

  /// Completed when the request settles (used by pull-to-refresh).
  final Completer<void>? completer;

  const LoadDocumentsEvent({this.folderId, this.folderName, this.search, this.silent = false, this.completer});
  @override
  List<Object?> get props => [folderId, folderName, search, silent, completer];
}

// ─── States ─────────────────────────────────────────────────────────────────
abstract class DocumentsState extends Equatable {
  const DocumentsState();
  @override
  List<Object?> get props => [];
}

class DocumentsInitial extends DocumentsState {}

class DocumentsLoading extends DocumentsState {}

class DocumentsLoaded extends DocumentsState {
  final List<DocumentFolderModel> folders;
  final List<DocumentFileModel> files;
  final String? currentFolderId;
  final String? currentFolderName;
  final String searchQuery;

  /// Set when a background refresh failed; the previous content stays visible.
  final String? refreshError;

  const DocumentsLoaded({
    required this.folders,
    required this.files,
    this.currentFolderId,
    this.currentFolderName,
    this.searchQuery = '',
    this.refreshError,
  });

  @override
  List<Object?> get props => [folders, files, currentFolderId, currentFolderName, searchQuery, refreshError];
}

class DocumentsError extends DocumentsState {
  final String message;
  const DocumentsError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC (loading only; uploads and deletions are driven by the page, which
// shows their progress and errors, and then asks for a silent reload) ────────
class DocumentsBloc extends Bloc<DocumentsEvent, DocumentsState> {
  final DocumentsRepository documentsRepository;
  int _requestSeq = 0;

  DocumentsBloc({required this.documentsRepository}) : super(DocumentsInitial()) {
    on<LoadDocumentsEvent>(_onLoadDocuments);
  }

  Future<void> _onLoadDocuments(LoadDocumentsEvent event, Emitter<DocumentsState> emit) async {
    final seq = ++_requestSeq;
    final previous = state;
    final kept = event.silent && previous is DocumentsLoaded ? previous : null;
    if (kept == null) emit(DocumentsLoading());
    try {
      final results = await Future.wait([
        documentsRepository.getFolders(),
        documentsRepository.getFiles(folderId: event.folderId, search: event.search),
      ]);
      if (seq != _requestSeq) return;
      emit(DocumentsLoaded(
        folders: results[0] as List<DocumentFolderModel>,
        files: results[1] as List<DocumentFileModel>,
        currentFolderId: event.folderId,
        currentFolderName: event.folderName,
        searchQuery: event.search ?? '',
      ));
    } catch (e) {
      if (seq != _requestSeq) return;
      final message = apiErrorMessage(e, fallback: 'Не удалось загрузить документы');
      if (kept != null) {
        emit(DocumentsLoaded(
          folders: kept.folders,
          files: kept.files,
          currentFolderId: kept.currentFolderId,
          currentFolderName: kept.currentFolderName,
          searchQuery: kept.searchQuery,
          refreshError: message,
        ));
      } else {
        emit(DocumentsError(message));
      }
    } finally {
      event.completer?.complete();
    }
  }
}
