import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const KaloMonApp());

class KaloMonApp extends StatelessWidget {
  const KaloMonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KaloMon',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E293B),
        colorScheme: const ColorScheme.dark(
          primary: Colors.amber,
          secondary: Colors.amberAccent,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  String _selectedCharacter = "character3";

  int _gold = 0;
  int _gems = 0;
  int _level = 1;
  double _xp = 0.0;
  double _maxXp = 500.0;
  double _stamina = 50.0;
  double _maxStamina = 50.0;

  double _todayDistanceKm = 0.0;
  double _todayCalories = 0.0;

  double _weight = 70.0;
  double _height = 175.0;
  int _age = 23;
  double _muscleMass = 30.0;

  String _selectedBg = '기본';
  List<String> _ownedBgs = ['기본'];
  List<String> _ownedFurniture = []; // 구매한 가구 리스트
  List<String> _equippedFurniture = []; // 맵에 배치된 가구 리스트 (새로 추가)

  bool _q1Claimed = false;
  bool _q2Claimed = false;
  bool _q3Claimed = false;

  double get _targetCalories {
    double bmr = (10 * _weight) + (6.25 * _height) - (5 * _age) + 5;
    return bmr * 0.2;
  }

  bool get _hasClaimableQuest {
    bool q1Ready = (1.0 >= 3.0) && !_q1Claimed;
    bool q2Ready = (_todayCalories >= _targetCalories) && !_q2Claimed;
    bool q3Ready = (_todayDistanceKm >= 3.0) && !_q3Claimed;
    return q1Ready || q2Ready || q3Ready;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _syncHealthData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _gold = 20000;
      _gems = prefs.getInt('gems') ?? 45;
      _level = prefs.getInt('level') ?? 25;
      _xp = prefs.getDouble('xp') ?? 350.0;
      _stamina = prefs.getDouble('stamina') ?? 40.0;
      _weight = prefs.getDouble('weight') ?? 70.0;
      _height = prefs.getDouble('height') ?? 175.0;
      _age = prefs.getInt('age') ?? 23;
      _muscleMass = prefs.getDouble('muscleMass') ?? 30.0;
      _selectedBg = prefs.getString('selectedBg') ?? '기본';
      _ownedBgs = prefs.getStringList('ownedBgs') ?? ['기본'];
      _ownedFurniture = prefs.getStringList('ownedFurniture') ?? [];
      _equippedFurniture = prefs.getStringList('equippedFurniture') ?? []; // 배치 로드
      _q1Claimed = prefs.getBool('q1Claimed') ?? false;
      _q2Claimed = prefs.getBool('q2Claimed') ?? false;
      _q3Claimed = prefs.getBool('q3Claimed') ?? false;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gold', _gold);
    await prefs.setInt('gems', _gems);
    await prefs.setInt('level', _level);
    await prefs.setDouble('xp', _xp);
    await prefs.setDouble('stamina', _stamina);
    await prefs.setDouble('weight', _weight);
    await prefs.setDouble('height', _height);
    await prefs.setInt('age', _age);
    await prefs.setDouble('muscleMass', _muscleMass);
    await prefs.setString('selectedBg', _selectedBg);
    await prefs.setStringList('ownedBgs', _ownedBgs);
    await prefs.setStringList('ownedFurniture', _ownedFurniture);
    await prefs.setStringList('equippedFurniture', _equippedFurniture); // 배치 저장
    await prefs.setBool('q1Claimed', _q1Claimed);
    await prefs.setBool('q2Claimed', _q2Claimed);
    await prefs.setBool('q3Claimed', _q3Claimed);
  }

  Future<void> _syncHealthData() async {
    await Permission.activityRecognition.request();
    Health health = Health();
    var types = [HealthDataType.DISTANCE_DELTA, HealthDataType.ACTIVE_ENERGY_BURNED];
    bool hasPermissions = await health.requestAuthorization(types);
    if (hasPermissions) {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      try {
        List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
          types: types, startTime: midnight, endTime: now,
        );
        double totalMeters = 0.0;
        double totalKcal = 0.0;
        for (var point in healthData) {
          if (point.type == HealthDataType.DISTANCE_DELTA) {
            totalMeters += double.tryParse(point.value.toString()) ?? 0.0;
          } else if (point.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
            totalKcal += double.tryParse(point.value.toString()) ?? 0.0;
          }
        }
        setState(() {
          _todayDistanceKm = totalMeters / 1000.0;
          _todayCalories = totalKcal;
        });
      } catch (e) {
        debugPrint("건강 데이터 동기화 에러: $e");
      }
    }
  }

  void _claimReward(int questId, int rewardXp, int rewardGold, int rewardGems) {
    setState(() {
      if (questId == 1) _q1Claimed = true;
      if (questId == 2) _q2Claimed = true;
      if (questId == 3) _q3Claimed = true;
      _xp += rewardXp;
      _gold += rewardGold;
      _gems += rewardGems;
      if (_xp >= _maxXp) {
        _level += 1;
        _xp -= _maxXp;
        _stamina = _maxStamina;
      }
    });
    _saveData();
  }

