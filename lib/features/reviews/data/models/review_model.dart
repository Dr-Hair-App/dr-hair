import 'package:flutter/foundation.dart';

@immutable
class ReviewModel {
  final String id;
  final String name;
  final int rating;
  final String category;
  final String treatment;
  final String duration;
  final String comment;
  final bool verified;
  final String avatar;

  const ReviewModel({
    required this.id,
    required this.name,
    required this.rating,
    required this.category,
    this.treatment = 'Hair Treatment',
    this.duration = '',
    required this.comment,
    this.verified = true,
    this.avatar = '',
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final rawRating = json['rating'];
    final ratingNum = rawRating is num
        ? rawRating.round()
        : int.tryParse(rawRating?.toString() ?? '') ?? 0;

    return ReviewModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      rating: ratingNum.clamp(0, 5),
      category: json['category']?.toString() ?? 'General',
      treatment:
          json['treatment']?.toString() ??
          (json['category'] != null
              ? '${json['category']} Care'
              : 'Hair Treatment'),
      duration: json['duration']?.toString() ?? '',
      comment: json['message']?.toString() ?? json['comment']?.toString() ?? '',
      verified:
          json['is_verified'] == true ||
          json['verified'] == true ||
          json['status'] == 'active',
      avatar: json['avatar']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rating': rating,
    'category': category,
    'treatment': treatment,
    'duration': duration,
    'comment': comment,
    'verified': verified,
    'avatar': avatar,
  };
}
