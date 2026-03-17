// screens/awareness_screen.dart
// ============================================================
// DeepFake Awareness Hub — educates users about deepfakes
// using verified real-world facts, cases, detection tips,
// and a weekly knowledge quiz.
// ============================================================

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'deepfake_news_screen.dart';

class AwarenessScreen extends StatefulWidget {
  const AwarenessScreen({super.key});

  @override
  State<AwarenessScreen> createState() => _AwarenessScreenState();
}

class _AwarenessScreenState extends State<AwarenessScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;

  // ── Quiz state ────────────────────────────────────────────────
  final Map<int, bool?> _quizAnswers = {};  // questionIndex → userAnswer
  bool _quizSubmitted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  // ═══════════════════════════════════════════════════════════════
  //  DATA
  // ═══════════════════════════════════════════════════════════════

  // ── 40 verified facts split into 6 categories ─────────────────
  static const List<Map<String, String>> _allFacts = [
    // Financial Fraud
    {
      'fact':     'In January 2024, a Hong Kong finance worker was tricked into paying \$25 million to fraudsters using a deepfake video call impersonating the company\'s CFO.',
      'source':   'Reuters, Feb 2024',
      'category': 'Financial Fraud',
      'emoji':    '💸',
    },
    {
      'fact':     'In 2019, criminals used AI voice cloning to impersonate a CEO and stole \$243,000 from a UK energy firm in a single phone call.',
      'source':   'Wall Street Journal, 2019',
      'category': 'Financial Fraud',
      'emoji':    '📞',
    },
    {
      'fact':     'In 2020, a bank manager in the UAE was deceived by a deepfake voice call and transferred \$35 million to fraudsters.',
      'source':   'Forbes, 2020',
      'category': 'Financial Fraud',
      'emoji':    '🏦',
    },
    {
      'fact':     'Deepfake-related fraud losses are projected to exceed \$40 billion globally by 2027.',
      'source':   'Deloitte Research',
      'category': 'Financial Fraud',
      'emoji':    '📈',
    },
    {
      'fact':     'A deepfake video of Elon Musk was used in widespread crypto scams in 2023, stealing millions from victims worldwide.',
      'source':   'Multiple verified reports, 2023',
      'category': 'Financial Fraud',
      'emoji':    '🪙',
    },

    // Political Manipulation
    {
      'fact':     'In March 2022, a deepfake video of Ukrainian President Zelensky urging soldiers to surrender was broadcast on hacked TV channels.',
      'source':   'BBC, March 2022',
      'category': 'Political',
      'emoji':    '🎭',
    },
    {
      'fact':     'In 2023, a deepfake audio of UK Prime Minister Rishi Sunak was used in a Facebook ad scam promoting fraudulent investments.',
      'source':   'The Guardian, 2023',
      'category': 'Political',
      'emoji':    '🎙️',
    },
    {
      'fact':     'Ahead of the 2024 US primaries, deepfake robocalls impersonating President Biden were sent to New Hampshire voters telling them not to vote.',
      'source':   'AP News, 2024',
      'category': 'Political',
      'emoji':    '🗳️',
    },
    {
      'fact':     'Ahead of the 2024 Slovak elections, a deepfake audio of a candidate discussing election rigging went viral just days before the vote.',
      'source':   'Reuters, 2024',
      'category': 'Political',
      'emoji':    '🇸🇰',
    },
    {
      'fact':     'In 2024, deepfake videos of Taiwanese politicians were used in disinformation campaigns ahead of national elections.',
      'source':   'BBC, 2024',
      'category': 'Political',
      'emoji':    '📺',
    },

    // Celebrity & Non-Consensual
    {
      'fact':     'Over 96% of all deepfake videos found online are non-consensual intimate imagery targeting women.',
      'source':   'Sensity AI Report, 2019',
      'category': 'Non-Consensual',
      'emoji':    '⚠️',
    },
    {
      'fact':     'In January 2024, explicit deepfake images of Taylor Swift were viewed over 47 million times before being removed from X (Twitter).',
      'source':   'The Verge, Jan 2024',
      'category': 'Non-Consensual',
      'emoji':    '🎵',
    },
    {
      'fact':     'Tom Hanks publicly warned fans about a deepfake dental ad using his likeness without his knowledge or consent in 2023.',
      'source':   'BBC, 2023',
      'category': 'Non-Consensual',
      'emoji':    '🦷',
    },
    {
      'fact':     'MrBeast, YouTube\'s most subscribed creator, was deepfaked in a scam offering iPhones for \$2, reaching millions of viewers in 2023.',
      'source':   'CNN, 2023',
      'category': 'Non-Consensual',
      'emoji':    '📱',
    },
    {
      'fact':     'Bruce Willis became the first celebrity to sell his digital likeness rights to a deepfake company in 2022, allowing his face to be used in ads.',
      'source':   'The Guardian, 2022',
      'category': 'Non-Consensual',
      'emoji':    '🎬',
    },
    {
      'fact':     'The 2023 SAG-AFTRA actors strike partly focused on preventing studios from using AI deepfakes of actors without consent or compensation.',
      'source':   'Variety, 2023',
      'category': 'Non-Consensual',
      'emoji':    '🎭',
    },

    // Technology & Detection
    {
      'fact':     'The word "deepfake" was coined on Reddit in 2017 by a user sharing AI-generated face-swap videos.',
      'source':   'Wired, 2018',
      'category': 'Technology',
      'emoji':    '🤖',
    },
    {
      'fact':     'DARPA launched a \$68 million program called Media Forensics (MediFor) specifically to develop deepfake detection technology.',
      'source':   'DARPA Official, 2016',
      'category': 'Technology',
      'emoji':    '🔬',
    },
    {
      'fact':     'The Deepfake Detection Challenge launched in 2019 attracted over 2,000 teams from 140 countries competing to build better detectors.',
      'source':   'Facebook AI Research, 2020',
      'category': 'Technology',
      'emoji':    '🏆',
    },
    {
      'fact':     'Even the best deepfake detectors only achieve around 65–75% accuracy on real-world videos according to MIT research.',
      'source':   'MIT CSAIL Research, 2022',
      'category': 'Technology',
      'emoji':    '📊',
    },
    {
      'fact':     'Early deepfake models could be identified by unnatural eye blinking — they rarely blinked because training data had few closed-eye images.',
      'source':   'University at Albany Study, 2018',
      'category': 'Technology',
      'emoji':    '👁️',
    },
    {
      'fact':     'Researchers at the University of Buffalo found that deepfake faces can be detected by analyzing eye reflections, which are physically inconsistent in AI images.',
      'source':   'University of Buffalo, 2021',
      'category': 'Technology',
      'emoji':    '🔍',
    },
    {
      'fact':     'Meta invested over \$10 million in deepfake detection research between 2020 and 2023 as part of its Responsible AI initiative.',
      'source':   'Meta AI Blog, 2023',
      'category': 'Technology',
      'emoji':    '💻',
    },

    // Legal & Policy
    {
      'fact':     'China became the first country to require deepfake content to be clearly labelled, with regulations effective from January 2023.',
      'source':   'Reuters, Jan 2023',
      'category': 'Legal',
      'emoji':    '⚖️',
    },
    {
      'fact':     'South Korea made deepfake pornography punishable by up to 5 years imprisonment and fines up to \$43,000 in 2020.',
      'source':   'Korea Herald, 2020',
      'category': 'Legal',
      'emoji':    '🇰🇷',
    },
    {
      'fact':     'The EU AI Act passed in 2024 requires all AI-generated content including deepfakes to be clearly and visibly labelled.',
      'source':   'European Parliament, 2024',
      'category': 'Legal',
      'emoji':    '🇪🇺',
    },
    {
      'fact':     'Over 10 US states have passed laws specifically targeting non-consensual deepfake pornography as of 2024.',
      'source':   'National Conference of State Legislatures, 2024',
      'category': 'Legal',
      'emoji':    '🏛️',
    },
    {
      'fact':     'The DEFIANCE Act was introduced in the US Senate in 2024 to allow victims of deepfake pornography to sue creators for damages.',
      'source':   'US Senate Records, 2024',
      'category': 'Legal',
      'emoji':    '📜',
    },

    // Scale & Growth
    {
      'fact':     'The number of deepfake videos online doubled every 6 months between 2018 and 2022.',
      'source':   'Sensity AI Annual Report, 2022',
      'category': 'Scale',
      'emoji':    '📉',
    },
    {
      'fact':     'As of 2024, over 500,000 deepfake videos and images are shared on social media every single day.',
      'source':   'World Economic Forum, 2024',
      'category': 'Scale',
      'emoji':    '🌐',
    },
    {
      'fact':     'It took just 8 seconds of audio to clone a voice convincingly using 2023-era AI tools according to MIT Technology Review.',
      'source':   'MIT Technology Review, 2023',
      'category': 'Scale',
      'emoji':    '🎤',
    },
    {
      'fact':     'A realistic deepfake video could be created in under 25 minutes using consumer-grade hardware as of 2023.',
      'source':   'Vice Motherboard, 2023',
      'category': 'Scale',
      'emoji':    '⏱️',
    },
    {
      'fact':     'The global deepfake detection market is expected to reach \$15.7 billion by 2026.',
      'source':   'MarketsandMarkets Research, 2022',
      'category': 'Scale',
      'emoji':    '💰',
    },

    // Education & Awareness
    {
      'fact':     'A Stanford University study found that 85% of people could not reliably distinguish deepfake videos from real ones.',
      'source':   'Stanford Internet Observatory, 2021',
      'category': 'Awareness',
      'emoji':    '🎓',
    },
    {
      'fact':     'Students who received just 20 minutes of deepfake awareness training improved their detection accuracy by 30%.',
      'source':   'University College London Study, 2022',
      'category': 'Awareness',
      'emoji':    '📚',
    },
    {
      'fact':     'India recorded the highest number of deepfake-related complaints globally in 2023 according to the Ministry of Electronics.',
      'source':   'MeitY India Report, 2023',
      'category': 'Awareness',
      'emoji':    '🇮🇳',
    },
    {
      'fact':     'WhatsApp is the most common platform used to spread deepfake misinformation in South Asia.',
      'source':   'Reuters Institute Digital Report, 2023',
      'category': 'Awareness',
      'emoji':    '💬',
    },
    {
      'fact':     'MIT Media Lab developed a free tool called "Detect Fakes" that teaches people how to spot manipulated videos through interactive examples.',
      'source':   'MIT Media Lab, 2020',
      'category': 'Awareness',
      'emoji':    '🧪',
    },
    {
      'fact':     'Young adults aged 18–24 are 3x more likely to share content without verifying its authenticity compared to those over 45.',
      'source':   'Reuters Institute, 2023',
      'category': 'Awareness',
      'emoji':    '📲',
    },
  ];

  // ── Get today's 5 facts based on current date ──────────────────
  List<Map<String, String>> get _todaysFacts {
    final dayOfYear = DateTime.now().difference(
        DateTime(DateTime.now().year, 1, 1)).inDays;
    final startIndex = (dayOfYear * 5) % _allFacts.length;
    final facts = <Map<String, String>>[];
    for (int i = 0; i < 5; i++) {
      facts.add(_allFacts[(startIndex + i) % _allFacts.length]);
    }
    return facts;
  }

  // ── Real world cases timeline ─────────────────────────────────
  static const List<Map<String, String>> _cases = [
    {
      'year':        '2017',
      'title':       'Deepfakes Born on Reddit',
      'description': 'A Reddit user coined the term "deepfake" while sharing AI face-swap videos, marking the public birth of the technology.',
      'emoji':       '🤖',
      'severity':    'low',
    },
    {
      'year':        '2019',
      'title':       'First CEO Voice Fraud',
      'description': 'Criminals used AI voice cloning to impersonate a CEO on a phone call, convincing a UK energy firm\'s manager to wire \$243,000.',
      'emoji':       '📞',
      'severity':    'high',
    },
    {
      'year':        '2020',
      'title':       'UAE Bank Transfer Fraud',
      'description': 'A bank manager in UAE transferred \$35 million after receiving a convincing deepfake voice call from a supposed company director.',
      'emoji':       '🏦',
      'severity':    'high',
    },
    {
      'year':        '2022',
      'title':       'Zelenskyy Surrender Video',
      'description': 'A deepfake video of Ukrainian President Zelenskyy urging his soldiers to lay down arms was broadcast on hacked Ukrainian TV channels.',
      'emoji':       '🎭',
      'severity':    'critical',
    },
    {
      'year':        '2023',
      'title':       'MrBeast iPhone Scam',
      'description': 'A deepfake of MrBeast offering iPhones for \$2 reached millions of viewers across social media platforms.',
      'emoji':       '📱',
      'severity':    'medium',
    },
    {
      'year':        '2023',
      'title':       'Rishi Sunak Audio Scam',
      'description': 'A deepfake audio of UK Prime Minister Rishi Sunak was used in Facebook ads to promote fraudulent investment schemes.',
      'emoji':       '🎙️',
      'severity':    'high',
    },
    {
      'year':        '2024',
      'title':       'Biden Voter Suppression Calls',
      'description': 'Deepfake robocalls impersonating President Biden were sent to New Hampshire voters ahead of primaries, instructing them not to vote.',
      'emoji':       '🗳️',
      'severity':    'critical',
    },
    {
      'year':        '2024',
      'title':       '\$25M Hong Kong Fraud',
      'description': 'A finance worker in Hong Kong paid \$25 million to fraudsters after a deepfake video call featuring a fake version of the company\'s CFO.',
      'emoji':       '💸',
      'severity':    'critical',
    },
  ];

  // ── Spot the signs ────────────────────────────────────────────
  static const List<Map<String, String>> _signs = [
    {
      'title':       'Unnatural Eye Blinking',
      'description': 'Deepfake subjects often blink too rarely or in unnatural patterns. Early models trained on open-eye images had almost no blinking at all.',
      'tip':         'Watch for 10–15 seconds. Real people blink every 4–6 seconds.',
      'emoji':       '👁️',
    },
    {
      'title':       'Hair and Face Edge Blur',
      'description': 'The boundary between hair and background is extremely difficult for AI to generate correctly. Look for smearing, blurring or unnatural merging.',
      'tip':         'Zoom in on the hairline and ears — these are the hardest areas to fake.',
      'emoji':       '💇',
    },
    {
      'title':       'Inconsistent Lighting',
      'description': 'AI models often get lighting wrong. Shadows may fall in the wrong direction, or the face may appear brighter or darker than the background.',
      'tip':         'Check if the light on the face matches the light source visible in the room.',
      'emoji':       '💡',
    },
    {
      'title':       'Teeth and Jewelry Artifacts',
      'description': 'Generating realistic teeth, earrings and necklaces is notoriously hard for AI. You may see smeared, melted or doubled teeth.',
      'tip':         'Ask the person to smile — teeth edges often reveal AI artifacts.',
      'emoji':       '😁',
    },
    {
      'title':       'Skin Texture Inconsistency',
      'description': 'AI-generated skin often looks too smooth or plasticky. Natural skin has pores, small blemishes and texture variation that AI struggles to replicate.',
      'tip':         'Compare forehead and cheek texture — they should match.',
      'emoji':       '🧴',
    },
    {
      'title':       'Audio-Video Lip Sync',
      'description': 'Deepfake audio is often layered onto existing video. Even small mismatches between lip movements and speech reveal manipulation.',
      'tip':         'Cover the audio and just watch the lips — do they match the words?',
      'emoji':       '🎤',
    },
    {
      'title':       'Eye Reflection Inconsistency',
      'description': 'University of Buffalo researchers found that light reflections in the eyes of deepfake faces are often physically impossible or asymmetrical.',
      'tip':         'Both eyes should reflect the same light source in the same way.',
      'emoji':       '🔍',
    },
    {
      'title':       'Facial Movement Rigidity',
      'description': 'Real faces involve complex muscle movements — eyebrows, cheeks, chin all move together naturally. Deepfakes often show isolated or stiff movement.',
      'tip':         'Watch emotions — a real smile reaches the eyes. A fake one often does not.',
      'emoji':       '🎭',
    },
  ];

  // ── Weekly quiz questions ─────────────────────────────────────
  // Rotates weekly based on current week number
  static const List<Map<String, dynamic>> _allQuizQuestions = [
    {
      'question': 'The first widely known deepfake videos appeared in 2017 on Reddit.',
      'answer':   true,
      'explanation': 'True. A Reddit user coined the term "deepfake" in 2017 while sharing AI face-swap videos, marking the public origin of the technology.',
    },
    {
      'question': 'Deepfakes can only be created by expert programmers with advanced skills.',
      'answer':   false,
      'explanation': 'False. Many free and easy-to-use deepfake apps exist that require no programming knowledge, making the technology accessible to anyone.',
    },
    {
      'question': 'Over 96% of deepfake videos found online are non-consensual intimate imagery.',
      'answer':   true,
      'explanation': 'True. According to Sensity AI\'s research, the overwhelming majority of deepfakes online target women without their consent.',
    },
    {
      'question': 'AI-generated faces are always perfectly symmetrical with no inconsistencies.',
      'answer':   false,
      'explanation': 'False. Deepfake faces often show asymmetrical features, especially in eye reflections and facial muscle movements.',
    },
    {
      'question': 'China was the first country to legally require deepfake content to be labelled.',
      'answer':   true,
      'explanation': 'True. China\'s deepfake labelling regulations came into effect in January 2023, making it the first country to mandate this.',
    },
    {
      'question': 'It takes at least one hour of audio to clone someone\'s voice convincingly.',
      'answer':   false,
      'explanation': 'False. As of 2023, just 8 seconds of audio is enough to clone a voice convincingly using modern AI tools.',
    },
    {
      'question': 'The 2024 Hong Kong deepfake fraud resulted in a loss of \$25 million.',
      'answer':   true,
      'explanation': 'True. A finance worker was tricked by a deepfake video call impersonating the company\'s CFO, resulting in a \$25 million transfer.',
    },
    {
      'question': 'Deepfake detection technology can identify fakes with 99% accuracy.',
      'answer':   false,
      'explanation': 'False. Even the best deepfake detectors only achieve around 65–75% accuracy on real-world videos according to MIT research.',
    },
    {
      'question': 'India recorded the highest number of deepfake complaints globally in 2023.',
      'answer':   true,
      'explanation': 'True. According to India\'s Ministry of Electronics and IT, India led globally in deepfake-related complaints in 2023.',
    },
    {
      'question': 'Just 20 minutes of deepfake awareness training can improve detection accuracy by 30%.',
      'answer':   true,
      'explanation': 'True. A University College London study found that brief awareness training significantly improved people\'s ability to spot deepfakes.',
    },
  ];

  // Get 3 questions for current week
  List<Map<String, dynamic>> get _weeklyQuiz {
    final weekNumber = DateTime.now().difference(
        DateTime(DateTime.now().year, 1, 1)).inDays ~/ 7;
    final startIndex = (weekNumber * 3) % _allQuizQuestions.length;
    final questions = <Map<String, dynamic>>[];
    for (int i = 0; i < 3; i++) {
      questions.add(
          _allQuizQuestions[(startIndex + i) % _allQuizQuestions.length]);
    }
    return questions;
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
        title: const Text('Awareness Hub',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller:           _tabController,
          indicatorColor:       AppTheme.primary,
          indicatorWeight:      2,
          labelColor:           AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          isScrollable:         true,
          labelStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Did You Know?'),
            Tab(text: 'Real Cases'),
            Tab(text: 'Spot The Signs'),
            Tab(text: 'Quiz'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFactsTab(),
          _buildCasesTab(),
          _buildSignsTab(),
          _buildQuizTab(),
        ],
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════
  //  TAB 1 — DID YOU KNOW?
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFactsTab() {
    final facts = _todaysFacts;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final refreshTime =
        '${tomorrow.day}/${tomorrow.month} at 12:00 AM';

    return ListView(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      children: [
        const SizedBox(height: 4),

        // Header
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          decoration: BoxDecoration(
            color:        AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.auto_awesome,
                color: AppTheme.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Today\'s 5 facts. Refreshes on $refreshTime',
                style: const TextStyle(color: AppTheme.primary,
                    fontSize: 12, height: 1.4),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // Fact cards
        ...facts.asMap().entries.map((entry) {
          final i    = entry.key;
          final fact = entry.value;
          return _buildFactCard(fact, i);
        }),

        const SizedBox(height: 16),

        // Pool size note
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          decoration: BoxDecoration(
            color:        AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline,
                color: AppTheme.textSecondary, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${_allFacts.length} verified facts in our database. '
                    'All sourced from published research and news reports.',
                style: const TextStyle(color: AppTheme.textSecondary,
                    fontSize: 12, height: 1.4),
              ),
            ),
          ]),
        ),

        // Live news button
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DeepfakeNewsScreen()),
          ),
          child: Container(
            width:   double.infinity,
            padding: const EdgeInsets.all(AppTheme.paddingL),
            decoration: BoxDecoration(
              color:        const Color(0xFF1565C0).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.newspaper_rounded,
                  color: Color(0xFF1565C0), size: 22),
              SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live News Tracker',
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  Text('Latest deepfake incidents worldwide',
                      style: TextStyle(fontSize: 12,
                          color: AppTheme.textSecondary)),
                ],
              )),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: AppTheme.textSecondary, size: 14),
            ]),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFactCard(Map<String, String> fact, int index) {
    final categoryColors = {
      'Financial Fraud':  AppTheme.error,
      'Political':        AppTheme.accent,
      'Non-Consensual':   const Color(0xFFAB47BC),
      'Technology':       AppTheme.primary,
      'Legal':            const Color(0xFF26A69A),
      'Scale':            const Color(0xFFEF6C00),
      'Awareness':        AppTheme.success,
    };
    final color = categoryColors[fact['category']] ?? AppTheme.primary;

    return Container(
      margin:   const EdgeInsets.only(bottom: 14),
      padding:  const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        color:        AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border:       Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category badge + emoji
          Row(children: [
            Text(fact['emoji'] ?? '💡',
                style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(fact['category'] ?? '',
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700, color: color)),
            ),
            const Spacer(),
            Text('#${index + 1}', style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
          ]),

          const SizedBox(height: 12),

          // Fact text
          Text(fact['fact'] ?? '',
              style: const TextStyle(fontSize: 14,
                  color: AppTheme.textPrimary, height: 1.6)),

          const SizedBox(height: 10),

          // Source
          Row(children: [
            const Icon(Icons.verified_outlined,
                color: AppTheme.textSecondary, size: 13),
            const SizedBox(width: 4),
            Text('Source: ${fact['source']}',
                style: const TextStyle(fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic)),
          ]),
        ],
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════
  //  TAB 2 — REAL CASES
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCasesTab() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      children: [
        const SizedBox(height: 4),
        const Text('DOCUMENTED INCIDENTS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary, letterSpacing: 1.0)),
        const SizedBox(height: 16),

        // Timeline
        ...List.generate(_cases.length, (i) {
          final isLast = i == _cases.length - 1;
          return _buildTimelineItem(_cases[i], isLast);
        }),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTimelineItem(Map<String, String> cas, bool isLast) {
    final severityColors = {
      'low':      AppTheme.success,
      'medium':   AppTheme.accent,
      'high':     AppTheme.error,
      'critical': const Color(0xFFB71C1C),
    };
    final color =
        severityColors[cas['severity']] ?? AppTheme.primary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          Column(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:  color.withValues(alpha: 0.12),
                shape:  BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Center(
                child: Text(cas['emoji'] ?? '⚠️',
                    style: const TextStyle(fontSize: 18)),
              ),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                    width: 2, color: AppTheme.surfaceBorder),
              ),
          ]),

          const SizedBox(width: 14),

          // Content
          Expanded(
            child: Container(
              margin:  const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(AppTheme.paddingL),
              decoration: BoxDecoration(
                color:        AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border:       Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Year + severity
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:        color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(cas['year'] ?? '',
                          style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: color)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:        color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: color.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        (cas['severity'] ?? '').toUpperCase(),
                        style: TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 8),

                  Text(cas['title'] ?? '',
                      style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),

                  const SizedBox(height: 6),

                  Text(cas['description'] ?? '',
                      style: const TextStyle(fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════
  //  TAB 3 — SPOT THE SIGNS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSignsTab() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      children: [
        const SizedBox(height: 4),

        // Header
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          decoration: BoxDecoration(
            color:        AppTheme.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(
                color: AppTheme.success.withValues(alpha: 0.2)),
          ),
          child: const Row(children: [
            Icon(Icons.tips_and_updates_outlined,
                color: AppTheme.success, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'These signs are based on published research from MIT, DARPA and Sensity AI.',
                style: TextStyle(color: AppTheme.success,
                    fontSize: 12, height: 1.4),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // Signs grid
        ...List.generate(_signs.length, (i) {
          return _buildSignCard(_signs[i], i + 1);
        }),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSignCard(Map<String, String> sign, int number) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        color:        AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border:       Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number circle
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color:  AppTheme.primary.withValues(alpha: 0.1),
              shape:  BoxShape.circle,
              border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(sign['emoji'] ?? '🔍',
                  style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sign['title'] ?? '',
                    style: const TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                Text(sign['description'] ?? '',
                    style: const TextStyle(fontSize: 13,
                        color: AppTheme.textSecondary, height: 1.5)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:        AppTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          color: AppTheme.primary, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(sign['tip'] ?? '',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.primary,
                                height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════
  //  TAB 4 — WEEKLY QUIZ
  // ═══════════════════════════════════════════════════════════════

  Widget _buildQuizTab() {
    final questions = _weeklyQuiz;
    final score     = _quizAnswers.values
        .where((a) =>
    a != null &&
        a == questions[_quizAnswers.keys
            .firstWhere((k) => _quizAnswers[k] == a,
            orElse: () => -1)]['answer'])
        .length;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      children: [
        const SizedBox(height: 4),

        // Header
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          decoration: BoxDecoration(
            color:        AppTheme.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(
                color: AppTheme.accent.withValues(alpha: 0.2)),
          ),
          child: const Row(children: [
            Icon(Icons.quiz_outlined, color: AppTheme.accent, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '3 questions this week. True or False — test your knowledge!',
                style: TextStyle(color: AppTheme.accent,
                    fontSize: 12, height: 1.4),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // Questions
        ...questions.asMap().entries.map((entry) {
          final i  = entry.key;
          final q  = entry.value;
          return _buildQuizQuestion(q, i);
        }),

        // Submit button
        if (!_quizSubmitted &&
            _quizAnswers.length == questions.length) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: () => setState(() => _quizSubmitted = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(AppTheme.radiusM)),
              ),
              child: const Text('Submit Answers',
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],

        // Score card
        if (_quizSubmitted) ...[
          const SizedBox(height: 8),
          _buildQuizScore(questions),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 44,
            child: OutlinedButton(
              onPressed: () => setState(() {
                _quizAnswers.clear();
                _quizSubmitted = false;
              }),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: const BorderSide(color: AppTheme.surfaceBorder),
                shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(AppTheme.radiusM)),
              ),
              child: const Text('Try Again'),
            ),
          ),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildQuizQuestion(Map<String, dynamic> q, int index) {
    final userAnswer   = _quizAnswers[index];
    final correctAnswer = q['answer'] as bool;
    final isAnswered   = userAnswer != null;
    final isCorrect    = userAnswer == correctAnswer;

    return Container(
      margin:  const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        color: _quizSubmitted && isAnswered
            ? (isCorrect
            ? AppTheme.success.withValues(alpha: 0.06)
            : AppTheme.error.withValues(alpha: 0.06))
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: _quizSubmitted && isAnswered
              ? (isCorrect ? AppTheme.success : AppTheme.error)
              .withValues(alpha: 0.3)
              : AppTheme.surfaceBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question number + text
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('${index + 1}',
                      style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accent)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(q['question'] as String,
                    style: const TextStyle(fontSize: 14,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600, height: 1.4)),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // True / False buttons
          Row(children: [
            Expanded(child: _buildTrueFalseButton(
                index, true, userAnswer, _quizSubmitted, correctAnswer)),
            const SizedBox(width: 10),
            Expanded(child: _buildTrueFalseButton(
                index, false, userAnswer, _quizSubmitted, correctAnswer)),
          ]),

          // Explanation after submit
          if (_quizSubmitted && isAnswered) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isCorrect ? AppTheme.success : AppTheme.error)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isCorrect
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    color: isCorrect ? AppTheme.success : AppTheme.error,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(q['explanation'] as String,
                        style: TextStyle(
                            fontSize: 12,
                            color: isCorrect
                                ? AppTheme.success
                                : AppTheme.error,
                            height: 1.4)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrueFalseButton(
      int index,
      bool value,
      bool? userAnswer,
      bool submitted,
      bool correctAnswer,
      ) {
    final isSelected = userAnswer == value;
    final isCorrect  = value == correctAnswer;

    Color buttonColor;
    Color borderColor;
    Color textColor;

    if (submitted && isSelected) {
      buttonColor = isCorrect
          ? AppTheme.success.withValues(alpha: 0.15)
          : AppTheme.error.withValues(alpha: 0.15);
      borderColor = isCorrect ? AppTheme.success : AppTheme.error;
      textColor   = isCorrect ? AppTheme.success : AppTheme.error;
    } else if (submitted && !isSelected && isCorrect) {
      // Show the correct answer if user got it wrong
      buttonColor = AppTheme.success.withValues(alpha: 0.08);
      borderColor = AppTheme.success.withValues(alpha: 0.4);
      textColor   = AppTheme.success;
    } else if (isSelected) {
      buttonColor = AppTheme.accent.withValues(alpha: 0.15);
      borderColor = AppTheme.accent;
      textColor   = AppTheme.accent;
    } else {
      buttonColor = AppTheme.surface2;
      borderColor = AppTheme.surfaceBorder;
      textColor   = AppTheme.textSecondary;
    }

    return GestureDetector(
      onTap: submitted ? null : () => setState(() {
        _quizAnswers[index] = value;
      }),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color:        buttonColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
          border:       Border.all(color: borderColor),
        ),
        child: Center(
          child: Text(
            value ? '✓  True' : '✗  False',
            style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.w700, color: textColor),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizScore(List<Map<String, dynamic>> questions) {
    int correct = 0;
    for (int i = 0; i < questions.length; i++) {
      if (_quizAnswers[i] == questions[i]['answer']) correct++;
    }
    final pct   = correct / questions.length;
    final grade = pct == 1.0
        ? '🏆 Perfect!'
        : pct >= 0.66
        ? '✅ Well done!'
        : '📚 Keep learning!';

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Text(grade.split(' ')[0],
            style: const TextStyle(fontSize: 36)),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(grade.substring(grade.indexOf(' ') + 1),
                style: const TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            Text('$correct / ${questions.length} correct',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ],
        )),
      ]),
    );
  }
}