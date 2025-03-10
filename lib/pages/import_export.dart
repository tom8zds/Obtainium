import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:obtainiumi/components/custom_app_bar.dart';
import 'package:obtainiumi/components/generated_form.dart';
import 'package:obtainiumi/components/generated_form_modal.dart';
import 'package:obtainiumi/custom_errors.dart';
import 'package:obtainiumi/providers/apps_provider.dart';
import 'package:obtainiumi/providers/settings_provider.dart';
import 'package:obtainiumi/providers/source_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ImportExportPage extends StatefulWidget {
  const ImportExportPage({super.key});

  @override
  State<ImportExportPage> createState() => _ImportExportPageState();
}

class _ImportExportPageState extends State<ImportExportPage> {
  bool importInProgress = false;

  @override
  Widget build(BuildContext context) {
    SourceProvider sourceProvider = SourceProvider();
    var appsProvider = context.watch<AppsProvider>();
    var settingsProvider = context.watch<SettingsProvider>();

    var outlineButtonStyle = ButtonStyle(
      shape: MaterialStateProperty.all(
        StadiumBorder(
          side: BorderSide(
            width: 1,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );

    urlListImport({String? initValue, bool overrideInitValid = false}) {
      showDialog<Map<String, dynamic>?>(
          context: context,
          builder: (BuildContext ctx) {
            return GeneratedFormModal(
              initValid: overrideInitValid,
              title: tr('importFromURLList'),
              items: [
                [
                  GeneratedFormTextField('appURLList',
                      defaultValue: initValue ?? '',
                      label: tr('appURLList'),
                      max: 7,
                      additionalValidators: [
                        (dynamic value) {
                          if (value != null && value.isNotEmpty) {
                            var lines = value.trim().split('\n');
                            for (int i = 0; i < lines.length; i++) {
                              try {
                                sourceProvider.getSource(lines[i]);
                              } catch (e) {
                                return '${tr('line')} ${i + 1}: $e';
                              }
                            }
                          }
                          return null;
                        }
                      ])
                ]
              ],
            );
          }).then((values) {
        if (values != null) {
          var urls = (values['appURLList'] as String).split('\n');
          setState(() {
            importInProgress = true;
          });
          appsProvider.addAppsByURL(urls).then((errors) {
            if (errors.isEmpty) {
              showMessage(tr('importedX', args: [plural('apps', urls.length)]),
                  context);
            } else {
              showDialog(
                  context: context,
                  builder: (BuildContext ctx) {
                    return ImportErrorDialog(
                        urlsLength: urls.length, errors: errors);
                  });
            }
          }).catchError((e) {
            showError(e, context);
          }).whenComplete(() {
            setState(() {
              importInProgress = false;
            });
          });
        }
      });
    }

    runObtainiumExport({bool pickOnly = false}) async {
      HapticFeedback.selectionClick();
      appsProvider
          .exportApps(
              pickOnly:
                  pickOnly || (await settingsProvider.getExportDir()) == null,
              sp: settingsProvider)
          .then((String? result) {
        if (result != null) {
          showMessage(tr('exportedTo', args: [result]), context);
        }
      }).catchError((e) {
        showError(e, context);
      });
    }

    runObtainiumImport() {
      HapticFeedback.selectionClick();
      FilePicker.platform.pickFiles().then((result) {
        setState(() {
          importInProgress = true;
        });
        if (result != null) {
          String data = File(result.files.single.path!).readAsStringSync();
          try {
            jsonDecode(data);
          } catch (e) {
            throw ObtainiumError(tr('invalidInput'));
          }
          appsProvider.importApps(data).then((value) {
            var cats = settingsProvider.categories;
            appsProvider.apps.forEach((key, value) {
              for (var c in value.app.categories) {
                if (!cats.containsKey(c)) {
                  cats[c] = generateRandomLightColor().value;
                }
              }
            });
            appsProvider.addMissingCategories(settingsProvider);
            showMessage(
                tr('importedX', args: [plural('apps', value)]), context);
          });
        } else {
          // User canceled the picker
        }
      }).catchError((e) {
        showError(e, context);
      }).whenComplete(() {
        setState(() {
          importInProgress = false;
        });
      });
    }

    runUrlImport() {
      FilePicker.platform.pickFiles().then((result) {
        if (result != null) {
          urlListImport(
              overrideInitValid: true,
              initValue: RegExp('https?://[^"]+')
                  .allMatches(
                      File(result.files.single.path!).readAsStringSync())
                  .map((e) => e.input.substring(e.start, e.end))
                  .toSet()
                  .toList()
                  .where((url) {
                try {
                  sourceProvider.getSource(url);
                  return true;
                } catch (e) {
                  return false;
                }
              }).join('\n'));
        }
      });
    }

    runSourceSearch(AppSource source) {
      () async {
        var values = await showDialog<Map<String, dynamic>?>(
            context: context,
            builder: (BuildContext ctx) {
              return GeneratedFormModal(
                title: tr('searchX', args: [source.name]),
                items: [
                  [
                    GeneratedFormTextField('searchQuery',
                        label: tr('searchQuery'))
                  ],
                  ...source.searchQuerySettingFormItems.map((e) => [e])
                ],
              );
            });
        if (values != null &&
            (values['searchQuery'] as String?)?.isNotEmpty == true) {
          setState(() {
            importInProgress = true;
          });
          var urlsWithDescriptions = await source
              .search(values['searchQuery'] as String, querySettings: values);
          if (urlsWithDescriptions.isNotEmpty) {
            var selectedUrls =
                // ignore: use_build_context_synchronously
                await showDialog<List<String>?>(
                    context: context,
                    builder: (BuildContext ctx) {
                      return UrlSelectionModal(
                        urlsWithDescriptions: urlsWithDescriptions,
                        selectedByDefault: false,
                      );
                    });
            if (selectedUrls != null && selectedUrls.isNotEmpty) {
              var errors = await appsProvider.addAppsByURL(selectedUrls);
              if (errors.isEmpty) {
                // ignore: use_build_context_synchronously
                showMessage(
                    tr('importedX',
                        args: [plural('apps', selectedUrls.length)]),
                    context);
              } else {
                // ignore: use_build_context_synchronously
                showDialog(
                    context: context,
                    builder: (BuildContext ctx) {
                      return ImportErrorDialog(
                          urlsLength: selectedUrls.length, errors: errors);
                    });
              }
            }
          } else {
            throw ObtainiumError(tr('noResults'));
          }
        }
      }()
          .catchError((e) {
        showError(e, context);
      }).whenComplete(() {
        setState(() {
          importInProgress = false;
        });
      });
    }

    runMassSourceImport(MassAppUrlSource source) {
      () async {
        var values = await showDialog<Map<String, dynamic>?>(
            context: context,
            builder: (BuildContext ctx) {
              return GeneratedFormModal(
                title: tr('importX', args: [source.name]),
                items: source.requiredArgs
                    .map((e) => [GeneratedFormTextField(e, label: e)])
                    .toList(),
              );
            });
        if (values != null) {
          setState(() {
            importInProgress = true;
          });
          var urlsWithDescriptions = await source.getUrlsWithDescriptions(
              values.values.map((e) => e.toString()).toList());
          var selectedUrls =
              // ignore: use_build_context_synchronously
              await showDialog<List<String>?>(
                  context: context,
                  builder: (BuildContext ctx) {
                    return UrlSelectionModal(
                        urlsWithDescriptions: urlsWithDescriptions);
                  });
          if (selectedUrls != null) {
            var errors = await appsProvider.addAppsByURL(selectedUrls);
            if (errors.isEmpty) {
              // ignore: use_build_context_synchronously
              showMessage(
                  tr('importedX', args: [plural('apps', selectedUrls.length)]),
                  context);
            } else {
              // ignore: use_build_context_synchronously
              showDialog(
                  context: context,
                  builder: (BuildContext ctx) {
                    return ImportErrorDialog(
                        urlsLength: selectedUrls.length, errors: errors);
                  });
            }
          }
        }
      }()
          .catchError((e) {
        showError(e, context);
      }).whenComplete(() {
        setState(() {
          importInProgress = false;
        });
      });
    }

    return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return [
              SliverOverlapAbsorber(
                handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: CustomAppBar(title: tr('importExport')),
              ),
            ];
          },
          body: Builder(builder: (context) {
            return CustomScrollView(slivers: <Widget>[
              SliverOverlapInjector(
                handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              ),
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                sliver: SliverList.list(
                  children: [
                    FutureBuilder(
                      future: settingsProvider.getExportDir(),
                      builder: (context, snapshot) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    style: outlineButtonStyle,
                                    onPressed: appsProvider.apps.isEmpty ||
                                            importInProgress
                                        ? null
                                        : () {
                                            runObtainiumExport(pickOnly: true);
                                          },
                                    child: Text(tr('pickExportDir')),
                                  ),
                                ),
                                const SizedBox(
                                  width: 16,
                                ),
                                Expanded(
                                  child: TextButton(
                                    style: outlineButtonStyle,
                                    onPressed: appsProvider.apps.isEmpty ||
                                            importInProgress ||
                                            snapshot.data == null
                                        ? null
                                        : runObtainiumExport,
                                    child: Text(tr('obtainiumExport')),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 8,
                            ),
                            Row(
                              children: [
                                Expanded(
                                    child: TextButton(
                                        style: outlineButtonStyle,
                                        onPressed: importInProgress
                                            ? null
                                            : runObtainiumImport,
                                        child: Text(tr('obtainiumImport')))),
                              ],
                            ),
                            if (snapshot.data != null)
                              Column(
                                children: [
                                  const SizedBox(height: 16),
                                  GeneratedForm(
                                      items: [
                                        [
                                          GeneratedFormSwitch(
                                            'autoExportOnChanges',
                                            label: tr('autoExportOnChanges'),
                                            defaultValue: settingsProvider
                                                .autoExportOnChanges,
                                          )
                                        ]
                                      ],
                                      onValueChanges:
                                          (value, valid, isBuilding) {
                                        if (valid && !isBuilding) {
                                          if (value['autoExportOnChanges'] !=
                                              null) {
                                            settingsProvider
                                                    .autoExportOnChanges =
                                                value['autoExportOnChanges'] ==
                                                    true;
                                          }
                                        }
                                      }),
                                ],
                              ),
                          ],
                        );
                      },
                    ),
                    if (importInProgress)
                      const Column(
                        children: [
                          SizedBox(
                            height: 14,
                          ),
                          LinearProgressIndicator(),
                          SizedBox(
                            height: 14,
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          const Divider(
                            height: 32,
                          ),
                          TextButton(
                              onPressed:
                                  importInProgress ? null : urlListImport,
                              child: Text(
                                tr('importFromURLList'),
                              )),
                          const SizedBox(height: 8),
                          TextButton(
                              onPressed: importInProgress ? null : runUrlImport,
                              child: Text(
                                tr('importFromURLsInFile'),
                              )),
                        ],
                      ),
                    ...sourceProvider.sources
                        .where((element) => element.canSearch)
                        .map((source) => Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 8),
                                  TextButton(
                                      onPressed: importInProgress
                                          ? null
                                          : () {
                                              runSourceSearch(source);
                                            },
                                      child: Text(
                                          tr('searchX', args: [source.name])))
                                ])),
                    ...sourceProvider.massUrlSources.map((source) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 8),
                              TextButton(
                                  onPressed: importInProgress
                                      ? null
                                      : () {
                                          runMassSourceImport(source);
                                        },
                                  child:
                                      Text(tr('importX', args: [source.name])))
                            ])),
                  ],
                ),
              )
            ]);
          }),
        ),
        persistentFooterButtons: [
          Center(
            child: Text(tr('importedAppsIdDisclaimer'),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
          ),
        ]);
  }
}