  void _updateProfileData(double w, double h, int a, double m) {
    setState(() { _weight = w; _height = h; _age = a; _muscleMass = m; });
    _saveData();
  }

  void _buyAndApplyBg(String name, int price) {
    if (_ownedBgs.contains(name)) {
      setState(() => _selectedBg = name);
      _saveData();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name 배경이 적용되었습니다.')));
    } else {
      if (_gold >= price) {
        setState(() { _gold -= price; _ownedBgs.add(name); _selectedBg = name; });
        _saveData();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name 배경을 구매하고 적용했습니다!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('골드가 부족합니다.')));
      }
    }
  }

  // 가구 구매 및 배치/해제
  void _toggleFurniture(String name, int price) {
    setState(() {
      if (!_ownedFurniture.contains(name)) {
        if (_gold >= price) {
          _gold -= price;
          _ownedFurniture.add(name);
          _equippedFurniture.add(name);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name 구매 및 배치가 완료되었습니다!')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('골드가 부족합니다.')));
        }
      } else {
        if (_equippedFurniture.contains(name)) {
          _equippedFurniture.remove(name);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name 배치가 해제되었습니다.')));
        } else {
          _equippedFurniture.add(name);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name 배치가 완료되었습니다!')));
        }
      }
    });
    _saveData();
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return HomeTab(
          selectedCharacter: _selectedCharacter,
          gold: _gold, gems: _gems, level: _level, xp: _xp, maxXp: _maxXp,
          stamina: _stamina, maxStamina: _maxStamina,
          selectedBg: _selectedBg,
          equippedFurniture: _equippedFurniture, //  실제 배치된 가구만 화면에 전달
          onCharacterChanged: (newChar) => setState(() => _selectedCharacter = newChar),
        );
      case 1:
        return QuestTab(
          todayDistanceKm: _todayDistanceKm, todayCalories: _todayCalories, targetCalories: _targetCalories,
          q1Claimed: _q1Claimed, q2Claimed: _q2Claimed, q3Claimed: _q3Claimed,
          onRewardClaimed: _claimReward, onSyncRequested: _syncHealthData,
        );
      case 2:
        return KitchenPage(selectedCharacter: _selectedCharacter);
      case 3:
        return ProfileTab(
          weight: _weight, height: _height, age: _age, muscleMass: _muscleMass, targetCalories: _targetCalories,
          onProfileUpdated: _updateProfileData,
        );
      case 4:
        return RoomDecorTab(
          gold: _gold, gems: _gems, ownedBgs: _ownedBgs, selectedBg: _selectedBg, onBuyBg: _buyAndApplyBg,
          ownedFurniture: _ownedFurniture,
          equippedFurniture: _equippedFurniture,
          onToggleFurniture: _toggleFurniture, //  새 함수 연결
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _buildCurrentPage()),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'HOME'),
          BottomNavigationBarItem(
            icon: Badge(isLabelVisible: _hasClaimableQuest, child: const Icon(Icons.assignment)),
            label: 'QUEST',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: 'KITCHEN'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'PROFILE'),
          const BottomNavigationBarItem(icon: Icon(Icons.chair), label: 'ROOM'),
        ],
      ),
    );
  }
}

// 10x16 픽셀 매핑 및 동적 히트박스 하이브리드 엔진
enum TileType { wall, floor, water }

class Tile {
  TileType type;
  bool isOccupied;
  Tile({required this.type, this.isOccupied = false});
}

class ManualCharacterView extends StatefulWidget {
  final String selectedCharacter;
  final String selectedBg;
  final double areaWidth;
  final double areaHeight;
  final List<String> equippedFurniture; //  이름 변경

  const ManualCharacterView({
    super.key,
    required this.selectedCharacter,
    required this.selectedBg,
    required this.areaWidth,
    required this.areaHeight,
    required this.equippedFurniture,
  });

  @override
  State<ManualCharacterView> createState() => _ManualCharacterViewState();
}

class _ManualCharacterViewState extends State<ManualCharacterView> {
  Timer? _moveTimer;

  double _x = 150.0;
  double _y = 300.0;
  int _direction = 2;
  int _step = 0;
  int _tickCount = 0;
  final double _speed = 4.0;

  final int _cols = 10;
  final int _rows = 16;
  List<List<Tile>> _gridMap = [];

  final double charWidth = 80.0;
  final double charHeight = 160.0;

