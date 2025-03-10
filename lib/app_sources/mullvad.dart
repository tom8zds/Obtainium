import 'package:html/parser.dart';
import 'package:http/http.dart';
import 'package:obtainiumi/app_sources/github.dart';
import 'package:obtainiumi/custom_errors.dart';
import 'package:obtainiumi/providers/source_provider.dart';

class Mullvad extends AppSource {
  Mullvad() {
    host = 'mullvad.net';
  }

  @override
  String sourceSpecificStandardizeURL(String url) {
    RegExp standardUrlRegEx = RegExp('^https?://$host');
    RegExpMatch? match = standardUrlRegEx.firstMatch(url.toLowerCase());
    if (match == null) {
      throw InvalidURLError(name);
    }
    return url.substring(0, match.end);
  }

  @override
  String? changeLogPageFromStandardUrl(String standardUrl) =>
      'https://github.com/mullvad/mullvadvpn-app/blob/master/CHANGELOG.md';

  @override
  Future<APKDetails> getLatestAPKDetails(
    String standardUrl,
    Map<String, dynamic> additionalSettings,
  ) async {
    Response res = await sourceRequest('$standardUrl/en/download/android');
    if (res.statusCode == 200) {
      var versions = parse(res.body)
          .querySelectorAll('p')
          .map((e) => e.innerHtml)
          .where((p) => p.contains('Latest version: '))
          .map((e) {
            var match = RegExp('[0-9]+(\\.[0-9]+)*').firstMatch(e);
            if (match == null) {
              return '';
            } else {
              return e.substring(match.start, match.end);
            }
          })
          .where((element) => element.isNotEmpty)
          .toList();
      if (versions.isEmpty) {
        throw NoVersionError();
      }
      String? changeLog;
      try {
        changeLog = (await GitHub().getLatestAPKDetails(
                'https://github.com/mullvad/mullvadvpn-app',
                {'fallbackToOlderReleases': true}))
            .changeLog;
      } catch (e) {
        // Ignore
      }
      return APKDetails(
          versions[0],
          getApkUrlsFromUrls(['https://mullvad.net/download/app/apk/latest']),
          AppNames(name, 'Mullvad-VPN'),
          changeLog: changeLog);
    } else {
      throw getObtainiumHttpError(res);
    }
  }
}
