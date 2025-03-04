import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:lolisnatcher/src/data/booru_item.dart';
import 'package:lolisnatcher/src/handlers/service_handler.dart';
import 'package:lolisnatcher/src/widgets/common/settings_widgets.dart';
import 'package:lolisnatcher/src/widgets/thumbnail/thumbnail.dart';

class UnknownViewerPlaceholder extends StatelessWidget {
  const UnknownViewerPlaceholder({Key? key, required this.item, required this.index}) : super(key: key);

  final BooruItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Thumbnail(
              item: item,
              index: index,
              isStandalone: false,
              ignoreColumnsCount: true,
            ),
            LayoutBuilder(
              builder: (BuildContext layoutContext, BoxConstraints constraints) {
                return Container(
                  color: Colors.black87,
                  width: constraints.maxWidth / 2,
                  height: 200,
                  child: Center(
                    child: SizedBox(
                      child: SettingsButton(
                        name: 'Unknown file format, click here to open in browser',
                        action: () {
                          ServiceHandler.launchURL(item.postURL);
                        },
                        icon: const Icon(CupertinoIcons.question),
                        drawTopBorder: true,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