  final Map<String, Map<String, dynamic>> gymFurnitureSpecs = {
    '파워 랙': {
      'asset': 'assets/power_rack.png',
      'l': 0.02, 't': 0.025, 'w': 0.43,  // 크기/위치 약간 조정
      'hitX': [0,1,2,3], 'hitY': [3,4,5,6] // 히트박스 세로로 1칸 더 확장 (타입오류 해결 위해 List<int>로 자동 캐스팅됨)
    },
    '케이블 머신': {
      'asset': 'assets/cable.png',
      'l': 0.55, 't': 0.06, 'w': 0.45,  //  요청: 크기 대폭 확대 (0.28 -> 0.36) 및 위치 중앙으로 조정
      'hitX': [3,4,5,6], 'hitY': [3,4,5,6] // 충돌 영역 가로로 2칸 확장 (가로 4칸 사용)
    },
    '런닝머신': {
      'asset': 'assets/treadmill.png',
      'l': -0.07, 't': 0.65, 'w': 0.60,  // 원본에 더 가깝게 바닥에 밀착
      'hitX': [0,1,2,3], 'hitY': [11,12,13,14] // 세로 히트박스 위치 조정
    },
    '덤벨 세트': {
      'asset': 'assets/dumbel.png',
      'l': 0.197, 't': 0.33, 'w': 0.8,  //  요청: 크기 대폭 확대 (0.4 -> 0.45) 및 원본 위치로 이동
      'hitX': [5,6,7,8,9], 'hitY': [11,12,13,14] // 충돌 영역 가로로 1칸 확장 (가로 5칸 사용)
    },
    '동기부여 포스터': {
      'asset': 'assets/poster.png',
      'l': 0.45, 't': 0.03, 'w': 0.14,
      'hitX': [], 'hitY': [] // 벽걸이라 충돌 없음 유지
    },
  };
  final Map<String, Map<String, dynamic>> poolFurnitureSpecs = {
    '안전 수칙': { 'asset': 'assets/safety.png', 'l': 0.1, 't': 0.15, 'w': 0.15, 'hitX': [], 'hitY': [] }, // 벽걸이
    '경고 표지판': { 'asset': 'assets/caution.png', 'l': 0.3, 't': 0.15, 'w': 0.15, 'hitX': [], 'hitY': [] }, // 벽걸이
    '응급 처치함': { 'asset': 'assets/emergency_kit.png', 'l': 0.6, 't': 0.15, 'w': 0.3, 'hitX': [], 'hitY': [] }, // 벽걸이
    '구명 튜브': { 'asset': 'assets/tube.png', 'l': 0.05, 't': 0.4, 'w': 0.4, 'hitX': [0,1,2,3,4], 'hitY': [7,8,9] }, // 바닥 배치
    '오리발 보관함': { 'asset': 'assets/fin.png', 'l': 0.05, 't': 0.7, 'w': 0.35, 'hitX': [0,1,2,3], 'hitY': [12,13,14] }, // 바닥 배치
    '수영 장비장': { 'asset': 'assets/equipment.png', 'l': 0.55, 't': 0.7, 'w': 0.35, 'hitX': [5,6,7,8], 'hitY': [12,13,14] }, // 바닥 배치
  };

  @override
  void initState() {
    super.initState();
    _generateGridMap();
    _resetPosition();
  }

