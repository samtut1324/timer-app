import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:just_audio/just_audio.dart' as ja;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pomodoro Apple Style',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101014),
        textTheme: GoogleFonts.bebasNeueTextTheme(
          Theme.of(context).textTheme,
        ),
        useMaterial3: true,
        // Forcer l'utilisation de Material Design pour Stripe
        materialTapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const PomodoroHomePage(),
    );
  }
}

class PomodoroHomePage extends StatefulWidget {
  const PomodoroHomePage({super.key});

  @override
  State<PomodoroHomePage> createState() => _PomodoroHomePageState();
}

class _PomodoroHomePageState extends State<PomodoroHomePage> with SingleTickerProviderStateMixin {
  int selectedPreset = 0;
  final List<Map<String, int>> presets = [
    {'work': 47, 'break': 13},
    {'work': 94, 'break': 26},
    {'work': 141, 'break': 39},
  ];

  bool isWorking = true;
  bool isRunning = false;
  bool isPaused = false;
  late int totalSeconds;
  late int currentSeconds;
  Timer? _timer;

  int totalSessions = 0;
  int totalFocusMinutes = 0;
  int totalBreakMinutes = 0;
  int totalCycles = 0;
  int totalFocusSessions = 0;

  // Images d'arrière-plan
  final List<String> bgImages = [
    'assets/IMG1.jpg',
    'assets/IMG2.jpg',
    'assets/IMG3.jpg',
  ];
  int bgIndex = 0;

  // Couleur du texte selon luminosité de fond
  Color textColor = Colors.white;

  bool isPremium = false;

