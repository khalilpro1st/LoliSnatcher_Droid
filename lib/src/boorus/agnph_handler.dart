import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'package:lolisnatcher/src/data/booru_item.dart';
import 'package:lolisnatcher/src/data/booru.dart';
import 'package:lolisnatcher/src/handlers/booru_handler.dart';
import 'package:lolisnatcher/src/utils/logger.dart';

// TODO improve tag fecthing, add data from it to tag handler?

class AGNPHHandler extends BooruHandler {
  AGNPHHandler(Booru booru, int limit) : super(booru, limit);

  @override
  bool hasSizeData = true;

  /// Because the api doesn't return tags we will create fetched and have another function set tags at a later time.
  /// Seems to work for now but could cause a performance impact.
  /// Makes results show on screen faster than waiting on getDataByID
  @override
  List parseListFromResponse(response) {
    var parsedResponse = XmlDocument.parse(response.body);
    totalCount.value = int.tryParse(parsedResponse.getElement("posts")?.getAttribute("count") ?? '0') ?? 0;
    return parsedResponse.findAllElements("post").toList();
  }

  @override
  BooruItem? parseItemFromResponse(responseItem, int index) {
    String fileURL = responseItem.getElement("file_url")?.innerText ?? "";
    String sampleURL = responseItem.getElement("preview_url")?.innerText ?? "";
    String thumbnailURL = responseItem.getElement("thumbnail_url")?.innerText ?? "";
    if (sampleURL.isEmpty) {
      sampleURL = fileURL;
    }

    String postID = responseItem.getElement("id")?.innerText ?? "";
    if (postID.isNotEmpty && fileURL.isNotEmpty) {
      BooruItem item = BooruItem(
        fileURL: fileURL,
        sampleURL: sampleURL,
        thumbnailURL: thumbnailURL,
        tagsList: [],
        postURL: makePostURL(responseItem.getElement("id")?.innerText ?? ""),
        fileWidth: double.tryParse(responseItem.getElement("width")?.innerText ?? ""),
        fileHeight: double.tryParse(responseItem.getElement("height")?.innerText ?? ""),
        serverId: responseItem.getElement("id")?.innerText ?? "",
        rating: responseItem.getElement("rating")?.innerText,
        score: responseItem.getElement("fav_count")?.innerText,
        sources: [responseItem.getElement("source")?.innerText ?? ""],
        md5String: responseItem.getElement("md5")?.innerText,
        postDate: responseItem.getElement("created_at")?.innerText, // Fri Jun 18 02:13:45 -0500 2021
        postDateFormat: "unix", // when timezone support added: "EEE MMM dd HH:mm:ss Z yyyy",
      );

      int newIndex = fetched.length + index;
      getTagsLater(postID, newIndex);

      return item;
    } else {
      return null;
    }
  }

  void getTagsLater(String postID, int fetchedIndex) async {
    try {
      Uri uri = Uri.parse("${booru.baseURL}/gallery/post/show/$postID/?api=xml");
      var response = await http.get(uri, headers: getHeaders());
      Logger.Inst().log("Getting post data: $postID", className, "getTagsLater", LogTypes.booruHandlerRawFetched);
      if (response.statusCode == 200) {
        Logger.Inst().log("Got data for: $postID", className, "getTagsLater", LogTypes.booruHandlerRawFetched);
        var parsedResponse = XmlDocument.parse(response.body);
        var post = parsedResponse.getElement('post');
        String tagStr = post!.getElement("tags")?.innerText ?? "";
        if (post.getElement("tags")!.innerText.isNotEmpty) {
          String artist = post.getElement("artist")?.innerText ?? "";
          tagStr = "artist:$artist ${tagStr.replaceAll(artist, "")}";
        }
        fetched.elementAt(fetchedIndex).tagsList = tagStr.split(" ");
      } else {
        Logger.Inst().log("AGNPHHandler failed to get post", "AGNPHHandler", "getTagsLater", LogTypes.booruHandlerFetchFailed);
      }
    } catch (e) {
      Logger.Inst().log(e.toString(), "AGNPHHandler", "getTagsLater", LogTypes.exception);
    }
  }

  @override
  String makePostURL(String id) {
    // EXAMPLE: https://agn.ph/gallery/post/show/352470/
    return "${booru.baseURL}/gallery/post/show/$id";
  }

  @override
  String makeURL(String tags) {
    String tagStr = tags.replaceAll("artist:", "").replaceAll(" ", "+");
    // EXAMPLE: https://agn.ph/gallery/post/?search=sylveon&page=1&api=xml
    return "${booru.baseURL}/gallery/post/?search=$tagStr&page=$pageNum&api=xml";
  }

  @override
  String makeTagURL(String input) {
    // EXAMPLE: https://agn.ph/gallery/tags/?sort=count&order=desc&search=gard&api=xml
    return "${booru.baseURL}/gallery/tags/?sort=count&order=desc&search=$input&api=xml";
  }

  @override
  List parseTagSuggestionsList(response) {
    var parsedResponse = XmlDocument.parse(response.body);
    return parsedResponse.findAllElements("tag").toList();
  }

  @override
  String? parseTagSuggestion(responseItem, int index) {
    // TODO parse tag type
    return responseItem.getElement("name")?.innerText ?? "";
  }
}