  @override
  void didUpdateWidget(ManualCharacterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedBg != oldWidget.selectedBg || widget.equippedFurniture.length != oldWidget.equippedFurniture.length) {
      _generateGridMap();
      if (widget.selectedBg != oldWidget.selectedBg) _resetPosition();
    }
  }

  void _resetPosition() {
    setState(() {
      _x = widget.areaWidth / 2 - (charWidth / 2);
      _y = widget.areaHeight / 2;
      _direction = 2;
    });
  }

  void _generateGridMap() {
    _gridMap = List.generate(_rows, (r) {
      return List.generate(_cols, (c) {
        TileType type = TileType.floor;
        if (widget.selectedBg == '주방') { if (r < 5) type = TileType.wall; }
        else if (widget.selectedBg == '헬스장') { if (r < 4) type = TileType.wall; }
        else if (widget.selectedBg == '수영장') {
          if (r < 4) type = TileType.wall;
          if (c >= 6 && r >= 7) type = TileType.water;
        }
        else { if (r < 4) type = TileType.wall; }
        return Tile(type: type);
      });
    });

// 🔥 동적 히트박스 주입: 헬스장 & 수영장 모두 적용
    Map<String, Map<String, dynamic>> targetSpecs = {};
    if (widget.selectedBg == '헬스장') targetSpecs = gymFurnitureSpecs;
    if (widget.selectedBg == '수영장') targetSpecs = poolFurnitureSpecs;

    for (String name in widget.equippedFurniture) {
      if (targetSpecs.containsKey(name)) {
        List<int> hitX = List<int>.from(targetSpecs[name]!['hitX']);
        List<int> hitY = List<int>.from(targetSpecs[name]!['hitY']);
        for (int x in hitX) {
          for (int y in hitY) {
            if (y < _rows && x < _cols) _gridMap[y][x].isOccupied = true;
          }
        }
      }
    }
  }

  bool _canMoveTo(double nx, double ny) {
    double tileW = widget.areaWidth / _cols;
    double tileH = widget.areaHeight / _rows;

    double feetX = nx + (charWidth / 2);
    double feetY = ny + charHeight - 20;

    int gridX = (feetX / tileW).floor();
    int gridY = (feetY / tileH).floor();

    if (gridX < 0 || gridX >= _cols || gridY < 0 || gridY >= _rows) return false;

    Tile targetTile = _gridMap[gridY][gridX];
    if (targetTile.type == TileType.wall) return false;
    if (targetTile.type == TileType.water) return false;
    if (targetTile.isOccupied) return false;

    return true;
  }

  void _startMoving(int dir) {
    _direction = dir;
    _moveTimer?.cancel();
    _moveTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      setState(() {
        double nx = _x; double ny = _y;
        if (_direction == 1) nx += _speed;
        else if (_direction == 2) ny += _speed;
        else if (_direction == 3) nx -= _speed;
        else if (_direction == 0) ny -= _speed;

        nx = nx.clamp(0.0, widget.areaWidth - charWidth);
        ny = ny.clamp(0.0, widget.areaHeight - charHeight);

        if (_canMoveTo(nx, ny)) { _x = nx; _y = ny; }

        _tickCount++;
        if (_tickCount >= 8) { _step = 1 - _step; _tickCount = 0; }
      });
    });
  }

  void _stopMoving() {
    _moveTimer?.cancel();
    setState(() { _step = 0; });
  }

  String _getCurrentSprite() {
    if (widget.selectedCharacter != "character3") {
      if (widget.selectedCharacter == "캐릭터 1") return 'assets/1772771310720.png';
      if (widget.selectedCharacter == "캐릭터 2") return 'assets/1772771352804.png';
      return 'assets/placeholder.png';
    }
    if (_direction == 0) return _step == 0 ? 'assets/오뒤.png' : 'assets/왼뒤.png';
    if (_direction == 1) return _step == 0 ? 'assets/오2.png' : 'assets/오3.png';
    if (_direction == 2) return _step == 0 ? 'assets/오앞.png' : 'assets/왼앞.png';
    if (_direction == 3) return _step == 0 ? 'assets/왼2.PNG' : 'assets/왼3.PNG';
    return 'assets/오앞.png';
  }

  Widget _buildDirBtn(IconData icon, int dir) {
    return GestureDetector(
      onTapDown: (_) => _startMoving(dir),
      onTapUp: (_) => _stopMoving(),
      onTapCancel: () => _stopMoving(),
      child: Container(
        width: 55, height: 55,
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle, border: Border.all(color: Colors.amber.withOpacity(0.7), width: 2)),
        child: Icon(icon, color: Colors.amber, size: 35),
      ),
    );
  }

  @override
  void dispose() { _moveTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    double tileW = widget.areaWidth / _cols;
    double tileH = widget.areaHeight / _rows;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Column(
              children: List.generate(_rows, (r) => Container(
                height: tileH,
                child: Row(
                  children: List.generate(_cols, (c) {
                    Tile targetTile = _gridMap[r][c];
                    Color debugColor = Colors.transparent;
                    if (targetTile.type == TileType.wall) debugColor = Colors.red.withOpacity(0.3);
                    else if (targetTile.type == TileType.water) debugColor = Colors.blue.withOpacity(0.3);
                    else if (targetTile.isOccupied) debugColor = Colors.green.withOpacity(0.3);
                    return Container(width: tileW, decoration: BoxDecoration(color: debugColor, border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5)));
                  }),
                ),
              )),
            ),
          ),
        ),

        if (widget.selectedBg == '헬스장')
          ...widget.equippedFurniture.where((name) => gymFurnitureSpecs.containsKey(name)).map((name) {
            final spec = gymFurnitureSpecs[name]!;
            return Positioned(
              left: widget.areaWidth * spec['l'],
              top: widget.areaHeight * spec['t'],
              width: widget.areaWidth * spec['w'],
              child: Image.asset(spec['asset'], fit: BoxFit.contain),
            );
          }),

        if (widget.selectedBg == '수영장')
          ...widget.equippedFurniture.where((name) => poolFurnitureSpecs.containsKey(name)).map((name) {
            final spec = poolFurnitureSpecs[name]!;
            return Positioned(
              left: widget.areaWidth * spec['l'],
              top: widget.areaHeight * spec['t'],
              width: widget.areaWidth * spec['w'],
              child: Image.asset(spec['asset'], fit: BoxFit.contain),
            );
          }),

        Positioned(
          left: _x, top: _y,
          child: Transform.scale(
            scale: 0.8,
            child: Image.asset(_getCurrentSprite(), fit: BoxFit.contain, height: charHeight, errorBuilder: (context, error, stackTrace) => const SizedBox.shrink()),
          ),
        ),

        Positioned(
          bottom: 30, right: 20,
          child: Column(
            children: [
              _buildDirBtn(Icons.keyboard_arrow_up, 0), const SizedBox(height: 6),
              Row(children: [_buildDirBtn(Icons.keyboard_arrow_left, 3), const SizedBox(width: 60), _buildDirBtn(Icons.keyboard_arrow_right, 1)]),
              const SizedBox(height: 6), _buildDirBtn(Icons.keyboard_arrow_down, 2),
            ],
          ),
        )
      ],
    );
  }
}

// ============================================================================
// 홈 탭
// ============================================================================
class HomeTab extends StatelessWidget {
  final String selectedCharacter;
  final int gold; final int gems; final int level;
  final double xp; final double maxXp; final double stamina; final double maxStamina;
  final String selectedBg;
  final List<String> equippedFurniture;
  final Function(String) onCharacterChanged;

  const HomeTab({
    super.key, required this.selectedCharacter, required this.gold, required this.gems, required this.level,
    required this.xp, required this.maxXp, required this.stamina, required this.maxStamina,
    required this.selectedBg, required this.equippedFurniture, required this.onCharacterChanged,
  });

