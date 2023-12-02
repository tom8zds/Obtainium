import 'package:easy_localization/easy_localization.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart';
import 'package:obtainiumi/components/generated_form.dart';
import 'package:obtainiumi/custom_errors.dart';
import 'package:obtainiumi/providers/source_provider.dart';

class SteamMobile extends AppSource {
  SteamMobile() {
    host = 'store.steampowered.com';
    name = tr('steam');
    additionalSourceAppSpecificSettingFormItems = [
      [
        GeneratedFormDropdown('app', apks.entries.toList(),
            label: tr('app'), defaultValue: apks.entries.toList()[0].key)
      ]
    ];
  }

  final apks = {'steam': tr('steamMobile'), 'steam-chat-app': tr('steamChat')};

  @override
  String sourceSpecificStandardizeURL(String url) {
    return 'https://$host';
  }

  @override
  Future<APKDetails> getLatestAPKDetails(
    String standardUrl,
    Map<String, dynamic> additionalSettings,
  ) async {
    Response res = await sourceRequest('https://$host/mobile');
    if (res.statusCode == 200) {
      var apkNamePrefix = additionalSettings['app'] as String?;
      if (apkNamePrefix == null) {
        throw NoReleasesError();
      }
      String apkInURLRegexPattern =
          '/$apkNamePrefix-([0-9]+\\.)*[0-9]+\\.apk\$';
      var links = parse(res.body)
          .querySelectorAll('a')
          .map((e) => e.attributes['href'] ?? '')
          .where((e) => RegExp('https://.*$apkInURLRegexPattern').hasMatch(e))
          .toList();

      if (links.isEmpty) {
        throw NoReleasesError();
      }
      var versionMatch = RegExp(apkInURLRegexPattern).firstMatch(links[0]);
      if (versionMatch == null) {
        throw NoVersionError();
      }
      var version = links[0].substring(
          versionMatch.start + apkNamePrefix.length + 2, versionMatch.end - 4);
      var apkUrls = [links[0]];
      return APKDetails(version, getApkUrlsFromUrls(apkUrls),
          AppNames(name, apks[apkNamePrefix]!));
    } else {
      throw getObtainiumHttpError(res);
    }
  }
}
