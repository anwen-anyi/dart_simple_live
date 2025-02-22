import 'dart:convert';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/convert_helper.dart';
import 'package:simple_live_core/src/common/http_client.dart';

class DouyinSite implements LiveSite {
  @override
  String id = "douyin";

  @override
  String name = "抖音直播";

  @override
  LiveDanmaku getDanmaku() => DouyinDanmaku();

  Map<String, dynamic> headers = {
    "Authority": "live.douyin.com",
    "Referer": "https://live.douyin.com",
    "User-Agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.51",
  };

  Future<Map<String, dynamic>> getRequestHeaders() async {
    try {
      if (headers.containsKey("cookie")) {
        return headers;
      }
      var head = await HttpClient.instance
          .head("https://live.douyin.com", header: headers);
      head.headers["set-cookie"]?.forEach((element) {
        var cookie = element.split(";")[0];
        if (cookie.contains("ttwid")) {
          headers["cookie"] = cookie;
        }
      });
      return headers;
    } catch (e) {
      CoreLog.error(e);
      return headers;
    }
  }

  @override
  Future<List<LiveCategory>> getCategores() async {
    List<LiveCategory> categories = [];
    var result = await HttpClient.instance.getText(
      "https://live.douyin.com/hot_live",
      queryParameters: {},
      header: {
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.51",
      },
    );

    var renderData =
        RegExp(r'<script id="RENDER_DATA" type="application/json">(.*?)</script>')
                .firstMatch(result)
                ?.group(1) ??
            "";
    var renderDataJson = json.decode(Uri.decodeFull(renderData.trim()));

    for (var item in renderDataJson["app"]["layoutData"]["categoryTab"]
        ["categoryData"]) {
      List<LiveSubCategory> subs = [];
      var id = '${item["partition"]["id_str"]},${item["partition"]["type"]}';
      for (var subItem in item["sub_partition"]) {
        var subCategory = LiveSubCategory(
          id: '${subItem["partition"]["id_str"]},${subItem["partition"]["type"]}',
          name: asT<String?>(subItem["partition"]["title"]) ?? "",
          parentId: id,
          pic: "",
        );
        subs.add(subCategory);
      }

      var category = LiveCategory(
        children: subs,
        id: id,
        name: asT<String?>(item["partition"]["title"]) ?? "",
      );
      subs.insert(
          0,
          LiveSubCategory(
            id: category.id,
            name: category.name,
            parentId: category.id,
            pic: "",
          ));
      categories.add(category);
    }
    return categories;
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(LiveSubCategory category,
      {int page = 1}) async {
    var ids = category.id.split(',');
    var partitionId = ids[0];
    var partitionType = ids[1];
    var result = await HttpClient.instance.getJson(
      "https://live.douyin.com/webcast/web/partition/detail/room/",
      queryParameters: {
        "aid": 6383,
        "app_name": "douyin_web",
        "live_id": 1,
        "device_platform": "web",
        "count": 15,
        "offset": (page - 1) * 15,
        "partition": partitionId,
        "partition_type": partitionType,
        "req_from": 2
      },
      header: await getRequestHeaders(),
    );

    var hasMore = (result["data"]["data"] as List).length >= 15;
    var items = <LiveRoomItem>[];
    for (var item in result["data"]["data"]) {
      var roomItem = LiveRoomItem(
        roomId: "${item["web_rid"]},${item["room"]["id_str"]}",
        title: item["room"]["title"].toString(),
        cover: item["room"]["cover"]["url_list"][0].toString(),
        userName: item["room"]["owner"]["nickname"].toString(),
        online: int.tryParse(
                item["room"]["room_view_stats"]["display_value"].toString()) ??
            0,
      );
      items.add(roomItem);
    }
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1}) async {
    var result = await HttpClient.instance.getJson(
      "https://live.douyin.com/webcast/web/partition/detail/room/",
      queryParameters: {
        "aid": 6383,
        "app_name": "douyin_web",
        "live_id": 1,
        "device_platform": "web",
        "count": 15,
        "offset": (page - 1) * 15,
        "partition": 720,
        "partition_type": 1,
      },
      header: await getRequestHeaders(),
    );

    var hasMore = (result["data"]["data"] as List).length >= 15;
    var items = <LiveRoomItem>[];
    for (var item in result["data"]["data"]) {
      var roomItem = LiveRoomItem(
        roomId: "${item["web_rid"]},${item["room"]["id_str"]}",
        title: item["room"]["title"].toString(),
        cover: item["room"]["cover"]["url_list"][0].toString(),
        userName: item["room"]["owner"]["nickname"].toString(),
        online: int.tryParse(
                item["room"]["room_view_stats"]["display_value"].toString()) ??
            0,
      );
      items.add(roomItem);
    }
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    var ids = roomId.split(',');
    var webRid = ids[0];
    var roomIdStr = ids[1];

    var result = await HttpClient.instance.getJson(
      "https://live.douyin.com/webcast/room/web/enter/",
      queryParameters: {
        "aid": 6383,
        "app_name": "douyin_web",
        "live_id": 1,
        "device_platform": "web",
        "enter_from": "web_live",
        "web_rid": webRid,
        "room_id_str": roomIdStr,
        "enter_source": "",
        "Room-Enter-User-Login-Ab": 0,
        "is_need_double_stream": false,
        "cookie_enabled": true,
        "screen_width": 1980,
        "screen_height": 1080,
        "browser_language": "zh-CN",
        "browser_platform": "Win32",
        "browser_name": "Edge",
        "browser_version": "114.0.1823.51"
      },
      header: await getRequestHeaders(),
    );
    var roomInfo = result["data"]["data"][0];
    return LiveRoomDetail(
      roomId: roomId,
      title: roomInfo["title"].toString(),
      cover: roomInfo["cover"]["url_list"][0].toString(),
      userName: roomInfo["owner"]["nickname"].toString(),
      userAvatar: roomInfo["owner"]["avatar_thumb"]["url_list"][0].toString(),
      online: asT<int?>(roomInfo["room_view_stats"]["display_value"]) ?? 0,
      status: (asT<int?>(roomInfo["status"]) ?? 0) == 2,
      url: "https://live.douyin.com/$webRid",
      introduction: roomInfo["title"].toString(),
      notice: "",
      danmakuData: roomId,
      data: roomInfo["stream_url"],
    );
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites(
      {required LiveRoomDetail detail}) async {
    List<LivePlayQuality> qualities = [];
    var qualityData = json.decode(
        detail.data["live_core_sdk_data"]["pull_data"]["stream_data"])["data"];
    var qulityList =
        detail.data["live_core_sdk_data"]["pull_data"]["options"]["qualities"];
    for (var quality in qulityList) {
      var qualityItem = LivePlayQuality(
        quality: quality["name"],
        sort: quality["level"],
        data: <String>[
          qualityData[quality["sdk_key"]]["main"]["flv"].toString(),
          qualityData[quality["sdk_key"]]["main"]["hls"].toString(),
        ],
      );
      qualities.add(qualityItem);
    }
    qualities.sort((a, b) => b.sort.compareTo(a.sort));
    return qualities;
  }

  @override
  Future<List<String>> getPlayUrls(
      {required LiveRoomDetail detail,
      required LivePlayQuality quality}) async {
    return quality.data;
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(String keyword,
      {int page = 1}) async {
    var result = await HttpClient.instance.getJson(
      "https://api.bilibili.com/x/web-interface/search/type?context=&search_type=live&cover_type=user_cover",
      queryParameters: {
        "order": "",
        "keyword": keyword,
        "category_id": "",
        "__refresh__": "",
        "_extra": "",
        "highlight": 0,
        "single_column": 0,
        "page": page
      },
      header: {"cookie": "buvid3=infoc;"},
    );

    var items = <LiveRoomItem>[];
    for (var item in result["data"]["result"]["live_room"] ?? []) {
      var title = item["title"].toString();
      //移除title中的<em></em>标签
      title = title.replaceAll(RegExp(r"<.*?em.*?>"), "");
      var roomItem = LiveRoomItem(
        roomId: item["roomid"].toString(),
        title: title,
        cover: "https:${item["cover"]}@400w.jpg",
        userName: item["uname"].toString(),
        online: int.tryParse(item["online"].toString()) ?? 0,
      );
      items.add(roomItem);
    }
    return LiveSearchRoomResult(hasMore: items.length >= 40, items: items);
  }

  @override
  Future<LiveSearchAnchorResult> searchAnchors(String keyword,
      {int page = 1}) async {
    var result = await HttpClient.instance.getJson(
      "https://api.bilibili.com/x/web-interface/search/type?context=&search_type=live_user&cover_type=user_cover",
      queryParameters: {
        "order": "",
        "keyword": keyword,
        "category_id": "",
        "__refresh__": "",
        "_extra": "",
        "highlight": 0,
        "single_column": 0,
        "page": page
      },
      header: {"cookie": "buvid3=infoc;"},
    );

    var items = <LiveAnchorItem>[];
    for (var item in result["data"]["result"] ?? []) {
      var uname = item["uname"].toString();
      //移除title中的<em></em>标签
      uname = uname.replaceAll(RegExp(r"<.*?em.*?>"), "");
      var anchorItem = LiveAnchorItem(
        roomId: item["roomid"].toString(),
        avatar: "https:${item["uface"]}@400w.jpg",
        userName: uname,
        liveStatus: item["is_live"],
      );
      items.add(anchorItem);
    }
    return LiveSearchAnchorResult(hasMore: items.length >= 40, items: items);
  }

  @override
  Future<bool> getLiveStatus({required String roomId}) async {
    var result = await getRoomDetail(roomId: roomId);
    return result.status;
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage(
      {required String roomId}) {
    return Future.value(<LiveSuperChatMessage>[]);
  }
}
