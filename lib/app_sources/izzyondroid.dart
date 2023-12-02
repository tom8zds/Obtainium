import 'package:obtainiumi/app_sources/fdroid.dart';
import 'package:obtainiumi/custom_errors.dart';
import 'package:obtainiumi/providers/source_provider.dart';

class IzzyOnDroid extends AppSource {
  late FDroid fd;

  IzzyOnDroid() {
    host = 'izzysoft.de';
    fd = FDroid();
    additionalSourceAppSpecificSettingFormItems =
        fd.additionalSourceAppSpecificSettingFormItems;
    allowSubDomains = true;
  }

  @override
  String sourceSpecificStandardizeURL(String url) {
    RegExp standardUrlRegExA = RegExp('^https?://android.$host/repo/apk/[^/]+');
    RegExpMatch? match = standardUrlRegExA.firstMatch(url.toLowerCase());
    if (match == null) {
      RegExp standardUrlRegExB =
          RegExp('^https?://apt.$host/fdroid/index/apk/[^/]+');
      match = standardUrlRegExB.firstMatch(url.toLowerCase());
    }
    if (match == null) {
      throw InvalidURLError(name);
    }
    return url.substring(0, match.end);
  }

  @override
  Future<String?> tryInferringAppId(String standardUrl,
      {Map<String, dynamic> additionalSettings = const {}}) async {
    return fd.tryInferringAppId(standardUrl);
  }

  @override
  Future<APKDetails> getLatestAPKDetails(
    String standardUrl,
    Map<String, dynamic> additionalSettings,
  ) async {
    String? appId = await tryInferringAppId(standardUrl);
    return getAPKUrlsFromFDroidPackagesAPIResponse(
        await sourceRequest(
            'https://apt.izzysoft.de/fdroid/api/v1/packages/$appId'),
        'https://android.izzysoft.de/frepo/$appId',
        standardUrl,
        name,
        autoSelectHighestVersionCode:
            additionalSettings['autoSelectHighestVersionCode'] == true,
        trySelectingSuggestedVersionCode:
            additionalSettings['trySelectingSuggestedVersionCode'] == true,
        filterVersionsByRegEx: additionalSettings['filterVersionsByRegEx']);
  }
}
