import 'dart:convert';

import 'package:lolisnatcher/src/data/booru_item.dart';
import 'package:lolisnatcher/src/data/booru.dart';
import 'package:lolisnatcher/src/handlers/booru_handler.dart';

class PhilomenaHandler extends BooruHandler {
  PhilomenaHandler(Booru booru, int limit) : super(booru, limit);

  @override
  String validateTags(tags) {
    if (tags == "" || tags == " ") {
      return "*";
    } else {
      return tags;
    }
  }

  @override
  List parseListFromResponse(response) {
    Map<String, dynamic> parsedResponse = jsonDecode(response.body);
    return (parsedResponse['images'] ?? []) as List;
  }

  @override
  BooruItem? parseItemFromResponse(responseItem, int index) {
    var current = responseItem;
    if (current['representations']['full'] != null) {
      String sampleURL = current['representations']['medium'], thumbURL = current['representations']['thumb_small'];
      if (current["mime_type"].toString().contains("video")) {
        String tmpURL = "${sampleURL.substring(0, sampleURL.lastIndexOf("/") + 1)}thumb.gif";
        sampleURL = tmpURL;
        thumbURL = tmpURL;
      }

      String fileURL = current['representations']['full'];
      if (!fileURL.contains("http")) {
        sampleURL = booru.baseURL! + sampleURL;
        thumbURL = booru.baseURL! + thumbURL;
        fileURL = booru.baseURL! + fileURL;
      }

      List<String> currentTags = current['tags'].toString().substring(1, current['tags'].toString().length - 1).split(", ");
      for (int x = 0; x < currentTags.length; x++) {
        if (currentTags[x].contains(" ")) {
          currentTags[x] = currentTags[x].replaceAll(" ", "+");
        }
      }
      BooruItem item = BooruItem(
        fileURL: fileURL,
        fileWidth: current['width']?.toDouble(),
        fileHeight: current['height']?.toDouble(),
        fileSize: current['size'],
        sampleURL: sampleURL,
        thumbnailURL: thumbURL,
        tagsList: currentTags,
        postURL: makePostURL(current['id'].toString()),
        serverId: current['id'].toString(),
        score: current['score'].toString(),
        sources: [current['source_url'].toString()],
        postDate: current['created_at'],
        postDateFormat: "yyyy-MM-dd'T'HH:mm:ss'Z'",
        fileNameExtras: "${booru.name}_${current['id']}_"
      );

      return item;
    } else {
      return null;
    }
  }

  @override
  String makePostURL(String id) {
    return "${booru.baseURL}/images/$id";
  }

  @override
  String makeURL(String tags) {
    // EXAMPLE: https://derpibooru.org/api/v1/json/search/images?q=solo&per_page=20&page=1
    String filter = "2";
    if (booru.baseURL!.contains("derpibooru")) {
      filter = "56027";
    }
    if (booru.apiKey == "") {
      return "${booru.baseURL}/api/v1/json/search/images?filter_id=$filter&q=${tags.replaceAll(" ", ",")}&per_page=${limit.toString()}&page=${pageNum.toString()}";
    } else {
      return "${booru.baseURL}/api/v1/json/search/images?key=${booru.apiKey}&q=${tags.replaceAll(" ", ",")}&per_page=${limit.toString()}&page=${pageNum.toString()}";
    }
  }

  @override
  String makeTagURL(String input) {
    if (input.isEmpty) {
      input = '*';
    }
    return "${booru.baseURL}/api/v1/json/search/tags?q=$input*&per_page=10";
  }

  @override
  List parseTagSuggestionsList(response) {
    Map<String, dynamic> parsedResponse = jsonDecode(response.body);
    return parsedResponse['tags'];
  }

  @override
  String? parseTagSuggestion(responseItem, int index) {
    List tagStringReplacements = [
      ["-colon-", ":"],
      ["-dash-", "-"],
      ["-fwslash-", "/"],
      ["-bwslash-", "\\"],
      ["-dot-", "."],
      ["-plus-", "+"]
    ];

    String tag = responseItem['slug'].toString();
    for (int x = 0; x < tagStringReplacements.length; x++) {
      tag = tag.replaceAll(tagStringReplacements[x][0], tagStringReplacements[x][1]);
    }
    return tag;
  }
}
