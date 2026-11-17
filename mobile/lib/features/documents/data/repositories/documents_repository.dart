import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/document_model.dart';

class DocumentsRepository {
  final ApiClient apiClient;

  DocumentsRepository({required this.apiClient});

  Future<List<DocumentFolderModel>> getFolders() async {
    final response = await apiClient.get('/documents/folders');
    if (response.statusCode == 200) {
      final list = JsonHelpers.toList(response.data);
      return list.map((e) => DocumentFolderModel.fromJson(JsonHelpers.toMap(e))).toList();
    }
    throw Exception('Не удалось загрузить папки');
  }

  Future<DocumentFolderModel> createFolder(String name) async {
    final response = await apiClient.post('/documents/folders', data: {'name': name});
    if (response.statusCode == 200 || response.statusCode == 201) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return DocumentFolderModel.fromJson(map);
    }
    throw Exception('Не удалось создать папку');
  }

  Future<List<DocumentFileModel>> getFiles({String? folderId, String? search}) async {
    final query = <String, dynamic>{};
    if (folderId != null && folderId.isNotEmpty) {
      query['folderId'] = folderId;
    }
    if (search != null && search.isNotEmpty) {
      query['search'] = search;
    }

    final response = await apiClient.get(
      '/documents/files',
      queryParameters: query,
    );

    if (response.statusCode == 200) {
      final list = JsonHelpers.toList(response.data);
      return list.map((e) => DocumentFileModel.fromJson(JsonHelpers.toMap(e))).toList();
    }
    throw Exception('Не удалось загрузить файлы');
  }

  Future<DocumentFileModel> uploadFile({
    File? file,
    required String folderId,
    String? fileName,
  }) async {
    FormData formData;
    if (file != null) {
      final name = fileName ?? file.path.split(Platform.pathSeparator).last;
      formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: name),
        'folderId': folderId,
      });
    } else {
      formData = FormData.fromMap({
        'fileName': fileName ?? 'document.pdf',
        'folderId': folderId,
      });
    }

    final response = await apiClient.post(
      '/documents/upload',
      data: formData,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return DocumentFileModel.fromJson(map);
    }
    throw Exception('Ошибка при загрузке файла');
  }
}
