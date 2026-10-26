// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'answer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Answer _$AnswerFromJson(Map<String, dynamic> json) => Answer(
  answer: json['answer'] as String?,
  products:
      (json['products'] as List<dynamic>?)
          ?.map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList(),
  sources:
      (json['sources'] as List<dynamic>?)
          ?.map((e) => Source.fromJson(e as Map<String, dynamic>))
          .toList(),
);

Map<String, dynamic> _$AnswerToJson(Answer instance) => <String, dynamic>{
  'answer': instance.answer,
  'products': instance.products,
  'sources': instance.sources,
};

Source _$SourceFromJson(Map<String, dynamic> json) => Source(
  id: json['id'] as String?,
  title: json['title'] as String?,
  organization: json['organization'] as String?,
  url: json['url'] as String?,
  published_on: json['published_on'] as String?,
  reviewed_on: json['reviewed_on'] as String?,
);

Map<String, dynamic> _$SourceToJson(Source instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'organization': instance.organization,
  'url': instance.url,
  'published_on': instance.published_on,
  'reviewed_on': instance.reviewed_on,
};
