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

class _MyHomePageState extends State<MyHomePage> {
  final _defaultDurationInMin = 45;
  Timer _timer;
  bool _running = false;
  DateTime _nextAlert;
  Duration _timeUntilNextAlert;

  @override
  void initState() {
    _getAlertTimeFromLocal();
    super.initState();
  }

  void _startTimer() {
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

    setState(() {
      _running = true;
    });
  }

  _onTimerTick(Timer timer) {
    if (_nextAlert == null || DateTime.now().isAfter(_nextAlert)) {
      timer.cancel();
      setState(() {
        _running = false;
      });
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
      }
    }
  }

  _stopTimer() async {
    _timer.cancel();
    await flutterLocalNotificationsPlugin.cancelAll();
    setState(() {
      _running = false;
    });
    _clearNextAlertFromLocal();
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
            )
          ],
        ),
      ),
      floatingActionButton: !_running
          ? FloatingActionButton(
              onPressed: () {
                _nextAlert = DateTime.now()
                    .add(Duration(minutes: _defaultDurationInMin));
                _startTimer();
              },
              tooltip: 'Start Timer',
              child: Icon(Icons.timer),
            )
          : FloatingActionButton(
              onPressed: _stopTimer,
              tooltip: 'Stop Timer',
              child: Icon(Icons.stop),
            ),
    );
  }

  String _getTimeText() {
    if (!_running) {
      return '$_defaultDurationInMin:00';
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
    var scheduledNotificationDateTime = _nextAlert;
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'StandUp', 'StandUpReminder', 'StandUp take 5 reminder',
        importance: Importance.Max,
        priority: Priority.Max,
        enableVibration: true,
        enableLights: true,
        channelShowBadge: true,
        playSound: true);
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    NotificationDetails platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.schedule(
      0,
      'StundUp!',
      'StundUp and take 5!',
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
