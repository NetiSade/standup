import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
// initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
  var initializationSettingsAndroid = AndroidInitializationSettings('exercise');
  var initializationSettingsIOS = IOSInitializationSettings(
      onDidReceiveLocalNotification: onDidReceiveLocalNotification);
  var initializationSettings = InitializationSettings(
      initializationSettingsAndroid, initializationSettingsIOS);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onSelectNotification: selectNotification);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StandUp!',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  int _workDurationInMin = 45;
  int _breakDurationInMin = 5;
  Timer _timer;
  bool _running = false;
  DateTime _nextAlert;
  Duration _timeUntilNextAlert;
  bool _autoRestart = false;
  bool _inBreak = false;

  @override
  void initState() {
    _getAlertTimeFromLocal();
    _getPrefsFromLocal();
    super.initState();
  }

  @override
  void dispose() {
    _timer.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('StandUP!'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _getTimeText(),
              style: Theme.of(context)
                  .textTheme
                  .headline1
                  .copyWith(color: Theme.of(context).primaryColor),
            ),
            if (_running && _autoRestart)
              Text(
                _inBreak ? '⛱️ Break Time ⛱️' : '🛠️ Work Time 🛠️',
                style: Theme.of(context)
                    .textTheme
                    .headline6
                    .copyWith(color: Theme.of(context).accentColor),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (!_running) {
              _startTimer();
            } else {
              _stopTimer();
            }
          },
          child: AnimatedCrossFade(
            firstChild: Icon(Icons.play_arrow),
            secondChild: Icon(Icons.stop),
            crossFadeState:
                _running ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 300),
          )),
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            DrawerHeader(
                child: Text('Settings',
                    style: Theme.of(context)
                        .textTheme
                        .headline6
                        .copyWith(color: Theme.of(context).accentColor))),
            SwitchListTile(
              title: Text("Auto Restart"),
              onChanged: (bool value) {
                setState(() {
                  _autoRestart = value;
                  _savePrefsToLocal();
                });
              },
              value: _autoRestart,
            ),
            ListTile(
              title: Text('Work Time:'),
              trailing: Container(
                width: 150,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    IconButton(
                        icon: Icon(
                          Icons.remove,
                          color: Theme.of(context).primaryColor,
                        ),
                        onPressed: () {
                          if (_workDurationInMin > 20)
                            setState(() {
                              _workDurationInMin -= 5;
                              _savePrefsToLocal();
                            });
                        }),
                    Text(_workDurationInMin.toString(),
                        style: Theme.of(context)
                            .textTheme
                            .subtitle1
                            .copyWith(color: Theme.of(context).accentColor)),
                    IconButton(
                        icon: Icon(
                          Icons.add,
                          color: Theme.of(context).primaryColor,
                        ),
                        onPressed: () {
                          if (_workDurationInMin < 60)
                            setState(() {
                              _workDurationInMin += 5;
                              _savePrefsToLocal();
                            });
                        }),
                  ],
                ),
              ),
            ),
            ListTile(
              title: Text('Break Time:'),
              trailing: Container(
                width: 150,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    IconButton(
                        icon: Icon(
                          Icons.remove,
                          color: Theme.of(context).primaryColor,
                        ),
                        onPressed: () {
                          if (_breakDurationInMin > 1)
                            setState(() {
                              _breakDurationInMin -= 1;
                            });
                        }),
                    Text(_breakDurationInMin.toString(),
                        style: Theme.of(context)
                            .textTheme
                            .subtitle1
                            .copyWith(color: Theme.of(context).accentColor)),
                    IconButton(
                        icon: Icon(
                          Icons.add,
                          color: Theme.of(context).primaryColor,
                        ),
                        onPressed: () {
                          if (_breakDurationInMin < 15)
                            setState(() {
                              _breakDurationInMin += 1;
                            });
                        }),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _startTimer() {
    _nextAlert = DateTime.now().add(
        Duration(minutes: _inBreak ? _breakDurationInMin : _workDurationInMin));
    if (_nextAlert == null || _nextAlert.isBefore(DateTime.now())) {
      return;
    }

    if (_timer != null) {
      _timer.cancel();
    }

    _updateTimeUntilNextAlert();

    _timer = new Timer.periodic(
      Duration(seconds: 1),
      _onTimerTick,
    );

    _schedulNotification();
    _saveAlertTimeToLocal();
    _savePrefsToLocal();

    setState(() {
      _running = true;
    });
  }

  _onTimerTick(Timer timer) {
    if (_nextAlert == null || DateTime.now().isAfter(_nextAlert)) {
      if (_autoRestart) {
        setState(() {
          _inBreak = !_inBreak;
        });
        _startTimer();
      } else {
        timer.cancel();
        setState(() {
          _running = false;
        });
      }
    } else {
      _updateTimeUntilNextAlert();
    }
  }

  _updateTimeUntilNextAlert() {
    final diff = _timeUntilNextAlert = _nextAlert.difference(DateTime.now());
    if (_nextAlert == null || diff.inSeconds < 0) {
      return;
    }
    setState(() {
      _timeUntilNextAlert = diff;
    });
  }

  _saveAlertTimeToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nextAlert', _nextAlert.millisecondsSinceEpoch);
  }

  _savePrefsToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('workDurationInMin', _workDurationInMin);
    await prefs.setInt('breakDurationInMin', _breakDurationInMin);
    await prefs.setBool('autoRestart', _autoRestart);
    await prefs.setBool('inBreak', _inBreak);
  }

  _clearNextAlertFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nextAlert', 0);
  }

  _getAlertTimeFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('nextAlert')) {
      final timestamp = prefs.getInt('nextAlert');
      if (timestamp <= 0) {
        return;
      }
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (dateTime.isAfter(DateTime.now())) {
        _nextAlert = dateTime;
        _startTimer();
      } else {
        _clearNextAlertFromLocal();
        setState(() {
          _inBreak = false;
        });
      }
    }
  }

  _getPrefsFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('workDurationInMin')) {
      _workDurationInMin = prefs.getInt('workDurationInMin');
    }
    if (prefs.containsKey('breakDurationInMin')) {
      _breakDurationInMin = prefs.getInt('breakDurationInMin');
    }
    if (prefs.containsKey('autoRestart')) {
      _autoRestart = prefs.getBool('autoRestart');
    }
    if (prefs.containsKey('inBreak')) {
      _inBreak = prefs.getBool('inBreak');
    }
  }

  _stopTimer() async {
    _timer.cancel();
    await flutterLocalNotificationsPlugin.cancelAll();
    setState(() {
      _running = false;
      _inBreak = false;
    });

    _clearNextAlertFromLocal();
  }

  String _getTimeText() {
    if (!_running) {
      return '$_workDurationInMin:00';
    }
    return _printDuration(_timeUntilNextAlert);
  }

  String _printDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<void> _schedulNotification() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    final scheduledNotificationDateTime = _nextAlert;
    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'StandUp', 'StandUpReminder', 'StandUp take 5 reminder',
        importance: Importance.Max,
        priority: Priority.Max,
        enableVibration: true,
        enableLights: true,
        channelShowBadge: true,
        playSound: true,
        autoCancel: true,
        showWhen: true);
    final iOSPlatformChannelSpecifics = IOSNotificationDetails();
    final platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.schedule(
      0,
      'StundUp!',
      _inBreak ? 'Time to back to work!' : 'StundUp and take a break!',
      scheduledNotificationDateTime,
      platformChannelSpecifics,
      androidAllowWhileIdle: true,
    );
  }
}

Future onDidReceiveLocalNotification(
    int id, String title, String body, String payload) {
  print(
      'onDidReceiveLocalNotification title: $title | body: $body | payload: $payload');
  return Future.value();
}

Future selectNotification(String payload) {
  print('selectNotification payload: $payload');
  return Future.value();
}
