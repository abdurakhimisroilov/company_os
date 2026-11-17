import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
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
  const LoadDocumentsEvent({this.folderId, this.folderName, this.search});
  @override
  List<Object?> get props => [folderId, folderName, search];
}

class UploadDocumentEvent extends DocumentsEvent {
  final String folderId;
  final String fileName;
  const UploadDocumentEvent({required this.folderId, required this.fileName});
  @override
  List<Object?> get props => [folderId, fileName];
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

  const DocumentsLoaded({
    required this.folders,
    required this.files,
    this.currentFolderId,
    this.currentFolderName,
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [folders, files, currentFolderId, currentFolderName, searchQuery];
}

class DocumentsActionSuccess extends DocumentsState {
  final String message;
  const DocumentsActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class DocumentsError extends DocumentsState {
  final String message;
  const DocumentsError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
class DocumentsBloc extends Bloc<DocumentsEvent, DocumentsState> {
  final DocumentsRepository documentsRepository;

  DocumentsBloc({required this.documentsRepository}) : super(DocumentsInitial()) {
    on<LoadDocumentsEvent>(_onLoadDocuments);
    on<UploadDocumentEvent>(_onUpload);
  }

  Future<void> _onLoadDocuments(LoadDocumentsEvent event, Emitter<DocumentsState> emit) async {
    emit(DocumentsLoading());
    try {
      final folders = await documentsRepository.getFolders();
      final files = await documentsRepository.getFiles(folderId: event.folderId, search: event.search);
      emit(DocumentsLoaded(
        folders: folders,
        files: files,
        currentFolderId: event.folderId,
        currentFolderName: event.folderName,
        searchQuery: event.search ?? '',
      ));
    } catch (e) {
      emit(DocumentsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onUpload(UploadDocumentEvent event, Emitter<DocumentsState> emit) async {
    try {
      await documentsRepository.uploadFile(folderId: event.folderId, fileName: event.fileName);
      emit(const DocumentsActionSuccess('Файл успешно загружен'));
      add(LoadDocumentsEvent(folderId: event.folderId));
    } catch (e) {
      emit(DocumentsError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
