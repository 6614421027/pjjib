// main.dart
/*
dependencies:
  flutter:
    sdk: flutter
  path_provider: ^2.0.14
  shared_preferences: ^2.1.1
  table_calendar: ^3.0.9
  intl: ^0.18.1
  image_picker: ^1.0.4
  fl_chart: ^0.68.0
  google_fonts: ^5.0.0
*/

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

//======================
// THEME & COLORS
//======================
final Color pastelPink = Color(0xFFF8BBD0);
final Color pastelPurple = Color(0xFFCE93D8);
final Color pastelBlue = Color(0xFFB3E5FC);
final Color pastelBackground = Color(0xFFF3E5F5);

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mooda+',
      theme: ThemeData(
        primaryColor: pastelPink,
        scaffoldBackgroundColor: pastelBackground,
        textTheme: GoogleFonts.kanitTextTheme(),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: pastelPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          shadowColor: Colors.grey[300],
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      home: SplashOrAuth(),
      debugShowCheckedModeBanner: false,
    );
  }
}

//======================
// SPLASH OR LOGIN
//======================
class SplashOrAuth extends StatefulWidget {
  @override
  State<SplashOrAuth> createState() => _SplashOrAuthState();
}

class _SplashOrAuthState extends State<SplashOrAuth> {
  bool _loggedIn = false;
  String? _username;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final u = prefs.getString('username');
    setState(() {
      _loggedIn = u != null;
      _username = u;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _loggedIn
        ? HomeScreen(username: _username!)
        : LoginPage(onLogin: (u) => setState(() => {_loggedIn = true, _username = u}));
  }
}

//======================
// LOGIN / REGISTER PAGE
//======================
class LoginPage extends StatefulWidget {
  final void Function(String username) onLogin;
  LoginPage({required this.onLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _isLogin = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final prefs = await SharedPreferences.getInstance();
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text.trim();
    if (_isLogin) {
      final stored = prefs.getString('pass_$username');
      if (stored == password) {
        await prefs.setString('username', username);
        widget.onLogin(username);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง')));
      }
    } else {
      if (prefs.containsKey('pass_$username')) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ชื่อผู้ใช้นี้มีอยู่แล้ว')));
      } else {
        await prefs.setString('pass_$username', password);
        await prefs.setString('username', username);
        widget.onLogin(username);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pastelBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Mooda+',
                  style: GoogleFonts.kanit(
                      fontSize: 36, fontWeight: FontWeight.bold, color: pastelPurple)),
              SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _userCtrl,
                      decoration: InputDecoration(
                        labelText: 'ชื่อผู้ใช้',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      validator: (v) => v!.isEmpty ? 'กรอกชื่อผู้ใช้' : null,
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'รหัสผ่าน',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      validator: (v) => v!.isEmpty ? 'กรอกรหัสผ่าน' : null,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(onPressed: _submit, child: Text(_isLogin ? 'เข้าสู่ระบบ' : 'สมัคร')),
                    TextButton(
                        onPressed: () => setState(() => _isLogin = !_isLogin),
                        child: Text(_isLogin ? 'สร้างบัญชีใหม่' : 'เข้าสู่ระบบ')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//======================
// HOME SCREEN
//======================
class HomeScreen extends StatefulWidget {
  final String username;
  HomeScreen({required this.username});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Entry> _entries = [];
  DateTime _selectedDate = DateTime.now();

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/mooda_${widget.username}.json');
  }

  Future<void> _loadEntries() async {
    final f = await _getFile();
    if (!await f.exists()) {
      setState(() => _entries = []);
      return;
    }
    final text = await f.readAsString();
    final list = (jsonDecode(text) as List).map((e) => Entry.fromJson(e)).toList();
    setState(() => _entries = list);
  }

  Future<void> _saveEntries() async {
    final f = await _getFile();
    await f.writeAsString(jsonEncode(_entries.map((e) => e.toJson()).toList()));
  }

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  void _addOrEditEntry([Entry? entry]) async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => FeelingsPage(initialDate: _selectedDate, existing: entry)));
    if (result is Entry) {
      if (entry != null) _entries.remove(entry);
      _entries.add(result);
      await _saveEntries();
      setState(() {});
    }
  }

  void _deleteEntry(Entry e) async {
    setState(() => _entries.remove(e));
    await _saveEntries();
  }

  List<Entry> _entriesOn(DateTime day) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    return _entries.where((e) => e.dateKey == key).toList();
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => SplashOrAuth()), (_) => false);
  }

  void _openSummary() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => MonthlySummaryPage(entries: _entries)));
  }

  @override
  Widget build(BuildContext context) {
    final todayEntries = _entriesOn(_selectedDate);
    return Scaffold(
      appBar: AppBar(
        title: Text('Mooda+ - ${widget.username}'),
        backgroundColor: pastelPurple,
        actions: [
          IconButton(onPressed: _openSummary, icon: Icon(Icons.bar_chart)),
          IconButton(onPressed: _logout, icon: Icon(Icons.logout)),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2000, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _selectedDate,
            selectedDayPredicate: (d) => isSameDay(d, _selectedDate),
            onDaySelected: (selected, focused) => setState(() => _selectedDate = selected),
            eventLoader: (d) => _entriesOn(d),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(color: pastelPink, shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: pastelPurple, shape: BoxShape.circle),
            ),
            headerStyle: HeaderStyle(
              titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              formatButtonVisible: false,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('บันทึกวันที่ ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                    onPressed: () => _addOrEditEntry(),
                    icon: Icon(Icons.add),
                    label: Text('เพิ่ม')),
              ],
            ),
          ),
          Expanded(
            child: todayEntries.isEmpty
                ? Center(child: Text('ยังไม่มีบันทึก'))
                : ListView.builder(
                    itemCount: todayEntries.length,
                    itemBuilder: (_, i) {
                      final e = todayEntries[i];
                      return Card(
                        child: ListTile(
                          leading: e.toEmojiWidget(),
                          title: Text(e.feeling),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (e.note != null) Text(e.note!),
                              if (e.imagePath != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Image.file(File(e.imagePath!), height: 120, fit: BoxFit.cover),
                                ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (val) {
                              if (val == 'edit') _addOrEditEntry(e);
                              if (val == 'delete') _deleteEntry(e);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'edit', child: Text('แก้ไข')),
                              PopupMenuItem(value: 'delete', child: Text('ลบ')),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

//======================
// MONTHLY SUMMARY
//======================
class MonthlySummaryPage extends StatelessWidget {
  final List<Entry> entries;
  MonthlySummaryPage({required this.entries});

  Map<String, int> _countByFeeling(DateTime month) {
    final map = {'มีความสุข': 0, 'เศร้า': 0, 'เฉยๆ': 0, 'เบื่อ': 0, 'โกรธ': 0};
    for (var e in entries) {
      final d = DateTime.parse(e.timestamp);
      if (d.year == month.year && d.month == month.month) {
        map[e.feeling] = (map[e.feeling] ?? 0) + 1;
      }
    }
    return map;
  }

  Color _colorForFeeling(String f) {
    switch (f) {
      case 'มีความสุข':
        return Colors.greenAccent;
      case 'เศร้า':
        return Colors.blueAccent;
      case 'เฉยๆ':
        return Colors.grey;
      case 'เบื่อ':
        return Colors.orangeAccent;
      case 'โกรธ':
        return Colors.redAccent;
      default:
        return Colors.purpleAccent;
    }
  }

  String _emojiForFeeling(String f) {
    switch (f) {
      case 'มีความสุข':
        return '😊';
      case 'เศร้า':
        return '😢';
      case 'เฉยๆ':
        return '😐';
      case 'เบื่อ':
        return '😒';
      case 'โกรธ':
        return '😠';
      default:
        return '🙂';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final data = _countByFeeling(now);
    final total = data.values.fold<int>(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(title: Text('สรุปอารมณ์ ${DateFormat('MMMM yyyy', 'th').format(now)}'), backgroundColor: pastelPurple),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: total == 0
            ? Center(child: Text('ยังไม่มีข้อมูลในเดือนนี้'))
            : Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: data.entries.map((e) {
                          final percent = (e.value / total) * 100;
                          return PieChartSectionData(
                            title: '${e.key}\n${percent.toStringAsFixed(1)}%',
                            value: e.value.toDouble(),
                            color: _colorForFeeling(e.key),
                            radius: 60,
                            titleStyle: TextStyle(color: Colors.white, fontSize: 12),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  ...data.entries.map((e) => ListTile(
                        leading: CircleAvatar(backgroundColor: _colorForFeeling(e.key), child: Text(_emojiForFeeling(e.key))),
                        title: Text('${e.key}'),
                        trailing: Text('${e.value} ครั้ง'),
                      )),
                ],
              ),
      ),
    );
  }
}

//======================
// FEELINGS PAGE
//======================
class FeelingsPage extends StatefulWidget {
  final DateTime initialDate;
  final Entry? existing;
  FeelingsPage({required this.initialDate, this.existing});
  @override
  State<FeelingsPage> createState() => _FeelingsPageState();
}

class _FeelingsPageState extends State<FeelingsPage> {
  String? _selectedFeeling;
  final _noteCtrl = TextEditingController();
  File? _imageFile;
  final picker = ImagePicker();

  final feelings = [
    {'label': 'มีความสุข', 'key': 'happy'},
    {'label': 'เศร้า', 'key': 'sad'},
    {'label': 'เฉยๆ', 'key': 'neutral'},
    {'label': 'เบื่อ', 'key': 'bored'},
    {'label': 'โกรธ', 'key': 'angry'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _selectedFeeling = widget.existing!.feeling;
      _noteCtrl.text = widget.existing!.note ?? '';
      if (widget.existing!.imagePath != null) _imageFile = File(widget.existing!.imagePath!);
    }
  }

  Future<void> _pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  void _save() {
    if (_selectedFeeling == null) return;
    final e = Entry(
      feeling: _selectedFeeling!,
      note: _noteCtrl.text,
      timestamp: DateTime.now().toIso8601String(),
      imagePath: _imageFile?.path,
    );
    Navigator.pop(context, e);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('บันทึกอารมณ์'), backgroundColor: pastelPurple),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              children: feelings.map((f) {
                final selected = _selectedFeeling == f['label'];
                return ChoiceChip(
                  label: Text(f['label']!),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedFeeling = f['label']),
                  selectedColor: pastelPink,
                );
              }).toList(),
            ),
            SizedBox(height: 12),
            TextField(controller: _noteCtrl, decoration: InputDecoration(labelText: 'โน้ต')),
            SizedBox(height: 12),
            if (_imageFile != null) Image.file(_imageFile!, height: 150),
            ElevatedButton.icon(onPressed: _pickImage, icon: Icon(Icons.image), label: Text('เลือกภาพ')),
            Spacer(),
            ElevatedButton(onPressed: _save, child: Text('บันทึก'))
          ],
        ),
      ),
    );
  }
}

//======================
// ENTRY MODEL
//======================
class Entry {
  final String feeling;
  final String? note;
  final String timestamp;
  final String? imagePath;

  Entry({required this.feeling, this.note, required this.timestamp, this.imagePath});

  String get dateKey => timestamp.substring(0, 10);

  Map<String, dynamic> toJson() =>
      {'feeling': feeling, 'note': note, 'timestamp': timestamp, 'imagePath': imagePath};

  factory Entry.fromJson(Map<String, dynamic> json) => Entry(
      feeling: json['feeling'],
      note: json['note'],
      timestamp: json['timestamp'],
      imagePath: json['imagePath']);

  Widget toEmojiWidget() {
    switch (feeling) {
      case 'มีความสุข':
        return Text('😊');
      case 'เศร้า':
        return Text('😢');
      case 'เฉยๆ':
        return Text('😐');
      case 'เบื่อ':
        return Text('😒');
      case 'โกรธ':
        return Text('😠');
      default:
        return Text('🙂');
    }
  }
}
