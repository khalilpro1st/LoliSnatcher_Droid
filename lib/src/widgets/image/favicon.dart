import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:lolisnatcher/src/services/dio_downloader.dart';
import 'package:lolisnatcher/src/widgets/image/custom_image_provider.dart';

import '../../utils/logger.dart';

class Favicon extends StatefulWidget {
  final String faviconURL;
  const Favicon(this.faviconURL, {Key? key}) : super(key: key);

  @override
  State<Favicon> createState() => _FaviconState();
}

class _FaviconState extends State<Favicon> {
  bool isFailed = false;
  CancelToken? _dioCancelToken;
  DioDownloader? client;
  ImageProvider? faviconProvider;

  static const double iconSize = 20;

  @override
  void didUpdateWidget(Favicon oldWidget) {
    // force redraw on tab change
    if (oldWidget.faviconURL != widget.faviconURL) {
      // print('favicon changed');
      restartLoading();
    }
    super.didUpdateWidget(oldWidget);
  }

  Future<void> downloadFavicon() async {
    _dioCancelToken = CancelToken();
    client = DioDownloader(
      widget.faviconURL,
      cancelToken: _dioCancelToken,
      onError: _onError,
      onDone: (Uint8List bytes, String url) {
        if (!isFailed) {
          faviconProvider = getImageProvider(bytes, url);
          updateState();
        }
      },
      cacheEnabled: true,
      cacheFolder: 'favicons',
      timeoutTime: 5000,
      fileNameExtras: 'favicon_'
    );
    client!.runRequest();
    // client!.runRequestIsolate();
    return;
  }

  ImageProvider getImageProvider(Uint8List bytes, String url) {
    return MemoryImageTest(bytes, imageUrl: url);
  }

  void _onError(Exception error) {
    //// Error handling
    if (error is DioError && CancelToken.isCancel(error)) {
      // print('Canceled by user: $error');
    } else {
      isFailed = true;
      updateState();
      // print('Dio request cancelled: $error');
    }
  }

  @override
  void initState() {
    super.initState();
    downloadFavicon();
  }

  void updateState() {
    if (mounted) setState(() {});
  }

  void restartLoading() {
    disposables();

    isFailed = false;

    updateState();

    downloadFavicon();
  }

  void disposeClient() {
    client?.dispose();
    client = null;
  }

  @override
  void dispose() {
    disposables();
    super.dispose();
  }

  void disposables() {
    // faviconProvider?.evict();
    faviconProvider = null;
    if (!(_dioCancelToken != null && _dioCancelToken!.isCancelled)) {
      _dioCancelToken?.cancel();
    }
    disposeClient();
  }

  Widget loadingElementBuilder(BuildContext ctx) {
    // if (loadingProgress == null && !settingsHandler.thumbnailCache) {
    //   // Resulting image for network loaded thumbnail
    //   return child;
    // }

    if (isFailed) {
      return Center(
        child: InkWell(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.broken_image, size: iconSize),
            ],
          ),
          onTap: () {
            isFailed = false;
            restartLoading();
          },
        ),
      );
    } else {
      return const Icon(null); // Center(child: CircularProgressIndicator());
    }
  }

  @override
  Widget build(BuildContext context) {
    // print('Favicon build ${widget.faviconURL}');

    // return const SizedBox();

    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (faviconProvider == null) loadingElementBuilder(context),

          AnimatedOpacity(
            opacity: faviconProvider != null ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: faviconProvider != null
                ? Image(
                    image: faviconProvider!,
                    width: iconSize,
                    height: iconSize,
                    errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                      Logger.Inst().log("Failed to load favicon: ${widget.faviconURL}", "Favicon", "build", LogTypes.imageInfo);
                      isFailed = true;
                      return loadingElementBuilder(context);
                      // return const Icon(Icons.broken_image, size: iconSize);
                    },
                  )
                : null,
          ),

          // Image(
          //   image: NetworkImage(widget.faviconURL),
          //   width: iconSize,
          //   height: iconSize,
          //   errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
          //     return const Icon(Icons.broken_image, size: iconSize);
          //   },
          // ),
        ],
      ),
    );
  }
}
