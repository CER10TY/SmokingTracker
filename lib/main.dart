import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:fluttertoast/fluttertoast.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smoking Tracker',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.brown,
      ),
      home: MyHomePage(title: 'Smoking tracker'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  Map<String, int> previousCigarettes = {
    "2019-01-21": 6,
    "2019-01-22": 2,
    "2019-01-23": 5,
    "2019-01-24": 5,
    "2019-01-25": 8,
    "2019-01-26": 0,
    "2019-01-27": 3,
    "2019-01-28": 5,
    "2019-01-29": 8,
    "2019-01-30": 8,
    "2019-01-31": 8,
    "2019-02-01": 4,
    "2019-02-02": 0};
  String lastCigarette = "<never>";

  void _incrementCounter() {
    String formattedTime = _formatDateOrTime(new DateTime.now(), "Time");
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      lastCigarette = "$formattedTime";
      _saveTodayToDB(lastCigarette, _counter);
      _counter++;
    });
  }

  Future<void> _exportToCSV() async {
    final directory = await getApplicationDocumentsDirectory();
    File csvFile = File("${directory.path}/smoking-consumption.csv");

    String csvString = "Date;Amount;\n";
    var consumption = await _getConsumptionFromDB();
    consumption.forEach((k,v) {
      csvString += "$k;$v;\n";
    });

    await csvFile.writeAsString(csvString, mode: FileMode.write, encoding: SystemEncoding(), flush: true);

    Fluttertoast.showToast(
        msg: "Exported to CSV...",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIos: 2,
        backgroundColor: Colors.brown,
        textColor: Colors.white,
        fontSize: 16.0
    );
  }

  Future<void> _exportToCSVDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Export to CSV'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Do you really want to export the statistics to CSV?'),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('Yes'),
              onPressed: () {
                _exportToCSV();
                Navigator.of(context).pop();
              },
            ),
            FlatButton(
              child: Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  
  void _showPreviousDaysFuture() {
    Navigator.of(context).push(
      new MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return new Scaffold(
              appBar: new AppBar(
                  title: const Text('Previous days'),
                  actions: <Widget>[
                    new IconButton(icon: const Icon(Icons.playlist_play), onPressed: _exportToCSVDialog)
                  ],
              ),
              body: FutureBuilder<Map<String, int>>(
                  future: _getConsumptionFromDB(),
                  builder: (BuildContext context, AsyncSnapshot<Map<String, int>> snapshot) {
                    switch (snapshot.connectionState) {
                      case ConnectionState.none:
                        return Text('Press button to start.');
                      case ConnectionState.active:
                      case ConnectionState.waiting:
                        return Text('Awaiting result...');
                      case ConnectionState.done:
                        if (snapshot.hasError)
                          return Text('Error: ${snapshot.error}');
                        final List<ListTile> tiles = new List<ListTile>();
                        snapshot.data.forEach((k,v) {
                          var tile = new ListTile(
                              title: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                        "$k:",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        )
                                    ),
                                  ),
                                  Text(
                                      "${v.toString()}",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w300,
                                      )
                                  ),
                                  Icon(
                                    Icons.whatshot,
                                    size: 16,
                                  )
                                ],
                              )
                          );
                          tiles.add(tile);
                        });
                        final List<Widget> divided = ListTile.divideTiles(
                            context: context,
                            tiles: tiles
                        ).toList();

                        return new ListView(
                            children: divided
                        );
                    }
                  }
              ),
          );
        }
      )
    );
  }

  @override
  Widget build(BuildContext context) {

    _createDatabase(previousCigarettes);
    String formattedDate = _formatDateOrTime(new DateTime.now(), "Date");

    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
        actions: <Widget>[
          new IconButton(icon: const Icon(Icons.list), onPressed: _showPreviousDaysFuture)
        ],
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.whatshot,
              size: 50,
            ),
            FutureBuilder<int>(
              future: _getLastAmountFromDB(),
              builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.none:
                    return Text('Press button to start.');
                  case ConnectionState.active:
                  case ConnectionState.waiting:
                    return Text('Awaiting result...');
                  case ConnectionState.done:
                    if (snapshot.hasError)
                      return Text('Error: ${snapshot.error}');
                    // Success, start building here
                    return new Text(
                      snapshot.data.toString(),
                      style: Theme.of(context).textTheme.display1
                    );
                }
              }
            ),