class ImportErrorDialog extends StatefulWidget {
  const ImportErrorDialog(
      {super.key, required this.urlsLength, required this.errors});

  final int urlsLength;
  final List<List<String>> errors;

  @override
  State<ImportErrorDialog> createState() => _ImportErrorDialogState();
}

class _ImportErrorDialogState extends State<ImportErrorDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(tr('importErrors')),
      content:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          tr('importedXOfYApps', args: [
            (widget.urlsLength - widget.errors.length).toString(),
            widget.urlsLength.toString()
          ]),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        Text(
          tr('followingURLsHadErrors'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        ...widget.errors.map((e) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(
                  height: 16,
                ),
                Text(e[0]),
                Text(
                  e[1],
                  style: const TextStyle(fontStyle: FontStyle.italic),
                )
              ]);
        })
      ]),
      actions: [
        TextButton(
            onPressed: () {
              Navigator.of(context).pop(null);
            },
            child: Text(tr('okay')))
      ],
    );
  }
}

// ignore: must_be_immutable
class UrlSelectionModal extends StatefulWidget {
  UrlSelectionModal(
      {super.key,
      required this.urlsWithDescriptions,
      this.selectedByDefault = true,
      this.onlyOneSelectionAllowed = false});

  Map<String, List<String>> urlsWithDescriptions;
  bool selectedByDefault;
  bool onlyOneSelectionAllowed;