  ap.AudioPlayer? _audioPlayer;
  ja.AudioPlayer? _workMusicPlayer;
  double _musicVolume = 0.0;
  final double _maxVolume = 0.5; // Volume max pour la musique de fond
  final Duration _fadeDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _audioPlayer = ap.AudioPlayer();
    _loadStats();
    _resetTimer();
    _updateTextColorForBg();
    _loadPremiumStatus();
  }

  @override
  Future<void> dispose() async {
    _audioPlayer?.dispose();
    await _stopWorkMusic();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    totalSessions = prefs.getInt('totalSessions') ?? 0;
    totalFocusMinutes = prefs.getInt('totalFocusMinutes') ?? 0;
    totalBreakMinutes = prefs.getInt('totalBreakMinutes') ?? 0;
    totalCycles = prefs.getInt('totalCycles') ?? 0;
    totalFocusSessions = prefs.getInt('totalFocusSessions') ?? 0;
    setState(() {});
  }

  Future<void> _saveStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('totalSessions', totalSessions);
    await prefs.setInt('totalFocusMinutes', totalFocusMinutes);
    await prefs.setInt('totalBreakMinutes', totalBreakMinutes);
    await prefs.setInt('totalCycles', totalCycles);
    await prefs.setInt('totalFocusSessions', totalFocusSessions);
  }

  Future<void> _loadPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isPremium = prefs.getBool('isPremium') ?? false;
    });
  }

  void _resetTimer() async {
    setState(() {
      isWorking = true;
      isRunning = false;
      isPaused = false;
      totalSeconds = (isWorking ? presets[selectedPreset]['work']! : presets[selectedPreset]['break']!) * 60;
      currentSeconds = totalSeconds;
      _timer?.cancel();
    });
    await _stopWorkMusic();
  }

  Future<void> _stopWorkMusic() async {
    if (_workMusicPlayer != null) {
      try {
        await _workMusicPlayer!.stop();
        await _workMusicPlayer!.dispose();
        print('MUSIQUE ARRÊTÉE');
      } catch (e) {
        print('Erreur arrêt musique: $e');
      }
      _workMusicPlayer = null;
    }
  }

  void _startTimer() {
    setState(() {
      isRunning = true;
      isPaused = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (currentSeconds > 0) {
        setState(() {
          currentSeconds--;
        });
      } else {
        _switchMode();
      }
    });
  }

  Future<void> _pauseTimer() async {
    _timer?.cancel();
    setState(() {
      isPaused = true;
      isRunning = false;
    });
    await _stopWorkMusic();
  }

  void _resumeTimer() {
    if (isWorking)
    _startTimer();
  }

  Future<void> _switchMode() async {
    setState(() {
      if (!isWorking) {
        totalSessions++;
        totalFocusMinutes += presets[selectedPreset]['work']!;
        totalBreakMinutes += presets[selectedPreset]['break']!;
        totalFocusSessions++;
        _saveStats();
      }
    });
    await _stopWorkMusic();
    setState(() {
      isWorking = !isWorking;
      totalSeconds = (isWorking ? presets[selectedPreset]['work']! : presets[selectedPreset]['break']!) * 60;
      currentSeconds = totalSeconds;
      if (isWorking && isRunning) {
        if (totalFocusSessions % 4 == 0) {
          totalCycles++;
          _saveStats();
        }
      }
    });
  }

  String _formatTime(int seconds) {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return "$min:$sec";
  }

  void _navigateToStats() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatsPage(
          totalSessions: totalSessions,
          totalFocusMinutes: totalFocusMinutes,
          totalBreakMinutes: totalBreakMinutes,
          totalCycles: totalCycles,
          totalFocusSessions: totalFocusSessions,
        ),
      ),
    );
  }

  // Calcule la luminosité moyenne de l'image d'arrière-plan
  Future<double> _calculateImageBrightness(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(byteData.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (pixels == null) return 255;

    int totalLuminance = 0;
    int pixelCount = image.width * image.height;

    for (int i = 0; i < pixels.lengthInBytes; i += 4) {
      final r = pixels.getUint8(i);
      final g = pixels.getUint8(i + 1);
      final b = pixels.getUint8(i + 2);
      // Luminosité perçue
      final lum = 0.299 * r + 0.587 * g + 0.114 * b;
      totalLuminance += lum.toInt();
    }

    return totalLuminance / pixelCount;
  }

  // Met à jour la couleur du texte selon la luminosité du fond
  Future<void> _updateTextColorForBg() async {
    double brightness = await _calculateImageBrightness(bgImages[bgIndex]);
    setState(() {
      textColor = brightness < 128 ? Colors.white : Colors.black;
    });
  }

  // Inverse la couleur noir/blanc pour contraste sur bouton
  Color brightnessInvertColor(Color color) {
    return color == Colors.white ? Colors.black : Colors.white;
  }

  // Change l'image d'arrière-plan et met à jour la couleur du texte
  void _changeBackground() {
    setState(() {
      bgIndex = (bgIndex + 1) % bgImages.length;
    });
    _updateTextColorForBg();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final progress = 1 - currentSeconds / totalSeconds;

    return Scaffold(
      backgroundColor: const Color(0xFFE5D0CC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.only(left: 32.0, right: 32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TIMER',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontSize: 40,
                          letterSpacing: 2,
                          color: const Color(0xFF172121),
                        ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.chart_bar_alt_fill, color: Color(0xFF172121)),
                    onPressed: _navigateToStats,
                    tooltip: 'Statistiques',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: selectedPreset,
                thumbColor: const Color(0xFF172121),
                backgroundColor: const Color(0xFF444554),
                onValueChanged: (int? value) {
                  if (value != null) {
                    setState(() {
                      selectedPreset = value;
                      _resetTimer();
                    });
                  }
                },
                children: {
                  0: _buildSegment('47', '13', selectedPreset == 0),
                  1: _buildSegment('94', '26', selectedPreset == 1),
                  2: _buildSegment('141', '39', selectedPreset == 2),
                },
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: Center(
                child: CustomPaint(
                  size: Size(size.width * 0.7, size.width * 0.7),
                  painter: _RingPainter(progress, ringColor: const Color(0xFF172121), baseColor: const Color(0xFF444554)),
                  child: SizedBox(
                    width: size.width * 0.7,
                    height: size.width * 0.7,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isWorking ? 'WORK' : 'BREAK',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: const Color(0xFF172121),
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _formatTime(currentSeconds),
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF172121),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isRunning)
                    ElevatedButton(
                      onPressed: _pauseTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF172121),
                        foregroundColor: const Color(0xFFE5D0CC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                        elevation: 0,
                      ),
                      child: const Text('PAUSE'),
                    )
                  else if (isPaused)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _resumeTimer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF172121),
                            foregroundColor: const Color(0xFFE5D0CC),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            textStyle: const TextStyle(fontSize: 18),
                            elevation: 0,
                          ),
                          child: const Text('RESUME'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _resetTimer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            textStyle: const TextStyle(fontSize: 18),
                            elevation: 0,
                          ),
                          child: const Text('RESET'),
                        ),
                      ],
                    )
                  else
                    ElevatedButton(
                      onPressed: _startTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF172121),
                        foregroundColor: const Color(0xFFE5D0CC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                        elevation: 0,
                      ),
                      child: const Text('START'),
                    ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegment(String work, String pause, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF172121) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$work / $pause',
        style: TextStyle(
          color: selected ? const Color(0xFFE5D0CC) : const Color(0xFF172121),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}

