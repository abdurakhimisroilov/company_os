import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/document_model.dart';

class DocumentsRepository {
  final ApiClient apiClient;

  DocumentsRepository({required this.apiClient});

  /// Server limit for a single uploaded file.
  static const int maxFileBytes = 25 * 1024 * 1024;

  Map<String, dynamic> _data(dynamic body) {
    return JsonHelpers.toMap(body is Map && body.containsKey('data') ? body['data'] : body);
  }

  Future<List<DocumentFolderModel>> getFolders() async {
    final response = await apiClient.get(ApiEndpoints.documentFolders);
    return JsonHelpers.toList(response.data).map((e) => DocumentFolderModel.fromJson(JsonHelpers.toMap(e))).toList();
  }

  Future<DocumentFolderModel> createFolder(String name) async {
    final response = await apiClient.post(ApiEndpoints.documentFolders, data: {'name': name});
    return DocumentFolderModel.fromJson(_data(response.data));
  }

  Future<void> renameFolder(String id, String name) async {
    await apiClient.patch('${ApiEndpoints.documentFolders}/$id', data: {'name': name});
  }

  /// Deletes the folder together with the files stored in it.
  Future<void> deleteFolder(String id) async {
    await apiClient.delete('${ApiEndpoints.documentFolders}/$id');
  }

  /// Files of one folder, or of the whole organization when [folderId] is null.
  Future<List<DocumentFileModel>> getFiles({String? folderId, String? search}) async {
    final query = <String, dynamic>{};
    if (folderId != null && folderId.isNotEmpty) query['folderId'] = folderId;
    if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();

    final response = await apiClient.get('${ApiEndpoints.documents}/files', queryParameters: query);
    return JsonHelpers.toList(response.data).map((e) => DocumentFileModel.fromJson(JsonHelpers.toMap(e))).toList();
  }

  /// `POST /documents/upload` (multipart `file` + optional `folderId`).
  Future<DocumentFileModel> uploadFile({
    required String filePath,
    String? folderId,
    String? fileName,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final body = await apiClient.uploadFile(
      filePath,
      customFileName: fileName,
      path: '${ApiEndpoints.documents}/upload',
      fields: {if (folderId != null && folderId.isNotEmpty) 'folderId': folderId},
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return DocumentFileModel.fromJson(_data(body));
  }

  Future<void> deleteFile(String id) async {
    await apiClient.delete('${ApiEndpoints.documents}/files/$id');
  }
}
