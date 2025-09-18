import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import 'all_cases_screen.dart';
import 'case_types_stats.dart';
import '../widgets/my_cases_detail_bottom_view.dart';
import 'archived_cases_screen.dart';
import 'my_cases_screen.dart';
import 'login_screen.dart';
import 'create_case_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  String? _error;

  int _totalCases = 0;
  int _myCasesCount = 0;
  int _confirmedCount = 0;

  // all case types returned by the backend (sorted descending by total)
  List<CaseTypeShort> _caseTypes = [];

  // API base
  final String _base = 'https://health-case-tracker-backend-o82a.onrender.com/api';

  // display control — now 3 columns so three cards fit in a row
  static const int _columns = 3;
  static const int _initialRows = 2; // two horizontal lines (rows)
  static const int _initialVisibleCount = _columns * _initialRows; // 6 visible initially
  bool _isExpanded = false;

  // bottom nav
  int _selectedIndex = 0;

  // keep refresh key for child My Cases panel
  final GlobalKey<_MyCasesPanelState> _myCasesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<String> _token() async {
    return Provider.of<AuthProvider>(context, listen: false).user!.token;
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Future.wait([_loadCounts(), _loadCaseTypeSummary()]);
      if (_myCasesKey.currentState != null) {
        await _myCasesKey.currentState!.fetchMyCases();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load dashboard data';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadCounts() async {
    final token = await _token();

    List<dynamic> allCases = [];

    try {
      final primary = await http.get(Uri.parse('$_base/cases/all-officers'), headers: {'Authorization': 'Bearer $token'});
      if (primary.statusCode == 200) {
        allCases = jsonDecode(primary.body) as List<dynamic>;
      } else {
        final root = await http.get(Uri.parse('$_base/cases'), headers: {'Authorization': 'Bearer $token'});
        if (root.statusCode == 200) {
          allCases = jsonDecode(root.body) as List<dynamic>;
        } else {
          allCases = [];
        }
      }
    } catch (_) {
      allCases = [];
    }

    int confirmed = 0;
    for (final c in allCases) {
      try {
        final s = (c['status'] ?? '').toString().toLowerCase();
        if (s == 'confirmed') confirmed++;
      } catch (_) {}
    }

    int myCount = 0;
    try {
      final myResp = await http.get(Uri.parse('$_base/cases/my-cases'), headers: {'Authorization': 'Bearer $token'});
      if (myResp.statusCode == 200) {
        final list = jsonDecode(myResp.body) as List<dynamic>;
        myCount = list.length;
      } else {
        myCount = 0;
      }
    } catch (_) {
      myCount = 0;
    }
    setState(() {
      _totalCases = allCases.length;
      _confirmedCount = confirmed;
      _myCasesCount = myCount;
    });
  }

  Future<void> _loadCaseTypeSummary() async {
    final token = await _token();
    try {
      final resp = await http.get(Uri.parse('$_base/cases/type-summary'), headers: {'Authorization': 'Bearer $token'});
      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body) as List;
        final List<CaseTypeShort> items = data.map((e) {
          final name = (e['name'] ?? '').toString();
          final total = int.tryParse((e['total'] ?? 0).toString()) ?? 0;
          final id = (e['caseTypeId'] ?? '').toString();
          return CaseTypeShort(id: id, name: name, total: total);
        }).toList();

        items.sort((a, b) => b.total.compareTo(a.total));
        setState(() {
          _caseTypes = items;
          if (_caseTypes.length <= _initialVisibleCount) _isExpanded = true;
        });
      } else {
        setState(() {
          _caseTypes = [];
        });
      }
    } catch (_) {
      setState(() {
        _caseTypes = [];
      });
    }
  }

  Future<void> _openAllCases() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AllCasesScreen()));
    _refreshAll();
  }

  Future<void> _openCaseTypeStats() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CaseTypeStatsScreen()));
    _refreshAll();
  }

  Widget _buildTopCountsRow() {
    Widget smallCard({required String label, required int count, required VoidCallback? onTap}) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                children: [
                  Text(count.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Custom card for "My cases" — archived badge removed per request.
    Widget myCasesCard() {
      return Expanded(
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => setState(() => _selectedIndex = 1),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_myCasesCount.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('My cases', style: TextStyle(fontSize: 12, color: Colors.black87)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        myCasesCard(),
        const SizedBox(width: 8),
        smallCard(label: 'All cases', count: _totalCases, onTap: _openAllCases),
        const SizedBox(width: 8),
        smallCard(label: 'Confirmed', count: _confirmedCount, onTap: null),
      ],
    );
  }

  Widget _buildCaseTypeGrid() {
    final visibleList = _isExpanded ? _caseTypes : _caseTypes.take(_initialVisibleCount).toList();
    final tiles = <Widget>[];

    for (final t in visibleList) {
      tiles.add(_CaseTypeTile(name: t.name, count: t.total));
    }

    // If collapsed and there are more items than visible, add an inline "View more" tile at the end.
    if (!_isExpanded && _caseTypes.length > _initialVisibleCount) {
      tiles.add(_InlineExpandTile(
        label: 'View more',
        onTap: () => setState(() => _isExpanded = true),
      ));
    } else if (_isExpanded && _caseTypes.length > _initialVisibleCount) {
      // When expanded, show a "Show less" tile to collapse back
      tiles.add(_InlineExpandTile(
        label: 'Show less',
        onTap: () => setState(() => _isExpanded = false),
      ));
    }

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: _columns,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      // childAspectRatio tuned for 3-column layout (wider/shorter tiles)
      childAspectRatio: 1.8,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: tiles,
    );
  }

  Widget _dashboardContent() {
    final titleStyle = const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20);

    return Column(
      children: [
        const SizedBox(height: 12),
        // Title + total reported cases count (centered)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Reported cases', style: titleStyle),
            const SizedBox(width: 8),
            Text('(${_totalCases.toString()})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 12),

        // Top counts cards — now stretches full width like the case type summary container.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _buildTopCountsRow(),
        ),

        const SizedBox(height: 16),

        // Case type summary header with "View Details" link (navigates to full stats page)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Expanded(
                child: Text('Case Type Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              TextButton(
                onPressed: _openCaseTypeStats,
                child: const Text('View Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // case type grid (inside white rounded container)
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.96),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _caseTypes.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(_error ?? 'No case type summary available', style: TextStyle(color: Colors.grey.shade700)),
                        )
                      : _buildCaseTypeGrid(),
                  const SizedBox(height: 12),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Build a nav icon widget with optional badge and active highlight.
  Widget _buildNavIcon(IconData iconData, int badgeCount, bool active) {
    final bgColor = active ? Colors.teal.shade50 : Colors.transparent;
    final iconColor = active ? Colors.teal.shade800 : Colors.grey[700];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(iconData, size: 20, color: iconColor),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Center(
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String appBarTitle = _selectedIndex == 0 ? 'Dashboard' : 'My Reported Cases';

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: const Text('Health Case Tracker',
                  style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 0); // stay in Dashboard tab
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('My Cases'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MyCasesScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('All Cases'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AllCasesScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archived Cases'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ArchivedCasesScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Case Types Stats'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CaseTypeStatsScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                final auth =
                    Provider.of<AuthProvider>(context, listen: false);
                await auth.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.teal.shade800, Colors.teal.shade300], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _dashboardContent(),
                    _MyCasesPanel(key: _myCasesKey),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal.shade800,
        unselectedItemColor: Colors.grey.shade700,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        onTap: (i) async {
          setState(() {
            _selectedIndex = i;
          });

          if (i == 0) {
            await _refreshAll();
          } else if (i == 1) {
            if (_myCasesKey.currentState != null) {
              await _myCasesKey.currentState!.fetchMyCases();
            }
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: _buildNavIcon(Icons.dashboard, 0, _selectedIndex == 0),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(Icons.assignment, _myCasesCount, _selectedIndex == 1),
            label: 'My cases',
          ),
        ],
      ),
    );
  }
}

///// Simple model used by the dashboard to display case type summary
class CaseTypeShort {
  final String id;
  final String name;
  final int total;
  CaseTypeShort({required this.id, required this.name, required this.total});
}

/// Reduced-size case type tile suitable for 3-per-row layout
class _CaseTypeTile extends StatelessWidget {
  final String name;
  final int count;
  const _CaseTypeTile({required this.name, required this.count});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(count.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineExpandTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _InlineExpandTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(label == 'View more' ? Icons.expand_more : Icons.expand_less, color: Colors.grey.shade700, size: 18),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

/// --- Inline My Cases Panel (reusable inside Dashboard)
class _MyCasesPanel extends StatefulWidget {
  const _MyCasesPanel({Key? key}) : super(key: key);

  @override
  _MyCasesPanelState createState() => _MyCasesPanelState();
}

class _MyCasesPanelState extends State<_MyCasesPanel> {
  List<dynamic> myCases = [];
  bool isLoading = true;
  String? recentlyUpdatedCaseId;
  String selectedFilter = 'All';

  Future<String> _token() async {
    return Provider.of<AuthProvider>(context, listen: false).user!.token;
  }

  @override
  void initState() {
    super.initState();
    fetchMyCases();
  }

  Future<void> fetchMyCases() async {
    setState(() => isLoading = true);
    try {
      final token = await _token();
      final response = await http.get(
        Uri.parse('https://health-case-tracker-backend-o82a.onrender.com/api/cases/my-cases'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          myCases = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          myCases = [];
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load cases')));
      }
    } catch (e) {
      setState(() {
        myCases = [];
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load cases')));
    }
  }

  Future<void> _navigateToCreateCase() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateCaseScreen()),
    );
    await fetchMyCases();
  }

  Widget _buildCenterAddButton() {
    // Stylish centered circular button for users with no cases
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _navigateToCreateCase,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00796B), Color(0xFF26A69A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.shade700.withOpacity(0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.add, size: 68, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Report your first case',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildRightAddButton() {
    // Small circular add button placed to the right below the filter bar
    return Padding(
      padding: const EdgeInsets.only(right: 16.0, top: 8.0),
      child: Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _navigateToCreateCase,
            borderRadius: BorderRadius.circular(28),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00796B), Color(0xFF26A69A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.shade700.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> updateStatus(String caseId, [String? status, String? patientStatus]) async {
    final token = await _token();

    if (status == 'deleted') {
      final response = await http.delete(
        Uri.parse('https://health-case-tracker-backend-o82a.onrender.com/api/cases/$caseId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() => recentlyUpdatedCaseId = caseId);
        fetchMyCases();
        Future.delayed(const Duration(seconds: 6), () {
          setState(() => recentlyUpdatedCaseId = null);
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Case deleted successfully'), backgroundColor: Colors.red.shade600, behavior: SnackBarBehavior.floating));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Failed to delete case'), backgroundColor: Colors.red.shade600, behavior: SnackBarBehavior.floating));
      }
      return;
    }

    if (status == 'archived') {
      final response = await http.patch(
        Uri.parse('https://health-case-tracker-backend-o82a.onrender.com/api/cases/$caseId/archive'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() => recentlyUpdatedCaseId = caseId);
        fetchMyCases();
        Future.delayed(const Duration(seconds: 6), () {
          setState(() => recentlyUpdatedCaseId = null);
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Case archived'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Failed to archive case'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
      }
      return;
    }

    final response = await http.put(
      Uri.parse('https://health-case-tracker-backend-o82a.onrender.com/api/cases/$caseId/status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (status != null) 'status': status,
        if (patientStatus != null) 'patientStatus': patientStatus,
      }),
    );

    if (response.statusCode == 200) {
      setState(() => recentlyUpdatedCaseId = caseId);
      fetchMyCases();
      Future.delayed(const Duration(seconds: 6), () {
        setState(() => recentlyUpdatedCaseId = null);
      });

      final message = status != null ? 'Case successfully marked as ${status.toUpperCase()}' : 'Patient status updated to $patientStatus';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green.shade700, behavior: SnackBarBehavior.floating));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Failed to update status'), backgroundColor: Colors.red.shade600, behavior: SnackBarBehavior.floating));
    }
  }

  List<Map<String, dynamic>> getFilteredCases() {
    return myCases.where((c) {
      final caseStatus = c['status']?.toString().toLowerCase();
      final patientStatus = c['patient']?['status']?.toString().toLowerCase();

      switch (selectedFilter.toLowerCase()) {
        case 'suspected':
        case 'confirmed':
        case 'not a case':
          return caseStatus == selectedFilter.toLowerCase();
        case 'recovered':
        case 'ongoing treatment':
        case 'deceased':
          return patientStatus == selectedFilter.toLowerCase();
        default:
          return true;
      }
    }).cast<Map<String, dynamic>>().toList();
  }

  Widget caseSummaryCard(Map<String, dynamic> data) {
    String nameOf(dynamic v) {
      if (v == null) return 'N/A';
      if (v is Map) return (v['name'] ?? v['community']?['name'] ?? v['district']?['name'] ?? v['region']?['name'] ?? 'N/A').toString();
      return v.toString();
    }

    final patient = data['patient'] ?? {};
    final ct = data['caseType'];
    final caseType = (ct is Map ? (ct['name'] ?? 'UNKNOWN') : 'UNKNOWN').toString().toUpperCase();

    final caseStatus = (data['status'] ?? 'unknown').toString();
    final timeline = (data['timeline'] ?? '').toString();
    final formattedTimeline = timeline.isNotEmpty ? DateFormat.yMMMd().format(DateTime.tryParse(timeline) ?? DateTime.now()) : 'N/A';

    final hf = data['healthFacility'];
    Map<String, dynamic>? location;
    if (hf is Map) {
      if (hf['location'] is Map) {
        location = Map<String, dynamic>.from(hf['location']);
      } else {
        location = {
          'region': hf['region'],
          'district': hf['district'],
          'subDistrict': hf['subDistrict'],
          'community': hf['community'],
        };
      }
    }

    String displayLocation = 'N/A';
    final caseCommunity = data['community'];
    if (caseCommunity != null) {
      displayLocation = nameOf(caseCommunity);
    } else if (location != null) {
      displayLocation = nameOf(location['community']);
    } else if (hf is Map) {
      displayLocation = nameOf(hf['community']);
    }

    final isRecently = data['_id'] == recentlyUpdatedCaseId;

    Color statusColor = Colors.grey;
    switch (caseStatus.toLowerCase()) {
      case 'suspected':
        statusColor = Colors.orange;
        break;
      case 'confirmed':
        statusColor = Colors.red;
        break;
      case 'not a case':
        statusColor = Colors.green;
        break;
    }

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        builder: (_) => CaseDetailBottomSheet(caseData: data, onUpdate: updateStatus, onRefresh: fetchMyCases),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRecently ? Colors.yellow.shade100 : Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 3, offset: const Offset(2, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(caseType, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(caseStatus.toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: statusColor)),
          ]),
          const SizedBox(height: 4),
          Text.rich(TextSpan(text: 'Reported: ', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]), children: [
            TextSpan(text: '$formattedTimeline · $displayLocation', style: const TextStyle(fontWeight: FontWeight.normal)),
          ])),
          Text.rich(TextSpan(text: 'Person: ', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]), children: [
            TextSpan(text: '${(patient['name'] ?? 'Unknown')} · ${(patient['gender'] ?? 'n/a')}, ${(patient['age'] ?? 'n/a')}yrs'),
          ])),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCases = getFilteredCases();

    return Column(
      children: [
        const SizedBox(height: 16),
        Text('My Reported Cases (${filteredCases.length})', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: Colors.white.withAlpha((0.95 * 255).toInt()), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              children: [
                Container(
                  decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: DropdownButtonFormField<String>(
                    value: selectedFilter,
                    onChanged: (v) => setState(() => selectedFilter = v!),
                    items: [
                      'All',
                      'Suspected',
                      'Confirmed',
                      'Not a Case',
                      'Ongoing Treatment',
                      'Recovered',
                      'Deceased',
                    ].map((label) => DropdownMenuItem(value: label, child: Text(label))).toList(),
                    decoration: InputDecoration(labelText: 'Filter', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.grey[50]),
                  ),
                ),

                // If user has cases, show a small add button aligned to the right
                if (!isLoading && myCases.isNotEmpty) _buildRightAddButton(),

                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : myCases.isEmpty
                          // User has no cases at all -> show large centered stylish "+" to create a case
                          ? _buildCenterAddButton()
                          // User has some cases -> show filtered list (existing logic intact)
                          : filteredCases.isEmpty
                              ? const Center(child: Text('No cases match your filter.'))
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  itemCount: filteredCases.length,
                                  itemBuilder: (ctx, i) => caseSummaryCard(filteredCases[i]),
                                ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
