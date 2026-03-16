// screens/challenge_screen.dart
// ============================================================
// Challenge Mode — "Can you spot the fake?"
// 10-round game where users guess REAL or FAKE before the
// timer runs out. Tracks score, combos and shows a grade.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

// ── Data model ────────────────────────────────────────────────────
class ChallengeImage {
  final int    index;
  final String url;
  final String answer; // 'REAL' or 'FAKE'

  const ChallengeImage({
    required this.index,
    required this.url,
    required this.answer,
  });

  factory ChallengeImage.fromJson(Map<String, dynamic> json) =>
      ChallengeImage(
        index:  json['index']  as int,
        url:    json['url']    as String,
        answer: json['answer'] as String,
      );
}

// ── Game state enum ───────────────────────────────────────────────
enum RoundState { waiting, correct, wrong, timeout }

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen>
    with TickerProviderStateMixin {

  // ── Game data ─────────────────────────────────────────────────
  List<ChallengeImage> _images    = [];
  int   _currentIndex  = 0;
  int   _score         = 0;
  int   _combo         = 0;       // Consecutive correct answers
  int   _maxCombo      = 0;
  int   _timeLeft      = 10;      // Seconds per round
  bool  _isLoading     = true;
  bool  _isGameOver    = false;
  bool  _hasGuessed    = false;
  String? _userGuess;             // 'REAL' or 'FAKE'
  RoundState _roundState = RoundState.waiting;

  // Track per-round results for end screen
  final List<bool> _roundResults = [];

  // ── Timer ─────────────────────────────────────────────────────
  Timer?            _timer;
  late AnimationController _timerAnim;

  // ── Feedback animation ────────────────────────────────────────
  late AnimationController _feedbackAnim;
  late Animation<double>   _feedbackScale;

  // ── Card flip animation ───────────────────────────────────────
  late AnimationController _cardAnim;
  late Animation<double>   _cardScale;

  // ── Combo animation ───────────────────────────────────────────
  late AnimationController _comboAnim;
  late Animation<double>   _comboScale;

  @override
  void initState() {
    super.initState();

    // Timer bar animation
    _timerAnim = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 10),
    );

    // Feedback (correct/wrong) pulse
    _feedbackAnim = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 400),
    );
    _feedbackScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _feedbackAnim, curve: Curves.elasticOut),
    );

    // Card entrance scale
    _cardAnim = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 350),
    );
    _cardScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _cardAnim, curve: Curves.easeOut),
    );

    // Combo pop
    _comboAnim = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    );

    _loadRound();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerAnim.dispose();
    _feedbackAnim.dispose();
    _cardAnim.dispose();
    _comboAnim.dispose();
    super.dispose();
  }


  // ── Load 10 images from backend ───────────────────────────────
  Future<void> _loadRound() async {
    setState(() => _isLoading = true);
    try {
      final savedUser = await StorageService.getSavedUser();
      if (savedUser == null) return;

      final response = await http.get(
        Uri.parse(AppConstants.challengeEndpoint),
        headers: {
          'Authorization': 'Bearer ${savedUser.token}',
          'Accept':        'application/json',
        },
      ).timeout(AppConstants.requestTimeout);

      if (response.statusCode == 200) {
        final body   = jsonDecode(response.body) as Map<String, dynamic>;
        final images = (body['images'] as List)
            .map((e) => ChallengeImage.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _images       = images;
          _currentIndex = 0;
          _score        = 0;
          _combo        = 0;
          _maxCombo     = 0;
          _isLoading    = false;
          _isGameOver   = false;
          _roundResults.clear();
        });
        _startRound();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }


  // ── Start a single round ──────────────────────────────────────
  void _startRound() {
    setState(() {
      _timeLeft   = 10;
      _hasGuessed = false;
      _userGuess  = null;
      _roundState = RoundState.waiting;
    });
    _timerAnim.forward(from: 0);
    _cardAnim.forward(from: 0);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        t.cancel();
        _onTimeout();
      }
    });
  }


  // ── User taps REAL or FAKE ────────────────────────────────────
  void _onGuess(String guess) {
    if (_hasGuessed) return;
    _timer?.cancel();
    _timerAnim.stop();

    final correct = guess == _images[_currentIndex].answer;
    HapticFeedback.mediumImpact();

    setState(() {
      _hasGuessed = true;
      _userGuess  = guess;
      _roundState = correct ? RoundState.correct : RoundState.wrong;
      if (correct) {
        _score++;
        _combo++;
        if (_combo > _maxCombo) _maxCombo = _combo;
      } else {
        _combo = 0;
      }
      _roundResults.add(correct);
    });

    _feedbackAnim.forward(from: 0);
    if (_combo >= 3) _comboAnim.forward(from: 0);

    // Auto-advance after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), _nextRound);
  }


  // ── Timer ran out ─────────────────────────────────────────────
  void _onTimeout() {
    if (_hasGuessed) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _hasGuessed = true;
      _roundState = RoundState.timeout;
      _combo      = 0;
      _roundResults.add(false);
    });
    _feedbackAnim.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 1500), _nextRound);
  }


  // ── Move to next round or end game ────────────────────────────
  void _nextRound() {
    if (!mounted) return;
    if (_currentIndex >= _images.length - 1) {
      setState(() => _isGameOver = true);
      HapticFeedback.heavyImpact();
    } else {
      setState(() => _currentIndex++);
      _startRound();
    }
  }


  // ── Grade based on score ──────────────────────────────────────
  Map<String, dynamic> _getGrade() {
    final pct = _score / _images.length;
    if (pct == 1.0) return {'grade': 'S', 'label': 'Perfect!',      'color': const Color(0xFFFFD700)};
    if (pct >= 0.9) return {'grade': 'A', 'label': 'Excellent!',    'color': AppTheme.success};
    if (pct >= 0.7) return {'grade': 'B', 'label': 'Good Job!',     'color': AppTheme.primary};
    if (pct >= 0.5) return {'grade': 'C', 'label': 'Not Bad!',      'color': AppTheme.accent};
    if (pct >= 0.3) return {'grade': 'D', 'label': 'Keep Trying!',  'color': AppTheme.error};
    return           {'grade': 'F', 'label': 'Train Harder!',        'color': AppTheme.error};
  }


  // ── Share score ───────────────────────────────────────────────
  Future<void> _shareScore() async {
    final grade = _getGrade();
    await Share.share(
      'I scored $_score/${_images.length} on TruthLens AI Challenge Mode!\n'
          'Grade: ${grade['grade']} — ${grade['label']}\n'
          'Max combo: $_maxCombo 🔥\n'
          'Can you beat me? #TruthLensAI #DeepfakeChallenge',
    );
  }


  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Challenge Mode',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Round counter in appbar
        actions: [
          if (!_isLoading && !_isGameOver)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentIndex + 1} / ${_images.length}',
                  style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _isGameOver
          ? _buildGameOver()
          : _buildGame(),
    );
  }


  // ── Loading ───────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(color: AppTheme.primary),
        SizedBox(height: 16),
        Text('Loading challenge...', style: TextStyle(
            color: AppTheme.textSecondary, fontSize: 14)),
      ]),
    );
  }


  // ── Main game UI ──────────────────────────────────────────────
  Widget _buildGame() {
    final image = _images[_currentIndex];

    return Column(children: [

      // ── Score + combo bar ──────────────────────────────────
      _buildScoreBar(),

      // ── Timer bar ─────────────────────────────────────────
      _buildTimerBar(),

      const SizedBox(height: 16),

      // ── Combo banner ──────────────────────────────────────
      if (_combo >= 3 && _hasGuessed)
        _buildComboBanner(),

      // ── Image card ────────────────────────────────────────
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ScaleTransition(
            scale: _cardScale,
            child: _buildImageCard(image),
          ),
        ),
      ),

      const SizedBox(height: 20),

      // ── Guess buttons or feedback ──────────────────────────
      _hasGuessed
          ? _buildFeedback()
          : _buildGuessButtons(),

      const SizedBox(height: 32),
    ]);
  }


  // ── Score bar ─────────────────────────────────────────────────
  Widget _buildScoreBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color:   AppTheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Score
          Row(children: [
            const Icon(Icons.star_rounded,
                color: Color(0xFFFFD700), size: 20),
            const SizedBox(width: 6),
            Text('$_score pts', style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary)),
          ]),

          // Round dots
          Row(children: List.generate(_images.length, (i) {
            Color color;
            if (i < _roundResults.length) {
              color = _roundResults[i] ? AppTheme.success : AppTheme.error;
            } else if (i == _currentIndex) {
              color = AppTheme.primary;
            } else {
              color = AppTheme.surfaceBorder;
            }
            return Container(
              width: 8, height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            );
          })),

          // Combo
          Row(children: [
            const Text('🔥', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text('x$_combo', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: _combo >= 3 ? AppTheme.accent : AppTheme.textSecondary)),
          ]),
        ],
      ),
    );
  }


  // ── Timer bar ─────────────────────────────────────────────────
  Widget _buildTimerBar() {
    final color = _timeLeft > 5
        ? AppTheme.success
        : _timeLeft > 3
        ? AppTheme.accent
        : AppTheme.error;

    return Column(children: [
      AnimatedBuilder(
        animation: _timerAnim,
        builder: (_, __) => LinearProgressIndicator(
          value:           1.0 - _timerAnim.value,
          backgroundColor: AppTheme.surfaceBorder,
          valueColor:      AlwaysStoppedAnimation<Color>(color),
          minHeight:       4,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Time left: ${_timeLeft}s',
                style: TextStyle(fontSize: 12, color: color,
                    fontWeight: FontWeight.w600)),
            Text('Spot the deepfake!',
                style: const TextStyle(fontSize: 12,
                    color: AppTheme.textSecondary)),
          ],
        ),
      ),
    ]);
  }


  // ── Combo banner ──────────────────────────────────────────────
  Widget _buildComboBanner() {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
          CurvedAnimation(parent: _comboAnim, curve: Curves.elasticOut)),
      child: Container(
        margin:  const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color:        AppTheme.accent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: AppTheme.accent.withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('🔥', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text('$_combo in a row!',
              style: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w800, color: AppTheme.accent)),
        ]),
      ),
    );
  }


  // ── Image card ────────────────────────────────────────────────
  Widget _buildImageCard(ChallengeImage image) {
    // Overlay color when answered
    Color? overlayColor;
    if (_hasGuessed) {
      if (_roundState == RoundState.correct) {
        overlayColor = AppTheme.success.withOpacity(0.25);
      } else if (_roundState == RoundState.wrong ||
          _roundState == RoundState.timeout) {
        overlayColor = AppTheme.error.withOpacity(0.25);
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: _hasGuessed
              ? (_roundState == RoundState.correct
              ? AppTheme.success
              : AppTheme.error)
              : AppTheme.surfaceBorder,
          width: _hasGuessed ? 2.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color:      AppTheme.primary.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusL - 1),
        child: Stack(fit: StackFit.expand, children: [
          // The face image
          Image.network(
            image.url,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                color: AppTheme.surface,
                child: const Center(child: CircularProgressIndicator(
                    color: AppTheme.primary, strokeWidth: 2)),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              color: AppTheme.surface,
              child: const Center(child: Icon(Icons.broken_image,
                  color: AppTheme.textSecondary, size: 48)),
            ),
          ),

          // Overlay when answered
          if (overlayColor != null)
            Container(color: overlayColor),

          // Answer reveal stamp
          if (_hasGuessed)
            Positioned(
              bottom: 16, right: 16,
              child: ScaleTransition(
                scale: _feedbackScale,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _roundState == RoundState.correct
                        ? AppTheme.success
                        : AppTheme.error,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    image.answer,
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w900, fontSize: 16,
                        letterSpacing: 1),
                  ),
                ),
              ),
            ),

          // "?" overlay before guessing
          if (!_hasGuessed)
            Positioned(
              top: 16, right: 16,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color:  Colors.black.withOpacity(0.5),
                  shape:  BoxShape.circle,
                ),
                child: const Center(
                  child: Text('?', style: TextStyle(color: Colors.white,
                      fontSize: 20, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
        ]),
      ),
    );
  }


  // ── Guess buttons ─────────────────────────────────────────────
  Widget _buildGuessButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        // REAL button
        Expanded(
          child: GestureDetector(
            onTap: () => _onGuess('REAL'),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D2B1F), Color(0xFF0A4A2A)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(color: AppTheme.success.withOpacity(0.5)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_rounded,
                      color: AppTheme.success, size: 22),
                  SizedBox(width: 8),
                  Text('REAL', style: TextStyle(fontSize: 18,
                      fontWeight: FontWeight.w900, color: AppTheme.success,
                      letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // FAKE button
        Expanded(
          child: GestureDetector(
            onTap: () => _onGuess('FAKE'),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2B0D0D), Color(0xFF4A0A0A)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(color: AppTheme.error.withOpacity(0.5)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dangerous_rounded,
                      color: AppTheme.error, size: 22),
                  SizedBox(width: 8),
                  Text('FAKE', style: TextStyle(fontSize: 18,
                      fontWeight: FontWeight.w900, color: AppTheme.error,
                      letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }


  // ── Feedback after guess ──────────────────────────────────────
  Widget _buildFeedback() {
    String emoji;
    String text;
    Color  color;

    switch (_roundState) {
      case RoundState.correct:
        emoji = _combo >= 3 ? '🔥' : '✅';
        text  = _combo >= 3 ? 'On fire!' : 'Correct!';
        color = AppTheme.success;
        break;
      case RoundState.wrong:
        emoji = '❌';
        text  = 'Wrong!';
        color = AppTheme.error;
        break;
      case RoundState.timeout:
        emoji = '⏰';
        text  = 'Too slow!';
        color = AppTheme.accent;
        break;
      default:
        emoji = '';
        text  = '';
        color = AppTheme.textSecondary;
    }

    return ScaleTransition(
      scale: _feedbackScale,
      child: Container(
        margin:  const EdgeInsets.symmetric(horizontal: 20),
        height:  60,
        decoration: BoxDecoration(
          color:        color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border:       Border.all(color: color.withOpacity(0.4)),
        ),
        child: Center(
          child: Text('$emoji  $text',
              style: TextStyle(fontSize: 20,
                  fontWeight: FontWeight.w800, color: color)),
        ),
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════
  //  GAME OVER SCREEN
  // ═══════════════════════════════════════════════════════════════

  Widget _buildGameOver() {
    final grade     = _getGrade();
    final gradeChar = grade['grade']  as String;
    final label     = grade['label']  as String;
    final color     = grade['color']  as Color;
    final accuracy  = (_score / _images.length * 100).toStringAsFixed(0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      child: Column(children: [
        const SizedBox(height: 16),

        // ── Grade circle ───────────────────────────────────
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            shape:  BoxShape.circle,
            color:  color.withOpacity(0.12),
            border: Border.all(color: color, width: 3),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3),
                blurRadius: 24, spreadRadius: 4)],
          ),
          child: Center(
            child: Text(gradeChar, style: TextStyle(fontSize: 56,
                fontWeight: FontWeight.w900, color: color)),
          ),
        ),

        const SizedBox(height: 16),

        Text(label, style: TextStyle(fontSize: 26,
            fontWeight: FontWeight.w900, color: color)),

        const SizedBox(height: 4),

        const Text('Round Complete!',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),

        const SizedBox(height: 28),

        // ── Stats row ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingL),
          decoration: BoxDecoration(
            color:        AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            border:       Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Row(children: [
            _buildStatCol('Score',    '$_score / ${_images.length}', AppTheme.primary),
            _buildStatDivider(),
            _buildStatCol('Accuracy', '$accuracy%',                  color),
            _buildStatDivider(),
            _buildStatCol('Max Combo','$_maxCombo 🔥',               AppTheme.accent),
          ]),
        ),

        const SizedBox(height: 20),

        // ── Round results dots ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingL),
          decoration: BoxDecoration(
            color:        AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            border:       Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ROUND BREAKDOWN',
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.0)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _roundResults.asMap().entries.map((e) {
                  return Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: e.value
                          ? AppTheme.success.withOpacity(0.15)
                          : AppTheme.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: e.value ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                    child: Center(
                      child: Text(e.value ? '✓' : '✗',
                          style: TextStyle(
                              color: e.value ? AppTheme.success : AppTheme.error,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ── Action buttons ──────────────────────────────────
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _shareScore,
              icon:  const Icon(Icons.share_rounded, size: 18),
              label: const Text('Share Score',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side:    const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape:   RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _loadRound,
              icon:  const Icon(Icons.replay_rounded, size: 18),
              label: const Text('Play Again',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape:   RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM)),
              ),
            ),
          ),
        ]),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Home',
                style: TextStyle(color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
        ),

        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildStatCol(String label, String value, Color color) {
    return Expanded(
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11,
            color: AppTheme.textSecondary)),
      ]),
    );
  }

  Widget _buildStatDivider() =>
      Container(width: 1, height: 36, color: AppTheme.surfaceBorder);
}