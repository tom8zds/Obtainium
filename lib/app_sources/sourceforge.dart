import 'package:html/parser.dart';
import 'package:http/http.dart';
import 'package:obtainiumi/custom_errors.dart';
import 'package:obtainiumi/providers/source_provider.dart';

class SourceForge extends AppSource {
  SourceForge() {
    host = 'sourceforge.net';
  }

  @override
  String sourceSpecificStandardizeURL(String url) {
    RegExp standardUrlRegExB = RegExp('^https?://$host/p/[^/]+');
    RegExpMatch? match = standardUrlRegExB.firstMatch(url.toLowerCase());
    if (match != null) {
      url =
          'https://${Uri.parse(url.substring(0, match.end)).host}/projects/${url.substring(Uri.parse(url.substring(0, match.end)).host.length + '/projects/'.length + 1)}';
    }
    RegExp standardUrlRegExA = RegExp('^https?://$host/projects/[^/]+');
    match = standardUrlRegExA.firstMatch(url.toLowerCase());
    if (match == null) {
      throw InvalidURLError(name);
    }
    return url.substring(0, match.end);
  }

  @override
  Future<APKDetails> getLatestAPKDetails(
    String standardUrl,
    Map<String, dynamic> additionalSettings,
  ) async {
    Response res = await sourceRequest('$standardUrl/rss?path=/');
    if (res.statusCode == 200) {
      var parsedHtml = parse(res.body);
      var allDownloadLinks =
          parsedHtml.querySelectorAll('guid').map((e) => e.innerHtml).toList();
      getVersion(String url) {
        try {
          var tokens = url.split('/');
          var fi = tokens.indexOf('files');
          return tokens[tokens[fi + 2] == 'download' ? fi - 1 : fi + 1];
        } catch (e) {
          return null;
        }
      }

      String? version = getVersion(allDownloadLinks[0]);
      if (version == null) {
        throw NoVersionError();
      }
      var apkUrlListAllReleases = allDownloadLinks
          .where((element) => element.toLowerCase().endsWith('.apk/download'))
          .toList();
      var apkUrlList =
          apkUrlListAllReleases // This can be used skipped for fallback support later
              .where((element) => getVersion(element) == version)
              .toList();
      return APKDetails(
          version,
          getApkUrlsFromUrls(apkUrlList),
          AppNames(
              name, standardUrl.substring(standardUrl.lastIndexOf('/') + 1)));
    } else {
      throw getObtainiumHttpError(res);
    }
  }
}