  @override
  State<UrlSelectionModal> createState() => _UrlSelectionModalState();
}

class _UrlSelectionModalState extends State<UrlSelectionModal> {
  Map<MapEntry<String, List<String>>, bool> urlWithDescriptionSelections = {};

  @override
  void initState() {
    super.initState();
    for (var url in widget.urlsWithDescriptions.entries) {
      urlWithDescriptionSelections.putIfAbsent(url,
          () => widget.selectedByDefault && !widget.onlyOneSelectionAllowed);
    }
    if (widget.selectedByDefault && widget.onlyOneSelectionAllowed) {
      selectOnlyOne(widget.urlsWithDescriptions.entries.first.key);
    }
  }

  selectOnlyOne(String url) {
    for (var uwd in urlWithDescriptionSelections.keys) {
      urlWithDescriptionSelections[uwd] = uwd.key == url;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(
          widget.onlyOneSelectionAllowed ? tr('selectURL') : tr('selectURLs')),
      content: Column(children: [
        ...urlWithDescriptionSelections.keys.map((urlWithD) {
          selectThis(bool? value) {
            setState(() {
              value ??= false;
              if (value! && widget.onlyOneSelectionAllowed) {
                selectOnlyOne(urlWithD.key);
              } else {
                urlWithDescriptionSelections[urlWithD] = value!;
              }
            });
          }

          var urlLink = GestureDetector(
              onTap: () {
                launchUrlString(urlWithD.key,
                    mode: LaunchMode.externalApplication);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    urlWithD.value[0],
                    style: const TextStyle(
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.start,
                  ),
                  Text(
                    Uri.parse(urlWithD.key).host,
                    style: const TextStyle(
                        decoration: TextDecoration.underline, fontSize: 12),
                  )
                ],
              ));

          var descriptionText = Text(
            urlWithD.value[1].length > 128
                ? '${urlWithD.value[1].substring(0, 128)}...'
                : urlWithD.value[1],
            style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
          );

          var selectedUrlsWithDs = urlWithDescriptionSelections.entries
              .where((e) => e.value)
              .toList();

          var singleSelectTile = ListTile(
            title: urlLink,
            subtitle: GestureDetector(
              onTap: () {
                setState(() {
                  selectOnlyOne(urlWithD.key);
                });
              },
              child: descriptionText,
            ),
            leading: Radio<String>(
              value: urlWithD.key,
              groupValue: selectedUrlsWithDs.isEmpty
                  ? null
                  : selectedUrlsWithDs.first.key.key,
              onChanged: (value) {
                setState(() {
                  selectOnlyOne(urlWithD.key);
                });
              },
            ),
          );

          var multiSelectTile = Row(children: [
            Checkbox(
                value: urlWithDescriptionSelections[urlWithD],
                onChanged: (value) {
                  selectThis(value);
                }),
            const SizedBox(
              width: 8,
            ),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  height: 8,
                ),
                urlLink,
                GestureDetector(
                  onTap: () {
                    selectThis(
                        !(urlWithDescriptionSelections[urlWithD] ?? false));
                  },
                  child: descriptionText,
                ),
                const SizedBox(
                  height: 8,
                )
              ],
            ))
          ]);

          return widget.onlyOneSelectionAllowed
              ? singleSelectTile
              : multiSelectTile;
        })
      ]),
      actions: [
        TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(tr('cancel'))),
        TextButton(
            onPressed:
                urlWithDescriptionSelections.values.where((b) => b).isEmpty
                    ? null
                    : () {
                        Navigator.of(context).pop(urlWithDescriptionSelections
                            .entries
                            .where((entry) => entry.value)
                            .map((e) => e.key.key)
                            .toList());
                      },
            child: Text(widget.onlyOneSelectionAllowed
                ? tr('pick')
                : tr('importX', args: [
                    plural(
                        'url',
                        urlWithDescriptionSelections.values
                            .where((b) => b)
                            .length)
                  ])))
      ],
    );
  }
}