//            Text(
//              '$_counter',
//              style: Theme.of(context).textTheme.display1,
//            ),
            Container(
              margin: EdgeInsets.only(top: 8.0),
              child: Text(
                'Current day: $formattedDate',
                style: Theme.of(context).textTheme.body1,
              )
            ),
            Container(
              margin: EdgeInsets.only(top: 8.0),
              child: FlatButton(
                color: Colors.brown,
                child: Text(
                    "Save consumption",
                    style: TextStyle(
                        color: Colors.white
                    )
                ),
                onPressed: () {
                  setState(() {
                    String formattedDate = _formatDateOrTime(new DateTime.now(), "Date");

                    previousCigarettes.addAll(
                        {"$formattedDate": _counter}
                    );
                    _saveConsumptionToDB("$formattedDate", _counter);
                  });
                },
              )
            ),
            Container(
              margin: EdgeInsets.only(top: 8.0),
              child: FutureBuilder<String>(
                  future: _getLastTimeFromDB(),
                  builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                    switch (snapshot.connectionState) {
                      case ConnectionState.none:
                        return Text('Press button to start.');
                      case ConnectionState.active:
                      case ConnectionState.waiting:
                        return Text('Awaiting result...');
                      case ConnectionState.done:
                        if (snapshot.hasError)
                          return Text('Error: ${snapshot.error}');
                        // Success, start building here
                        return new Text(
                            "Your last cigarette was at ${snapshot.data.toString()}",
                            style: Theme.of(context).textTheme.body1
                        );
                    }
                  }
              ),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  void _createDatabase(Map<String, int> records) async {

    var dbPath = await getDatabasesPath();
    String path = "$dbPath/cigarettes.db";

    // open the database
    await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      // When creating the db, create the table
      await db.execute(
          'CREATE TABLE cigarette_consumption (id INTEGER PRIMARY KEY, date TEXT, amount INTEGER)'
      );
      await db.execute(
          'CREATE TABLE consumption_today (id INTEGER PRIMARY KEY, time TEXT, amount INTEGER)'
      );

      // Insert 0
      await db.transaction((txn) async {
        await txn.rawInsert(
            'INSERT INTO consumption_today(time, amount) VALUES(?, ?)', ["<never>", 0]);
      });

      records.forEach((k, v) async {
        // Insert some records in a transaction
        await db.transaction((txn) async {
          await txn.rawInsert(
              'INSERT INTO cigarette_consumption(date, amount) VALUES(?, ?)', [k, v]);
        });
      });
    });
  }

  Future<Map<String, int>> _getConsumptionFromDB() async {
    Map<String, int> finalRecords = new Map<String, int>();
    var dbPath = await getDatabasesPath();
    String path = "$dbPath/cigarettes.db";

    // open the database
    Database database = await openDatabase(path, version: 1);

    List<Map> records = await database.rawQuery('SELECT * FROM cigarette_consumption');
    records.forEach((record) {
        Map<String,int> tmpMap = {record['date']: record['amount']};
        finalRecords.addAll(tmpMap);
    });
    return finalRecords;
  }

  void _saveConsumptionToDB(String date, int amount) async {
    var dbPath = await getDatabasesPath();
    String path = "$dbPath/cigarettes.db";
    // open the database
    Database database = await openDatabase(path, version: 1);

    // See if value exists already
    List<Map> records = await database.rawQuery('SELECT * FROM cigarette_consumption WHERE date = ? AND amount = ?', [date, amount]);
    if (records.length != 0) {
      await database.rawUpdate('UPDATE cigarette_consumption SET date = ?, amount = ? WHERE date = ?', [date, amount, date]);
    } else {
      // Insert some records in a transaction
      await database.transaction((txn) async {
        await txn.rawInsert(
            'INSERT INTO cigarette_consumption(date, amount) VALUES(?, ?)', [date, amount]);
      });
    }
  }

  void _saveTodayToDB(String time, int amount) async {
    var dbPath = await getDatabasesPath();
    String path = "$dbPath/cigarettes.db";

    Database database = await openDatabase(path, version: 1);

    // See if value exists already
    List<Map> records = await database.rawQuery('SELECT * FROM consumption_today WHERE time = ? AND amount = ?', [time, amount]);
    debugPrint("Today: ${records.toString()}");
    if (records.length != 0) {
      await database.rawUpdate('UPDATE consumption_today SET time = ?, amount = ? WHERE time = ?', [time, amount+1, time]);
    } else {
      // Insert some records in a transaction
      await database.transaction((txn) async {
        await txn.rawInsert(
            'INSERT INTO consumption_today(time, amount) VALUES(?, ?)', [time, amount+1]);
      });
    }
  }

  Future<int> _getLastAmountFromDB() async {
    var dbPath = await getDatabasesPath();
    String path = "$dbPath/cigarettes.db";

    Database database = await openDatabase(path, version: 1);

    List<Map> records = await database.rawQuery('SELECT * FROM consumption_today');
    debugPrint(records.last.toString());
    return records.last['amount'];
  }

  Future<String> _getLastTimeFromDB() async {
    var dbPath = await getDatabasesPath();
    String path = "$dbPath/cigarettes.db";

    Database database = await openDatabase(path, version: 1);

    List<Map> records = await database.rawQuery('SELECT * FROM consumption_today');
    debugPrint(records.last.toString());
    return records.last['time'];
  }

  String _formatDateOrTime(DateTime date, String format) {
    var returnStr = "";
    switch (format) {
      case "Date":
        returnStr = "${date.year.toString()}-";
        if (date.month.toString().length < 2) {
          returnStr += "0${date.month.toString()}-";
        } else {
          returnStr += "${date.month.toString()}-";
        }

        if (date.day.toString().length < 2) {
          returnStr += "0${date.day.toString()}";
        } else {
          returnStr += "${date.day.toString()}";
        }
        break;
      case "Time":
        if (date.hour.toString().length < 2) {
          returnStr = "0${date.hour.toString()}:";
        } else {
          returnStr = "${date.hour.toString()}:";
        }

        if (date.minute.toString().length < 2) {
          returnStr += "0${date.minute.toString()}";
        } else {
          returnStr += "${date.minute.toString()}";
        }
        break;
    }
    debugPrint(returnStr);
    return returnStr;
  }
}