  String _getBgAsset(String name) {
    if (name == '주방') return 'assets/kitchen_background.png';
    if (name == '헬스장') return 'assets/gym_background.png';
    if (name == '수영장') return 'assets/pool_background.png';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    String currentBgAsset = _getBgAsset(selectedBg);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('KALOMON', style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.monetization_on, color: Colors.yellow, size: 16), const SizedBox(width: 4), Text('$gold', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))])),
                      const SizedBox(width: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.diamond, color: Colors.cyanAccent, size: 16), const SizedBox(width: 4), Text('$gems', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))])),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(child: _buildMainStatBar("LV. $level (XP)", xp, maxXp, Colors.blueAccent)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMainStatBar("STAMINA", stamina, maxStamina, Colors.orangeAccent)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSelectButton("캐릭터 1"), const SizedBox(width: 8),
                  _buildSelectButton("캐릭터 2"), const SizedBox(width: 8),
                  _buildSelectButton("character3"),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    image: currentBgAsset.isNotEmpty ? DecorationImage(
                      image: AssetImage(currentBgAsset),
                      fit: BoxFit.fill,
                      colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.1), BlendMode.darken),
                    ) : null,
                  ),
                  child: ManualCharacterView(
                    selectedCharacter: selectedCharacter,
                    selectedBg: selectedBg,
                    areaWidth: constraints.maxWidth,
                    areaHeight: constraints.maxHeight,
                    equippedFurniture: equippedFurniture,
                  ),
                );
              }
          ),
        ),
      ],
    );
  }

  Widget _buildMainStatBar(String label, double current, double max, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)), Text('${current.toInt()}/${max.toInt()}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11))]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: (max > 0) ? (current / max).clamp(0.0, 1.0) : 0.0, backgroundColor: Colors.white12, color: color, minHeight: 6)),
      ],
    );
  }

  Widget _buildSelectButton(String characterName) {
    bool isSelected = (selectedCharacter == characterName);
    return OutlinedButton(
      onPressed: () => onCharacterChanged(characterName),
      style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? Colors.amber.withOpacity(0.2) : Colors.transparent,
          side: BorderSide(color: isSelected ? Colors.amber : Colors.blueGrey.withOpacity(0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          minimumSize: Size.zero
      ),
      child: Text(characterName, style: TextStyle(color: isSelected ? Colors.amber : Colors.white70, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
    );
  }
}

// ============================================================================
// 퀘스트, 프로필, 키친 (유지)
// ============================================================================
class QuestTab extends StatelessWidget {
  final double todayDistanceKm; final double todayCalories; final double targetCalories;
  final bool q1Claimed; final bool q2Claimed; final bool q3Claimed;
  final Function(int, int, int, int) onRewardClaimed; final VoidCallback onSyncRequested;

  const QuestTab({super.key, required this.todayDistanceKm, required this.todayCalories, required this.targetCalories, required this.q1Claimed, required this.q2Claimed, required this.q3Claimed, required this.onRewardClaimed, required this.onSyncRequested});

  @override
  Widget build(BuildContext context) {
    double displayDistance = double.parse(todayDistanceKm.toStringAsFixed(1)); int displayCalories = todayCalories.toInt(); int goalCalories = targetCalories.toInt();
    return Padding(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('DAILY QUESTS', style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)), GestureDetector(onTap: onSyncRequested, child: Row(children: const [Icon(Icons.sync, color: Colors.blueAccent, size: 20), SizedBox(width: 4), Text('동기화', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14))]))]), const SizedBox(height: 24), Expanded(child: ListView(children: [_buildDetailedQuestRow(1, Icons.eco, '건강한 식단 레시피 생성', 1.0, 3.0, 50, 10, 0, !q1Claimed, q1Claimed, isDouble: false), const SizedBox(height: 16), _buildDetailedQuestRow(2, Icons.local_fire_department, '목표 활동 칼로리 소모', displayCalories.toDouble(), goalCalories.toDouble(), 120, 30, 1, displayCalories >= goalCalories && !q2Claimed, q2Claimed, isDouble: false), const SizedBox(height: 16), _buildDetailedQuestRow(3, Icons.directions_run, '누적 3km 달리기', displayDistance, 3.0, 150, 50, 2, displayDistance >= 3.0 && !q3Claimed, q3Claimed, isDouble: true)]))]));
  }
  Widget _buildDetailedQuestRow(int questId, IconData icon, String title, double current, double max, int rewardXp, int rewardGold, int rewardGems, bool canClaim, bool isClaimed, {bool isDouble = false}) {
    bool isCompleted = current >= max; String currentText = isDouble ? current.toString() : current.toInt().toString(); String maxText = isDouble ? max.toString() : max.toInt().toString();
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16), border: Border.all(color: isCompleted && !isClaimed ? Colors.amber : Colors.blueGrey.withOpacity(0.3), width: isCompleted && !isClaimed ? 2 : 1)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Row(children: [Icon(icon, color: isClaimed ? Colors.grey : (isCompleted ? Colors.greenAccent : Colors.orange), size: 22), const SizedBox(width: 8), Expanded(child: Text(title, style: TextStyle(color: isClaimed ? Colors.grey : (isCompleted ? Colors.greenAccent : Colors.white), fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis))])), Text('($currentText/$maxText)', style: TextStyle(color: isClaimed ? Colors.grey : (isCompleted ? Colors.greenAccent : Colors.amber), fontWeight: FontWeight.bold, fontSize: 14))]), const SizedBox(height: 12), ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: (max > 0) ? (current / max).clamp(0.0, 1.0) : 0.0, backgroundColor: Colors.grey[800], color: isClaimed ? Colors.grey : (isCompleted ? Colors.greenAccent : Colors.amber), minHeight: 8)), const SizedBox(height: 12), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [const Text("보상: ", style: TextStyle(color: Colors.white54, fontSize: 12)), if (rewardXp > 0) Row(children: [const Icon(Icons.star, color: Colors.blueAccent, size: 12), Text(' $rewardXp  ', style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold))]), if (rewardGold > 0) Row(children: [const Icon(Icons.monetization_on, color: Colors.yellow, size: 12), Text(' $rewardGold  ', style: const TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.bold))]), if (rewardGems > 0) Row(children: [const Icon(Icons.diamond, color: Colors.cyanAccent, size: 12), Text(' $rewardGems', style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold))])]), if (canClaim) ElevatedButton(onPressed: () => onRewardClaimed(questId, rewardXp, rewardGold, rewardGems), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0), minimumSize: const Size(60, 30)), child: const Text("보상 받기", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))) else if (isClaimed) const Text("[ 수령 완료 ]", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))])]));
  }
}

