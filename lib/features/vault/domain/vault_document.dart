import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Type of document stored in the vault.
enum DocumentCategory {
  bank('Bank account', Icons.account_balance),
  insurance('Insurance', Icons.health_and_safety),
  investment('Investment', Icons.trending_up),
  property('Property', Icons.home_work),
  identity('Identity', Icons.badge),
  other('Other', Icons.description);

  const DocumentCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  static DocumentCategory fromName(String? name) =>
      DocumentCategory.values.firstWhere(
        (c) => c.name == name,
        orElse: () => DocumentCategory.other,
      );
}

/// One item in the vault, e.g. "SBI savings account" or "LIC policy".
class VaultDocument extends Equatable {
  const VaultDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.createdAt,
    this.notes = '',
    this.fileUrl,
    this.fileName,
    this.nomineeIds = const [],
  });

  final String id;
  final String title;
  final DocumentCategory category;
  final String notes;
  final String? fileUrl;
  final String? fileName;
  final List<String> nomineeIds;
  final DateTime createdAt;

  bool get hasFile => fileUrl != null;

  VaultDocument copyWith({String? fileUrl, String? fileName}) => VaultDocument(
        id: id,
        title: title,
        category: category,
        notes: notes,
        fileUrl: fileUrl ?? this.fileUrl,
        fileName: fileName ?? this.fileName,
        nomineeIds: nomineeIds,
        createdAt: createdAt,
      );

  /// Converts to a Map for Firestore and the Hive cache.
  /// Dates are stored as milliseconds so both stores can handle them.
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'category': category.name,
        'notes': notes,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'nomineeIds': nomineeIds,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory VaultDocument.fromMap(Map<String, dynamic> map) => VaultDocument(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        category: DocumentCategory.fromName(map['category'] as String?),
        notes: map['notes'] as String? ?? '',
        fileUrl: map['fileUrl'] as String?,
        fileName: map['fileName'] as String?,
        nomineeIds: List<String>.from(map['nomineeIds'] as List? ?? const []),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['createdAt'] as num?)?.toInt() ?? 0,
        ),
      );

  @override
  List<Object?> get props =>
      [id, title, category, notes, fileUrl, fileName, nomineeIds, createdAt];
}