class StatsPage extends StatelessWidget {
  final int totalSessions;
  final int totalFocusMinutes;
  final int totalBreakMinutes;
  final int totalCycles;
  final int totalFocusSessions;

  const StatsPage({super.key, required this.totalSessions, required this.totalFocusMinutes, required this.totalBreakMinutes, required this.totalCycles, required this.totalFocusSessions});

  @override
  Widget build(BuildContext context) {
    final focusHours = totalFocusMinutes ~/ 60;
    final focusMinutes = totalFocusMinutes % 60;
    final breakHours = totalBreakMinutes ~/ 60;
    final breakMinutes = totalBreakMinutes % 60;
    final avgFocus = totalFocusSessions > 0 ? (totalFocusMinutes / totalFocusSessions).toStringAsFixed(1) : '0';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Statistiques", style: TextStyle(fontSize: 24, color: Color(0xFF172121))),
        backgroundColor: const Color(0xFFE5D0CC),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF172121)),
      ),
      backgroundColor: const Color(0xFFE5D0CC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart, size: 80, color: Color(0xFF172121)),
            const SizedBox(height: 32),
            Text(
              "$totalSessions sessions",
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF172121)),
            ),
            const SizedBox(height: 16),
            Text(
              "$focusHours h ${focusMinutes.toString().padLeft(2, '0')} min de focus",
              style: const TextStyle(fontSize: 22, color: Color(0xFF444554)),
            ),
            const SizedBox(height: 8),
            Text(
              "$breakHours h ${breakMinutes.toString().padLeft(2, '0')} min de pause",
              style: const TextStyle(fontSize: 22, color: Color(0xFF444554)),
            ),
            const SizedBox(height: 8),
            Text(
              "$totalCycles cycles complets",
              style: const TextStyle(fontSize: 22, color: Color(0xFF444554)),
            ),
            const SizedBox(height: 8),
            Text(
              "Focus moyen : $avgFocus min/session",
              style: const TextStyle(fontSize: 22, color: Color(0xFF444554)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color baseColor;
  _RingPainter(this.progress, {this.ringColor = const Color(0xFF172121), this.baseColor = const Color(0xFF444554)});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint base = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    final Paint ring = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    // Anneau de fond
    canvas.drawCircle(size.center(Offset.zero), size.width / 2 - 18, base);
    // Anneau de progression
    double startAngle = -pi / 2;
    double sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - 18),
      startAngle,
      sweepAngle,
      false,
      ring,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.progress != progress;
}