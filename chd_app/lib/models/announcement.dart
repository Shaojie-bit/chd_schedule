class Announcement {
  final int id;
  final String title;
  final String content;
  final String type; // notice, update, warning
  final bool isPopup;
  final int versionCode;
  final String downloadUrl;
  final String createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    this.type = 'notice',
    this.isPopup = false,
    this.versionCode = 1,
    this.downloadUrl = '',
    required this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      type: json['type']?.toString() ?? 'notice',
      isPopup: json['is_popup'] == true || json['is_popup'] == 1,
      versionCode: json['version_code'] is int
          ? json['version_code']
          : int.tryParse(json['version_code']?.toString() ?? '1') ?? 1,
      downloadUrl: json['download_url']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type,
      'is_popup': isPopup,
      'version_code': versionCode,
      'download_url': downloadUrl,
      'created_at': createdAt,
    };
  }
}
