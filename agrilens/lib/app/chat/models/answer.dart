import 'package:agrilens/app/shop/models/product_model.dart';
import 'package:json_annotation/json_annotation.dart';

part 'answer.g.dart';

@JsonSerializable()
class Answer {
  final String? answer;
  final List<Product>? products;
  final List<Source>? sources;

  Answer({this.answer, this.products, this.sources});

  factory Answer.fromJson(Map<String, dynamic> json) => _$AnswerFromJson(json);
  Map<String, dynamic> toJson() => _$AnswerToJson(this);
}

@JsonSerializable()
class Source {
  final String? id;
  final String? title;
  final String? organization;
  final String? url;
  @JsonKey(name: 'published_on')
  final String? published_on;
  @JsonKey(name: 'reviewed_on')
  final String? reviewed_on;

  Source({
    this.id,
    this.title,
    this.organization,
    this.url,
    this.published_on,
    this.reviewed_on,
  });

  factory Source.fromJson(Map<String, dynamic> json) => _$SourceFromJson(json);
  Map<String, dynamic> toJson() => _$SourceToJson(this);
}