class ProfileTab extends StatefulWidget {
  final double weight; final double height; final int age; final double muscleMass; final double targetCalories;
  final Function(double, double, int, double) onProfileUpdated;
  const ProfileTab({super.key, required this.weight, required this.height, required this.age, required this.muscleMass, required this.targetCalories, required this.onProfileUpdated});
  @override State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late TextEditingController _weightCtrl; late TextEditingController _heightCtrl; late TextEditingController _ageCtrl; late TextEditingController _muscleCtrl;
  @override void initState() { super.initState(); _weightCtrl = TextEditingController(text: widget.weight.toString()); _heightCtrl = TextEditingController(text: widget.height.toString()); _ageCtrl = TextEditingController(text: widget.age.toString()); _muscleCtrl = TextEditingController(text: widget.muscleMass.toString()); }
  void _saveProfile() { double w = double.tryParse(_weightCtrl.text) ?? widget.weight; double h = double.tryParse(_heightCtrl.text) ?? widget.height; int a = int.tryParse(_ageCtrl.text) ?? widget.age; double m = double.tryParse(_muscleCtrl.text) ?? widget.muscleMass; widget.onProfileUpdated(w, h, a, m); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신체 스탯이 성공적으로 업데이트되었습니다.'))); }
  @override Widget build(BuildContext context) { return Padding(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('USER PROFILE', style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 20), TextField(controller: _ageCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: '나이 (세)', labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))), const SizedBox(height: 12), TextField(controller: _heightCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: '키 (cm)', labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))), const SizedBox(height: 12), TextField(controller: _weightCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: '몸무게 (kg)', labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))), const SizedBox(height: 12), TextField(controller: _muscleCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: '근육량 (kg)', labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))), const SizedBox(height: 24), ElevatedButton(onPressed: _saveProfile, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('스탯 저장 및 목표 갱신', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), const SizedBox(height: 30), Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blueGrey.withOpacity(0.5))), child: Column(children: [const Text('일일 목표 활동 칼로리', style: TextStyle(color: Colors.white70, fontSize: 14)), const SizedBox(height: 8), Text('${widget.targetCalories.toInt()} kcal', style: const TextStyle(color: Colors.orangeAccent, fontSize: 28, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('기초대사량 기반으로 자동 계산된 수치입니다.', style: TextStyle(color: Colors.white54, fontSize: 11))]))])); }
}

class KitchenPage extends StatefulWidget {
  final String selectedCharacter; const KitchenPage({super.key, required this.selectedCharacter});
  @override State<KitchenPage> createState() => _KitchenPageState();
}

