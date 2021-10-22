import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:internet_speed_test/callbacks_enum.dart';
import 'package:tuple/tuple.dart';

typedef void CancelListening();
typedef void DoneCallback(double transferRate, SpeedUnit unit);
typedef void ProgressCallback(
  double percent,
  double transferRate,
  SpeedUnit unit,
);
typedef void ErrorCallback(String errorMessage, String speedTestError);

class InternetSpeedTest {
  static const MethodChannel _channel =
      const MethodChannel('internet_speed_test');

  Map<int, Tuple3<ErrorCallback, ProgressCallback, DoneCallback>>
      _callbacksById = new Map();

  int downloadRate = 0;
  int uploadRate = 0;
  int downloadSteps = 0;
  int uploadSteps = 0;

  Future<void> _methodCallHandler(MethodCall call) async {
    print('arguments are ${call.arguments}');
    print('callbacks are $_callbacksById');

    int id = call.arguments["id"] ?? -1;

    switch (call.method) {
      case 'callListener':
        int type = call.arguments['type'] ?? -1;

        if (id == CallbacksEnum.START_DOWNLOAD_TESTING.index) {
          if (type == ListenerEnum.COMPLETE.index) {
            double transferRate = call.arguments['transferRate']?.toDouble() ?? 0.0;

            downloadSteps++;
            downloadRate +=
                int.parse((transferRate ~/ 1000).toString());
            print('download steps is $downloadSteps}');
            print('download steps is $downloadRate}');
            double average = (downloadRate ~/ downloadSteps).toDouble();
            SpeedUnit unit = SpeedUnit.Kbps;
            average /= 1000;
            unit = SpeedUnit.Mbps;

            _callbacksById[id]?.item3(average, unit);
            downloadSteps = 0;
            downloadRate = 0;
            _callbacksById.remove(id);
          } else if (type == ListenerEnum.ERROR.index) {
            String speedTestError = call.arguments["speedTestError"] ?? "Speed test error null";
            String errorMessage = call.arguments["errorMessage"] ?? "Error message null";

            print('onError : $speedTestError}');
            print('onError : $errorMessage');
            _callbacksById[id]?.item1(errorMessage, speedTestError);
            downloadSteps = 0;
            downloadRate = 0;
            _callbacksById.remove(id);
          } else if (type == ListenerEnum.PROGRESS.index) {
            double transferRate = call.arguments['transferRate']?.toDouble() ?? 0.0;
            double percent = call.arguments['percent']?.toDouble() ?? 0.0;

            double rate = (transferRate ~/ 1000).toDouble();
            print('rate is $rate');
            if (rate != 0) downloadSteps++;
            downloadRate += rate.toInt();
            SpeedUnit unit = SpeedUnit.Kbps;
            rate /= 1000;
            unit = SpeedUnit.Mbps;
            _callbacksById[id]?.item2(percent.toDouble(), rate, unit);
          }
        } else if (id == CallbacksEnum.START_UPLOAD_TESTING.index) {
          if (type == ListenerEnum.COMPLETE.index) {
            double transferRate = call.arguments['transferRate']?.toDouble() ?? 0.0;
            print('onComplete : $transferRate}');

            uploadSteps++;
            uploadRate +=
                int.parse((transferRate ~/ 1000).toString());
            print('download steps is $uploadSteps}');
            print('download steps is $uploadRate}');
            double average = (uploadRate ~/ uploadSteps).toDouble();
            SpeedUnit unit = SpeedUnit.Kbps;
            average /= 1000;
            unit = SpeedUnit.Mbps;
            _callbacksById[id]?.item3(average, unit);
            uploadSteps = 0;
            uploadRate = 0;
            _callbacksById.remove(id);
          } else if (type == ListenerEnum.ERROR.index) {
            String speedTestError = call.arguments["speedTestError"] ?? "Speed test error null";
            String errorMessage = call.arguments["errorMessage"] ?? "Error message null";

            print('onError : $speedTestError');
            print('onError : $errorMessage}');
            _callbacksById[id]?.item1(errorMessage, speedTestError);
          } else if (type == ListenerEnum.PROGRESS.index) {
            double transferRate = call.arguments['transferRate']?.toDouble() ?? 0.0;
            double percent = call.arguments['percent']?.toDouble() ?? 0.0;

            double rate = (transferRate ~/ 1000).toDouble();
            print('rate is $rate');
            if (rate != 0) uploadSteps++;
            uploadRate += rate.toInt();
            SpeedUnit unit = SpeedUnit.Kbps;
            rate /= 1000.0;
            unit = SpeedUnit.Mbps;
            _callbacksById[id]?.item2(percent.toDouble(), rate, unit);
          }
        }
        break;
      default:
        print(
            'TestFairy: Ignoring invoke from native. This normally shouldn\'t happen.');
    }

    _channel.invokeMethod("cancelListening", id);
  }

  Future<CancelListening> _startListening(
      Tuple3<ErrorCallback, ProgressCallback, DoneCallback> callback,
      CallbacksEnum callbacksEnum,
      String testServer,
      {Map<String, dynamic>? args,
      int fileSize = 200000}) async {
    _channel.setMethodCallHandler(_methodCallHandler);
    int currentListenerId = callbacksEnum.index;
    print('test $currentListenerId');
    _callbacksById[currentListenerId] = callback;
    await _channel.invokeMethod(
      "startListening",
      {
        'id': currentListenerId,
        'args': args,
        'testServer': testServer,
        'fileSize': fileSize,
      },
    );
    return () {
      _channel.invokeMethod("cancelListening", currentListenerId);
      _callbacksById.remove(currentListenerId);
    };
  }

  Future<CancelListening> startDownloadTesting(
      {required DoneCallback onDone,
      required ProgressCallback onProgress,
      required ErrorCallback onError,
      int fileSize = 200000,
      String testServer = 'http://ipv4.ikoula.testdebit.info/1M.iso'}) async {
    return await _startListening(Tuple3(onError, onProgress, onDone),
        CallbacksEnum.START_DOWNLOAD_TESTING, testServer,
        fileSize: fileSize);
  }

  Future<void> stopDownloadTest() async {
    await _channel.invokeMethod("stopDownloadTest", {
      "id": CallbacksEnum.STOP_DOWNLOAD_TEST.index
    });
  }

  Future<CancelListening> startUploadTesting({
    required DoneCallback onDone,
    required ProgressCallback onProgress,
    required ErrorCallback onError,
    int fileSize = 200000,
    String? authToken = null,
    String testServer = 'http://ipv4.ikoula.testdebit.info/',
  }) async {
    return await _startListening(Tuple3(onError, onProgress, onDone),
        CallbacksEnum.START_UPLOAD_TESTING, testServer, args: {"auth_token": authToken},
        fileSize: fileSize);
  }

  Future<void> stopUploadTest() async {
    await _channel.invokeMethod("stopUploadTest", {
      "id": CallbacksEnum.STOP_UPLOAD_TEST.index
    });
  }
}
