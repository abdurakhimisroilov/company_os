import '../../../../core/utils/json_helpers.dart';

class CompanyModel {
  final String id;
  final String name;
  final String? taxId;
  final String currency;
  final String? logoUrl;
  final String? description;
  final String? address;
  final String? phone;
  final String? email;
  final bool isCurrent;
  final String? userRole;
  final DateTime? createdAt;

  const CompanyModel({
    required this.id,
    required this.name,
    this.taxId,
    this.currency = 'UZS',
    this.logoUrl,
    this.description,
    this.address,
    this.phone,
    this.email,
    this.isCurrent = false,
    this.userRole,
    this.createdAt,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: JsonHelpers.toStr(json['id']),
      name: JsonHelpers.toStr(json['name'], 'Компания'),
      // The server may send a purely numeric tax id as a number.
      taxId: _optional(json['tax_id'] ?? json['taxId']),
      currency: JsonHelpers.toStr(json['currency'], 'UZS'),
      logoUrl: JsonHelpers.extractOptionalString(json['logo_url'] ?? json['logoUrl']),
      description: JsonHelpers.extractOptionalString(json['description']),
      address: JsonHelpers.extractOptionalString(json['address']),
      phone: JsonHelpers.extractOptionalString(json['phone']),
      email: JsonHelpers.extractOptionalString(json['email']),
      isCurrent: JsonHelpers.toBool(json['is_current'] ?? json['isCurrent'], false),
      userRole: JsonHelpers.extractOptionalString(json['user_role'] ?? json['userRole']),
      createdAt: JsonHelpers.toOptionalDateTime(json['created_at'] ?? json['createdAt']),
    );
  }

  static String? _optional(dynamic value) {
    final text = JsonHelpers.toStr(value).trim();
    return text.isEmpty ? null : text;
  }

  /// Owner of the organization: the only role allowed to delete it.
  bool get isOwner => (userRole ?? '').toUpperCase() == 'OWNER';

  /// Roles allowed to edit the organization's details.
  bool get canEdit => const {'OWNER', 'SUPER_ADMIN', 'ADMIN'}.contains((userRole ?? '').toUpperCase());

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'taxId': taxId,
      'currency': currency,
      'logoUrl': logoUrl,
      'description': description,
      'address': address,
      'phone': phone,
      'email': email,
      'isCurrent': isCurrent,
      'userRole': userRole,
    };
  }

  CompanyModel copyWith({
    String? id,
    String? name,
    String? taxId,
    String? currency,
    String? logoUrl,
    String? description,
    String? address,
    String? phone,
    String? email,
    bool? isCurrent,
    String? userRole,
    DateTime? createdAt,
  }) {
    return CompanyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      taxId: taxId ?? this.taxId,
      currency: currency ?? this.currency,
      logoUrl: logoUrl ?? this.logoUrl,
      description: description ?? this.description,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isCurrent: isCurrent ?? this.isCurrent,
      userRole: userRole ?? this.userRole,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