class _KitchenPageState extends State<KitchenPage> {
  final TextEditingController _ingredientController = TextEditingController(); final List<String> _ingredients = []; List<dynamic> _recipes = []; bool _isLoading = false; String _errorMessage = "";
  Widget _buildStatBar(IconData icon, String label, double value, double maxValue, Color color) { return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Icon(icon, color: color, size: 16), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))]), Text("${value.toInt() / maxValue.toInt()}", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11))]), const SizedBox(height: 5), ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: (maxValue > 0) ? value / maxValue : 0, backgroundColor: Colors.white12, color: color, minHeight: 6))]); }
  void _addIngredient() { final text = _ingredientController.text.trim(); if (text.isNotEmpty && !_ingredients.contains(text)) { setState(() { _ingredients.add(text); _ingredientController.clear(); }); } }
  void _removeIngredient(String ingredient) { setState(() => _ingredients.remove(ingredient)); }
  Future<void> fetchRecipes() async { if (_ingredients.isEmpty) { setState(() => _errorMessage = "최소 하나 이상의 식재료를 입력해주세요."); return; } setState(() { _isLoading = true; _errorMessage = ""; _recipes = []; }); try { final response = await http.post(Uri.parse('address'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({"ingredients": _ingredients})); if (response.statusCode == 200) { setState(() => _recipes = jsonDecode(utf8.decode(response.bodyBytes))); } else { setState(() => _errorMessage = "서버 오류가 발생했습니다."); } } catch (e) { setState(() => _errorMessage = "네트워크 통신에 실패했습니다."); } finally { setState(() => _isLoading = false); } }
  @override void dispose() { _ingredientController.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { return Scaffold(backgroundColor: Colors.transparent, appBar: AppBar(title: const Text('칼로레시피', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF0F172A), elevation: 0), body: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [Expanded(child: TextField(controller: _ingredientController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: '식재료 입력 (예: 계란, 양파)', hintStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)), onSubmitted: (_) => _addIngredient())), const SizedBox(width: 12), ElevatedButton(onPressed: _addIngredient, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16), backgroundColor: Colors.amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Icon(Icons.add, color: Colors.black))]), const SizedBox(height: 12), Wrap(spacing: 8.0, runSpacing: 4.0, children: _ingredients.map((ingredient) => Chip(label: Text(ingredient, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.amberAccent, deleteIcon: const Icon(Icons.close, size: 18, color: Colors.black54), onDeleted: () => _removeIngredient(ingredient))).toList()), const SizedBox(height: 16), ElevatedButton(onPressed: _isLoading ? null : fetchRecipes, style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: Colors.amber, foregroundColor: Colors.black, disabledBackgroundColor: Colors.amber.withOpacity(0.5)), child: Text(_isLoading ? "생성 중..." : "제안받기", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))), if (_errorMessage.isNotEmpty) ...[const SizedBox(height: 16), Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))], const SizedBox(height: 16), Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent)) : _recipes.isEmpty ? const Center(child: Text("식재료를 입력해주세요.", style: TextStyle(fontSize: 16, color: Colors.white70))) : ListView.builder(itemCount: _recipes.length, itemBuilder: (context, index) { final recipe = _recipes[index]; return Card(color: const Color(0xFF0F172A), margin: const EdgeInsets.only(bottom: 12), child: ExpansionTile(iconColor: Colors.amber, title: Text(recipe['recipe_name'] ?? '요리', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), children: [Container(padding: const EdgeInsets.all(16.0), child: Text("조리법: ${(recipe['instructions'] as List).join('\n')}", style: const TextStyle(color: Colors.white)))])); }))]))); }
}

// ============================================================================
// ROOM 탭 (스타일 샵 - 가구 구매 로직 적용)
// ============================================================================
class RoomDecorTab extends StatefulWidget {
  final int gold; final int gems; final List<String> ownedBgs; final String selectedBg; final Function(String, int) onBuyBg;
  final List<String> ownedFurniture;
  final List<String> equippedFurniture;
  final Function(String, int) onToggleFurniture;

  const RoomDecorTab({super.key, required this.gold, required this.gems, required this.ownedBgs, required this.selectedBg, required this.onBuyBg, required this.ownedFurniture, required this.equippedFurniture, required this.onToggleFurniture});

  @override
  State<RoomDecorTab> createState() => _RoomDecorTabState();
}

class _RoomDecorTabState extends State<RoomDecorTab> {
  String _interiorCategory = '기본 가구';

