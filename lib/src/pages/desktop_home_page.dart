import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:lolisnatcher/src/handlers/search_handler.dart';
import 'package:lolisnatcher/src/handlers/settings_handler.dart';
import 'package:lolisnatcher/src/handlers/snatch_handler.dart';
import 'package:lolisnatcher/src/pages/settings_page.dart';
import 'package:lolisnatcher/src/pages/snatcher_page.dart';
import 'package:lolisnatcher/src/services/get_perms.dart';
import 'package:lolisnatcher/src/widgets/common/flash_elements.dart';
import 'package:lolisnatcher/src/widgets/common/settings_widgets.dart';
import 'package:lolisnatcher/src/widgets/desktop/desktop_image_listener.dart';
import 'package:lolisnatcher/src/widgets/desktop/resizable_split_view.dart';
import 'package:lolisnatcher/src/widgets/gallery/tag_view.dart';
import 'package:lolisnatcher/src/widgets/preview/media_previews.dart';
import 'package:lolisnatcher/src/widgets/search/tag_search_box.dart';
import 'package:lolisnatcher/src/widgets/search/tag_search_button.dart';
import 'package:lolisnatcher/src/widgets/tabs/tab_booru_selector.dart';
import 'package:lolisnatcher/src/widgets/tabs/tab_buttons.dart';
import 'package:lolisnatcher/src/widgets/tabs/tab_selector.dart';

class DesktopHome extends StatelessWidget {
  const DesktopHome({Key? key}) : super(key: key);


  @override
  Widget build(BuildContext context) {
    final SettingsHandler settingsHandler = SettingsHandler.instance;
    final SearchHandler searchHandler = SearchHandler.instance;
    final SnatchHandler snatchHandler = SnatchHandler.instance;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        toolbarHeight: 60,
        backgroundColor: Theme.of(context).colorScheme.background,
        actions: <Widget>[
          // Obx(() {
          //   if (settingsHandler.booruList.isNotEmpty && searchHandler.list.isNotEmpty) {
          //     return const DesktopTabs();
          //   } else {
          //     return const SizedBox();
          //   }
          // }),
          Obx(() {
            if (settingsHandler.booruList.isNotEmpty && searchHandler.list.isNotEmpty) {
              // return const SizedBox(width: 5);
              return Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: const <Widget>[
                    SizedBox(width: 15),
                    TagSearchBox(),
                    TagSearchButton(),
                    Expanded(flex: 1, child: TabBooruSelector(true)),
                    Expanded(flex: 2, child: TabSelector()),
                    Expanded(flex: 2, child: TabButtons(false, WrapAlignment.start)),
                  ],
                ),
              );
            } else {
              return const SizedBox();
            }
          }),
          Obx(() {
            if (settingsHandler.booruList.isNotEmpty && searchHandler.list.isNotEmpty) {
              return SettingsButton(
                name: 'Snatcher',
                icon: Icon(Icons.download, color: Theme.of(context).colorScheme.onBackground),
                iconOnly: true,
                page: () => const SnatcherPage(),
              );
            } else {
              return const SizedBox();
            }
          }),
          Obx(() {
            if (settingsHandler.booruList.isEmpty || searchHandler.list.isEmpty) {
              return const Center(child: Text('Add Boorus in Settings'));
            } else {
              return const SizedBox();
            }
          }),
          SettingsButton(
            name: 'Settings',
            icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.onBackground),
            iconOnly: true,
            page: () => const SettingsPage(),
          ),
          Obx(() {
            if (searchHandler.list.isNotEmpty) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SettingsButton(
                    name: 'Save',
                    icon: Icon(Icons.save, color: Theme.of(context).colorScheme.onBackground),
                    iconOnly: true,
                    action: () {
                      getPerms();
                      // call a function to save the currently viewed image when the save button is pressed
                      if (searchHandler.currentTab.selected.isNotEmpty) {
                        snatchHandler.queue(
                          searchHandler.currentTab.getSelected(),
                          searchHandler.currentBooru,
                          settingsHandler.snatchCooldown,
                        );
                        searchHandler.currentTab.selected.value = [];
                      } else {
                        FlashElements.showSnackbar(
                          context: context,
                          title: const Text("No items selected", style: TextStyle(fontSize: 20)),
                          overrideLeadingIconWidget: const Text(" (」°ロ°)」 ", style: TextStyle(fontSize: 18)),
                        );
                      }
                    },
                  ),
                  if (searchHandler.currentTab.selected.isNotEmpty)
                    Positioned(
                      right: 2,
                      bottom: 5,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          border: Border.all(color: Theme.of(context).colorScheme.secondary, width: 1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Center(
                          child: FittedBox(
                            child: Text('${searchHandler.currentTab.selected.length}', style: TextStyle(color: Theme.of(context).colorScheme.onSecondary)),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            } else {
              return const SizedBox();
            }
          }),
        ],
      ),
      body: Center(
        child: ResizableSplitView(
          firstChild: ResizableSplitView(
            firstChild: const MediaPreviews(),
            secondChild: const DesktopTagListener(),
            startRatio: 0.66,
            minRatio: 0.33,
            maxRatio: 1,
            direction: SplitDirection.vertical,
            onRatioChange: (double newRatio) {
              // print('ratioChanged1 $newRatio');
              // TODO save to settings, but debounce the saving to file
            },
          ),
          secondChild: Obx(() => searchHandler.list.isEmpty ? const SizedBox() : DesktopImageListener(searchHandler.currentTab)),
          startRatio: 0.33,
          minRatio: 0.2,
          maxRatio: 0.8,
          onRatioChange: (double newRatio) {
            // print('ratioChanged2 $newRatio');
            // TODO save to settings, but debounce the saving to file
          },
        ),
      ),
    );
  }
}

class DesktopTagListener extends StatelessWidget {
  const DesktopTagListener({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final SearchHandler searchHandler = SearchHandler.instance;

    return Obx(() {
      if (searchHandler.list.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.secondary, width: 1),
        ),
        child: const TagView(),
      );
    });
  }
}
