import 'dart:async';

import 'package:flutter/material.dart';

import 'package:lolisnatcher/src/handlers/settings_handler.dart';
import 'package:lolisnatcher/src/utils/logger.dart';
import 'package:lolisnatcher/src/widgets/common/settings_widgets.dart';

class LoggerPage extends StatefulWidget {
  const LoggerPage({Key? key}) : super(key: key);
  @override
  State<LoggerPage> createState() => _LoggerPageState();
}

class _LoggerPageState extends State<LoggerPage> {
  final SettingsHandler settingsHandler = SettingsHandler.instance;
  List<LogTypes> ignoreLogTypes = [];

  @override
  void initState() {
    super.initState();
    ignoreLogTypes = settingsHandler.ignoreLogTypes;
  }

  @override
  void dispose() {
    super.dispose();
  }

  //called when page is closed, sets settingshandler variables and then writes settings to disk
  Future<bool> _onWillPop() async {
    settingsHandler.ignoreLogTypes = ignoreLogTypes;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    bool allLogTypesEnabled = ignoreLogTypes.toSet().intersection(LogTypes.values.toSet()).isEmpty;
    return WillPopScope(
      onWillPop: _onWillPop,
      child:Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text("Logger"),
          actions: [
            Switch(
              value: allLogTypesEnabled,
              onChanged: (bool newValue) {
                setState(() {
                  if (newValue) {
                    ignoreLogTypes = [];
                    Logger.Inst().log("Enabled all log types", "LoggerPage", "build", LogTypes.settingsLoad);
                  } else {
                    ignoreLogTypes = [...LogTypes.values];
                    Logger.Inst().log("Disabled all log types", "LoggerPage", "build", LogTypes.settingsLoad);
                  }
                });
              }
            ),
              ],
            ),
        body: Center(
          child: ListView.builder(
            itemCount: LogTypes.values.length,
            itemBuilder: (context, index) {
              return SettingsToggle(
                value: !ignoreLogTypes.contains(LogTypes.values[index]),
                onChanged: (newValue) {
                  setState(() {
                    if (ignoreLogTypes.contains(LogTypes.values[index])){
                      ignoreLogTypes.remove(LogTypes.values[index]);
                      Logger.Inst().log("Enabled logging for ${LogTypes.values[index]}", "LoggerPage", "build", LogTypes.settingsLoad);
                    } else {
                      ignoreLogTypes.add(LogTypes.values[index]);
                      Logger.Inst().log("Disabled logging for ${LogTypes.values[index]}", "LoggerPage", "build", LogTypes.settingsLoad);
                    }
                  });
                },
                title: LogTypes.values[index].toString().split('.').last,
              );
            },
          ),
        ),
      ),
    );
  }
}