  Widget _buildItemCard({IconData? icon, String? imagePath, required String name, required int price}) {
    bool isOwned = widget.ownedFurniture.contains(name);
    bool isEquipped = widget.equippedFurniture.contains(name);

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16), border: Border.all(color: isEquipped ? Colors.greenAccent : (isOwned ? Colors.amber : Colors.blueGrey.withOpacity(0.5)), width: isEquipped || isOwned ? 2 : 1)),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imagePath != null)
              Image.asset('assets/$imagePath', height: 45, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.white54, size: 30))
            else if (icon != null)
              Icon(icon, size: 40, color: Colors.white70),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.monetization_on, color: Colors.yellow, size: 12), const SizedBox(width: 4), Text('$price', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12))]),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => widget.onToggleFurniture(name, price),
              style: ElevatedButton.styleFrom(
                backgroundColor: isEquipped ? Colors.redAccent.withOpacity(0.8) : (isOwned ? Colors.blueAccent : Colors.amber),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                minimumSize: const Size(60, 26),
              ),
              child: Text(isEquipped ? '배치 해제' : (isOwned ? '배치하기' : '구매하기'), style: TextStyle(color: isEquipped || isOwned ? Colors.white : Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
            )
          ]
      ),
    );
  }

  Widget _buildBgCard(String name, int price, String assetPath) {
    bool isOwned = widget.ownedBgs.contains(name); bool isSelected = widget.selectedBg == name;
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? Colors.amber : Colors.blueGrey.withOpacity(0.5), width: isSelected ? 2 : 1), image: assetPath.isNotEmpty ? DecorationImage(image: AssetImage(assetPath), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken)) : null),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 8),
          if (!isOwned) Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.monetization_on, color: Colors.yellow, size: 14), const SizedBox(width: 4), Text('$price', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))]), const SizedBox(height: 12),
          ElevatedButton(onPressed: isSelected ? null : () => widget.onBuyBg(name, price), style: ElevatedButton.styleFrom(backgroundColor: isSelected ? Colors.grey : (isOwned ? Colors.blueAccent : Colors.amber), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), minimumSize: const Size(60, 30)), child: Text(isSelected ? '적용됨' : (isOwned ? '적용하기' : '구매하기'), style: TextStyle(color: isSelected ? Colors.white54 : (isOwned ? Colors.white : Colors.black), fontSize: 12, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('STYLE SHOP', style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
                Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.monetization_on, color: Colors.yellow, size: 16), const SizedBox(width: 4), Text('${widget.gold}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]))]),
              ],
            ),
            const SizedBox(height: 20),
            const TabBar(indicatorColor: Colors.amber, labelColor: Colors.amber, unselectedLabelColor: Colors.white54, tabs: [Tab(icon: Icon(Icons.chair), text: "인테리어"), Tab(icon: Icon(Icons.checkroom), text: "의상"), Tab(icon: Icon(Icons.wallpaper), text: "배경")]),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                children: [
                  Column(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(label: const Text('기본 가구'), selected: _interiorCategory == '기본 가구', onSelected: (val) => setState(() => _interiorCategory = '기본 가구'), selectedColor: Colors.amber.withOpacity(0.3), backgroundColor: Colors.transparent), const SizedBox(width: 8),
                            ChoiceChip(label: const Text('💪 헬스장'), selected: _interiorCategory == '헬스장 인테리어', onSelected: (val) => setState(() => _interiorCategory = '헬스장 인테리어'), selectedColor: Colors.amber.withOpacity(0.3), backgroundColor: Colors.transparent), const SizedBox(width: 8),
                            ChoiceChip(label: const Text('🏊 수영장'), selected: _interiorCategory == '수영장 인테리어', onSelected: (val) => setState(() => _interiorCategory = '수영장 인테리어'), selectedColor: Colors.amber.withOpacity(0.3), backgroundColor: Colors.transparent), const SizedBox(width: 8),
                            ChoiceChip(label: const Text('🍳 주방'), selected: _interiorCategory == '주방 인테리어', onSelected: (val) => setState(() => _interiorCategory = '주방 인테리어'), selectedColor: Colors.amber.withOpacity(0.3), backgroundColor: Colors.transparent),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _interiorCategory == '기본 가구'
                            ? const Center(child: Text("기본 가구 에셋이 비어있습니다.", style: TextStyle(color: Colors.white54)))
                            : _interiorCategory == '헬스장 인테리어'
                            ? GridView.count(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, children: [
                          _buildItemCard(imagePath: 'power_rack.png', name: '파워 랙', price: 1500),
                          _buildItemCard(imagePath: 'treadmill.png', name: '런닝머신', price: 1200),
                          _buildItemCard(imagePath: 'cable.png', name: '케이블 머신', price: 1800),
                          _buildItemCard(imagePath: 'dumbel.png', name: '덤벨 세트', price: 500),
                          _buildItemCard(imagePath: 'poster.png', name: '동기부여 포스터', price: 200)
                        ])
                            : _interiorCategory == '수영장 인테리어'
                            ? GridView.count(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, children: [
                          _buildItemCard(imagePath: 'safety.png', name: '안전 수칙', price: 100),
                          _buildItemCard(imagePath: 'caution.png', name: '경고 표지판', price: 100),
                          _buildItemCard(imagePath: 'emergency_kit.png', name: '응급 처치함', price: 300),
                          _buildItemCard(imagePath: 'tube.png', name: '구명 튜브', price: 500),
                          _buildItemCard(imagePath: 'fin.png', name: '오리발 보관함', price: 800),
                          _buildItemCard(imagePath: 'equipment.png', name: '수영 장비장', price: 1000)
                        ])
                            : const Center(child: Text("주방 가구가 곧 추가됩니다.", style: TextStyle(color: Colors.white54))),
                      ),
                    ],
                  ),
                  GridView.count(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, children: [_buildItemCard(icon: Icons.directions_run, name: '스포티 러닝복', price: 400), _buildItemCard(icon: Icons.accessibility_new, name: '캐주얼 후디', price: 250), _buildItemCard(icon: Icons.business_center, name: '모던 정장', price: 900), _buildItemCard(icon: Icons.snowshoeing, name: '고어텍스 등산복', price: 600), _buildItemCard(icon: Icons.face, name: '쿨 선글라스', price: 150), _buildItemCard(icon: Icons.watch, name: '스마트 워치', price: 700)]),
                  GridView.count(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, children: [_buildBgCard('주방', 1000, 'assets/kitchen_background.png'), _buildBgCard('헬스장', 1500, 'assets/gym_background.png'), _buildBgCard('수영장', 2000, 'assets/pool_background.png'), _buildBgCard('기본', 0, '')]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}